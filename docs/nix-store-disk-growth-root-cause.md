# Nix store disk-growth root-cause research

## Status

Root cause is **confirmed on `zoidberg` by direct measurement** of the live
profile directory, the GC-root table, and the Determinate collector's
documented policy. Three independent mechanisms combine; none of them alone
explains the growth, and fixing only one leaves the store unbounded.

Measurement baseline (zoidberg, 927 GiB volume, 7.4% free at the time of the
failed rebuild):

| Store fact | Value |
| --- | --- |
| `/nix/store` size | 146 GiB |
| Store paths | 114,321 |
| System generations (`/nix/var/nix/profiles/system-*-link`) | 148 |
| Store paths reachable only from dead roots | 2,701 (2.4%) |
| Indirect GC roots (`/nix/var/nix/gcroots/auto`) | 217 |
| … of those, dangling | 0 |
| … of those, `devenv` shells | 49 |

The decisive number is the last block: **2.4% of the store was collectable.**
A collector running every hour would have reclaimed nothing meaningful,
because 97.6% of the store was pinned by live roots.

## Confirmed root cause

**Retained profile generations are live GC roots, so retention policy — not
collector frequency — is the only thing that bounds store size.** Three facts
compose:

1. **Each retained generation pins its entire closure.** `system-768-link`
   through `system-915-link` were all present, one per `darwin-rebuild
   switch`, at roughly one switch per day. Every one of those symlinks is a
   GC root, so every closure it references is live. Garbage collection is
   definitionally unable to reclaim them. 148 generations of a system closure
   is the 146 GiB.

2. **nix-darwin's `nix.gc` does not exist on this host.** Determinate owns
   `/etc/nix/nix.conf`, which requires `nix.enable = false`
   (`hosts/zoidberg/default.nix`). That option gates `nix.gc.automatic` and
   `nix.optimise.automatic`, so the ordinary NixOS/nix-darwin answer is
   unavailable, and nothing replaced it. The NixOS hosts (`farnsworth`,
   `bender`) keep `nix.gc` because they do not set `nix.enable = false`.

