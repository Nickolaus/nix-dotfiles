# Coding Standards

## 1. Background

This repository is a single Nix flake configuring four host classes (nix-darwin, NixOS, WSL,
standalone Home Manager) and a large AI-agent tooling layer on top of them. It is maintained by
one person and edited heavily by coding agents.

That last fact is why this document exists. A human maintainer carries the local invariants in
their head; an agent does not, and neither does a reviewer reading a diff six months later.
Generic Nix idiom is already covered by the nixpkgs manual, and generic code smells are already
covered by the review tooling. This document records only what is specific to this repository
and cannot be derived from the code in front of you.

Several rules below are the codified conclusions of `docs/architecture-review-2026.md`, which
assessed the host and module graph against current upstream practice. Where a rule comes from
that review, its rationale says what the review actually found, so the rule can be re-examined
if the finding stops being true.

What this document is not: it is not a tutorial, not an architecture description, and not a
usage guide.

## 2. Scope

Applies to every `.nix`, `.sh`, `.py`, and Markdown file tracked in this repository, and to
every commit made to it, by a human or an agent.

Precedence against the repository's other documents:

| Document | Owns |
|---|---|
| `CODING_STANDARDS.md` | Code style and the rules a diff is checked against. |
| `AGENTS.md` | Agent workflow: which tools to search with, when to delegate, which checks to run. |
| `ARCHITECTURE.md` | Placement: where a new module goes. |
| `README.md` | Usage. |
| `docs/architecture-review-2026.md` | Standing architectural findings and the "do not change" list. |

On conflict, `AGENTS.md` wins for process and this document wins for style.

Out of scope and deliberately not ruled on: vendored upstream sources under `.agents/`, the
contents of flake inputs, and generated files. Files inherited from the upstream fork are in
scope but see §7 on grandfathering.

## 3. Goals

Rules in this document are expected to earn their place against these goals. A proposed rule
that serves none of them does not belong here.

1. **A rule must pull its weight.** Every rule costs a reader attention and an agent context. A
   practice nobody here gets wrong does not need a rule.
2. **Optimize for the reader.** This code is read far more often than written, increasingly by
   an agent reconstructing intent from a diff. Leave a trace.
3. **Make the invariant mechanical where possible.** A rule a machine can check is worth more
   than a rule a reviewer must remember. Prose is the fallback, not the goal.
4. **Fail closed.** Where a mistake would silently produce a wrong-but-evaluating
   configuration, prefer the form that refuses to build.
5. **Claim only what is implemented.** A configuration that describes stronger guarantees than
   it provides is worse than one that describes none.
6. **Be consistent with the wider Nix community** unless this repository has a specific reason
   to diverge, recorded as a rule.
7. **Concede to practicalities.** Upstream tools, a public repository, and one maintainer on one
   machine are real constraints. Where a rule cannot hold, say so in the rule rather than
   pretending.

## 4. Normative keywords

Interpreted per RFC 2119:

- **MUST** / **MUST NOT** -- absolute requirement or prohibition.
- **SHOULD** / **SHOULD NOT** -- valid reasons to deviate may exist in particular
  circumstances, but the implications must be understood and weighed first.
- **MAY** -- genuinely optional.

Keywords are used sparingly and only where they carry weight.

## 5. Rule classification

Every rule carries one of three classifications, following the MISRA model:

| Class | Meaning | Deviation |
|---|---|---|
| **Mandatory** | Must never be violated. A violation is a defect, not a style disagreement. | None. |
| **Required** | Must be met unless a recorded deviation exists. | Allowed with a documented deviation per §7. |
| **Advisory** | Should be met where practical. | No record needed; a reviewer may still raise it. |

The split is not about how annoying a violation looks. It tracks consequence: Mandatory rules
protect against a silent wrong result, a leaked secret, an unevaluable configuration, or a
claimed guarantee that does not exist. Required rules protect maintainability. Advisory rules
buy consistency.

## 6. Verification

Each rule below names where it is checked. Five enforcement levels exist here:

