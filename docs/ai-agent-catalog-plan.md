# AI Agent Catalog Plan

Date: 2026-07-08

## Purpose

Create a declarative, Nix-managed catalog for reusable AI-agent capabilities in
this dotfiles repo. The catalog should let Codex, Claude Code, Cursor, Vibe, and
future tools receive the right skills, custom agents, MCP references, hooks, and
plugin metadata without each integration growing its own parallel state model.

The goal is not to add a heavyweight runtime manager. Nix should be the catalog
manager: pin inputs, validate structure, render target-specific files, and roll
changes out through Home Manager or system activation.

## Research Basis

This plan is based on current upstream behavior and the local codebase shape.

External references checked:

- Codex skills: <https://developers.openai.com/codex/skills.md>
- Codex `AGENTS.md`: <https://developers.openai.com/codex/guides/agents-md.md>
- Codex MCP: <https://developers.openai.com/codex/mcp.md>
- Codex custom agents: <https://developers.openai.com/codex/subagents.md>
- Codex plugins: <https://developers.openai.com/codex/plugins/build.md>
- Claude Code skills: <https://code.claude.com/docs/en/skills>
- Claude Code subagents: <https://code.claude.com/docs/en/sub-agents>
- Agent Skills specification: <https://agentskills.io/specification>

Local references:

- [AGENTS.md](../AGENTS.md)
- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/architecture-review-2026.md](./architecture-review-2026.md)
- [hosts/shared/ai-agents.nix](../hosts/shared/ai-agents.nix)
- [hosts/shared/ai-agents-lib.nix](../hosts/shared/ai-agents-lib.nix)
- [hosts/shared/codex.nix](../hosts/shared/codex.nix)
- [hosts/shared/claude-code.nix](../hosts/shared/claude-code.nix)
- [home/features/ai/agent-configs.nix](../home/features/ai/agent-configs.nix)
- [home/features/ai/caveman.nix](../home/features/ai/caveman.nix)
- [home/features/ai/codebase-memory.nix](../home/features/ai/codebase-memory.nix)
- [home/features/ai/graphify.nix](../home/features/ai/graphify.nix)
- [home/features/ai/mcp-profiles.nix](../home/features/ai/mcp-profiles.nix)
- [home/features/ai/rtk.nix](../home/features/ai/rtk.nix)

## Current State

The repo already has the right foundation for agent-agnostic configuration.

- `aiAgents.mcpServers` is a neutral MCP server model rendered per target.
- `targets` and `targetOverrides` already express cross-agent variation without
  duplicating server definitions.
- `mcpProfiles` already separate always-on lightweight MCPs from heavy,
  task-specific tools.
- `caveman.nix`, `graphify.nix`, `codebase-memory.nix`, and `rtk.nix` already
  write agent instruction files and skill files, but each does so locally.
- Codex managed config is handled at system scope. Claude mutable user config is
  treated more cautiously and only merged where necessary.

The missing piece is not MCP. The missing piece is a first-class catalog layer
for skills, custom agents/subagents, and optional plugin distribution metadata.

## Design Principles

1. **Single source of truth**

   Define catalog entries once in Nix. Render target-specific files from that
   source. Do not hand-copy prompts, descriptions, target paths, or metadata.

2. **Use portable formats where they are truly portable**

   `SKILL.md` is the portable unit. Keep it canonical. Do not split it into
   `metadata.md` and `prompt.md`; that would create another local format and
   weaken compatibility with Codex, Claude Code, and the Agent Skills spec.

3. **Render vendor-specific files only at the edge**

   Codex custom agents are TOML. Claude subagents are Markdown with YAML
   frontmatter. These should be generated from a neutral role definition rather
   than forced into a fake universal file format.

4. **Preserve current ownership boundaries**

   System-level managed policy remains in `hosts/shared/*.nix`. User-level
   file fan-out remains in `home/features/ai/*.nix`. Shared helpers stay in
   `hosts/shared/ai-agents-lib.nix`.

5. **Prefer symlinked immutable sources where supported**

   Codex and current Claude Code both support symlinked skill directories. Use
   Home Manager `source` links by default unless a specific target requires a
   physical copy.

