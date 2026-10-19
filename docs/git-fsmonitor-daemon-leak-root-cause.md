# git core.fsmonitor--daemon process-leak root-cause research

## Status

Root cause is **confirmed against upstream git.git source** (master @
`c51408889c3b372814bc20b9431c3b74d0d268eb`, and cross-checked against the
`v2.55.0` tag this machine actually runs). The mailing-list side of the
investigation (lore.kernel.org) is **blocked in this environment** — every
`lore.kernel.org/git/...` URL, including the raw-mbox endpoint, returns an
Anubis anti-bot JavaScript challenge page (HTTP 200 with a `<script
id="anubis-main">` stub, no article text) rather than content, and
`public-inbox.org` mirrors the same message-ids returned HTTP 502. Where the
background section of this task assumed a specific framing ("no visible
idle-timeout flag" ⇒ "no shutdown mechanism at all"), the source shows that
framing is **half right**: there is a real, working, event-driven
shutdown-on-delete path on macOS, but **no idle/inactivity timeout exists on
any platform**, which is the actual gap that explains this machine's 964
orphans.

## Confirmed root cause

**git's built-in fsmonitor daemon has no concept of "unused" at all — only
"my watched root was removed, and I actually got told about it."** Two
separate, independently-sourced facts combine to produce an unbounded,
one-process-per-path leak in a worktree-churning environment like this one:

1. **There is no idle-timeout / max-age anywhere in git, on any platform, in
   any version checked (`v2.40.0` through current `master`).** The only
   config knobs `builtin/fsmonitor--daemon.c` reads are
   `fsmonitor.ipcthreads` and `fsmonitor.starttimeout` (startup timeout
   only — how long a *client* waits for the daemon to come up, not a
   daemon self-shutdown timer) —
   [`builtin/fsmonitor--daemon.c#L39-L62`](https://github.com/git/git/blob/c51408889c3b372814bc20b9431c3b74d0d268eb/builtin/fsmonitor--daemon.c#L39-L62).
   `Documentation/config/core.adoc`'s `core.fsmonitor` entry documents only
   enabling the feature and a legacy-hook-path compatibility warning for
   git ≤2.35.1 — no lifecycle text at all.

2. **A "health thread" lifecycle-management layer does exist in the
   architecture (one `.ctor/.dtor/.loop/.stop_async` backend per platform,
   wired up in `fsmonitor_run_daemon_1()` —
   [`builtin/fsmonitor--daemon.c#L1249-L1257`](https://github.com/git/git/blob/c51408889c3b372814bc20b9431c3b74d0d268eb/builtin/fsmonitor--daemon.c#L1249-L1257))
   — but it is only *implemented* for Windows.** The Windows backend
   (`compat/fsmonitor/fsm-health-win32.c`) polls every 60 seconds
   (`WAIT_FREQ_MS = 60*1000`) whether the worktree root's unique
   volume-serial+file-index identity still matches what it was at startup,
   and force-shuts-down the daemon if the root was moved/renamed/deleted —
   see the `has_worktree_moved()` doc-comment,
   [`fsm-health-win32.c#L95-L133`](https://github.com/git/git/blob/c51408889c3b372814bc20b9431c3b74d0d268eb/compat/fsmonitor/fsm-health-win32.c#L95-L133).
   The **Linux** backend is an explicit, commented no-op ("inotify has its
   own mechanisms for detecting filesystem unmount... we don't need a
   separate health thread like Windows does" —
   [`fsm-health-linux.c#L1-L26`](https://github.com/git/git/blob/c51408889c3b372814bc20b9431c3b74d0d268eb/compat/fsmonitor/fsm-health-linux.c)).
   The **Darwin (macOS)** backend —
   [`fsm-health-darwin.c`](https://github.com/git/git/blob/c51408889c3b372814bc20b9431c3b74d0d268eb/compat/fsmonitor/fsm-health-darwin.c)
   — is *also* a no-op, but with **zero rationale comment**, unlike Linux's.
   It has been an empty stub since at least `v2.40.0` (checked directly;
   identical four-function no-op body on both tags) through today's
   `master` — i.e. for the entire public life of the feature on macOS.

3. **macOS does have its own, separate, event-driven shutdown-on-delete
   path — in the FSEvents *listener* thread, not the health thread.**
   `compat/fsmonitor/fsm-listen-darwin.c`'s callback classifies every
   FSEvents record; when the watched `.git`/gitdir path itself reports
   `kFSEventStreamEventFlagItemRemoved` or `...ItemRenamed`, it `goto
   force_shutdown`s immediately —
   [`fsm-listen-darwin.c#L313-L324`](https://github.com/git/git/blob/c51408889c3b372814bc20b9431c3b74d0d268eb/compat/fsmonitor/fsm-listen-darwin.c#L313-L324),
   which sets `shutdown_style = FORCE_SHUTDOWN` and wakes the daemon's
   shutdown condvar at
   [`fsm-listen-darwin.c#L383-L391`](https://github.com/git/git/blob/c51408889c3b372814bc20b9431c3b74d0d268eb/compat/fsmonitor/fsm-listen-darwin.c#L383-L391).
   **This mechanism has a documented escape hatch that matches this
   machine's exact failure conditions.** When FSEvents tells the daemon it
   dropped/coalesced events (`ef_is_dropped`, which the kernel does under
   event-rate or backlog pressure), the code's own comment admits the gap:
   *"We assume that any events that we received in this callback after this
   dropped event may still be valid, so we continue rather than break.
   (And just in case there is a delete of '.git' hiding in there.)"* —
   [`fsm-listen-darwin.c#L247-L264`](https://github.com/git/git/blob/c51408889c3b372814bc20b9431c3b74d0d268eb/compat/fsmonitor/fsm-listen-darwin.c#L247-L264).
   In other words: **if the exact event batch containing the root-delete
   flag is itself the one FSEvents drops, the daemon never learns its
   watched directory is gone, and nothing else in git ever checks again.**
   This is a plausible, source-grounded explanation for orphans surviving a
   genuine `rm -rf`/`git worktree remove` under the kind of swap-thrashing,
   load-average-21 conditions already observed on this machine — but it is
   **inferred, not confirmed by any changelog or mailing-list postmortem**;
   no primary source states this failure mode explicitly as a known bug.

4. **Nothing in git itself ever calls `fsmonitor--daemon stop` on worktree
   removal.** `builtin/worktree.c` on current `master` contains **zero**
   references to `fsmonitor` (`grep -i fsmonitor builtin/worktree.c` ⇒ no
   matches, verified directly against the raw file). `fsmonitor-ipc.c`
   (the client side every git command uses to talk to/auto-spawn the
   daemon) only ever *spawns* the daemon on a cache-miss query
   ([`fsmonitor-ipc.c#L56-L66`](https://github.com/git/git/blob/c51408889c3b372814bc20b9431c3b74d0d268eb/fsmonitor-ipc.c#L56-L66));
   it has no stop/reap call anywhere.
   `Documentation/git-worktree.adoc` similarly has zero mentions of
   `fsmonitor`.

**Net effect for this machine's usage pattern:** any worktree path that
either (a) is still genuinely idle-but-present on disk (an agent finished a
task and the worktree directory was never `rm`'d or `worktree remove`'d),
or (b) was deleted but its root-delete FSEvents batch got coalesced/dropped
under load, keeps its daemon alive **forever**, because *no* code path in
git — on macOS, specifically — checks "has anyone asked me anything in N
days" or "does my watched path still exist" after the fact. This is exactly
the "one daemon per repo/worktree path ever touched, none ever reaped"
shape already observed (964 processes, uniform ~5-day age matching uptime).

**Confidence: high** on points 1, 2, 4 (read directly off current upstream
source, cross-checked against the exact release this machine runs).
**Confidence: medium** on the FSEvents-drop-races-with-delete explanation in
point 3 — it is a correct reading of the code's own acknowledged gap, but
no upstream issue/thread was found that names this exact race as the known
cause of real-world orphan reports.

## Evidence

- **`builtin/fsmonitor--daemon.c`** — CLI subcommands (`start`, `run`,
  `stop`, `status`), `--detach`, `fsmonitor__start_timeout_sec` default 60s
  (`FSMONITOR__START_TIMEOUT` = `fsmonitor.starttimeout`,
  [L39-L62](https://github.com/git/git/blob/c51408889c3b372814bc20b9431c3b74d0d268eb/builtin/fsmonitor--daemon.c#L39-L62)),
  health-thread wiring
  ([L1170-L1293](https://github.com/git/git/blob/c51408889c3b372814bc20b9431c3b74d0d268eb/builtin/fsmonitor--daemon.c#L1170-L1293)).
  No reference to `core.fsmonitor` config lifecycle beyond enable/disable.
- **`Documentation/config/core.adoc`** (fetched directly) — `core.fsmonitor`
  entry only covers enabling the daemon and a compatibility caveat for git
  ≤2.35.1 reading the boolean as a hook pathname; no lifecycle/cleanup text.
- **`Documentation/git-fsmonitor--daemon.adoc`** (fetched directly) —
  documents `start`/`run`/`stop`/`status` as manual, explicit operations;
  documents the submodule-blindness caveat and the network-filesystem
  caveat; contains no mention of auto-shutdown, idle timeout, or
  stop-on-worktree-removal.
- **`compat/fsmonitor/fsm-health-win32.c`** — the only platform with a real
  polling self-shutdown mechanism, and it fires only on
  moved/renamed/deleted/unmounted root, on a 60-second poll, never on
  elapsed idle time
  ([L1-L230, full file fetched](https://github.com/git/git/blob/c51408889c3b372814bc20b9431c3b74d0d268eb/compat/fsmonitor/fsm-health-win32.c)).
- **`compat/fsmonitor/fsm-health-darwin.c`** and **`fsm-health-linux.c`** —
  both four-function no-op stubs (fetched directly, full file in both
  cases). Linux's stub carries an explanatory comment citing inotify's own
  unmount detection; Darwin's carries no comment at all. Verified identical
  no-op shape at `v2.40.0` and current `master` — i.e. unimplemented on
  macOS since the feature's early life.
- **`compat/fsmonitor/fsm-listen-darwin.c`** — root-delete/root-rename
  detection via FSEvents flags
  ([L278-L324](https://github.com/git/git/blob/c51408889c3b372814bc20b9431c3b74d0d268eb/compat/fsmonitor/fsm-listen-darwin.c#L266-L324)),
  the dropped-event caveat comment quoted above
  ([L247-L264](https://github.com/git/git/blob/c51408889c3b372814bc20b9431c3b74d0d268eb/compat/fsmonitor/fsm-listen-darwin.c#L247-L264)),
  and the actual `force_shutdown:` handler
  ([L383-L391](https://github.com/git/git/blob/c51408889c3b372814bc20b9431c3b74d0d268eb/compat/fsmonitor/fsm-listen-darwin.c#L383-L391)).
- **`builtin/worktree.c`** (fetched directly, grepped for `fsmonitor`,
  case-insensitive) — zero matches. `git worktree remove`/`git worktree
  prune` never talk to `fsmonitor--daemon`.
- **`fsmonitor-ipc.c`** (fetched directly) — `spawn_daemon()` is the only
  lifecycle action the client side ever takes; no stop/reap call exists
  ([L56-L66](https://github.com/git/git/blob/c51408889c3b372814bc20b9431c3b74d0d268eb/fsmonitor-ipc.c#L56-L66)).
- **`Documentation/git-worktree.adoc`** (fetched directly, grepped) — zero
  matches for `fsmonitor`.
- **Release notes** — `v2.55.0`'s only fsmonitor-related entry is "The
  fsmonitor daemon has been implemented for Linux"; `v2.56.0`'s release
  notes contain no fsmonitor entries at all. No lifecycle/cleanup
  improvement has shipped in either of the two releases bracketing this
  machine's current version.
- **GitHub commit history for `builtin/fsmonitor--daemon.c`** (via GitHub
  API, `git/git` repo, not a mirror) shows active 2026 maintenance —
  `e36cda7d7a` "fsmonitor: plug token-data leak on early daemon-startup
  failures" (2026-07-05), and a 2026-04-15 cluster by Paul Tarjan:
  `1cbfa62766` "fsmonitor: add timeout to daemon stop command" (adds a
  30-second timeout so `fsmonitor--daemon stop` doesn't spin forever if the
  daemon is wedged) and `9266aaff0a` "fsmonitor: close inherited file
  descriptors and detach in daemon" (fixes the *spawned* daemon holding
  open FDs from its parent and calls `setsid()` on `--detach` so the
  daemon isn't in the spawning shell's process group). **Neither commit
  adds idle-timeout or path-existence-recheck logic** — they fix narrow
  hangs/FD-inheritance bugs, not the lifecycle gap described above.
- **Known, open, externally-reported instance of this exact symptom**:
  [microsoft/vscode#161088](https://github.com/microsoft/vscode/issues/161088),
  *"Git - Stop git fsmonitor--daemon beforce closing / renaming / deleting a
  repo"* — reporter states *"once it is launched, this daemon process stays
  in the background forever, preventing basic actions like renaming, moving
  or deleting the directory it watches"* and explicitly asks that *"VS Code
  should run `git fsmonitor--daemon stop` before closing a workspace and
  also before renaming or deleting a repo."* **Confirmed still open**, no
  upstream-git or VS Code fix landed; the only workaround on the thread is
  toggling `core.fsmonitor` off/on around the destructive operation — i.e.
  the same category of workaround this environment already applied.
- **Scalar/VFSForGit**: searched `microsoft/scalar` issues directly; found
  [microsoft/scalar#447](https://github.com/microsoft/scalar/issues/447)
  "scalar should remove added git setting when un-registering" and
  [#386](https://github.com/microsoft/scalar/issues/386) "Problems with
  watchman invocations" as the closest on-topic issues, but neither
  describes a shipped fsmonitor-daemon reaper; could not verify a claimed
  "`scalar unregister` stops the daemon" behavior against actual
  `Scalar.CommandLine` source (file not found at the guessed path) — **not
  used as a citation**, flagged here only so it is not silently dropped.
- **"PSA: Turn on Git's fsmonitor!" thread** (Chromium project, Google
  Groups, not lore.kernel.org — the actual thread lives on
  `groups.google.com/a/chromium.org/g/chromium-dev`, May 2023, started by
  Avi Drissman) — fetched directly. Contains setup instructions and
  reported speedups (e.g. Dale Curtis: "`git status` went from ~4s to
  0.6s" on macOS) but **no visible discussion of orphaned/accumulating
  daemon processes** in the portion of the thread retrievable here — a
  web-search summarization pass separately produced an unverifiable claim
  about "178 processes... doesn't grow" that could not be reproduced on a
  direct fetch of the same URL, so it is **not used** as evidence.
- **lore.kernel.org / public-inbox.org access**: every attempt (direct
  WebFetch, `curl` with a browser `User-Agent`, the `/raw` mbox endpoint,
  and the `public-inbox.org` mirror) either returned an Anubis
  JavaScript-challenge page or HTTP 502 in this environment. This means the
  original 2022 Jeff Hostetler "Builtin FSMonitor Part 3" cover letter
  (which, per secondary/search-engine summaries only, proposed the health
  thread partly to enable a future "idle-timeout auto-shutdown feature")
  could **not be independently read or quoted** here. Its existence as a
  patch series is corroborated by `patchwork.kernel.org` search-result
  titles and by the shipped `fsm-health-*` source tree itself, but the
  specific claim that *idle-timeout* was an explicit design goal (as
  opposed to only move/delete detection, which is what actually shipped)
  rests on a secondary (search-engine) paraphrase, not a primary quote, and
  should be treated as **unconfirmed**.
- **Explicit search for an upstream "this is a known bug/limitation"
  statement**: no lore.kernel.org thread, no git.git commit message, and no
  release-note entry was found (within what this environment could access)
  that frames daemon-process accumulation as an acknowledged bug with a
  tracked fix. The only on-the-record upstream-adjacent acknowledgment
  found is the VS Code issue above, which is a *consumer* of git filing a
  request against *git's* behavior — not an upstream git admission.

## Ranked fixes / workarounds

1. **Build and run a reaper script via launchd — necessary regardless of
   anything else, because no upstream mechanism bounds idle daemons on any
   platform.** Matches/replaces the earlier `core.fsmonitor=false` config
   change once validated.
   - **Design**: a shell script invoked every few minutes by a launchd
     `StartInterval` agent. For each process matching
     `fsmonitor--daemon run` in its command line (match the literal
     substring `fsmonitor--daemon run`, not `fsmonitor--daemon`, to avoid
     matching the parent `start`/`stop`/`status` invocations which exit
     immediately and are never long-running):
     1. Extract the watched worktree path. The daemon's argv does not
        carry the path directly (it derives it from the CWD at spawn time
        and listens on a Unix socket under
        `$watched_root/.git/fsmonitor--daemon.ipc` or the linked-worktree
        equivalent) — the safe way to recover the path without guessing is
        `lsof -p <pid>` and read the socket's directory, or
        `proc_pidinfo`/`lsof -a -p <pid> -d cwd` for the daemon's current
        working directory, since `fsmonitor_run_daemon()` does not chdir
        away from the worktree root before opening the socket. Treat a
        failure to resolve a path as "do not touch this PID" (fail closed).
     2. Check that the resolved path's `.git` (or, for a linked worktree,
        the file `.git` pointing at `.git/worktrees/<name>`) **no longer
        exists**. Only paths that fail this check are candidates for
        killing — this is the condition the user's task explicitly
        requires, and it is also exactly the condition git's own Darwin
        listener thread is *supposed* to catch and sometimes doesn't (see
        Confirmed root cause, point 3).
     3. Kill only those PIDs (`kill -TERM`, not `-KILL`, so the daemon's own
        IPC-server shutdown path runs and the socket is cleaned up the same
        way `fsmonitor--daemon stop` would do it).
     4. Log what was killed (PID, path, age) to a file the user can audit.
   - **launchd plist sketch** (`~/Library/LaunchAgents/com.user.fsmonitor-reaper.plist`):
     ```xml
     <?xml version="1.0" encoding="UTF-8"?>
     <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
       "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
     <plist version="1.0"><dict>
       <key>Label</key><string>com.user.fsmonitor-reaper</string>
       <key>ProgramArguments</key>
       <array>
         <string>/bin/zsh</string>
         <string>-c</string>
         <string>/Users/C.Hessel/.config/nix-dotfiles/scripts/fsmonitor-reaper.sh</string>
       </array>
       <key>StartInterval</key><integer>600</integer>
       <key>StandardOutPath</key><string>/tmp/fsmonitor-reaper.log</string>
       <key>StandardErrorPath</key><string>/tmp/fsmonitor-reaper.log</string>
       <key>RunAtLoad</key><false/>
     </dict></plist>
     ```
   - **`fsmonitor-reaper.sh` sketch**:
     ```sh
     #!/usr/bin/env bash
     set -euo pipefail
     ps -axo pid,command | grep 'fsmonitor--daemon run' | grep -v grep | \
     while read -r pid _; do
       # Resolve the daemon's cwd (= the watched worktree root).
       wt_path=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | awk '/^n/{print substr($0,2)}')
       [ -z "${wt_path:-}" ] && continue   # fail closed: can't resolve, don't touch

       # A worktree's git-dir pointer can be ".git" (file, linked worktree)
       # or ".git" (dir, main worktree) — either way, absence means gone.
       if [ ! -e "$wt_path/.git" ]; then
         age=$(ps -o etime= -p "$pid" | tr -d ' ')
         echo "$(date -Iseconds) killing pid=$pid path=$wt_path age=$age (no .git)"
         kill -TERM "$pid" 2>/dev/null || true
       fi
     done
     ```
   - **Effort**: ~30-45 minutes to write, test against a deliberately
     orphaned worktree, and install the launchd agent (`launchctl
     bootstrap gui/$(id -u)
     ~/Library/LaunchAgents/com.user.fsmonitor-reaper.plist`).
   - **Risk**: low, provided the `.git`-existence check runs *before* any
     kill and the script fails closed on path-resolution failure — this
     cannot kill a live daemon for a worktree that still exists, only ones
     already confirmed orphaned by the same test the user specified. The
     one residual risk is a narrow TOCTOU window (worktree deleted and
     immediately recreated with git re-initializing a *new* daemon on the
     same path between the reaper's existence-check and its kill) — low
     likelihood at a 5-10 minute poll interval, and the cost of hitting it
     is just one unnecessary daemon respawn, not data loss.
   - This directly answers investigation question 5's first option and is
     the **only one of the three evaluated options that is both effective
     and does not depend on an upstream mechanism that doesn't exist.**

2. **A `git worktree remove` wrapper that calls `fsmonitor--daemon stop`
   first.** Sound in principle (and this is literally what the VS Code
   issue above asks upstream git/VS Code to do) and cheap to add as a
   shell function/alias in this repo's dotfiles. **But it only covers one
   of the two leak vectors found above** — the clean "I remembered to run
   `git worktree remove`" path — and does nothing for: worktrees abandoned
   by `rm -rf` outside of git's own command (common for agent-spawned
   ephemeral worktrees that get torn down by the orchestrating script, not
   by `git worktree remove`), or daemons for worktrees that are simply
   idle-but-still-present for days. **Effort**: ~10 minutes (a fish/zsh
   function). **Risk**: none — it's strictly additive, a `stop` call
   against an already-dead or nonexistent daemon is a harmless no-op.
   Worth doing **in addition to** option 1, not instead of it.

3. **Per-worktree opt-in via `includeIf` instead of global
   `core.fsmonitor=true`.** Reduces the *rate* of new daemons (small,
   rarely-touched agent worktrees never get one at all) but doesn't fix
   the underlying lifecycle gap for the repos where it's intentionally
   enabled, and in this environment's stated usage pattern — ephemeral
   agent worktrees are exactly the ones that would NOT be covered by an
   `includeIf` carve-out for "specific large repos" — this option provides
   the least protection against the actual observed leak (964 small
   worktree paths, not a handful of large monorepos). It is a reasonable
   complementary posture (only turn it on where the `git status`
   performance win is large enough to matter) but **does not by itself
   solve the leak** and should not be relied on alone. **Effort**: ~15
   minutes to restructure `home/features/git/default.nix`'s fsmonitor
   setting behind a conditional. **Risk**: low, but gives a false sense of
   safety if adopted as the *only* mitigation.

## Recommendation

**No safe upstream mechanism exists yet for this exact failure mode; a
custom reaper is required.** Upstream git has a real, working,
event-driven shutdown-on-delete path on macOS (`fsm-listen-darwin.c`), and a
*different*, poll-based shutdown-on-move/delete path on Windows
(`fsm-health-win32.c`) — but **no version of git, on any platform, checked
from `v2.40.0` through current `master`, has ever implemented an
idle/inactivity timeout**, and nothing in `builtin/worktree.c` or
`fsmonitor-ipc.c` ever proactively stops a daemon. Given this environment's
specific usage pattern — frequent ephemeral worktree creation and
destruction by AI-agent subprocesses, which may not always go through `git
worktree remove`, under memory/CPU pressure that can plausibly interact
with the one documented gap in macOS's own delete-detection (dropped
FSEvents batches) — daemons for abandoned or merely-idle worktree paths
will keep accumulating indefinitely no matter how git itself is configured.

Re-enabling `core.fsmonitor=true` globally is **safe only if paired with
fix #1 (the launchd reaper)**, ideally plus #2 as a cheap belt-and-suspenders
addition. Re-enabling it with no reaper would reproduce the exact 964-process
state that caused the original swap/load incident — the new evidence that 15
daemons respawned within minutes of the mass-kill, on a machine with only 3
active worktrees, confirms the growth rate is fast enough that "revisit this
later" is not a safe interim posture. If the reaper is not built and
installed in the near term, **leave `core.fsmonitor=false` as currently
set** — that is the only zero-maintenance-cost option proven to prevent
recurrence, at the cost of the `git status` speedup fsmonitor exists to
provide.
