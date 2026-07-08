# Nix Skill-Onboarding Skill Handoff

Date: 2026-07-08

This handoff is for a new Codex or Claude Code session that should create a
repo-scoped skill for onboarding new Agent Skills into this repository's Nix
managed `aiAgents.catalog`.

The desired skill is not itself provided through `aiAgents.catalog`. It should
be checked into this repository as a project skill so it is available only when
working in this repo. `.agents/skills` is the source of truth; `.claude/skills`
should expose the same skill to Claude Code through a symlink.

## One-Shot Prompt

Paste this into a new Codex session from the repo root:

```text
Use Codex Plan mode.

Repository: /Users/C.Hessel/.config/nix-dotfiles

Goal: create a repo-scoped Agent Skill that helps onboard new skills into this
repo's Nix-managed aiAgents.catalog.

The skill itself must not be provided through aiAgents.catalog. Its source of
truth must live as a committed project skill under .agents/skills so Codex sees
it only in this repo. Also expose it to Claude Code by adding a project skill
symlink under .claude/skills pointing back to the .agents/skills source
directory.

Do not edit files yet.

First read:
1. AGENTS.md
2. docs/nix-skill-onboard-skill-handoff.md
3. docs/ai-agent-catalog-plan.md
4. docs/ai-agent-catalog-implementation-handoff.md
5. hosts/shared/ai-agent-catalog.nix
6. home/features/ai/agent-catalog.nix
7. hosts/shared/ai-agents-lib.nix
8. flake.nix
9. scripts/check-config.sh

Then produce a concrete implementation plan for the skill: files to add,
symlink to add, skill name/description, workflow, validation, and focused
checks. Wait for my approval before implementation.
```

For a Claude Code session, use the same prompt with this replacement:

```text
Use Claude Code planning first. Do not edit files until the plan is accepted.
The implementation target is the same: .agents/skills is source of truth, and
.claude/skills/nix-skill-onboard is a symlink to that source directory.
```

## Target Artifacts

Create this source skill:

```text
.agents/skills/nix-skill-onboard/SKILL.md
```

Also create this Claude Code project-skill symlink:

```text
.claude/skills/nix-skill-onboard -> ../../.agents/skills/nix-skill-onboard
```

Do not duplicate `SKILL.md` under `.claude/skills`. The symlink preserves a
single point of truth.

Recommended skill identity:

```yaml
name: nix-skill-onboard
description: Use when adding, importing, pinning, reviewing, or updating Agent Skills in this nix-dotfiles repo's aiAgents.catalog. Guides safe onboarding from GitHub, local sources, flake inputs, or vendored copies into the Nix-managed catalog with trust, target, validation, and rollout checks.
```

This path is deliberate:

- Codex scans repo `.agents/skills` from the working directory to repo root.
- Codex supports symlinked skill folders, but it does not need one here because
  `.agents/skills` is already its native repo skill location.
- Claude Code scans repo `.claude/skills` and supports a skill-directory symlink
  to another directory on disk in Claude Code v2.1.203 or newer.
- The skill is repo-specific and should not become a global/personal skill.
- The skill is not bootstrapped by the catalog it teaches agents to modify.
- It can safely mention this repo's internal files and workflows.

Docs-backed compatibility:

- Codex manual: repo skills live under `.agents/skills`; symlinked skill
  folders are supported.
- Claude Code skills docs: project skills live under `.claude/skills`; a
  `<skill-name>` entry can be a symlink to another directory in v2.1.203 or
  newer.
- If `.claude/skills` did not exist when Claude Code started, restart Claude
  Code after creating the directory. Edits to an existing `SKILL.md` are
  live-detected.

## Current Implementation Facts

The catalog implementation already exists.

Key files:

- `hosts/shared/ai-agent-catalog.nix`
  - Defines `aiAgents.catalog`.
  - Defines `skills`, `roles`, and `plugins` option schemas.
  - Default managed skills currently include caveman skills and
    `graphify-auto`.
  - `graphify` is runtime-owned, `external-experimental`, `implicit = false`,
    `managed = false`.
  - Trust enum: `local-authored`, `pinned-flake`, `vendored-reviewed`,
    `external-experimental`.
  - Managed skills require exactly one of `source` or `text`.
  - Managed skill frontmatter is checked at Nix evaluation.

- `home/features/ai/agent-catalog.nix`
  - Renders catalog skills into target-specific Home Manager files.
  - Writes applied manifest to `~/.agents/catalog/manifest.json`.
  - Provides `agent-catalog-check`.
  - Provides `agent-catalog-status`.