6. **Trust and provenance are first-class**

   Third-party skills can contain executable instructions and scripts. Public
   registries are discovery sources, not live mutation sources. Anything that
   reaches user machines should be pinned, reviewed, and classified.

7. **Validation is part of the product**

   A curated catalog without checks is only a folder. Broken names, duplicate
   entries, missing source files, unsupported targets, and dangling references
   should fail evaluation or `scripts/check-config.sh`.

## Target Architecture

Add one catalog option tree under the existing `aiAgents` namespace:

```nix
aiAgents.catalog = {
  enable = true;

  skills = {
    caveman = {
      source = aiSources.skills.caveman + "/skills/caveman";
      targets = [ "codex" "claude" "cursor" "vibe" ];
      trust = "pinned-flake";
      implicit = true;
      owner = "caveman";
    };
  };

  roles = {
    reviewer = {
      description = "Review diffs for correctness, security, regressions, and missing tests.";
      prompt = ''
        Review like repository owner. Prioritize bugs, security, regressions,
        and missing tests. Return findings first.
      '';
      targets = [ "codex" "claude" ];
      tools = [ "read" "search" ];
      skills = [ ];
      mcpServers = [ ];
      model = "inherit";
    };
  };

  plugins = {
    local-agent-tools = {
      targets = [ "codex" ];
      source = ./agents/plugins/local-agent-tools;
      installation = "AVAILABLE";
      category = "Productivity";
    };
  };
};
```

Keep options in a new system module:

- `hosts/shared/ai-agent-catalog.nix`

Render user files in a new Home Manager module:

- `home/features/ai/agent-catalog.nix`

Keep reusable render/check helpers in:

- `hosts/shared/ai-agents-lib.nix`

Import points:

- Add `./ai-agent-catalog.nix` to [hosts/shared/ai-agents-default.nix](../hosts/shared/ai-agents-default.nix).
- Add `./agent-catalog.nix` to [home/features/ai/default.nix](../home/features/ai/default.nix).

## Capability Model

| Capability | Portability | Source of truth | Render targets |
| --- | --- | --- | --- |
| Durable repo instructions | Partly portable | `AGENTS.md` plus tool-specific global files | Existing modules continue writing `.codex/AGENTS.md`, `.claude/CLAUDE.md`, `.vibe/AGENTS.md` |
| Skills | Portable core | Skill directory containing canonical `SKILL.md` | `~/.agents/skills`, `~/.claude/skills`, `~/.cursor/skills`, compatibility paths as needed |
| Skill sidecars | Vendor-specific | Nix metadata inside skill catalog entry | Codex `agents/openai.yaml`, Claude-only frontmatter fields when explicit |
| Custom agents/subagents | Not portable | Neutral `roles` attrset | Codex TOML under `~/.codex/agents`, Claude Markdown under `~/.claude/agents` |
| MCP servers | Protocol portable, config not portable | Existing `aiAgents.mcpServers` | Existing renderers |
| MCP profiles | Local operational profile | Existing `aiAgents.mcpProfiles` | Existing `mcp-profile-*` binaries |
| Hooks | Vendor-specific | Existing hook modules or future `catalog.hooks` | Codex requirements, Claude/Cursor settings JSON, OpenCode plugin files |
| Plugins | Distribution package | Catalog plugin entry plus plugin source dir | Codex marketplace JSON first; Claude plugin support can be added only if needed |

## Skill Catalog Rules

The catalog should validate every skill before rendering.

Required:

- `source` points to a directory.
- `source/SKILL.md` exists.
- frontmatter has `name` and `description`.
- `name` matches the Agent Skills naming rules: lowercase alphanumeric plus
  hyphen, no leading/trailing hyphen, no consecutive hyphens.
- directory basename matches `name` unless an explicit compatibility exception
  is documented.
- `description` is non-empty and no longer than 1024 characters.
- `targets` contains only enabled clients from `aiAgents.targets`.

Recommended warnings:

- `description` shorter than 40 characters.
- `SKILL.md` over 500 lines.
- `SKILL.md` embeds long reference content instead of linking `references/`.
- skill contains scripts but no trust/provenance note.
- vendor-specific frontmatter appears without target scoping.