| Level | Mechanism | Runs |
|---|---|---|
| **eval** | `assertion` in a Nix module | Any `nix eval` of a host; cannot be bypassed |
| **hook** | `.githooks/pre-commit` | Every commit; bypassable with `--no-verify` |
| **script** | `scripts/check-config.sh`, `check-skills.sh`, `check-skill-pins.sh` | Manually, and from `scripts/update-system.sh` |
| **tool** | `nixpkgs-fmt`, `shellcheck` | Not currently gated -- see `docs/coding-standards-decisions.md` |
| **review** | Human or agent reading the diff | Every change |

There is no CI. The `$CI` bypass guards inside the check scripts cannot fire today. A rule whose
only enforcement is **review** holds exactly as well as the review did, which is the argument
for promoting it to **eval** when the chance arises (INV-1).

## 7. Deviations

A deviation from a Required rule MUST be recorded at the point of deviation, not in this
document. The record carries:

1. the date, as `YYYY-MM-DD`;
2. what was deviated from and why, in terms of what was actually inspected;
3. a scope narrow enough to expire -- a store path, a version, a file, not a blanket category.

`SCAN_EXCEPTIONS` in `scripts/check-skills.sh` is the reference implementation of this pattern:
each entry is pinned to a Nix store path, so a dependency bump invalidates the deviation and
re-fails the gate until someone re-reviews the new source.

Files inherited from the upstream fork are in scope but not yet conformant. Whether they are
grandfathered until next touched is an open decision recorded in
`docs/coding-standards-decisions.md`; until it is settled, do not reformat them in an unrelated
change.

## 8. Rules

Rule IDs are stable. A retired rule keeps its ID and is marked retired rather than reused.

### 8.1 Invariants (INV)

**INV-1 -- An invariant is an assertion, not a comment.** *Mandatory.*
A change that introduces a reference one part of the configuration must satisfy MUST ship the
eval-time `assertion` proving it, in the same commit.
*Why:* a policy only prose states is unenforced, and the failure surfaces as a working-but-wrong
configuration rather than a build error. This is the single highest-value rule in this document.
*Check:* eval, review.

**INV-2 -- A failure message names the thing that must change.** *Required.*
An assertion message MUST name the full option path and read as a requirement:
`aiAgents.mcpServers.<name>.command must be set for stdio MCP servers.`
*Why:* the reader fixes it without reading the code that raised it.
*Check:* review.

**INV-3 -- Derive a mirror; never duplicate it.** *Required.*
Where one list must agree with another, it MUST be computed from the source of truth. A consumer
that cannot evaluate the source, such as a shell script, SHOULD parse it rather than restate it.
*Why:* duplicated lists drift silently. `scripts/check-skill-pins.sh` drifted from the flake's
skill inputs and stopped reporting one of them entirely.
*Check:* review.

**INV-4 -- Prefer an assertion to a warning comment.** *Advisory.*
*Check:* review.

### 8.2 Dependencies and pins (DEP)

**DEP-1 -- Pins are exact.** *Mandatory.*
No floating version, tag range, or branch reference. Every external dependency MUST resolve to
one immutable artifact.
*Check:* review.

**DEP-2 -- A pin carries its update annotation.** *Required.*
Every package-manager version pin MUST be preceded by the `# renovate:` marker its update
tooling reads. Prebuilt-binary hashes MUST carry `# release-sha256:`.
*Why:* an unannotated pin is invisible to the updater and silently rots.
*Check:* review.

**DEP-3 -- A version and its hash move together.** *Required.*
*Why:* a half-applied bump either fails to build or builds the old artifact under a new version
string. `scripts/update-mcp-runtime-versions.py` moves both in one pass.
*Check:* eval, review.

**DEP-4 -- Bumping a pin re-reviews its gate deviation.** *Mandatory.*
If a dependency has an artifact-scoped deviation (§7), the bump commit MUST update or remove
that deviation.
*Why:* the scoping exists precisely so the gate re-fails and forces a fresh look at the new
source. Skipping it converts a reviewed exception into an unreviewed one.
*Check:* script (`check-skills.sh`), review. Not the hook -- the hook never runs the scan.

**DEP-5 -- A commit-pinned input says why.** *Required.*
Pinning a commit rather than a tag MUST carry a comment stating that upstream ships no tag.
*Check:* review.