3. **`determinate-nixd`'s collector is a disk-full safety net, not a
   retention policy.** It targets 5-20% free and at least 30 GB, and escalates
   only below 5% free
   ([docs](https://docs.determinate.systems/determinate-nix/determinate-nixd/)).
   On a 927 GiB volume, 7.4% free is *inside* its steady-state band, so it
   was behaving correctly by doing nothing. It also only deletes already-dead
   paths; it never prunes generations, so on this host it had almost nothing
   it was permitted to delete.

`auto-optimise-store = true` (set in `hosts/shared/determinate.nix`) is a real
saving but a misleading one: hardlink deduplication shrinks the *marginal*
cost of each new generation, which lengthens the time before the growth
becomes visible without changing its direction. It also makes a separate
optimise pass pointless — paths are linked as they are written, so a `nix
store optimise` run hashes the whole store and reclaims nothing. Measured
here: `hard linking is currently saving 20.8 GiB` alongside `0.0 KiB freed by
hard-linking 0 files`. The weekly daemon therefore does not pass
`--optimise`.

## Contributing mechanism: cleanup ordered after the build

`scripts/update-system.sh` ran cleanup as an opt-in step *after*
`apply_changes`. A rebuild that exhausts the disk therefore aborts before
reaching the step that would have freed the space, and the next run starts
from the same state — the failure is self-sustaining. A rebuild needs headroom
for the new closure *before* any of the old one can be freed, so the check has
to precede the build.

## Contributing mechanism: unbounded caches outside the store

The store was not even the largest consumer. Caches with no declared bound
held more:

| Path | Size |
| --- | --- |
| `~/.cache/uv/archive-v0` | 158 GiB |
| `~/Library/Group Containers/HUAQ24HBR6.dev.orbstack/data/data.img.raw` | 83 GiB |
| `~/.ollama/models` | 51 GiB |
| `~/.npm` | 42 GiB |
| `~/.cache/codebase-memory-mcp` | 38 GiB |
| `~/.colima` | 24 GiB |

### The uv cache could not be pruned, by construction

This one has its own confirmed root cause, and it is a design flaw in how the
MCP servers are run rather than a missing cron job.

Every MCP server in this configuration is launched as `uv tool uvx --from ...`
or `uv run --script ...`. Each of those processes **holds a shared flock on
`~/.cache/uv/.lock` for its entire lifetime**, confirmed by `lsof`:

```
.uv-wrapp  1185  ...  9u  REG  /Users/C.Hessel/.cache/uv/.lock   # headroom proxy :8787
.uv-wrapp  1190  ...  9u  REG  /Users/C.Hessel/.cache/uv/.lock   # headroom proxy :8788
.uv-wrapp  2541  ...  9u  REG  /Users/C.Hessel/.cache/uv/.lock   # mcp-server-fetch
.uv-wrapp  2595  ...  9u  REG  /Users/C.Hessel/.cache/uv/.lock   # mcp-server-time
.uv-wrapp  2512  ...  9u  REG  /Users/C.Hessel/.cache/uv/.lock   # mcp-profile-gateway
```

Plain `uv cache prune` waits on that lock and then fails:

```
Cache is currently in-use, waiting for other uv processes to finish (use `--force` to override)
error: Timeout (300s) when waiting for lock on `/Users/C.Hessel/.cache/uv`
```

So the prune only succeeds when **no** MCP server is running, which is never
during normal use. `scripts/update-system.sh` additionally guarded its prune
behind "is any uv process running?", which is permanently true for the same
reason — the guard and the lock pointed the same way, and the cache grew to
4,383 `archive-v0` entries of which only 3 were referenced by a running
process.

`uv cache prune --force` skips the **in-use** check, not the **reference**
check: it still keeps entries that a cached environment references, so the
environments live servers execute from survive. That is what the script and
the scheduled agent now run. A total `uv cache clear` does delete those live
environments and will break running MCP servers mid-flight, so it belongs in a
plain terminal with Claude Code and headroom stopped.

### The same pattern in the AI tooling caches

The store and the uv cache are two instances of one shape: **state created
automatically, keyed by something that outlives its referent, never evicted.**
Two more instances live in the agent tooling.

**codebase-memory graphs are keyed per worktree.**
`codebaseMemoryScopedWrapper` (`hosts/shared/ai-agents.nix`) derives the cache
directory from `sha256(absolute git root)[0:12]`. That is deliberate — it is
what stops two worktrees sharing one graph — but it has two consequences:

- every worktree gets its own graph, and they are large (measured: 591-636 MB
  each for five of them), so the 34 live worktrees under
  `~/orca/workspaces/sbp/` are worth ~20 GB if all are indexed;
- the key is one-way, so once a worktree is deleted nothing can tell that its
  entry is unreachable. It survives forever.

That is how the cache reached 38 GiB. The wrapper now writes the git root to
`$cache_dir/.source-path`, and `home/features/cache-hygiene.nix` evicts entries
whose recorded worktree is gone. Entries predating the marker fall back to a
60-day access bound rather than outright deletion, so a live worktree that
simply has not been indexed recently is not thrown away.

**codex session transcripts have no retention.** `~/.codex` held 14 GiB:
`sessions/` 7.9 GiB across 3,053 files, `thread_history_1.sqlite` 1.7 GiB,
`archived_sessions/` 397 MiB. These are recorded history, not derived state, so
the bound is 180 days rather than anything aggressive, and
`thread_history_1.sqlite` is left alone — it is a single database, not a file
tree, and pruning it needs a vacuum rather than an unlink.

**Skills are not a factor.** Worth stating because it is the intuitive place to
look: 42 skills across `~/.claude/skills` (11 MiB), `~/.agents/skills`
(6.6 MiB) and `~/.codex/skills` (568 KiB) total **18 MiB**. Skill count is a
context-window and precedence question, never a disk one.

### Undeclared ollama models

`~/.ollama` held 51 GiB in seven models, none declared anywhere in this repo
and all last modified 16 months before the audit. Only two are referenced by
the configuration: `tavernari/git-commit-message:latest` (the commit-message
workflow) and `mistral:7b` (the local-coding test model). The other five —
`gemma3:27b` (17 GB), `devstral:24b` (14 GB), `gemma3:12b`, `gemma3:4b`,
`llama3.2` — were 44.4 GiB of undeclared drift and were removed; `ollama pull`
restores any of them. `gemma3:27b` would not have been usable on this host's
RAM in any case.

### Undeclared container VM

OrbStack is **not declared anywhere in this repo**, while Colima is (see
`home/features/darwin/shell.nix` and the `DOCKER_CONTEXT=colima` default in
`home/features/ai/crawl4ai.nix`). Two container VMs are installed and only one
is configured; the undeclared one holds 83 GiB in a single sparse image.

## Current policy

Retention is **45 days, minimum 5 generations**, applied uniformly:

| Host | Mechanism |
| --- | --- |
| `zoidberg` (darwin) | `hosts/shared/nix-gc-darwin.nix` — weekly `launchd` daemon running `nh clean all --keep 5 --keep-since 45d --optimise` |
| `farnsworth` (NixOS) | `nix.gc` weekly, `--delete-older-than 45d` |
| `bender` (NixOS-WSL) | `nix.gc` weekly, `--delete-older-than 45d` |
| all hosts | `environment.etc."determinate/config.json"` declares `garbageCollector.strategy = "automatic"` as the low-disk safety net |
| `zoidberg` uv cache | `home/features/cache-hygiene.nix` — weekly agent, `uv cache prune --force` (Sat 04:15) |
| `zoidberg` codebase-memory | same module — weekly agent evicting graphs whose worktree is gone, 60d fallback for unmarked entries (Sat 04:45) |
| `zoidberg` codex sessions | same module — weekly agent, 180d retention on `sessions/` and `archived_sessions/` (Sat 05:15) |
| manual / update runs | `scripts/update-system.sh`, knobs `GC_RETENTION`, `GC_KEEP_MIN`, `MIN_FREE_GIB` |

`nh clean all --keep-since` prunes indirect GC roots by age as well as profile
generations, which is what reclaims the 49 `devenv` shell roots once their
projects go quiet. Those roots are otherwise permanent: `devenv` recreates
them on every shell entry and never expires them, and because the project
directories still exist none of them show up as dangling.

`scripts/update-system.sh` enforces a `MIN_FREE_GIB` floor (default 50) before
`apply_changes`, and offers cleanup first when the floor is not met. The floor
is deliberately far above `determinate-nixd`'s band, because that band is
expressed as a percentage and a system closure is not.

## Investigating a recurrence

```bash
# Is the store actually collectable, or is it all pinned?
find /nix/var/nix/profiles -maxdepth 1 -name 'system-*-link' | wc -l
nix-store --gc --print-dead | wc -l

# Which roots are costing the most (weighted by what GC would really free)
nix-du -s 500MB | tred | dot -Tsvg > /tmp/store.svg

# Which package makes a generation big
nix-tree /run/current-system
nix path-info -rSh /run/current-system | sort -k2 -h | tail -20

# Non-store consumers
dust -d 1 -r ~
ncdu ~

# Who is holding the uv cache lock (and therefore blocking a plain prune)
lsof ~/.cache/uv/.lock
ls ~/.cache/uv/archive-v0 | wc -l
lsof -n | grep -o '/Users/[^/]*/\.cache/uv/archive-v0/[^/]*' | sort -u
```

A `nh clean all --elevation-strategy none` invocation panics when not run as
root — nh resolves an elevation program unconditionally. The launchd daemon is
fine because it already runs as root; a manual run needs `sudo`.
