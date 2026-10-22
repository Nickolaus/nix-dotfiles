---
name: ai-tool-evaluate
description: Overlap verdicts for this nix-dotfiles agent setup. Use before adding a skill, MCP server, CLI tool, hook, or plugin ("should I add X"), when comparing two tools ("X vs Y"), or when installed tools or always-on rules conflict.
---

# AI Tool Evaluate

Every tool in this setup owns a **job**. This skill finds where a **candidate** (a tool not yet installed) and the **incumbents** (installed tools and always-on rules) claim the same job, then returns a **verdict** and a **boundary rule** naming one owner per job. `nix-skill-onboard` executes skill onboarding after the verdict.

Source of truth: `.agents/skills/ai-tool-evaluate`, outside `aiAgents.catalog`. When a criterion's limit or a vendor's loading behaviour is in doubt, read `docs/ai-tool-evaluate-research.md`; it cites the primary sources.

## Steps

1. **Name the job.**

   - Candidate: read its upstream `SKILL.md`, README, MCP `tools/list` names, and server `instructions`. Record kind, upstream URL, and pinnable ref.
   - Conflict between incumbents: read each incumbent's source in its owning module or skill directory.

   Done when the job is one line in your own words; for a conflict, the colliding clauses are quoted verbatim.

2. **Inventory incumbents.** Read every surface:

   - Catalog skills: `agent-catalog-status`, `agent-catalog-check`, `jq` over `~/.agents/catalog/manifest.json`.
   - Skills outside the catalog: `~/.claude/skills/synced/`, `enabledPlugins` in `~/.claude/settings.json`, vendor built-ins listed in the session.
   - MCP: `aiAgents.mcpServers` and `aiAgents.mcpProfiles` in `hosts/shared/ai-agents.nix`; `mcp-profile-status`.
   - Always-on rules: `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.vibe/AGENTS.md`, and the `home/features/ai/*.nix` modules that write them.
   - Hooks: `.hooks` in `~/.claude/settings.json`, `~/.cursor/hooks.json`, Codex requirements hooks.
   - CLI tools: `*-status` commands and `home.packages` in `home/features/ai/*.nix`.

   Done when every surface is read and each incumbent whose job matches or neighbours the step 1 job is listed.

3. **Rate each overlap** `none`, `adjacent`, `partial`, or `full`. Count these as overlap too:

   - routing collision: trigger words shared between implicit skill descriptions;
   - name collision: one name across `~/.agents/skills`, `~/.claude/skills`, `~/.cursor/skills` (Cursor loads all three), or across MCP servers;
   - rule conflict: two always-on rules demanding opposite behaviour with no stated precedence.

   Done when every listed incumbent has a rating and a one-line reason.

4. **Score the criteria** for the candidate and each `partial` or `full` incumbent.

   Done when every cell holds a value and the source it came from.

5. **Draft the verdict** in the output template, then present it and wait for the user's approval or amendment. Write the boundary rule **provider-neutral**: it names the job and the portable tool that owns it. A single-vendor tool (a vendor built-in, or an entry narrowed to one target) owns only a job that exists on that vendor alone.

   Done when each `partial` or `full` overlap names one owner per job and the condition for using the other tool, and no single-vendor tool owns a job the other targets share.

6. **Record the approved verdict.**

   - Boundary rule: into the owning module's Boundary rules block, or into the always-on rule text for a rule conflict.
   - Rejected upstream skill: into `aiAgents.catalog.upstreamNotOnboarded`.
   - Receipt, carrying only tool name, verdict, and a criteria pointer:

     ```bash
     ai-receipt-log --kind decision --status info --summary "<tool>: <verdict>" --evidence "<criteria pointer>"
     ```

   Done when the boundary rule sits in the owning module and the receipt is logged.

7. **Hand off** an `adopt`, `replace`, or `trial` verdict by kind:

   - skill: `nix-skill-onboard`;
   - MCP server: `aiAgents.mcpServers` entry; `targets = [ ]` plus an `mcpProfiles` entry when heavy or single-purpose;
   - CLI tool: `home/features/ai/<tool>.nix` with a `<tool>-status` command and a Boundary rules block;
   - hook or always-on rule: its owning feature module;
   - plugin: `aiAgents.catalog.plugins`.

   Done when the reply's `Next:` line names the hand-off target.

## Criteria

| Criterion | Measure |
| --- | --- |
| Coverage | Jobs the candidate does that the incumbent does not, and the reverse. |
| Always-on context cost | Implicit skill description chars (0 with `disable-model-invocation`); always-on rule size; MCP server instructions plus tool names. Claude caps the skill listing at 1% of context, Codex at 2%; overflow drops descriptions. |
| Routing collision | Trigger words shared with existing implicit skills. |
| Enforcement mode | A rule that must hold every turn belongs in a hook or always-on rule; a judgement-call workflow belongs in a skill. |
| Supply chain | Pinnable ref, maintainer activity, SkillSpector result, trust level, local vs network or provider calls. |
| Target portability | Works on codex, claude, cursor, vibe, or needs a documented narrowing. A vendor built-in is an incumbent only on its own target. |
| Removal cost | Files, hooks, state, services left behind; whether activation self-cleans. |

## Verdicts

- `adopt`: onboard as trusted (`pinned-flake` or `vendored-reviewed`).
- `replace <X>`: adopt and retire X; X's module or catalog entry notes the supersession.
- `coexist <X>`: keep both; the boundary rule names which tool owns which job.
- `trial`: `external-experimental`, explicit-only, with a named review trigger. The catalog's `implicit = false` is a label; explicit-only takes frontmatter `disable-model-invocation: true` (Claude Code, Cursor, Vibe) plus `agents/openai.yaml` `policy.allow_implicit_invocation: false` (Codex). When upstream lacks either, use a `text` copy carrying both (sidecar via `extraFiles`), or `managed = false`.
- `reject`: reason recorded per step 6.

A conflict between incumbents takes `replace <X>` or `coexist <X>`.

## Output

```markdown
## Verdict: <adopt | replace X | coexist X | trial | reject> — <tool>
Next: <one command or file to open>

### Job
<one line; forces in tension>

### Overlap
| Incumbent | Kind | Overlap | Owner for job | Reason |

### Criteria
| Criterion | Candidate | Incumbent |

### Boundary rule (for <owning module>)
Prefer <A> for <job>; use <B> only when <condition>.

### Consequences
<including negatives and removal cost>
```