**DEP-6 -- A new skill-source input is registered.** *Required.*
It MUST be added to `flake/ai-agent-sources.nix`, the typed registry. Input declarations
themselves stay static in `flake.nix`.
*Check:* eval, review.

**DEP-7 -- Do not depend on a nixpkgs alias.** *Required.*
Reference the real attribute, not a compatibility alias or a versioned alias that upstream will
retire.
*Why:* upstream removals break host evaluation outright. The review found Linux evaluation fully
blocked by one removed package, and a versioned alias has since been replaced for the same
reason. See EVAL-1.
*Check:* eval, review.

### 8.3 Secrets (SEC)

**SEC-1 -- Secrets are consumed by reference, never by value.** *Mandatory.*
A secret MUST be consumed as a runtime path or an environment-variable name. A secret value MUST
NOT enter the Nix store, a build log, or a derivation.
*Why:* the Nix store is world-readable and this repository is public.
*Check:* review.

**SEC-2 -- No credential in the repository.** *Mandatory.*
No token, key, cookie, or password in Nix, scripts, documentation, workflow receipts, or commit
messages.
*Check:* review.

**SEC-3 -- A sops declaration is complete.** *Required.*
`format = "yaml"`, `mode = "0600"`, and a path under `${config.home.homeDirectory}`.
*Check:* review.

**SEC-4 -- A declared secret exists in the encrypted store.** *Mandatory.*
Adding a secret in Nix MUST add it to `home/features/secrets/secrets.yaml` in the same change.
*Why:* the mismatch fails at activation, not evaluation. `scripts/check-config.sh` cross-checks
the two without needing an age identity.
*Check:* script, review.

**SEC-5 -- A recipient change re-keys the store.** *Mandatory.*
Changing `.sops.yaml` recipients MUST run `sops updatekeys` on the secrets file in the same
commit.
*Why:* in a public repository, removing a recipient is not revocation -- every earlier revision
stays decryptable by whoever held a key at the time. Treat the secret as compromised and rotate
it instead.
*Check:* review.

**SEC-6 -- MCP credentials are referenced by name.** *Required.*
Use the env-var-name option (`bearerTokenEnvVar`), never a literal.
*Check:* review.

**SEC-7 -- A security suppression is dated, scoped, and sourced.** *Mandatory.*
See §7. The rationale MUST be written from the findings actually read, naming them.
*Why:* an undated blanket suppression is a hole, not an exception.
*Check:* review.

### 8.4 State and convergence (STATE)

**STATE-1 -- Never write into a consumed repository's working tree.** *Mandatory.*
Tooling pointed at a project MUST NOT create state inside that project.
*Why:* it pollutes unrelated repositories and leaks one project's data into another's cache.
*Check:* review.

**STATE-2 -- State lives in the platform's state directory.** *Required.*
`$XDG_STATE_HOME` / `$XDG_DATA_HOME` / `$XDG_CACHE_HOME` on Linux, `~/Library/…` on Darwin.
*Check:* review.

**STATE-3 -- Wrap and fail closed.** *Required.*
Where a third-party tool insists on the working directory, wrap it so it refuses to run rather
than silently falling back to a shared location.
*Why:* a shared fallback mixes state across projects undetectably.
*Check:* review.

**STATE-4 -- Convergence runs in both directions.** *Mandatory.*
An activation step MUST be idempotent, and disabling a feature MUST remove exactly what enabling
it added, leaving a co-owned file otherwise untouched.
*Why:* a one-way activation leaves orphaned configuration that outlives the option that created
it.
*Check:* review.

**STATE-5 -- Merging into a co-owned file is create, validate, merge, replace atomically.**
*Required.*
Invalid input warns and no-ops; it never truncates. Use the repository's merge helpers rather
than hand-rolling.
*Why:* another tool owns that file concurrently; a naive write loses its entries.
*Check:* review.

**STATE-6 -- `writeBoundary` is the default activation anchor.** *Advisory.*
Any other anchor carries a reason.
*Check:* review.

### 8.5 Activation (ACT)

