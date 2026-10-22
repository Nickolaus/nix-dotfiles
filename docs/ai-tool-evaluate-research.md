# AI Tool Evaluate Research

Date: 2026-10-22

## Purpose

Validate the design of a proposed `ai-tool-evaluate` skill. The skill decides
whether a candidate AI tool (Agent Skill, MCP server, CLI tool, hook, plugin)
belongs in this setup. It inventories what is installed, finds overlapping
responsibilities, and returns a verdict with a preference rule.
`nix-skill-onboard` then executes the decision.

## 1. Summary

| # | Recommendation | Verdict | Why |
| --- | --- | --- | --- |
| 1 | Separate `ai-tool-evaluate` skill upstream of `nix-skill-onboard` | Confirmed, with one boundary fix | The trigger and scope differ, and skill routing is description-based. `nix-skill-onboard` also claims "explain why it should stay out", so the two skills need an explicit boundary. |
| 2 | Inventory of catalog skills, unmanaged skills, MCP, CLI, hooks, plugins, built-ins | Adjusted | Add always-on instruction injections, `upstreamNotOnboarded`, MCP profiles, and per-target duplicate fan-out. `ask-matt` is catalog-managed, not unmanaged. |
| 3 | Fixed comparison criteria | Adjusted | Context cost must be measured per surface: skill listing, always-on instructions, MCP server instructions, hooks. Add routing collision and an enforcement-mode check. Merge trust and maintenance into one supply-chain criterion. |
| 4 | Verdict, overlap table, boundary text, hand-off, `ai-receipt-log --kind decision` | Adjusted | Add a `coexist` verdict, because the existing boundary-rules blocks are exactly that outcome. Receipts are local state and forbid paths and file contents, so the durable record must live in the repo. Hand-off must branch by tool kind. |
| 5 | `responsibilities` field and overlap check in `agent-catalog-check` | Adjusted | It is feasible, but it belongs in Nix evaluation, not in the Python check. Use a controlled vocabulary, emit warnings only, and add an explicit coexistence acknowledgement. |

## 2. Findings

### 2.1 Repo current state

- `nix-skill-onboard` is repo-scoped and covers only skills. It says it onboards a skill "or explain[s] why it should stay out of the catalog" (`.agents/skills/nix-skill-onboard/SKILL.md:8`). Its workflow is inspect, classify trust, review metadata, choose targets, edit the catalog, pin, and validate (`:12-144`). It has no inventory of capabilities, no overlap analysis, and no comparison of alternatives. The recommendation 1 premise holds. Line 8 overlaps the "reject" verdict.
- The catalog skill schema has the fields `source`, `text`, `extraFiles`, `scanExtraFiles`, `targets`, `trust`, `implicit`, `owner`, and `managed` (`hosts/shared/ai-agent-catalog.nix:144-209`). No field describes the job a skill owns. MCP servers carry only transport and target fields (`hosts/shared/ai-agents.nix:187-300`).
- Nix assertions already cross-reference catalog roles against `aiAgents.mcpServers` (`hosts/shared/ai-agent-catalog.nix:550-571`). This module is therefore the one place where skills and MCP servers are both visible at evaluation time.
- `agent-catalog-check` is a Python script over `~/.agents/catalog/manifest.json` (`home/features/ai/agent-catalog.nix:190-341`). The manifest exports only skill fields: `owner trust implicit managed targets` (`:131`). It has no MCP data. The check covers frontmatter validity, the 1024-char description limit, drift from the pinned source, orphan skill directories (skipping `synced`), and `upstreamNotOnboarded` (`:240-313`). Duplicate names are reported as "n/a", because attrset keys are unique (`:430`).
- `upstreamNotOnboarded` already records upstream skills that were deliberately left out (`hosts/shared/ai-agent-catalog.nix:71-82`, `:494-497`). The live check lists 13 caveman and 10 mattpocock skills there. This is an existing reject record for skills.
- `ai-receipt-log` exists. It accepts `--kind decision` and the statuses `info|pass|fail|needs-work|ready|blocked` (`home/features/ai/workflow-receipts.nix:8-24`, `:55-157`). The global receipt rules forbid prompts, secrets, file contents, and full paths. They also define receipts as local state, not project source (`workflow-receipts.nix:203-204`; rendered into the global CLAUDE.md).
- Hand-written "Boundary rules" blocks exist in `home/features/ai/chonkie.nix:55`, `home/features/ai/ollaya.nix:152`, and `home/features/ai/crawl4ai.nix:123`. Each one names a neighbour tool and a preference: chonkie vs graphify/codebase-memory, ollaya vs fetch/crawl4ai, crawl4ai vs context7/fetch/web profile. In each case both tools are kept, with a rule for when to use which.
- `docs/ai-agent-catalog-plan.md` plans validation for duplicate names, unsupported targets, missing sources, and role references (`:412-444`). It has no responsibility or overlap concept. Hooks are "existing hook modules or future `catalog.hooks`", and plugins are declared but not rendered (`:178-179`, `hosts/shared/ai-agent-catalog.nix:486-490`). Nothing planned conflicts with this proposal.