- `hosts/shared/ai-agents-lib.nix`
  - Owns target path helpers:
    - `skillTargetDir`
    - `skillTargetPath`
    - `renderedSkillPathsFor`

- `scripts/check-config.sh`
  - Runs `nix flake check`.
  - Evaluates catalog candidate manifest.
  - Runs applied `agent-catalog-check` only when command and manifest exist.
  - Evaluates declared hosts and installer packages.

Current applied status:

- Codex/Vibe discover catalog skills through `~/.agents/skills`.
- Cursor discovers caveman skills through `~/.cursor/skills`.
- Claude discovers `graphify-auto` through `~/.claude/skills`.
- Runtime Graphify skill files are generated by `graphify.nix`, not managed by
  catalog.

## Skill Scope

The new skill should help future agents do this one job well:

```text
Given a requested skill source or skill idea, safely onboard it into this repo's
Nix-managed aiAgents.catalog or explain why it should not be onboarded.
```

It should cover:

- adding local-authored skills
- adding GitHub/pinned external skill sources
- deciding when to vendor a reviewed copy
- deciding when to mark a skill runtime-owned instead of managed
- choosing `targets`
- choosing `trust`
- deciding `implicit`
- preserving secrets and avoiding registry auto-install
- running correct validation
- updating documentation only when needed

It should not:

- create a generic public skill manager
- install skills live from public registries during activation
- add secrets or tokens to Nix, skill files, plugin manifests, or docs
- change MCP/server/profile design unless needed for a skill dependency
- rewrite the catalog renderer unless the catalog schema cannot express the
  requested onboarding

## Required Workflow Inside The Skill

The skill body should instruct the agent to follow this workflow.

1. Inspect current state.

   Read these first when onboarding a skill:

   - `AGENTS.md`
   - `hosts/shared/ai-agent-catalog.nix`
   - `home/features/ai/agent-catalog.nix`
   - `hosts/shared/ai-agents-lib.nix`
   - `flake.nix`
   - `scripts/check-config.sh`

   Run:

   ```bash
   agent-catalog-status
   ```

   Use `rg` for local search. Do not use broad Nix checks before editing.

2. Classify source.

   Use one of these categories:

   - `local-authored`: skill source lives in this repo.
   - `pinned-flake`: source is a pinned flake input, usually `flake = false`.
   - `vendored-reviewed`: source is copied into this repo after review.
   - `external-experimental`: visible/reportable, but not implicitly invoked.

3. Review skill metadata.

   Check `SKILL.md`:

   - frontmatter exists
   - `name` matches catalog key
   - `description` is specific enough for implicit routing
   - no credentials, tokens, private paths, or unsafe instructions
   - scripts exist only when deterministic behavior justifies them

4. Decide target set.

   Use existing target names only:

   ```nix
   [ "codex" "claude" "cursor" "vibe" ]
   ```

   Prefer explicit target selection over universal fan-out. Mention known target
   behavior:

   - Codex/Vibe use `.agents/skills`.
   - Claude uses `.claude/skills`.
   - Cursor uses `.cursor/skills`.
   - Target path logic belongs in `ai-agents-lib.nix`, not per skill module.

5. Modify catalog.

   For managed source skill:

   ```nix
   my-skill = {
     source = flake.inputs.some-source + "/skills/my-skill";
     targets = [ "codex" "claude" "cursor" "vibe" ];
     trust = "pinned-flake";
     owner = "github:owner/repo";
     implicit = true;
   };
   ```

   For local text skill:

   ```nix
   my-skill = {
     text = ''
       ---
       name: my-skill
       description: Clear trigger description.
       ---

       Instructions.
     '';
     targets = [ "codex" ];
     trust = "local-authored";
     owner = "nix-dotfiles";
     implicit = true;
   };
   ```

   For runtime-owned skill:

   ```nix
   my-runtime-skill = {
     targets = [ "codex" ];
     trust = "external-experimental";
     owner = "tool-name";
     implicit = false;
     managed = false;
   };
   ```

6. If adding GitHub source.

   Prefer pinned flake input:

   ```nix
   some-skills = {
     url = "github:owner/repo/<rev-or-tag>";
     flake = false;
   };
   ```

   Then use `flake.inputs.some-skills + "/path/to/skill"`.

   Do not use `npx skills add`, `skill-installer`, or registry install as the
   production rollout mechanism. Those are discovery/scouting tools only.

