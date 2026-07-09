# AI Agent Catalog Implementation Handoff

Date: 2026-07-08

This is a handoff document, not the design spec. The source of truth for the
architecture and feature design is [ai-agent-catalog-plan.md](./ai-agent-catalog-plan.md).

Use this file to start a fresh Codex session in Plan mode, make that session
read the plan correctly, and then let it produce an implementation plan that can
be approved with Implement.

## One-Shot Prompt

Paste this into a new Codex session from the repo root:

```text
Use Codex Plan mode.

Repository: /Users/C.Hessel/.config/nix-dotfiles

Goal: implement the Nix-managed AI agent catalog. Treat
docs/ai-agent-catalog-plan.md as the design source of truth, and treat
docs/ai-agent-catalog-implementation-handoff.md as the execution handoff.

Do not edit files yet.

First read, in order:
1. AGENTS.md
2. docs/ai-agent-catalog-implementation-handoff.md
3. docs/ai-agent-catalog-plan.md
4. Existing AI modules named in the handoff read list

Then inspect the current repo state and produce a concrete implementation plan:
- exact files to add/edit
- migration strategy for existing caveman and Graphify skill fan-out
- checks to add
- verification commands to run
- risks and how the implementation avoids them

After presenting that plan, wait for me to approve implementation.
```

## Handoff Contract

The next session should not treat this handoff as another competing plan. It
should use it as a checklist for consuming the actual plan.

Required behavior:

- Read [ai-agent-catalog-plan.md](./ai-agent-catalog-plan.md) completely before
  proposing implementation.
- Confirm the codebase still matches the assumptions in the plan.
- Convert the plan into a file-by-file implementation plan.
- Keep changes scoped to the AI catalog work.
- Preserve current working behavior unless the plan explicitly says to migrate
  it.
- Stop after planning until the user approves implementation.

## Read List

The new session should inspect these files before planning edits:

- [AGENTS.md](../AGENTS.md)
- [docs/ai-agent-catalog-plan.md](./ai-agent-catalog-plan.md)
- [hosts/shared/ai-agents.nix](../hosts/shared/ai-agents.nix)
- [flake/ai-agent-sources.nix](../flake/ai-agent-sources.nix)
- [hosts/shared/ai-agents-lib.nix](../hosts/shared/ai-agents-lib.nix)
- [hosts/shared/ai-agents-default.nix](../hosts/shared/ai-agents-default.nix)
- [hosts/shared/codex.nix](../hosts/shared/codex.nix)
- [hosts/shared/claude-code.nix](../hosts/shared/claude-code.nix)
- [home/features/ai/default.nix](../home/features/ai/default.nix)
- [home/features/ai/agent-configs.nix](../home/features/ai/agent-configs.nix)
- [home/features/ai/caveman.nix](../home/features/ai/caveman.nix)
- [home/features/ai/graphify.nix](../home/features/ai/graphify.nix)
- [home/features/ai/codebase-memory.nix](../home/features/ai/codebase-memory.nix)
- [home/features/ai/rtk.nix](../home/features/ai/rtk.nix)
- [home/features/ai/mcp-profiles.nix](../home/features/ai/mcp-profiles.nix)
- [scripts/check-config.sh](../scripts/check-config.sh)

If Codex/Claude skill behavior, custom-agent behavior, or plugin behavior is
uncertain, verify against current official docs before planning that part.

## Planning Instructions

The implementation plan produced by the new session should be organized around
the rollout phases in [ai-agent-catalog-plan.md](./ai-agent-catalog-plan.md),
but it should not blindly implement every future phase if doing so would
increase risk.

The first production slice should include:

- catalog option schema
- skill rendering
- skill validation/checking
- `agent-catalog-status`
- `agent-catalog-check`
- `scripts/check-config.sh` integration: always validate catalog candidate at
  eval time, and run applied `agent-catalog-check` only when current Home
  Manager generation already exposes command and manifest
- migration or clearly documented bridging for existing caveman skill fan-out
- migration or clearly documented bridging for Graphify-owned skills

The Plan mode response should explicitly decide whether role/plugin rendering is
part of the first implementation or deferred. If deferred, it must explain why
and make sure any schema added for roles/plugins is honest about not being
rendered yet.

## Implementation Guardrails

Preserve these invariants from the design plan:

- `aiAgents.mcpServers` remains the MCP source of truth.
- `aiAgents.mcpProfiles` remains the MCP profile source of truth.
- Runtime services remain in their feature modules.
- No public registry auto-install during activation.
- No secrets in catalog metadata, generated files, plugin manifests, or status
  output.
- No broad unrelated refactor.
- No duplicate long-term target-path tables in multiple modules.
- Existing global instruction files keep their current behavior.
- Existing status commands remain meaningful.

The implementation should prefer small shared helpers over a large abstraction.
Only extract a helper into `ai-agents-lib.nix` when at least two call sites need
it or when it prevents target-path duplication.

## Files Likely To Change

Expected additions:

- `hosts/shared/ai-agent-catalog.nix`
- `home/features/ai/agent-catalog.nix`

Expected edits:

- `hosts/shared/ai-agents-default.nix`
- `hosts/shared/ai-agents-lib.nix`
- `home/features/ai/default.nix`
- `home/features/ai/caveman.nix`
- `home/features/ai/graphify.nix`
- `scripts/check-config.sh`

Possible edits:

- `ARCHITECTURE.md`
- `README.md`
- `docs/ai-agent-catalog-plan.md`

Avoid editing unrelated modules unless inspection proves it is necessary.

## What Counts As Done

The implementation is done only when:

- the first production slice from this handoff is implemented
- current behavior is preserved or intentionally migrated
- status/check commands exist and are usable
- all target path rendering for migrated skills is centralized
- catalog validation catches obvious broken entries
- `scripts/check-config.sh` covers both pre-activation catalog evaluation and
  applied catalog check when available
- repo verification passes

If implementation cannot complete one item, the final response must say which
item is deferred and why.

## Verification Required

Run these before final response:

```bash
nix flake check
nix eval .#darwinConfigurations.zoidberg.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.farnsworth.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.farnsworth-x86.config.system.build.toplevel.drvPath
./scripts/check-config.sh
```

Also run the new commands after implementation:

```bash
agent-catalog-check
agent-catalog-status
```

If the sandbox blocks Nix cache lock access under `~/.cache/nix`, rerun the
same verification command with scoped escalation and explain why.

## Expected Final Response From New Session

The final implementation response should be concise and include:

- files changed
- behavior added
- existing behavior preserved
- verification commands and results
- any deferred work with reason

Do not include a long restatement of the design. Link back to
[ai-agent-catalog-plan.md](./ai-agent-catalog-plan.md) for design context.