Trust levels:

```nix
trust = "local-authored" | "pinned-flake" | "vendored-reviewed" | "external-experimental";
```

Rendering policy:

- `local-authored`, `pinned-flake`, and `vendored-reviewed` can be enabled by
  default.
- `external-experimental` should require explicit opt-in and should not get
  pre-approved tools or implicit invocation by default.

## Target-Specific Skill Rendering

Codex:

- Prefer `~/.agents/skills/<name>` for portable user skills.
- Allow optional `/etc/codex/skills/<name>` only for machine-wide admin skills.
- Generate `agents/openai.yaml` only from explicit Nix metadata.
- Use `skills.config` only to disable or policy-adjust already visible skills.

Claude Code:

- Render to `~/.claude/skills/<name>` for personal skills when Claude-specific
  features are required.
- Otherwise allow using shared `~/.agents/skills` if a target supports it, but
  do not rely on undocumented behavior.
- Use Claude-specific frontmatter only when the skill intentionally targets
  Claude: `disable-model-invocation`, `allowed-tools`, `context`, `agent`,
  `paths`, or `hooks`.

Cursor:

- Continue supporting `~/.cursor/skills/<name>` because current modules already
  use that documented global path.
- Add project-only handling later if a repo needs committed Cursor skills or
  rules.

Vibe:

- Prefer `~/.agents/skills/<name>` based on current local module behavior.
- Do not invent Vibe-specific sidecars until Vibe exposes stable config for
  them.

## Role And Subagent Rendering

Do not store one Markdown subagent file and hope every agent reads it. Store a
neutral role and render per target.

Neutral role fields:

```nix
{
  description = "...";
  prompt = "...";
  targets = [ "codex" "claude" ];
  tools = [ "read" "search" "shell" ];
  deniedTools = [ ];
  model = "inherit";
  effort = null;
  maxTurns = null;
  skills = [ ];
  mcpServers = [ ];
  sandboxMode = null;
  isolation = null;
}
```

Codex renderer:

- Output TOML files under `~/.codex/agents/<name>.toml`.
- Required fields: `name`, `description`, `developer_instructions`.
- Optional fields can reuse normal Codex config keys: `model`,
  `model_reasoning_effort`, `sandbox_mode`, `mcp_servers`, `skills.config`.
- Keep Codex default behavior explicit: Codex only spawns subagents when asked.

Claude renderer:

- Output Markdown files under `~/.claude/agents/<name>.md`.
- Required frontmatter: `name`, `description`.
- Body is the system prompt.
- Map `tools`, `model`, `skills`, `mcpServers`, `maxTurns`, `effort`, and
  `isolation` only where semantics match Claude docs.
- Do not render Claude `permissionMode`, `hooks`, or `memory` unless explicitly
  set; these fields have operational/security consequences.

Validation:

- Every `roles.<name>.skills` item must exist in `catalog.skills`.
- Every `roles.<name>.mcpServers` item must exist in `aiAgents.mcpServers`.
- Tool names should be target-mapped. Neutral names like `read`, `search`, and
  `shell` should be rendered through a small mapping table instead of copied.

## Plugin Strategy

Use plugins as packaging, not as the internal authoring primitive.

Codex:

- Generate `~/.agents/plugins/marketplace.json` from `aiAgents.catalog.plugins`.
- Keep plugin source paths local or pinned.
- Use plugins when bundling skills with MCP config, app integrations, hooks,
  assets, or workspace-shareable packages.

Claude:

- Do not add Claude plugin rendering in the first implementation unless there
  is a concrete package to distribute. Claude plugin behavior differs enough
  that it should be added as a separate renderer once needed.

Rule:

- Skills are authored and validated first.
- Plugins package already-valid skills.
- Marketplace files should never be the only place a skill is described.

## Integration With Existing Modules

Phase in without rewriting working modules immediately.

Initial migration targets:

1. Move `cavemanSkills` list and fan-out from `caveman.nix` into
   `aiAgents.catalog.skills`.
2. Keep `cavemanDefaultInstructions` in `caveman.nix` for now because it is a
   behavior default, not only a skill install.