**ACT-1 -- Ordinary activation does not mutate machine state from upstream drift.**
*Mandatory.*
A `switch` MUST NOT update, upgrade, or otherwise change installed software based on what
changed upstream. Activation enforces only that the machine matches the declared configuration.
*Why:* otherwise two activations of an unchanged repository produce two different machines, and
reproducibility is gone. The review found Homebrew activation doing exactly that with
`autoUpdate` and `upgrade` enabled; both are now off, and mutable upgrades live in the explicit
update workflow instead.
*Check:* review.

**ACT-2 -- Mutable upgrade work lives in the explicit update workflow.** *Required.*
`scripts/update-system.sh` is the only place that performs a mutable upgrade. Declarative
cleanup during activation is acceptable, and intentionally removes undeclared packages.
*Check:* review.

**ACT-3 -- Activation is scoped to its platform.** *Required.*
An activation step that only works on one platform MUST be guarded, not merely documented as
platform-specific. See PLAT-1.
*Check:* eval, review.

### 8.6 Generated shell (GEN)

**GEN-1 -- Escape every interpolated value.** *Mandatory.*
Generated shell MUST pass interpolated values through `lib.escapeShellArg` /
`lib.escapeShellArgs`.
*Why:* an unescaped interpolation is a shell injection.
*Check:* review.

**GEN-2 -- Store-pin non-system binaries.** *Required.*
Third-party binaries are referenced by store path, hoisted to a `let` alias when repeated. Bare
coreutils MAY be called in an activation script, where Home Manager provides `PATH`.
*Check:* review.

**GEN-3 -- Generated scripts fail fast.** *Required.*
`set -euo pipefail`, or `set -eu` for a POSIX `sh` launcher.
*Check:* review.

### 8.7 Module structure (ARCH)

**ARCH-1 -- An optional input must be absent without breaking evaluation.** *Mandatory.*
A Home Manager module reading system-level configuration MUST take `osConfig ? { }` and guard
the read.
*Why:* the WSL and standalone paths evaluate `home/bender.nix` with no system configuration at
all. Breaking this breaks those hosts silently, and they are not covered by the default check
path (DOC-3).
*Check:* eval, review.

**ARCH-2 -- A new feature is a new file.** *Required.*
It lives under the owning directory and is imported from that directory's `default.nix`. It MUST
NOT be appended to an unrelated module.
*Check:* review.

**ARCH-3 -- An option-owning module binds `cfg`.** *Required.*
`cfg = config.<namespace>;` as a `let` binding, with the module's output gated on it.
*Check:* review.

**ARCH-4 -- A new agent-facing capability enters through the catalog.** *Required.*
Any new tool, skill, or MCP server is declared in `aiAgents.catalog` with an explicit `trust`
from the closed enum and explicit `targets`. `external-experimental` trust stays
explicit-invocation only.
*Why:* the catalog is what the trust and scan gates see. A capability wired in outside it is
ungated.
*Check:* eval, script, review.

**ARCH-5 -- Shared helper logic lives in the shared library.** *Advisory.*
Prefer extending the AI-agent helper library over copying a helper. Where two similar helpers
are deliberately kept separate, CMT-4 applies.
*Check:* review.

**ARCH-6 -- Parallel host variants go through one constructor.** *Advisory.*
Where host definitions are intentionally parallel, abstract the repeated shape into a
constructor rather than duplicating the block.
*Why:* the review found NixOS host construction duplicated in two places; it is now a set of
small host-constructor helpers.
*Check:* review.

### 8.8 Ownership boundaries (OWN)

**OWN-1 -- Nix does not own another tool's mutable user state.** *Mandatory.*
A file a third-party tool writes to as part of normal operation MUST NOT be generated
declaratively. Specifically: `~/.codex/config.toml` is never managed declaratively again.
*Why:* Nix and the tool then fight over the same file, and a rebase or an activation silently
discards the other side's writes. The review records this as a settled decision, and the Claude
global-MCP merge is flagged as the remaining instance to narrow.
*Check:* review.

**OWN-2 -- One shared data model, per-tool renderers.** *Required.*
`aiAgents` holds the neutral data. Each agent client gets its own renderer, which is where
ownership differences belong. One identical ownership model MUST NOT be forced onto clients
whose config and state models differ.
*Why:* the clients genuinely differ. The review names the forced-single-ownership attempt as the
thing the current design fixed.
*Check:* review.

