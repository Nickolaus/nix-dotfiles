# Architecture Review 2026

## Overview

This review assesses the current `nix-dotfiles` repository against 2026 best practices for a serious personal infrastructure and developer-workstation setup. It is architecture-first, grounded in the current host/module graph and current evaluation behavior, not a style review.

The repo is generally in decent shape. The host split is readable, the `home/features` layering is understandable, and the recent `aiAgents` refactor is directionally correct. The current evaluated state is healthy for the actively checked hosts:

- Darwin evaluation passed.
- NixOS `farnsworth` evaluation passed.

This document separates:

- repo facts
- inferences from those facts
- best-practice comparisons informed by current upstream documentation

## What’s Strong

### Clear repo structure

The split between flake outputs, host configuration, shared modules, and Home Manager features is easy to follow.

Key references:

- [flake.nix](../flake.nix)
- [hosts/zoidberg/default.nix](../hosts/zoidberg/default.nix)
- [hosts/farnsworth/default.nix](../hosts/farnsworth/default.nix)
- [home/features/default.nix](../home/features/default.nix)

### Correct direction on AI config ownership

The current `aiAgents` design is much closer to the right abstraction boundary:

- one shared neutral MCP/defaults model
- per-tool renderers
- tool-specific ownership boundaries where required

This is the right direction for Codex, Claude, and Cursor. The important improvement was avoiding a forced single ownership model across tools.

Key references:

- [hosts/shared/ai-agents.nix](../hosts/shared/ai-agents.nix)
- [hosts/shared/codex.nix](../hosts/shared/codex.nix)
- [hosts/shared/claude-code.nix](../hosts/shared/claude-code.nix)
- [home/features/ai/agent-configs.nix](../home/features/ai/agent-configs.nix)

### Secrets are kept out of the Nix store

The repo uses `sops-nix` correctly as the baseline mechanism for secrets materialization. Secret values are not embedded in generated config files and are instead materialized into the home directory at activation time.

Key reference:

- [home/features/secrets/default.nix](../home/features/secrets/default.nix)

## Findings

### 1. Resolved: NixOS evaluation was blocked by a removed package

#### Repo fact

The Linux package list previously referenced `mysql80`, which was removed upstream:

- [home/features/linux/packages.nix](../home/features/linux/packages.nix:70)

Current evaluation fails with:

```text
error: 'mysql80' reached end of life on 2026-04-30 and has been removed.
```

#### Inference

This showed that upstream removals can break Linux evaluation entirely when host evaluation is not part of regular repo hygiene.

#### Current state

`mysql80` has been replaced with `mariadb.client`, and `nixosConfigurations.farnsworth.config.system.build.toplevel.drvPath` now evaluates.

#### Best-practice comparison

For a flake-based workstation repo, host evaluation should be part of normal repo hygiene. A broken evaluation target is a top-priority maintenance defect, not an incidental package issue.

### 2. High: the repo claims ephemeral-root impermanence semantics that it does not actually implement

#### Repo facts

The repo comments describe a tmpfs-backed or wiped root:

- [modules/nixos/impermanence/default.nix](../modules/nixos/impermanence/default.nix:12)
- [hosts/farnsworth/disko.nix](../hosts/farnsworth/disko.nix:69)

But the actual disk layout mounts Btrfs `@root` directly at `/`:

- [hosts/farnsworth/disko.nix](../hosts/farnsworth/disko.nix:70)

The repo configures `environment.persistence."/persist"`:

- [modules/nixos/impermanence/default.nix](../modules/nixos/impermanence/default.nix:16)

But there is no corresponding implementation that makes `/` ephemeral on reboot.

#### Inference

This is not just a documentation issue. The current design presents stronger persistence/security semantics than the machine actually has.

#### Best-practice comparison

Impermanence requires two distinct pieces:

1. a persistence definition
2. a root filesystem strategy that is actually wiped or recreated

Having only `environment.persistence` is not equivalent to an ephemeral root.

### 3. High: Claude is still the weakest ownership fit in the generalized agent setup

#### Repo facts

Claude settings are generated declaratively:

- [home/features/ai/agent-configs.nix](../home/features/ai/agent-configs.nix:68)

Global MCPs are merged by rewriting the top-level `mcpServers` field inside `~/.claude.json`:

- [home/features/ai/agent-configs.nix](../home/features/ai/agent-configs.nix:77)

The generated file used as merge input is:

- [home/features/ai/agent-configs.nix](../home/features/ai/agent-configs.nix:71)

#### Inference

This means Nix still effectively owns part of Claude’s mutable user-state domain. That is weaker than the current Codex model and less clean than Cursor’s explicitly managed global MCP file.

#### Best-practice comparison

Claude’s config/state model is not the same as Codex’s or Cursor’s. The current merge approach is workable, but it is still more brittle than a clearly separate managed-policy layer or a narrower user-owned integration boundary.

### 4. Medium-high: the shared AI/MCP model is not fully cross-platform operationally

#### Repo facts

Some MCP servers rely on inherited environment variables:

- [hosts/shared/ai-agents.nix](../hosts/shared/ai-agents.nix:111)

The repo exports those env vars through a macOS `launchctl` helper:

- [home/features/secrets/default.nix](../home/features/secrets/default.nix:8)
- [home/features/secrets/default.nix](../home/features/secrets/default.nix:118)
- [home/features/secrets/default.nix](../home/features/secrets/default.nix:123)

I found no Linux equivalent for propagating the same secret-backed environment into GUI/session scope.

#### Inference

The abstract model says these MCP definitions are shared, but the operational authentication path is Darwin-specific today.

