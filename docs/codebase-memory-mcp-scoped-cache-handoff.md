# codebase-memory-mcp scoped-cache handoff

## Goal

Create a commit-ready upstream PR for
`DeusData/codebase-memory-mcp` that lets Codex and other agents register
`codebase-memory-mcp` globally while keeping indexes strictly scoped per
repository/project, without shell wrappers and without writing MCP config or
cache files into a repo commit tree.

Desired end-state for this dotfiles repo:

```toml
[mcp_servers.codebase-memory]
command = "/run/current-system/sw/bin/codebase-memory-mcp"

[mcp_servers.codebase-memory.env]
CBM_CACHE_SCOPE = "git-root"
CBM_AUTO_INDEX = "true"
```

No tracked `.codex/config.toml` per repo. No tracked `.codex/cache`. No shared
global project list leaking unrelated repos into every session.

## Source-Backed Problem Statement

Codex supports MCP servers through user-level `~/.codex/config.toml` and
trusted project `.codex/config.toml`. It supports stdio `command`, `args`,
`env`, `env_vars`, and `cwd`; it does not document a global per-project MCP
config table. Official source:
`https://developers.openai.com/codex/mcp`.

`codebase-memory-mcp` currently uses one cache directory knob:

- README line 443: `CBM_CACHE_DIR` default is
  `~/.cache/codebase-memory-mcp`, and "All project indexes config stored
  here."
- `src/foundation/platform.c:404-418`: `cbm_resolve_cache_dir()` returns
  `CBM_CACHE_DIR` when set, otherwise `$HOME/.cache/codebase-memory-mcp`.
- README line 474: SQLite databases persist under the global default cache.

`auto_index` is currently persistent cache config, not stateless environment
configuration:

- README lines 109-117: `codebase-memory-mcp config set auto_index true`
  enables indexing on MCP session start.
- `src/cli/cli.h:237-260`: config is stored in `_config.db`; known keys are
  `auto_index` and `auto_index_limit`.
- `src/mcp/mcp.c:4318-4324`: `maybe_auto_index()` reads `auto_index` and
  `auto_index_limit` from `srv->config`.

Session/project detection already exists:

- `src/mcp/mcp.c:4227-4257`: server detects session root from `getcwd()` and
  derives `session_project` with `cbm_project_name_from_path()`.
- `src/mcp/mcp.c:4260-4268`: auto-index pipeline indexes
  `srv->session_root`.

Current workaround options are all flawed:

- Global cache: clean MCP registration, but `list_projects` sees unrelated
  repos and cross-repo data can enter context.
- Project `.codex/config.toml` + repo-local cache: hard boundary, but pollutes
  commit tree with agent-specific config/ignore/cache scaffolding.
- Shell wrapper: can derive cache from git root, but is explicitly not wanted
  and is less consistent than native MCP config.
- `.git/info` cache: avoids commit tree pollution, but is git-specific,
  worktree-sensitive, and still needs per-repo initialization for
  `auto_index`.

## Required Upstream Feature

Implement native scoped cache resolution and env-driven auto-index defaults.

### 1. `CBM_CACHE_SCOPE`

Add environment variable:

```text
CBM_CACHE_SCOPE=global|git-root|cwd
```

Proposed behavior:

- unset or `global`: exact current behavior.
- `git-root`: find containing Git root from process cwd. If no Git root can be
  found, fail closed with a clear stderr error and MCP startup failure. Do not
  silently fall back to the global cache.
- `cwd`: scope cache to canonical cwd. Useful for non-git workspaces and tests.

Cache location for scoped modes:

```text
${CBM_CACHE_BASE_DIR:-$XDG_CACHE_HOME/codebase-memory-mcp/repos}/<slug>-<hash>/
```

Fallback base if `XDG_CACHE_HOME` is missing:

```text
$HOME/.cache/codebase-memory-mcp/repos
```