**OWN-3 -- One domain, one owner module.** *Required.*
Storage layout, persistence, and storage maintenance each live in exactly one module, and so
does any other low-level domain.
*Why:* the review found Btrfs maintenance declared in two places, with the ownership split
unclear at the point of change.
*Check:* review.

**OWN-4 -- A tool-specific boundary recorded as deliberate stays deliberate.** *Required.*
Where `docs/architecture-review-2026.md` lists a pattern under "Do Not Change", a change that
reverses it MUST update that document in the same commit, with the reason.
*Why:* otherwise a settled decision gets re-litigated by whoever next finds it inconsistent.
*Check:* review.

### 8.9 Platform scope (PLAT)

**PLAT-1 -- A cross-platform abstraction is wired everywhere or scoped explicitly.**
*Mandatory.*
An abstraction presented as shared MUST either have equivalent runtime plumbing on every
platform it claims, or be explicitly scoped to the platforms where it is fully wired.
*Why:* the review found the shared MCP model operationally Darwin-only, because the
secret-backed environment propagation it depends on exists only through a macOS `launchctl`
helper, with no Linux equivalent. The abstraction said shared; the authentication path was not.
*Check:* review.

**PLAT-2 -- No channel-based mechanism in a flake-managed repository.** *Required.*
Update detection compares a freshly resolved lock against `flake.lock`. `nix-channel` and
channel-derived paths MUST NOT appear.
*Why:* the review found a Linux update timer running `nix-channel --update`, which reported
nothing about actual flake input drift. It now diffs a generated lock against the repository
lock.
*Check:* review.

### 8.10 Evaluation health (EVAL)

**EVAL-1 -- A broken evaluation target is a top-priority defect.** *Mandatory.*
Every host class MUST evaluate. A change that breaks evaluation of any host is fixed before
other work, not deferred as an incidental packaging issue.
*Why:* the review found Linux evaluation fully blocked by a single upstream package removal, and
the breakage was invisible because host evaluation was not part of routine hygiene.
*Check:* script, review.

**EVAL-2 -- Host evaluation is routine hygiene, not an incident response.** *Required.*
`scripts/check-config.sh` stays in the normal maintenance workflow: native host and installer
evaluation by default, `--all-systems` for full coverage.
*Check:* script, review.

### 8.11 Comments (CMT)

**CMT-1 -- A comment carries the why.** *Required.*
The failure mode, the upstream issue number where one exists, and the alternative that was
rejected.
*Why:* this is the only record of why the code is not the obvious shape. There is no cap on
comment length -- the long ones here are the most valuable artifacts in the repository.
*Check:* review.

**CMT-2 -- Comments describe the current state.** *Required.*
Never a narration of what used to be there, or which version changed what.
*Check:* review.

**CMT-3 -- Existing comments survive.** *Required.*
Do not delete or shorten a comment the change does not invalidate.
*Check:* review.

**CMT-4 -- Record a deliberate non-merge.** *Required.*
Where two helpers look duplicated but are intentionally separate, say so at the helper.
*Why:* otherwise the next reader, human or agent, "simplifies" them into a defect.
*Check:* review.

**CMT-5 -- Use `--`, not an em-dash.** *Advisory.*
*Check:* review.

**CMT-6 -- Never claim a guarantee the implementation does not provide.** *Mandatory.*
A comment, option description, or warning MUST NOT describe stronger persistence, isolation, or
security semantics than the code actually implements. Where the implementation is weaker, state
what is true.
*Why:* the review found the impermanence module and disk layout describing a tmpfs-backed or
wiped root while the real layout mounts the Btrfs root subvolume directly, so the repository
presented stronger persistence and security semantics than the machine has. A wrong guarantee is
worse than a missing one, because it is relied on.
*Check:* review.

### 8.12 Nix style (NIX)

All *Advisory* unless noted; all currently **review**-enforced, with `nixpkgs-fmt` adoption
pending in `docs/coding-standards-decisions.md`.

- **NIX-1** Two-space indent, spaces only.
- **NIX-2** No `with lib;`. `with pkgs;` only inside a package list. *Required.*
- **NIX-3** Platform guards use `pkgs.stdenv.hostPlatform.isDarwin` / `isLinux`, never
  `stdenv.isDarwin`. *Required* -- the short form is deprecated upstream.