3. Move `graphify-auto` and Graphify skill path metadata into catalog entries,
   but keep Graphify install/update/onboard commands in `graphify.nix`.
4. Keep codebase-memory as an MCP/workflow module until upstream scoped-cache
   work lands. Its AGENTS instructions can later become a skill.
5. Keep RTK hooks in `rtk.nix`; optionally add an `rtk` skill later only if
   there is a real reusable workflow beyond current global instructions.

Do not force all AI modules through the catalog. Catalog owns reusable agent
capabilities. Runtime services and launchd/systemd concerns stay in their
feature modules.

## File Layout

Recommended local layout after implementation:

```text
flake/
  ai-agent-sources.nix       # typed registry for AI-owned flake inputs

hosts/shared/
  ai-agent-catalog.nix       # option schema and default catalog entries
  ai-agents-lib.nix          # shared render/validation helpers

home/features/ai/
  agent-catalog.nix          # user-level rendered files and status command
  default.nix                # imports agent-catalog.nix

agents/
  skills/                    # optional local-authored canonical skill sources
    reviewer/SKILL.md
    nix-maintenance/SKILL.md
  plugins/                   # optional local plugin package sources
    local-agent-tools/.codex-plugin/plugin.json

docs/
  ai-agent-catalog-plan.md   # this plan
```

`agents/skills` is optional. Use it only for local-authored skills whose source
should live in this repo.

Nix flake inputs must remain statically declared in `flake.nix`, so external
AI-owned inputs still get pinned there under an AI agent source section. Their
typed use-site registry belongs in `flake/ai-agent-sources.nix`. Catalog and AI
feature modules should consume that registry instead of reaching directly into
`flake.inputs`, keeping skill repositories, MCP server flakes, and agent-tool
sources grouped without placing flake-level source data inside host module
folders.

## Status And Operations

Add one status command:

```bash
agent-catalog-status
```

It should report:

- enabled targets
- rendered skill count per target
- missing source files
- duplicate names
- role count per target
- plugin marketplace path and plugin count
- trust summary by level
- warnings for experimental entries

Keep existing specialist status commands:

- `caveman-status`
- `graphify-status`
- `codebase-memory-status`
- `mcp-profile-status`
- `rtk-status`
- `headroom-status`

`agent-catalog-status` should summarize catalog health, not replace operational
status for services.

## Validation Plan

Nix evaluation assertions:

- duplicate skill names fail
- unsupported targets fail
- missing source directories fail when statically known
- missing role references fail
- duplicate role names fail
- invalid trust value fails
- plugin source path missing fails

Build/check scripts:

- Add `agent-catalog-check` shell command or Nix package.
- Wire it into `scripts/check-config.sh` in two layers: pre-activation Nix
  evaluation of the generated catalog candidate, and applied-state
  `agent-catalog-check` only when the command and manifest already exist.
- Validate Markdown/frontmatter using a small script rather than ad hoc grep.
- Prefer Python or `yq` only if already available through Nix; avoid hidden
  host dependencies.

Suggested checks:

```text
agent-catalog-check
  parse every SKILL.md frontmatter
  validate Agent Skills naming rules
  validate description length and specificity floor
  validate target-specific sidecars
  validate generated marketplace JSON
  print warnings separately from hard failures
```

Manual verification:

- `nix eval .#darwinConfigurations.zoidberg.config.system.build.toplevel.drvPath`
- `nix eval .#nixosConfigurations.farnsworth.config.system.build.toplevel.drvPath`
- `nix eval .#nixosConfigurations.farnsworth-x86.config.system.build.toplevel.drvPath`
- `./scripts/check-config.sh`
- `agent-catalog-status`

## Security Model

Skills are executable instructions. Treat them as supply-chain inputs.

Rules:

- Never install directly from a public registry into live paths during normal
  activation.
- Discover externally, then pin via flake input or vendor reviewed copy.
- Record provenance for each external skill.
- Do not grant pre-approved shell/tools to external skills by default.
- Keep secrets out of Nix store and generated sidecars.
- Do not render bearer tokens or API keys into skills, plugin manifests, or
  marketplace JSON.
