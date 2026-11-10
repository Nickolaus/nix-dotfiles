# Coding standards: open proposals and rejected tooling

Companion to `CODING_STANDARDS.md`. Nothing here is binding and nothing here is a review
finding. The standard itself stays free of counts and tool inventories so it does not go stale;
this file is where the point-in-time measurements live.

Measurements taken 2026-11-10. Re-measure before acting on any of them.

## Open proposals

### 1. `nixpkgs-fmt --check` gate in `.githooks/pre-commit`

`nixpkgs-fmt` is already in the user profile and gated nowhere. 18 of 80 `.nix` files do not
conform, so adopting the gate needs one reformat commit first.

Known cost: the reformat collapses the aligned trailing comments in `home/features/packages.nix`
and de-indents the multi-line function arguments in `home/features/ssh/keys.nix` in a way that
reads worse.

A review of all 18 files confirmed `nixpkgs-fmt` does not alter the contents of any `''…''`
string, so embedded shell and Python are safe. That finding is specific to those files as they
stand, not a general guarantee.

Open question: whether the files inherited from the upstream fork are grandfathered until next
touched. They account for most of the 18.

### 2. `shellcheck -S warning` must be clean

`shellcheck` is already in the user profile and invoked nowhere. Two findings remain repo-wide,
both SC2155 in `hosts/farnsworth/scripts/vm-test-setup.sh`. The cost of adopting this gate is
now close to zero.

### 3. No trailing whitespace; exactly one terminating newline

Violated in roughly 20 files. `nixpkgs-fmt` fixes both for `.nix`; shell files need a separate
check.

### 4. Module argument header: single-line, alphabetical, `...` last

The newest modules already do this; older ones use a leading-comma multi-line header. Converge
when a file is next edited, never as a sweep.

### 5. Hoist `lib` functions into `inherit (lib) …;` at three or more uses

Followed by about 20 files, with about 27 using inline `lib.` only. Same converge-on-edit rule.

## Rejected, with the reason

- **`nixfmt-rfc-style` or `alejandra`.** Would rewrite all 80 files for no correctness gain. The
  de facto style is already `nixpkgs-fmt`-shaped, and a full rewrite makes every future
  `git blame` and the next upstream-fork merge noise.
- **`statix` and `deadnix`.** The patterns they target are already absent by hand: no
  `with lib;`, no legacy `stdenv.isDarwin`, no unused top-level bindings found. Revisit only if
  a defect class appears that eval-time assertions cannot catch.
- **GitHub Actions CI.** The expensive checks need a Darwin runner for the primary host, a Linux
  runner for the others, Determinate Nix, and a `uv`-installed SkillSpector. Substantial setup
  to duplicate what `scripts/update-system.sh` already runs locally. Related: the `$CI` bypass
  guards in `scripts/check-config.sh` and `scripts/check-skills.sh` cannot fire today, since
  there is no CI. Delete or document them rather than building a CI to match.
- **`shfmt`.** Reformats 8 of 10 scripts, and every divergence is redirect or heredoc spacing.
  The four-space indent is the only shell formatting convention worth asserting, and it already
  holds everywhere.
- **A Nix line-length limit.** Legitimate long lines exist: an embedded keymap, skill
  descriptions that must be a single YAML scalar, a long jq filter. A limit would force worse
  code.
- **A repo-wide formatting or argument-order sweep.** Would bury the semantic history of the AI
  layer and conflicts with the rule in `AGENTS.md` about not touching unrelated work. The single
  exception is the one reformat pass proposal 1 requires to become enforceable.
- **A commit-message linter.** The convention is clean across the last 150 commits, and the
  global agent instructions already forbid interactive commit helpers in headless agents.
- **A cap on comment length.** Inverted priority: the long comments carrying upstream issue
  numbers and rejected designs are among the most valuable artifacts in the repo. The standard
  requires them.
- **A documentation-drift linter.** No reliable way to check that prose matches a tree. Kept as
  a review obligation in the standard instead.
- **A rule on import-list ordering.** One list is alphabetical, another is grouped with platform
  directories last. Both are deliberate.

## Known gaps not yet decided

- `--all-systems` is the only path that evaluates the NixOS, WSL and standalone host classes,
  and it does not run from the Darwin host by default. The standard states the gap; closing it
  needs a decision about where that evaluation runs.
- `scripts/check-skills.sh` reports 4 caution warnings across 41 scanned sources under the
  pinned SkillSpector v2.13.4. The highest is `diagnosing-bugs` at MEDIUM/27, one HIGH issue
  categorised System Prompt Leakage / Direct Prompt Extraction, which matched the words
  `show instruction` in a comment describing a `step "<instruction>"` helper in that skill's
  `scripts/hitl-loop.template.sh`. Adopting `--strict` would need a decision on that finding
  and on the three LOW cautions.
- `overlays/` is documented in `README.md` and contains no tracked files.
- `ARCHITECTURE.md` predates the AI-agent layer, the catalog, `flake/`, `packages/`, and the
  `bender` host, and still describes NixOS support as a template to be activated.