Use canonical absolute path before hashing. Include basename slug for
debuggability, plus a stable hash to avoid collisions and to reduce leaking
full paths in directory names.

Backwards compatibility:

- Explicit `CBM_CACHE_DIR` must remain highest precedence.
- Existing users with no new env vars get identical behavior.

### 2. `CBM_AUTO_INDEX` and `CBM_AUTO_INDEX_LIMIT`

Add environment overrides:

```text
CBM_AUTO_INDEX=true|false|1|0|on|off
CBM_AUTO_INDEX_LIMIT=50000
```

Precedence:

1. Env override when set.
2. Existing `_config.db` values.
3. Existing defaults.

This lets agent config be stateless and globally reusable. It avoids running
`codebase-memory-mcp config set auto_index true` once per scoped cache.

### 3. MCP `instructions`

Codex docs say Codex reads an MCP server's `instructions` field returned at
initialization. Add concise server instructions to the initialize response.

Suggested first 512 chars:

```text
Use list_projects first. For repo-scoped sessions, select only the project
whose root_path equals the current git root/cwd. Pass that project name to
get_architecture, get_graph_schema, search_graph, trace_path, query_graph,
detect_changes, and related tools. Never treat other project entries as
current context.
```

This improves agent behavior but does not replace cache scoping.

## Implementation Plan

1. Clone upstream:

```bash
git clone https://github.com/DeusData/codebase-memory-mcp.git
cd codebase-memory-mcp
git checkout -b feat/scoped-cache-env
```

2. Inspect current code:

```bash
rg -n "CBM_CACHE_DIR|cbm_resolve_cache_dir|auto_index|maybe_auto_index|initialize|instructions" src tests README.md
```

3. Add cache-scope resolver in `src/foundation/platform.c`.

Suggested API shape:

```c
const char *cbm_resolve_cache_dir(void);
```

Keep public signature unchanged if possible. Internally:

- Check `CBM_CACHE_DIR`.
- Else read `CBM_CACHE_SCOPE`.
- For `git-root`, discover root by walking upward from `getcwd()` until a
  `.git` directory or file is found.
- Canonicalize selected root with `realpath()`.
- Build scoped cache path under base dir.
- Ensure directory exists before opening `_config.db`.
- Return clear error if scope is `git-root` and no root exists.

If current platform layer cannot return errors cleanly, add:

```c
int cbm_resolve_cache_dir_ex(char *out, size_t out_sz, char *err, size_t err_sz);
```

and gradually route startup paths through it while preserving old function for
callers that cannot handle errors.

4. Add env bool/int helpers.

Likely location: `src/foundation/platform.c` or a small env/config helper.

Behavior should match current config bool parsing:

```text
true, 1, on, yes => true
false, 0, off, no => false
invalid => ignore env and log warning
```

5. Update `maybe_auto_index()` in `src/mcp/mcp.c`.

Current lines `4318-4324` read config DB only. Change to:

- initialize from config DB as today;
- override from `CBM_AUTO_INDEX` if valid;
- override limit from `CBM_AUTO_INDEX_LIMIT` if valid;
- log which source won at debug/info level.

6. Add MCP initialize `instructions`.

Current initialize response is covered by `tests/test_mcp.c`. Update
`cbm_mcp_initialize_response()` to include `instructions` as top-level server
instructions per MCP support in Codex docs. Keep text short and generic.

7. Update docs.

README `Environment Variables` table should add:

- `CBM_CACHE_SCOPE`
- `CBM_CACHE_BASE_DIR`
- `CBM_AUTO_INDEX`
- `CBM_AUTO_INDEX_LIMIT`

Add example:

```toml
[mcp_servers.codebase-memory]
command = "/absolute/path/to/codebase-memory-mcp"

[mcp_servers.codebase-memory.env]
CBM_CACHE_SCOPE = "git-root"
CBM_AUTO_INDEX = "true"
```