- Any skill that deploys, sends messages, deletes resources, edits secrets, or
  performs irreversible operations should default to explicit invocation only.

## Rollout Plan

### Phase 1: Catalog Skeleton

Deliverables:

- Add `hosts/shared/ai-agent-catalog.nix`.
- Add `home/features/ai/agent-catalog.nix`.
- Add minimal `aiAgents.catalog.enable`.
- Add type definitions for `skills`, `roles`, and `plugins`.
- Add `agent-catalog-status`.

Acceptance:

- No behavior change for existing skills or MCP setup.
- Existing host evaluations still pass.

### Phase 2: Skill Rendering

Deliverables:

- Implement skill source validation.
- Render portable skill fan-out for `codex`, `claude`, `cursor`, and `vibe`.
- Add sidecar rendering for Codex `agents/openai.yaml`.
- Add warnings for Claude-specific frontmatter in portable skills.

Migration:

- Move caveman skill list into catalog.
- Move Graphify skill metadata into catalog.

Acceptance:

- `caveman-status` and `graphify-status` still show expected files.
- `agent-catalog-status` shows matching rendered skills.

### Phase 3: Role Rendering

Deliverables:

- Add neutral `roles` schema.
- Render Codex TOML custom agents.
- Render Claude Markdown/YAML subagents.
- Validate role references to skills and MCP servers.

Initial roles:

- `reviewer`: code review focused on correctness/security/tests.
- `investigator`: read-only codebase and docs exploration.
- `builder`: tightly scoped implementation worker.

Acceptance:

- Rendered files are syntactically valid.
- Roles do not grant broader tools than intended.
- Codex and Claude differences are visible in generated output.

### Phase 4: Plugin Marketplace

Deliverables:

- Generate personal Codex marketplace JSON at `~/.agents/plugins/marketplace.json`.
- Add catalog plugin entries with local/pinned sources.
- Validate plugin paths and manifest shape.

Acceptance:

- Marketplace JSON is valid.
- No plugin is installed or enabled implicitly unless the catalog says so.

### Phase 5: Checks And CI Hygiene

Deliverables:

- Add `agent-catalog-check`.
- Wire into `scripts/check-config.sh` with pre-activation candidate validation
  plus applied-state check when available.
- Add Nix assertions for all statically-known consistency checks.

Acceptance:

- `./scripts/check-config.sh` covers catalog structure.
- Broken skill metadata fails before activation.

### Phase 6: Documentation And Migration Cleanup

Deliverables:

- Update `ARCHITECTURE.md` with agent catalog layer.
- Update `README.md` AI section with status commands and trust model.
- Remove duplicated per-module skill fan-out once migration is complete.

Acceptance:

- One documented path exists for adding a skill, role, plugin, or MCP profile.
- No duplicated target path tables remain outside renderer helpers unless a
  module has a clear operational reason.

## Non-Goals

- No long-running catalog daemon.
- No live registry auto-install during activation.
- No global memory or cross-repo skill auto-learning.
- No attempt to make Claude subagents and Codex custom agents share one file
  format.
- No replacement for existing MCP profile design.
- No secrets in catalog metadata.

## Open Questions

1. Should local-authored skills live in this repo under `agents/skills`, or in
   a separate pinned flake input from the start?
2. Should user-scope Claude skills be rendered to `~/.claude/skills` always, or
   only when Claude-specific fields are used?
3. Should Codex admin skills under `/etc/codex/skills` be supported now, or
   deferred until a real machine-wide policy need appears?
4. Should plugin marketplace generation be personal-only at first, or also
   support repo-scoped `.agents/plugins/marketplace.json`?
5. Should `codebase-memory` become a skill after upstream scoped-cache support,
   or remain only global instructions plus MCP onboarding?

## Recommended First Implementation

Start narrow:

1. Add catalog schema and status command.
2. Render skills only.
3. Migrate caveman and Graphify skill fan-out.
4. Add validation and `scripts/check-config.sh` integration.
5. Add role rendering after the skill catalog is stable.

This gives immediate DRY value without destabilizing existing MCP, Headroom,
RTK, Graphify, or codebase-memory behavior.
