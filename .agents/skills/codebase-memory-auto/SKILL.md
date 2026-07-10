---
name: codebase-memory-auto
description: Use when a repository task needs codebase-memory/CBM, code structure, callers, call graphs, dead code, dependency or impact analysis, architecture orientation, or "what breaks if I change X" reasoning. Auto-checks repo-scoped codebase-memory MCP availability, indexes when possible, repairs missing per-repo Codex config with codebase-memory-onboard, and falls back honestly when current-session MCP tools are unavailable.
---

# Codebase Memory Auto

Use repo-scoped codebase-memory as the first structural backend when available. Never use the upstream/global CBM cache or another repo's project entry.

## Workflow

1. Resolve current Git root with `git -c core.fsmonitor=false rev-parse --show-toplevel`.
2. If codebase-memory MCP tools are visible, call `list_projects`.
3. Select only the project whose `root_path` equals the Git root.
4. If that project is missing or has `nodes=0`, call `index_repository(repo_path=<absolute git root>, mode="fast")`, then re-check with `list_projects` or `index_status`.
5. Use graph tools for structural work:
   - `get_architecture` for orientation.
   - `search_graph` for symbols, definitions, and natural-language code discovery.
   - `query_graph` for multi-hop or aggregate questions.
   - `get_code_snippet` only after `search_graph` identifies the exact symbol.
6. Use `rg` only for narrow text checks or when graph tooling is unavailable.

## Missing MCP Tools

If codebase-memory MCP tools are not visible in the current session:

1. Run `codex-ai-status` from the repo root.
2. Inspect `.codex/config.toml`.
3. If there is no repo-scoped `[mcp_servers.codebase-memory]` with `CBM_CACHE_DIR`, run:

   ```bash
   codebase-memory-onboard <absolute git root>
   ```

4. Continue the current task with `rg` and local files.
5. Tell the user that CBM was onboarded for the next Codex session.

Do not claim MCP tools will appear in the current session after onboarding. Codex loads MCP servers at session start.

## Guardrails

- Only auto-onboard inside the current Git repo.
- Only write clone-local setup: `.codex/config.toml`, `.codex/cache/codebase-memory`, and `.git/info/exclude` or skip-worktree metadata.
- Do not commit per-clone MCP config or CBM cache.
- Do not run upstream `codebase-memory-mcp update`.
- Do not use relative `repo_path` for `index_repository`; use the absolute Git root.
- If `.codex/config.toml` exists but MCP tools are still missing, treat this as a stale session or launch/config problem; use local files and tell the user to start a new Codex session after checking `codex-ai-status`.