## Test Plan

Run upstream tests first to establish baseline:

```bash
make test
```

Add focused tests:

1. `CBM_CACHE_DIR` precedence:

- Set `CBM_CACHE_DIR=/tmp/cbm-explicit`.
- Set `CBM_CACHE_SCOPE=git-root`.
- Assert explicit dir wins.

2. `CBM_CACHE_SCOPE=git-root`:

- Create temp Git repo.
- Run from nested directory.
- Assert cache resolves under
  `$HOME/.cache/codebase-memory-mcp/repos/<slug>-<hash>` or test override
  base dir.
- Assert `_config.db` is created there after config open.

3. Git worktree handling:

- Use `.git` file format pointing to real gitdir.
- Assert root detection still returns worktree root, not gitdir path.

4. No git root fail-closed:

- Run from temp non-git dir with `CBM_CACHE_SCOPE=git-root`.
- Assert startup/config open fails with clear error and no global cache writes.

5. `CBM_CACHE_SCOPE=cwd`:

- Run from temp dir.
- Assert deterministic scoped cache from canonical cwd.

6. Env auto-index override:

- With empty config DB and `CBM_AUTO_INDEX=true`, assert
  `maybe_auto_index()` proceeds far enough to log/attempt indexing.
- With config DB true and `CBM_AUTO_INDEX=false`, assert it skips.
- Invalid env value logs warning and falls back to DB/default.

7. MCP initialize instructions:

- Update `tests/test_mcp.c` to assert initialize response contains
  `"instructions"` and key guidance terms like `list_projects` and
  `root_path`.

Manual smoke test:

```bash
tmp=$(mktemp -d)
git -C "$tmp" init
cd "$tmp"
CBM_CACHE_SCOPE=git-root CBM_AUTO_INDEX=true ./codebase-memory-mcp cli list_projects
```

Then test stdio:

```bash
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"manual","version":"0"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
| CBM_CACHE_SCOPE=git-root CBM_AUTO_INDEX=true ./codebase-memory-mcp
```

## Acceptance Criteria

- Global Codex MCP config can register `codebase-memory-mcp` once.
- No repo-local `.codex/config.toml` is required.
- No repo-local tracked cache directory or `.gitignore` entry is required.
- Each Git repo gets a distinct cache root automatically.
- `auto_index` can be enabled purely through MCP env config.
- `CBM_CACHE_DIR` behavior remains unchanged for existing users.
- No wrapper script is needed.
- Tests cover cache precedence, scoped root discovery, fail-closed behavior,
  env auto-index override, and MCP instructions.

## PR Shape

Recommended commit sequence:

1. `feat: add scoped cache resolution`
2. `feat: allow env auto-index defaults`
3. `feat: add MCP usage instructions`
4. `docs: document scoped agent cache setup`

Final PR title:

```text
feat: support repo-scoped cache for MCP agents
```

PR body should emphasize:

- Current behavior remains default.
- Feature is opt-in.
- Solves global MCP registration for multi-repo agent users.
- Prevents accidental cross-repo graph/context bleed.
- Removes need for wrappers or checked-in agent config.

## Risks And Notes

- Hash stability matters. Use a deterministic portable hash already present in
  the codebase if available; otherwise add a small stable hash helper with
  tests.
- Do not put caches inside `.git` by default. External user cache avoids
  mutating repository internals and works better with worktrees.
- `git-root` should fail closed when no root exists; silent fallback to global
  cache recreates the boundary problem.
- `CBM_AUTO_INDEX=true` may index large repos. Existing
  `auto_index_limit` behavior and new `CBM_AUTO_INDEX_LIMIT` should remain
  visible and documented.
- Direct tool visibility in Codex can still be deferred behind `tool_search`.
  Upstream cannot force Codex to always inject every MCP namespace. This PR
  should solve native registration and cache boundary, not Codex tool-list
  presentation.