#### Best-practice comparison

Cross-platform abstractions should either:

- have equivalent runtime plumbing on every supported platform, or
- be explicitly scoped to the platforms where they are fully wired

### 5. Resolved: Linux update notifications are now flake-aware

#### Repo fact

The Linux update timer previously ran:

- [hosts/farnsworth/default.nix](../hosts/farnsworth/default.nix:276)

and calls:

- [hosts/farnsworth/default.nix](../hosts/farnsworth/default.nix:278)

```bash
nix-channel --update
```

#### Inference

That update notification path was operationally stale. It did not reflect actual flake input drift and was conceptually from a different package-management model than the rest of the repo.

#### Current state

The timer now renders an updated `flake.lock` into a temporary file with `nix flake update --output-lock-file` and notifies only when that lock differs from the repo lock.

#### Best-practice comparison

In a flake-managed repo, update prompts should be tied to `flake.lock` or disabled. Channel-based notifications in a flake repo create ambiguity and low-signal operational noise.

### 6. Resolved: Darwin Homebrew activation is now idempotent

#### Repo facts

The Darwin Homebrew module previously set:

- [modules/darwin/brew/default.nix](../modules/darwin/brew/default.nix:15)

```nix
onActivation = {
  autoUpdate = true;
  cleanup = "zap";
  upgrade = true;
};
```

#### Inference

This was a convenience-first stance, not a reproducibility-first stance. It meant repeated activations could change machine state based on Homebrew upstream changes even without a repo diff.

#### Current state

Normal `darwin-rebuild switch` now disables Homebrew auto-update and package upgrades during activation. The explicit update workflow performs Homebrew updates in its own step using the declarative Brewfile.

#### Best-practice comparison

Keeping ordinary activation idempotent is the better default. Mutable Homebrew updates still exist, but they now happen during the explicit update workflow rather than every switch.

### 7. Resolved: low-level ownership duplication was reduced

#### Repo facts

Btrfs maintenance previously existed both in:

- [hosts/farnsworth/disko.nix](../hosts/farnsworth/disko.nix:142)
- [modules/nixos/btrfs-maintenance/default.nix](../modules/nixos/btrfs-maintenance/default.nix:8)

NixOS host construction was duplicated in:

- [flake.nix](../flake.nix:75)
- [flake.nix](../flake.nix:97)

Unused or dead structure existed:

- `supportedSystems` / `forAllSystems` in [flake.nix](../flake.nix:42)
- empty file [home/features/packages/default.nix](../home/features/packages/default.nix)

#### Inference

These are not acute issues, but they increase maintenance cost and make future changes more error-prone.

#### Current state

- Btrfs scrub ownership now lives in `modules/nixos/btrfs-maintenance`.
- `flake.nix` uses small host-constructor helpers for repeated Darwin, NixOS, and installer patterns.
- The unused `forAllSystems` binding and empty `home/features/packages/default.nix` file were removed.

#### Best-practice comparison

For a repo of this size, domain ownership should be single-purpose where possible:

- storage layout in one place
- storage maintenance in one place
- host constructors abstracted if variants are intentionally parallel

## Recommendations

### Immediate fixes

1. Keep the repo-level `scripts/check-config.sh` check in normal maintenance workflows:
   - Darwin evaluation
   - `farnsworth` evaluation
   - `farnsworth-x86` evaluation
   - installer package evaluation

### Medium-term refactors

1. Make the impermanence story true:
   - implement a genuinely ephemeral root, or
   - remove the tmpfs/ephemeral-root claims from comments and warnings
2. Rework Claude integration so Nix does not effectively own a mutable app state file.
3. Add Linux-equivalent secret/session propagation for shared MCP auth, or mark those integrations as Darwin-only until that exists.
4. Keep Btrfs ownership boundaries clear:
   - layout in `disko`
   - persistence in `impermanence`
   - maintenance in `modules/nixos/btrfs-maintenance`

### Optional longer-term improvements

1. Keep normal Darwin activation idempotent; use the explicit update workflow for Homebrew upgrades.

## Do Not Change

These patterns are correct and should remain intentionally tool-specific:

- Do not manage `~/.codex/config.toml` declaratively again.
- Do not force one identical ownership model onto Codex, Claude, and Cursor.
- Keep `aiAgents` as the shared data model and per-tool renderers as the ownership boundary.
- Keeping `home-manager.useGlobalPkgs = true` is fine, but its consequences should stay documented and understood.

## Known Blockers / Risks

- The root filesystem is persistent unless a separate ephemeral-root strategy is added.
- Claude global MCP handling is still more stateful and fragile than the rest of the agent architecture.
- Homebrew updates are intentionally mutable, but now isolated to the explicit update workflow rather than ordinary activation.

## Source Notes

External references used where current tool behavior materially affects conclusions:

- Nix flake checking and lock updates:
  - <https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-check.html>
  - <https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-update.html>
- Home Manager `useGlobalPkgs`:
  - <https://home-manager.dev/manual/23.05/nixos-options.html>
- nix-darwin manual:
  - <https://nix-darwin.github.io/nix-darwin/manual/index.html>
- impermanence:
  - <https://github.com/nix-community/impermanence>
- sops-nix:
  - <https://github.com/Mic92/sops-nix>
- Claude Code settings and MCP behavior:
  - <https://code.claude.com/docs/en/settings>
  - <https://code.claude.com/docs/en/mcp>
- Cursor MCP configuration:
  - <https://docs.cursor.com/advanced/model-context-protocol>
- Codex config behavior:
  - <https://github.com/openai/codex/blob/main/docs/config.md>