7. Validate.

   Run focused checks after edits:

   ```bash
   nixpkgs-fmt --check hosts/shared/ai-agent-catalog.nix home/features/ai/agent-catalog.nix hosts/shared/ai-agents-lib.nix
   agent-catalog-check
   agent-catalog-status
   ```

   If Nix files or flake inputs changed, run relevant Nix checks:

   ```bash
   nix eval '.#darwinConfigurations.zoidberg.config.home-manager.users."C.Hessel".home.file.".agents/catalog/manifest.json".text' >/dev/null
   ./scripts/check-config.sh
   ```

   If the change is only this repo-scoped skill's documentation, do not run Nix
   evaluation.

## Skill Creation Requirements

Follow `skill-creator` guidance:

- Keep `SKILL.md` concise.
- Use strong `description`; it is the routing signal.
- Do not create README, install guide, changelog, or unrelated docs inside the
  skill folder.
- Add reference files only if `SKILL.md` would otherwise become too long.
- If references are needed, keep them one level deep and link them directly
  from `SKILL.md`.

Recommended first implementation:

```text
.agents/skills/nix-skill-onboard/
  SKILL.md
.claude/skills/
  nix-skill-onboard -> ../../.agents/skills/nix-skill-onboard
```

Do not add `agents/openai.yaml` in first pass unless the implementation session
confirms repo-scoped Codex UI metadata is needed. The skill's value is the
workflow, not marketplace presentation.

## Expected Skill Behavior

When a future user asks any of these:

- "add this GitHub skill to my setup"
- "onboard this skill into nix"
- "make this skill available to Codex and Claude"
- "import this SKILL.md into aiAgents.catalog"
- "pin this skill repo and add it to catalog"

Codex should select `nix-skill-onboard` through `.agents/skills`; Claude Code
should select the same skill through the `.claude/skills` symlink. The selected
agent should then:

1. inspect existing catalog and target renderers
2. inspect requested skill source
3. recommend safe source strategy
4. add minimal Nix changes
5. run focused checks
6. report exact availability by target

## Plan-Mode Expectations

The implementation session should not immediately create the skill. It should
first present a plan containing:

- final skill path
- final Claude symlink path
- final skill name and description
- whether `SKILL.md` alone is enough
- exact files to add/edit
- no-op list of files intentionally not changed
- checks to run

Then wait for approval / Implement.

## What Counts As Done

Done means:

- `.agents/skills/nix-skill-onboard/SKILL.md` exists.
- `.claude/skills/nix-skill-onboard` exists as a symlink to
  `../../.agents/skills/nix-skill-onboard`.
- It has valid frontmatter.
- Description is specific enough for implicit selection.
- Body contains repo-specific onboarding workflow.
- It references existing catalog files accurately.
- It clearly says the skill itself is repo-scoped, not catalog-provided.
- It does not duplicate the whole catalog design docs.
- It tells agents not to live-install registry skills during activation.
- It defines focused validation rules.

## Verification For This Handoff's Implementation

Because creating this handoff is docs-only, verify only docs surface:

```bash
rg -n "nix-skill-onboard|aiAgents.catalog|agent-catalog-check|registry|flake input" docs/nix-skill-onboard-skill-handoff.md
rg -n "^```" docs/nix-skill-onboard-skill-handoff.md
rg -n "\.claude/skills|symlink|v2\.1\.203|single point of truth" docs/nix-skill-onboard-skill-handoff.md
```

For the future skill implementation session:

- If only `.agents/skills/nix-skill-onboard/SKILL.md` and the
  `.claude/skills/nix-skill-onboard` symlink are added, check frontmatter and
  symlink target only. No Nix eval needed.
- If catalog or flake files are changed, run catalog/Nix checks listed above.

## Open Questions For New Session

Plan mode should answer these before implementation:

1. Should the skill be only `SKILL.md`, or does it need one `references/` file?
2. Should the skill include example Nix snippets, or link to
   `hosts/shared/ai-agent-catalog.nix` and keep snippets minimal?
3. Should it mention Claude/Cursor/Vibe target behavior explicitly, or defer to
   `agent-catalog-status`?
4. Should it include a strict "ask before adding flake input" rule because
   flake input changes require network and lock updates?
5. Should the implementation session verify local Claude Code version before
   relying on symlink discovery, or document v2.1.203+ as a runtime requirement?