### 2.2 Observed overlaps, verified

| Pair or group | Evidence | Notes |
| --- | --- | --- |
| `caveman` vs `i-have-adhd` | Caveman reaches Claude through SessionStart, SubagentStart, and UserPromptSubmit hooks (`home/features/ai/caveman.nix:160-178`). i-have-adhd is embedded in `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, and `~/.vibe/AGENTS.md` (`home/features/ai/adhd.nix:34-36`). Both were active in this research session. | The two rule sets overlap: both put the answer first and ban preamble. They conflict on one point: i-have-adhd says "restate state every turn" while caveman says "no recap". Neither declares precedence. |
| `grilling`, `grill-me`, `grill-with-docs` | Manifest: only `grilling` is `implicit=true`; the other two are `implicit=false`. | In Claude Code, `disable-model-invocation: true` keeps the description out of context (2.3), so these two do not compete in routing. This is an overlap in name and purpose only. |
| `code-review`, `caveman-review`, `simplify`, `security-review` | Manifest: `code-review` and `caveman-review` are both `implicit=true`. `simplify` and `security-review` are Claude built-ins. | Real routing competition on "review the diff". |
| `graphify`/`graphify-auto` vs `codebase-memory` | `graphify-auto` falls back to codebase-memory (`hosts/shared/ai-agent-catalog.nix:130-134`). | The boundary is written down. |
| `fetch` vs `crawl4ai` | `crawl4ai.nix:123-127` | The boundary is written down. |
| `research` vs `anthropic-skills:deep-research` | The first is mattpocock and implicit. The second is a claude.ai synced skill under `~/.claude/skills/synced/`. | No boundary is written. The synced skill sits outside the catalog. |
| `headroom` vs `rtk` | rtk rewrites Bash output through hooks. Headroom runs an always-on compression proxy plus MCP compress (`home/features/ai/headroom.nix:30-31`). | Both own "context compression". No boundary is written. |
| `ask-matt` | The manifest lists it as `pinned-flake`, `managed=true`, `implicit=false`. | Correction: it is not unmanaged. It is a router over the mattpocock skills and the closest existing precedent for skill selection. |

### 2.3 Agent Skills: routing, budget, collisions

- Spec limits: `name` is 1-64 chars, lowercase alphanumeric plus single hyphens, and must match the directory name. `description` is 1-1024 chars and "should describe both what the skill does and when to use it". `metadata` is an arbitrary string map. Source: <https://agentskills.io/specification>.
- Progressive disclosure: metadata (~100 tokens per skill) loads at startup for all skills. The body (<5000 tokens recommended) loads on activation. Resources load on demand. Keep `SKILL.md` under 500 lines. Source: <https://agentskills.io/specification>.
- The spec says nothing about collisions, precedence, or overlapping skills.
- Anthropic: "Claude uses [the description] to choose the right Skill from potentially 100+ available Skills". Write it in third person and include specific triggers. Build evaluations first, with at least three scenarios and a baseline without the skill. Source: <https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices>.
- Claude Code listing budget: every listed skill "adds to your context on every turn". The listing budget is 1% of the context window. When it overflows, descriptions are dropped starting with the least-invoked skills. Each entry is capped at 1,536 chars. The controls are `skillListingBudgetFraction`, `SLASH_COMMAND_TOOL_CHAR_BUDGET`, and `skillListingMaxDescChars`. Source: <https://code.claude.com/docs/en/skills> ("Skill descriptions are cut short").
- Claude Code invocation modes: with `disable-model-invocation: true`, the description is not in context. `skillOverrides` accepts `on`, `name-only`, `user-invocable-only`, or `off`. `/skill-doctor` reports context cost and invocation frequency per skill. Source: <https://code.claude.com/docs/en/skills>.
- Claude Code name precedence: enterprise beats personal, and personal beats project. A plugin skill and a skill from any other location both load, because plugin skills are namespaced. Source: <https://code.claude.com/docs/en/skills>.
- Claude Code enforcement: "Claude skipped a rule that must hold every time: move the rule into a hook." Source: <https://code.claude.com/docs/en/skills> ("Claude stops following a skill"). This matters when deciding between a skill and a hook.
- Codex: user skills live in `$HOME/.agents/skills`, repo skills in every directory from cwd to the repo root, admin skills in `/etc/codex/skills`, and system skills ship with Codex. "If two skills share the same `name`, Codex doesn't merge them; both can appear in skill selectors." The initial list uses at most 2% of the context window, configurable with `skills.max_context_tokens` up to 10,000 tokens. When space runs short, descriptions are shortened first. `allow_implicit_invocation: false` in `agents/openai.yaml` blocks implicit use. Source: <https://learn.chatgpt.com/docs/build-skills> (redirect target of `developers.openai.com/codex/skills`).
- Cursor loads `.agents/skills`, `.cursor/skills`, `~/.agents/skills`, and `~/.cursor/skills`. "For compatibility" it also loads `.claude/skills`, `.codex/skills`, `~/.claude/skills`, and `~/.codex/skills`. It supports `disable-model-invocation` and `paths`. Duplicate-name behaviour is not documented. Source: <https://cursor.com/docs/context/skills>.
- Consequence for this repo: the catalog renders one skill to `~/.agents/skills` (Codex, Vibe), `~/.claude/skills`, and `~/.cursor/skills` (`.agents/skills/nix-skill-onboard/SKILL.md:51-55`). Cursor therefore discovers each fan-out skill up to three times. Whether Cursor deduplicates them is **unverified**. Codex sees one copy per scope.

### 2.4 MCP

- Tool names SHOULD be 1-128 chars and unique within a server. "Clients or proxies that aggregate tools from multiple servers MAY encounter naming collisions … and SHOULD implement a disambiguation strategy such as prefixing tool names with a server identifier." `serverInfo.name` "SHOULD NOT be relied upon for disambiguation". Clients MUST treat tool annotations as untrusted unless the server is trusted. Source: <https://modelcontextprotocol.io/specification/2026-07-28/server/tools>.
- `instructions` in `InitializeResult` is "Optional instructions for the client". Source: <https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle>.
- Claude Code tool search is on by default. "Only tool names and server instructions load at session start." There is no per-server tool cap. Server instructions and upfront tool descriptions are cut at 4,096 chars. Tool names longer than 128 chars (`mcp__<server>__<tool>`) are dropped. When the same server name appears in several scopes, the order is local > project > user > plugin > claude.ai, and there is no merge. Source: <https://code.claude.com/docs/en/mcp>.
- Consequence: an MCP candidate's always-on cost in Claude is its server instructions plus tool names, not its full schemas. The `mcp-profile-*` gateways add server-prefixed names (for example `mcp__mcp-profile-decide__fetch_fetch`). This is the disambiguation strategy the spec recommends.
- Repo pattern: heavy or single-purpose servers get `targets = [ ]` and are reached through a profile (`hosts/shared/ai-agents.nix:363-369`, `:384-386`, `:507-556`).

### 2.5 Evaluation practice

- ThoughtWorks Radar rings are Adopt ("should seriously consider using"), Trial ("ready for use, but not as completely proven"), Assess ("worth keeping an eye on"), and Caution ("not had good experiences with"). Source: <https://www.thoughtworks.com/radar/faq>. The fourth ring is now named Caution, not Hold.
- Nygard ADR sections are Title, Context ("forces at play … in tension"), Decision, Status (proposed or accepted), and Consequences ("all consequences … not just the positive ones"). Reversed decisions are kept and marked superseded. Source: <https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions>.
- OpenSSF Concise Guide sections are: Initial Assessment ("can the dependency be avoided", is the source authentic), Maintenance & Sustainability, Security Practices, Usability & Security, Adoption & Licensing, Practical Testing, and Code Evaluation. Source: <https://best.openssf.org/Concise-Guide-for-Evaluating-Open-Source-Software>.
- The local supply-chain gate already exists: the SkillSpector pre-rebuild scan (`scripts/check-config.sh:14-25`, `:109`; scan sources at `home/features/ai/agent-catalog.nix:134-148`).

## 3. Adjusted recommendations

### 3.1 Placement and boundary

- Create `.agents/skills/ai-tool-evaluate/SKILL.md`, repo-scoped, with a symlink in `.claude/skills/`. This is the same layout as `nix-skill-onboard` (`.claude/skills/nix-skill-onboard -> ../../.agents/skills/nix-skill-onboard`). Keep it out of `aiAgents.catalog`.
- Boundary with `nix-skill-onboard`: `ai-tool-evaluate` decides whether to adopt and what the candidate overlaps. `nix-skill-onboard` decides how to onboard, and may still refuse on trust, metadata, or security grounds only. Edit `nix-skill-onboard` line 8 to point fit and overlap questions at `ai-tool-evaluate`.
- Naming: Anthropic prefers gerunds (`evaluating-ai-tools`). The repo convention is noun-verb (`nix-skill-onboard`). Default to `ai-tool-evaluate` for consistency.

### 3.2 Frontmatter draft

```yaml
---
name: ai-tool-evaluate
description: Evaluates whether a candidate AI tool (Agent Skill, MCP server, CLI tool, hook, or plugin) should join this nix-dotfiles agent setup. Inventories installed capabilities, finds overlapping responsibilities, and returns an adopt, replace, coexist, trial, or reject verdict with a preference rule and boundary text. Use before nix-skill-onboard or before editing aiAgents.mcpServers, when the user asks "should I add X", "does X overlap with Y", or "X vs Y".
---
```

The draft is about 520 chars, under the 1,024 spec limit and the 1,536 Claude listing cap.

### 3.3 Workflow

1. **Identify the candidate.** Record its kind, upstream URL, pinnable ref, and the job it claims to own. Read primary sources only: the upstream `SKILL.md`, README, `tools/list` names, and server `instructions`.
2. **Inventory the installed setup.** Read these surfaces and do not guess:
   - Catalog skills: `agent-catalog-status`, `agent-catalog-check` (orphans, runtime-owned, `upstreamNotOnboarded`), and `jq` over `~/.agents/catalog/manifest.json`.
   - Outside the catalog: `~/.claude/skills/synced/` (claude.ai), plugin skills (`enabledPlugins` in `~/.claude/settings.json`), and vendor built-ins listed in the session.
   - MCP: `aiAgents.mcpServers` and `aiAgents.mcpProfiles` in `hosts/shared/ai-agents.nix`, plus `mcp-profile-status`.
   - Always-on instructions: `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.vibe/AGENTS.md`, and the feature modules that write them (`adhd.nix`, `caveman.nix`, `chonkie.nix`, `ollaya.nix`, `crawl4ai.nix`, `rtk.nix`, …).
   - Hooks: `.hooks` in `~/.claude/settings.json`, `~/.cursor/hooks.json`, and the Codex requirements hooks (`rtk.nix`).
   - CLI tools: `home.packages` and the `*-status` commands in `home/features/ai/*.nix`.
3. **Find overlaps.** For each inventory entry with the same or a neighbouring job, classify the overlap as `none`, `adjacent`, `partial`, or `full`. Also check:
   - routing collision: shared trigger keywords between implicit descriptions;
   - name collision across `~/.agents`, `~/.claude`, and `~/.cursor` skill roots, or across MCP servers;
   - conflicting always-on rules, as in the caveman vs i-have-adhd case.
4. **Score the criteria** in 3.4 for the candidate and for each overlapping incumbent.
5. **Decide** the verdict and the preference rule, using the vocabulary in 3.5.
6. **Hand off by kind:**
   - skill: `nix-skill-onboard`;
   - MCP server: an entry in `aiAgents.mcpServers`, with `targets = [ ]` plus a profile when it is heavy or single-purpose;
   - CLI tool: a new `home/features/ai/<tool>.nix` with a status command and a Boundary rules block;
   - hook: the owning feature module;
   - plugin: `aiAgents.catalog.plugins`, which are declared but not rendered.
7. **Record the decision.** Put the durable boundary text in the owning module. For a skill rejection, add the skill to `upstreamNotOnboarded` or a catalog comment. Then run `ai-receipt-log --kind decision --status info --summary "<tool>: <verdict>" --evidence "<criteria pointer>"`, with no paths and no file contents.

### 3.4 Comparison criteria

| Criterion | What to measure | Primary source |
| --- | --- | --- |
| Coverage | Which jobs the candidate does that the incumbent does not, and the reverse | Upstream docs |
| Always-on context cost | Skill description chars when implicit, 0 when `disable-model-invocation`; CLAUDE.md/AGENTS.md injection size; MCP server instructions and tool names | 2.3, 2.4 |
| Routing collision | Overlap in trigger keywords with existing implicit skills; whether a description would get dropped under the 1% (Claude) or 2% (Codex) budget | 2.3 |
| Enforcement mode | Must the rule hold every time (hook or injection) or apply by judgment (skill)? | Claude skills docs, 2.3 |
| Supply chain | Pinnable ref, maintainers and release cadence, SkillSpector result, trust level, local vs network/provider calls | OpenSSF guide, 2.5 |
| Target portability | Works on codex, claude, cursor, and vibe, or needs a documented narrowing | `nix-skill-onboard` step 4 |
| Removal cost | Files, hooks, state, and services left behind; whether activation self-cleans | Owning module |

### 3.5 Verdicts and output template

The verdicts follow the Radar rings, plus one verdict for overlaps:

- `adopt`: onboard as trusted (`pinned-flake` or `vendored-reviewed`).
- `replace <X>`: adopt and retire X. Mark the old decision superseded, as in an ADR.
- `coexist <X>`: keep both with a written boundary rule. This matches the existing chonkie, ollaya, and crawl4ai blocks.
- `trial`: `external-experimental`, `implicit = false`, with a review trigger.
- `reject`: record the reason. For skills, add to `upstreamNotOnboarded`.

```markdown
## Verdict: <adopt | replace X | coexist X | trial | reject> — <tool>
Next: <one command or file to open>

### Context
<job the candidate owns; forces in tension>

### Overlap
| Incumbent | Kind | Overlap | Winner for job | Reason |

### Criteria
| Criterion | Candidate | Incumbent |

### Preference rule
<"Prefer A for …; use B only when …">

### Boundary rules (paste into <owning module>)
- …

### Consequences
<including negatives and removal cost>

### Hand-off
<nix-skill-onboard | mcpServers entry | feature module>; receipt command
```

### 3.6 Catalog schema change (phase 2, after the skill proves useful)

1. Add `responsibilities = mkOption { type = types.listOf responsibilityType; default = [ ]; }` to `skillType` (`hosts/shared/ai-agent-catalog.nix:144`) and to `mcpServerType` (`hosts/shared/ai-agents.nix:187`).
   - `responsibilityType` is an enum defined once, for example `output-style`, `code-review`, `docs-lookup`, `web-fetch`, `web-crawl`, `code-graph`, `context-compression`, `research`, and `plan-interrogation`.
   - Free text would drift and could not be compared.
2. Add `coexistsWith = [ "<entry>" ]` to acknowledge an intentional overlap.
3. Emit the overlap check as an evaluation-time warning in `ai-agent-catalog.nix`, where skills and MCP servers are both visible (`:550-571`). Do not put it in the Python `agent-catalog-check`, whose manifest has no MCP data. Warn when two or more entries share a responsibility and do not list each other in `coexistsWith`.
   - Whether nix-darwin's top-level `warnings` option is available in this module context is **unverified**. Check it with a focused `nix eval` before relying on it.
4. Export `responsibilities` in the manifest (`home/features/ai/agent-catalog.nix:131`) so that `agent-catalog-status` can list them.
5. Limit: hooks, CLI tools, and CLAUDE.md injections are not catalog entries. The caveman vs i-have-adhd conflict lives in `caveman.nix` and `adhd.nix`, not in catalog fields. The skill must keep inventorying those surfaces by hand.

## 4. Open questions

1. Should `ai-tool-evaluate` be implicit, or explicit-only (`disable-model-invocation: true`)? It is repo-scoped, so its listing cost applies only in this repo, but explicit-only removes the risk of misfiring.
2. Should `nix-skill-onboard` grow to cover MCP servers and CLI tools, or should a separate executor per kind stay in the feature modules?
3. Should the caveman vs i-have-adhd conflict ("restate state" vs "no recap") get a written precedence rule now, as the first output of this skill?
4. Should the decision record be a dedicated `docs/decisions/` ADR file per verdict, or only boundary text in the owning module plus a receipt?
5. Should `responsibilities` (3.6) wait for 3 or more completed evaluations, so that the vocabulary comes from real verdicts?
