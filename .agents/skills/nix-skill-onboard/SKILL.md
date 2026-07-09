---
name: nix-skill-onboard
description: Use when adding, importing, pinning, reviewing, or updating Agent Skills in nix-dotfiles repo's aiAgents.catalog. Guides safe onboarding from GitHub, local sources, flake inputs, or vendored copies into Nix-managed catalog with trust, target, validation, and rollout checks.
---

# Nix Skill Onboard

Use this repo-scoped skill to onboard a requested Agent Skill into this repository's Nix-managed `aiAgents.catalog`, or to explain why it should stay out of the catalog.

This skill is itself project-local. Keep its source of truth under `.agents/skills/nix-skill-onboard`; do not add `nix-skill-onboard` to `aiAgents.catalog`.

## Workflow

1. Inspect current state before editing.

   Read:

   - `AGENTS.md`
   - `hosts/shared/ai-agent-catalog.nix`
   - `flake/ai-agent-sources.nix`
   - `home/features/ai/agent-catalog.nix`
   - `hosts/shared/ai-agents-lib.nix`
   - `flake.nix`
   - `scripts/check-config.sh`

   Run `agent-catalog-status` when available. Use `rg` for local search. Do not start with broad Nix checks.

2. Classify the requested skill source.

   Use exactly one trust/source category:

   - `local-authored`: source lives in this repo.
   - `pinned-flake`: source comes from a pinned flake input, usually `flake = false`.
   - `vendored-reviewed`: source is copied into this repo after review.
   - `external-experimental`: visible or reportable, but not implicitly invoked.

3. Review skill metadata and contents.

   Check the candidate `SKILL.md` has frontmatter, `name` matches catalog key, and `description` is specific enough for implicit routing. Reject or revise skills that contain credentials, tokens, private paths, unsafe instructions, unnecessary scripts, or broad registry-install assumptions.

4. Choose explicit targets.

   Use only existing target names: `codex`, `claude`, `cursor`, `vibe`. Prefer the smallest correct target set over universal fan-out.

   Known target paths:

   - Codex and Vibe use `.agents/skills`.
   - Claude uses `.claude/skills`.
   - Cursor uses `.cursor/skills`.

   Keep target path logic in `hosts/shared/ai-agents-lib.nix`; do not duplicate it in per-skill modules.

5. Modify the catalog only when appropriate.

   Managed source skill:

   ```nix
   my-skill = {
     source = aiSources.skills.some-source + "/skills/my-skill";
     targets = [ "codex" "claude" ];
     trust = "pinned-flake";
     owner = "github:owner/repo";
     implicit = true;
   };
   ```

   Local text skill:

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

   Runtime-owned or experimental skill:

   ```nix
   my-runtime-skill = {
     targets = [ "codex" ];
     trust = "external-experimental";
     owner = "tool-name";
     implicit = false;
     managed = false;
   };
   ```

6. Pin external GitHub sources through Nix.

   Nix flake inputs must be declared statically in `flake.nix`. Add the pinned input there under the AI agent source inputs section, then expose it through the typed registry in `flake/ai-agent-sources.nix`. Pin by release tag when available, otherwise by commit; avoid branch refs unless explicitly requested. Catalog and AI feature modules should consume `flake/ai-agent-sources.nix`, not reach directly into `flake.inputs`.

   ```nix
   # flake.nix
   some-skills = {
     url = "github:owner/repo/<tag-or-commit>";
     flake = false;
   };

   # flake/ai-agent-sources.nix
   skills = {
     some-skills = flake.inputs.some-skills;
   };
   ```

   Then reference `aiSources.skills.some-skills + "/path/to/skill"` from catalog modules.

   Do not use `npx skills add`, `skill-installer`, public registry auto-install, or activation-time downloads as the production rollout mechanism. Use those only for scouting.

7. Validate the changed surface.

   For skill-only catalog edits, run focused checks:

   ```bash
   nixpkgs-fmt --check flake/ai-agent-sources.nix hosts/shared/ai-agent-catalog.nix home/features/ai/agent-catalog.nix hosts/shared/ai-agents-lib.nix
   agent-catalog-check
   agent-catalog-status
   ```

   If Nix files or flake inputs changed, also run:

   ```bash
   nix eval '.#darwinConfigurations.zoidberg.config.home-manager.users."C.Hessel".home.file.".agents/catalog/manifest.json".text' >/dev/null
   ./scripts/check-config.sh
   ```

   If only this repo-scoped skill changes, validate the skill frontmatter and symlink; no Nix evaluation is needed.

## Reporting

Report what was added, trust classification, target availability, validation results, and any reason a requested skill was not onboarded. Keep secrets out of Nix, skill files, plugin manifests, and docs.