- **NIX-4** `let` bindings and option names are camelCase.
- **NIX-5** A boolean option is `mkEnableOption "<lowercase noun phrase>" // { default = …; }`,
  with the default always explicit, including when it is `false`.
- **NIX-6** Every `mkOption` carries `type`, `default`, and a `description` ending in a period.
  *Required.*
- **NIX-7** A computed default carries `defaultText`. *Required* -- without it the generated
  documentation renders a store path.
- **NIX-8** An option rename goes through `mkRenamedOptionModule` or `mkAliasOptionModule`,
  never a silent break. *Required.*

### 8.13 Shell style (SH)

- **SH-1** `#!/usr/bin/env bash`, `set -euo pipefail`, four-space indent, no tabs. *Required.*
- **SH-2** Argument parsing is `while [[ $# -gt 0 ]]` plus `case`. `--help|-h` prints a heredoc
  `usage()` and exits 0. An unknown argument goes to stderr with a lowercase `error: ` prefix,
  prints usage, and exits 2. *Required.*
- **SH-3** Resolve the repository root from `${BASH_SOURCE[0]}` and `cd` there before relative
  work. *Required.*
- **SH-4** Clean up temp files with `trap … EXIT`, or `rm -f --` on every exit path. *Required.*
- **SH-5** An absent optional tool makes the script skip and say so; only a required tool fails
  hard. *Advisory.*
- **SH-6** Mutable Homebrew work belongs only in `scripts/update-system.sh`. *Required* -- the
  specific case of ACT-2.

### 8.14 Commits (GIT)

- **GIT-1** A single-line Conventional Commit: `type(scope): subject`. No body, no trailers.
  *Required.*
- **GIT-2** Types in use: `feat`, `fix`, `chore`, `docs`, `refactor`, `perf`. *Required.*
- **GIT-3** Scope is a subsystem (`ai`, `deps`, `update`, `secrets`, `ssh`, `darwin`, `home`,
  `scripts`, `git`), never a file path. *Advisory.*
- **GIT-4** A dependency bump is `chore(deps): …`. *Advisory.*
- **GIT-5** There is no subject-length limit. *Advisory.*

### 8.15 Validation and documentation obligations (DOC)

**DOC-1 -- Scope checks to the changed surface.** *Required.*
Per `AGENTS.md`. Heavy validation stays in `scripts/check-config.sh`; the pre-commit hook stays
fast and only parses.
*Check:* review.

**DOC-2 -- A skill-surface change runs the scan.** *Required.*
A change to skill inputs, the agent catalog, or `.agents/skills/**` MUST run
`./scripts/check-skills.sh` before commit. The hook evaluates the catalog manifest but never
runs the scan.
*Check:* script, review.

**DOC-3 -- State what the fast path does not cover.** *Required.*
`--all-systems` is the only path that evaluates the NixOS, WSL and standalone host classes, and
it does not run from the Darwin host by default. Those host classes are unvalidated unless run
deliberately. A change touching them SHOULD say which path validated it. See EVAL-2.
*Check:* review.

**DOC-4 -- A new AI tool module ships its instructions block.** *Required.*
House shape -- a `## <Tool> (<scope>)` heading, then `Default command surface:`, then
`Boundary rules:` -- written to all three agent targets.
*Why:* a tool documented for one agent and not the others gets misused by the others.
*Check:* review.

**DOC-5 -- Repo-local skills have one canonical location.** *Required.*
`.agents/skills/<name>/`, exposed to Claude through a tracked relative symlink.
*Check:* review.

**DOC-6 -- A Homebrew entry says why it is not nixpkgs.** *Required.*
*Check:* review.

**DOC-7 -- An implemented research note is deleted.** *Advisory.*
Unless code still references it. A note recording standing findings, such as
`docs/architecture-review-2026.md`, is not an implementation note and stays.
*Check:* review.

**DOC-8 -- A new host, top-level directory, or subsystem updates `ARCHITECTURE.md`.** *Required.*
*Check:* review.

**DOC-9 -- A decision resting on upstream behavior cites the upstream document.** *Required.*
Where a rule, comment, or review conclusion depends on how a third-party tool behaves, link the
upstream documentation for it.
*Why:* upstream behavior changes, and a conclusion with no citation cannot be re-checked. The
architecture review carries its own source notes for exactly this reason.
*Check:* review.

**DOC-10 -- A review or research note separates facts from inference.** *Advisory.*
State the repository fact, then the inference drawn from it, then the comparison against
upstream practice. `docs/architecture-review-2026.md` is the model.
*Why:* it keeps a conclusion falsifiable by letting a reader check the fact independently.
*Check:* review.

## 9. Changing this document

A new rule MUST state its classification, its rationale, and its enforcement level, and MUST
justify itself against a goal in §3. A rule whose only argument is personal preference belongs
in `docs/coding-standards-decisions.md` as a proposal, not here.

A rule derived from a standing findings document cites it in the rationale, so the rule can be
dropped when the finding stops being true.

Point-in-time measurements -- how many files violate something, how many findings a tool reports
-- MUST NOT be written into this document. They go stale and make the standard look wrong. They
belong in `docs/coding-standards-decisions.md`, dated.

Pointers in this document name a file and a symbol, never a line number: line numbers rot on the
next edit, and a wrong pointer costs a reader more than no pointer.

## 10. External references

Normative and process:

- [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119.txt) -- normative keywords (§4).
- MISRA C:2012 -- the Mandatory / Required / Advisory classification model (§5).
- [Conventional Commits](https://www.conventionalcommits.org/) -- the commit format (§8.14).

Upstream behavior the rules depend on (DOC-9):

- [Nixpkgs manual](https://nixos.org/manual/nixpkgs/stable/) -- general Nix idiom, not restated
  here.
- [Home Manager manual](https://nix-community.github.io/home-manager/) -- activation script and
  DAG semantics (STATE-4, STATE-6), and the consequences of `useGlobalPkgs`.
- [nix-darwin manual](https://nix-darwin.github.io/nix-darwin/manual/index.html) -- Darwin
  activation and the Homebrew ownership model (ACT-1, ACT-2).
- [sops-nix](https://github.com/Mic92/sops-nix) -- secret handling (§8.3).
- [impermanence](https://github.com/nix-community/impermanence) -- what a persistence definition
  does and does not provide (CMT-6).
- [nix flake check](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-check.html)
  and [nix flake update](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-update.html)
  -- evaluation and lock handling (PLAT-2, EVAL-1).
- [Claude Code settings](https://code.claude.com/docs/en/settings) and
  [MCP](https://code.claude.com/docs/en/mcp), [Cursor MCP](https://docs.cursor.com/advanced/model-context-protocol),
  [Codex config](https://github.com/openai/codex/blob/main/docs/config.md) -- the per-client
  config and state models behind OWN-1 and OWN-2.

Repository documents:

- `docs/architecture-review-2026.md` -- standing architectural findings, the "do not change"
  list, and known blockers.
- `docs/coding-standards-decisions.md` -- open proposals, rejected tooling, and current
  measurements.

## 11. Glossary

- **Catalog** -- the declarative inventory of agent-facing skills, roles, and MCP servers in the
  AI-agent modules. The gates see the catalog, so a capability outside it is ungated (ARCH-4).
- **Trust tier** -- the closed enum classifying a skill's provenance:
  `local-authored`, `pinned-flake`, `vendored-reviewed`, `external-experimental`.
- **Profile** -- a named subset of MCP servers activated together.
- **Renderer** -- the per-client module that turns the neutral `aiAgents` data into one tool's
  own configuration format. The renderer, not the data model, is where ownership differences
  live (OWN-2).
- **Ownership boundary** -- the line between what this repository generates and what a
  third-party tool writes for itself (OWN-1).
- **Pin** -- an exact immutable reference to an external artifact: a flake input ref, a package
  version, or a release hash (§8.2).
- **Gate** -- a check that blocks a change: the pre-commit hook, an eval assertion, or a scan
  script (§6).
- **Deviation** -- a recorded, dated, narrowly scoped exception to a Required rule (§7).
- **Target** -- one of the agent clients configuration is rendered for: `codex`, `claude`,
  `cursor`, `vibe`.
