# 🛠️ Development Tools Cheatsheet

A comprehensive reference for all the enhanced tools in your nix-dotfiles configuration.

## 📋 Table of Contents

- [🖥️ Monitor Management](#️-monitor-management)
- [🔧 Git Workflow](#-git-workflow)
- [🤖 AI & LLM Tools](#-ai--llm-tools)
- [🖥️ Enhanced Tmux](#️-enhanced-tmux)
- [⚡ Workflow Automation](#-workflow-automation)
- [📊 System Monitoring](#-system-monitoring)
- [🌐 Network Tools](#-network-tools)
- [💻 Development Environment](#-development-environment)
- [🧪 Code Quality & Testing](#-code-quality--testing)
- [📝 Documentation & Viewing](#-documentation--viewing)
- [🚀 Productivity Utilities](#-productivity-utilities)

---

## 🖥️ Monitor Management

### AeroSpace + Hammerspoon Integration

**Automatic monitor detection and window layout management for external displays.**

#### Key Features
- **Intelligent Detection**: Automatically detects LG HDR 4K and other external monitors
- **Dynamic Layouts**: Switches between horizontal and vertical window splits based on display orientation
- **Hot-Plug Support**: Responds to monitor connection/disconnection events
- **Workspace Assignment**: Workspaces 6, 7, 8 are assigned to external monitors

#### Keyboard Shortcuts
```bash
# Manual layout trigger
Alt + Shift + M      # Force re-detect monitors and apply appropriate layouts

# Workspace navigation (External monitor workspaces)
Alt + F1             # Switch to workspace 6 (LG HDR 4K)
Alt + F2             # Switch to workspace 7 (LG HDR 4K)  
Alt + F3             # Switch to workspace 8 (LG HDR 4K)

# Move windows to external monitor workspaces
Alt + Shift + F1     # Move window to workspace 6 and follow
Alt + Shift + F2     # Move window to workspace 7 and follow
Alt + Shift + F3     # Move window to workspace 8 and follow
```

#### Automatic Behavior
```bash
# When LG HDR 4K is connected (Portrait mode):
# - Workspaces 6, 7, 8 use horizontal splits (windows stack vertically)
# - Perfect for rotated 4K displays

# When LG HDR 4K is disconnected (Laptop only):
# - Workspaces 6, 7, 8 use vertical splits (windows arrange side-by-side)
# - Optimized for laptop screen aspect ratio
```

#### Monitoring & Debugging
```bash
# Check AeroSpace status
pgrep -fl aerospace

# View current workspace
/run/current-system/sw/bin/aerospace list-workspaces --focused

# List windows in workspace
/run/current-system/sw/bin/aerospace list-windows --workspace 6

# Hammerspoon Console (for debug logs)
# Open Hammerspoon app → Console
# Look for "MonitorManager" messages
```

#### Configuration Files
- **AeroSpace Config**: `modules/darwin/aerospace/default.nix`
- **Monitor Detection**: `home/features/darwin/keybindings/hammerspoon/config/MonitorManager.lua`
- **Initialization**: `home/features/darwin/keybindings/hammerspoon/config/init.lua`

#### Troubleshooting
```bash
# Force trigger monitor detection
Alt + Shift + M

# Check Hammerspoon console for errors
# Open Hammerspoon → Console

# Test monitor detection manually (in Hammerspoon console)
MonitorManager.applyLayouts()

# Restart AeroSpace service
launchctl kickstart -k gui/$(id -u)/org.nixos.aerospace

# Restart Hammerspoon
# Hammerspoon → Reload Config
```

---

## 🔧 Git Workflow

### Lazygit - Terminal Git UI
```bash
# Start lazygit in current repo
lazygit

# Key bindings inside lazygit:
# j/k          - Navigate up/down
# h/l          - Navigate left/right between panels
# space        - Stage/unstage files
# c            - Commit
# P            - Push
# p            - Pull
# enter        - View diff/details
# q            - Quit
# ?            - Help
```

### Delta - Enhanced Git Diff (Already configured!)
```bash
# Your git is already configured to use delta automatically
git diff              # Shows beautiful syntax-highlighted diffs
git log -p            # Shows commit history with enhanced diffs
git show HEAD         # Shows last commit with delta formatting
```

---

## 🤖 AI & LLM Tools

### OpenCommit - AI-Powered Commit Messages (Tri-Provider System)

**Generate intelligent commit messages using your choice of three AI providers: local Ollama, cloud OpenAI, or advanced Claude.**

#### Quick Start - Any Provider
```bash
# Stage your changes and generate commit message
git add .
oco                   # Generate and commit with current provider

# Dry run (preview without committing)
oco --dry-run        # See what message would be generated
```

#### Provider Management (Core Feature)
```bash
# Switch between providers
oco-local            # Switch to Ollama → tavernari/git-commit-message:latest
oco-cloud            # Switch to OpenAI → gpt-4o-mini  
oco-claude           # Switch to Claude → claude-3-5-haiku-20241022
oco-provider         # Full provider management interface

# Provider status and health
oco-check            # Comprehensive health check for current provider
oco-provider status  # Detailed provider information and diagnostics

# Setup commands
oco-provider setup   # Interactive API key configuration (OpenAI/Claude)
```

#### Local Profile Selection
```bash
# Inspect or switch the local Ollama-backed profiles used by OpenCommit
oco-profile          # Show current provider/model + commit/general/coding profiles
oco-profile status
oco-profile commit   # Reset to the declarative commit profile
oco-profile general  # Use the lightweight general local profile
oco-profile coding   # Use the heavier coding local profile
oco-profile default  # Alias for commit
```

#### Core OpenCommit Commands
```bash
# Main commands (work with any provider)
oco                   # Generate commit message (alias: opencommit)
oc                    # Short alias for opencommit

# Git hook integration  
oco-hook-enable       # Enable automatic commit message generation
oco-hook-disable      # Disable git hook integration

# Configuration and diagnostics
oco-config           # View/edit opencommit settings
oco-config-get       # Show current configuration
```

#### Conventional Commit Types (Work with All Providers)
```bash
# Generate commits with specific types
oco-feat             # feat: commit message
oco-fix              # fix: commit message  
oco-docs             # docs: commit message
oco-style            # style: commit message
oco-refactor         # refactor: commit message
oco-test             # test: commit message
oco-chore            # chore: commit message
```

#### Provider-Specific Features

##### 🏠 Ollama (Local Provider)
```bash
# Switch to local provider
oco-local                    # Automatically sets model: tavernari/git-commit-message:latest

# Configuration:
# - API URL: http://127.0.0.1:11434/api/chat (default local endpoint)
# - Default Model: tavernari/git-commit-message:latest (commit-optimized)
# - Shared local profiles: commit / general / coding
# - Coding profile route: http://127.0.0.1:11436 (raw backend: http://127.0.0.1:11435)
# - Cost: 100% Free
# - Privacy: 100% Local (never leaves your machine)
# - Speed: 2-3 seconds (varies by model size)
```

##### ☁️ OpenAI (Cloud Provider)
```bash
# Switch to OpenAI provider
oco-cloud                    # Automatically sets model: gpt-4o-mini

# Configuration:
# - API URL: https://api.openai.com/v1
# - Default Model: gpt-4o-mini (cost-effective)
# - Alternative: gpt-4o (premium quality)
# - Cost: ~$0.01 per commit message
# - Privacy: Data sent to OpenAI
# - Speed: ~2 seconds
# - API Key: Auto-loaded from SOPS encrypted secrets
```

##### 🧠 Claude (Advanced Provider)
```bash
# Switch to Claude provider 
oco-claude                   # Automatically sets model: claude-3-5-haiku-20241022

# Configuration:
# - API URL: https://api.anthropic.com/v1
# - Default Model: claude-3-5-haiku-20241022 (fast)
# - Alternative: claude-3-5-sonnet-20241022 (advanced reasoning)
# - Cost: ~$0.02 per commit message
# - Privacy: Data sent to Anthropic
# - Speed: ~7 seconds
# - API Key: Auto-loaded from SOPS encrypted secrets
```

#### SOPS Secret Management (Automatic!)
```bash
# API keys are automatically loaded from encrypted secrets
# No manual configuration required!

# To add/update API keys:
sops home/features/secrets/secrets.yaml

# Add these entries:
# openai_api_key: sk-proj-your-openai-key-here
# claude_api_key: sk-ant-your-claude-key-here

# Keys are automatically loaded when switching providers
oco-cloud    # Loads OpenAI key from secrets
oco-claude   # Loads Claude key from secrets
```

#### Performance Comparison
| Provider | Speed | Quality | Cost | Privacy | Best Use Case |
|----------|-------|---------|------|---------|---------------|
| **Ollama** | 2-3s | Very Good | Free | 100% Local | Daily commits, experimentation |
| **OpenAI** | 2s | Excellent | $0.01/commit | Cloud | Production commits, team projects |
| **Claude** | 7s | Advanced | $0.02/commit | Cloud | Complex refactoring, detailed analysis |

#### Optimized Configuration 
Your opencommit system is pre-optimized with:
- **Input Tokens**: 32,768 (4x increase for multi-file context)
- **Output Tokens**: 300 (prevents truncation)
- **Format**: Conventional commits with clear descriptions
- **Language**: English
- **Behavior**: No auto-push, concise messages

### Ollama - Local LLM Server

**Run large language models locally for privacy and offline use.**

#### Service Management
```bash
# Health and status
llm-status           # Check default backend, coding backend, session proxy, and residency
llm-models           # Show declarative local profiles and install state
llm-doctor           # Check endpoints, session proxy, installs, cloud-disable state, codex/claude presence
llm-logs             # Tail default, coding, and session-proxy logs
llm-logs coding      # Tail the coding-endpoint log only
llm-logs session     # Tail the session-proxy log only

# Coding session lifecycle
llm-session start coding    # Preload qwen3-coder and start a warm coding session
llm-session refresh coding  # Refresh the coding idle timer to 10m
llm-session status coding   # Show residency, PROCESSOR, CONTEXT, UNTIL
llm-session finish coding   # Explicitly unload the coding model

# Model management
llm-pull commit      # Pull tavernari/git-commit-message:latest
llm-pull general     # Pull qwen3:8b-q4_K_M
llm-pull coding      # Pull qwen3-coder:30b-a3b-q4_K_M
llm-pull all         # Pull all declared profiles
```

#### Declarative Profiles
```bash
# commit  -> tavernari/git-commit-message:latest via default endpoint (11434)
# general -> qwen3:8b-q4_K_M via default endpoint (11434)
# coding  -> qwen3-coder:30b-a3b-q4_K_M via session endpoint (11436), backed by coding endpoint (11435)
# 480b is intentionally not part of the local profile catalog on this machine
```

#### Interactive Usage
```bash
# Run a declared profile
llm-run general
llm-run coding      # Interactive shell uses the raw coding backend

# One-shot commands
llm-run general "Explain this bash command: ls -la"
llm-run coding "Write a Nix module for an Ollama model pin"

# Smoke tests
llm-smoke general
llm-smoke coding    # Goes through the session-aware coding proxy
```

#### Service Configuration
- **Host**: `127.0.0.1` (localhost only for security)
- **Default Endpoint**: `11434` with `32768` context
- **Raw Coding Endpoint**: `11435` with `65536` context
- **Session Proxy Endpoint**: `11436`, forwarding to `11435`
- **Session Proxy Upstream Timeout**: `180s` (`localAi.runtime.sessionProxy.timeoutSeconds`) — bounds worst-case wait when the coding backend is slow/stuck behind another request; fails fast with a clear error instead of hanging
- **Idle Keep-Alive**: `10m` on both backends
- **Parallel Requests**: `1`
- **Max Loaded Models**: `1`
- **Queue Limit**: `32`
- **Coding Proxy Defaults**: injects `think=false` for native Ollama chat/generate and `reasoning_effort=none` for OpenAI-compatible chat unless the client overrides it
- **Cloud Features**: disabled via `OLLAMA_NO_CLOUD=1` and `~/.ollama/server.json`
- **Acceleration**: Apple Silicon Metal via the standard Ollama runtime; not forced to CPU-only
- **Coding Flash Attention**: enabled
- **Coding KV Cache**: `q8_0`
- **Models**: Stored in `~/.ollama/models/`
- **Logs**:
  - default endpoint: `~/.ollama/logs/server.log`
  - coding endpoint: `~/.local/state/ollama/coding-server.log`
  - session proxy: `~/.local/state/ollama/session-proxy.log`

#### Session Behavior
- `keep_alive=10m` means 10 minutes after the last completed request, not after service start
- Submitted coding-agent requests through `11436` refresh residency automatically
- Unsent editor typing does not refresh the model
- The session proxy defaults the coding route to non-thinking mode so Qwen does not spend editor time on hidden reasoning unless a client opts in explicitly
- Use `llm-session finish coding` when a task is done and you want to release memory immediately
- Prefer one local coding agent at a time. Cline and Roo share the same single-request coding backend, so running both together mostly creates queueing, not throughput

#### Agent Config Ownership
- Shared defaults come from `aiAgents`
- Codex shared defaults are rendered to `/etc/codex/managed_config.toml`
- Codex keeps `~/.codex/config.toml` user-owned for trust state and project config layering
- Cursor global MCP config is managed at `~/.cursor/mcp.json`
- Claude Code settings are managed at `~/.claude/settings.json`
- Claude Code global MCPs are merged into the top-level `mcpServers` section of `~/.claude.json`
- Project-specific MCPs should remain project-local:
  - Codex: `.codex/config.toml`
  - Cursor: `.cursor/mcp.json`
  - Claude Code: `.mcp.json`
- MCP transport schema:
  - `type = "http"` uses `url` and optional `headers`
  - `type = "sse"` uses `url` and optional `headers`
  - `type = "stdio"` uses `command`, optional `args`, and optional `env`
  - `targetOverrides.<codex|claude|cursor|vibe>` customizes one logical server per client
  - `targets = [ ]` opts a server out of native per-client registration entirely -- reachable only via an `aiAgents.mcpProfiles` profile (see below)
- GitHub MCP is HTTP, not stdio. Codex and Vibe both authenticate it natively (`bearer_token_env_var` / `api_key_env`); Claude Code and Cursor lack a native bearer-token field, so they get an `Authorization` header with an env-var placeholder (`${GITHUB_MCP_PAT}` / `${env:GITHUB_MCP_PAT}`) that each tool expands at startup instead.

#### MCP Profiles (`aiAgents.mcpProfiles`)
```bash
mcp-profile-status         # Declared profiles, member servers, and which servers are profile-only
mcp-profile-nix-dotfiles   # Aggregated stdio endpoint: default baseline + serena, for this repo
mcp-profile-web            # default baseline + chrome-devtools/puppeteer, for browser automation
mcp-profile-web-crawl      # default baseline + crawl4ai, explicit site crawling/extraction
mcp-profile-atlassian      # default baseline + atlassian
mcp-profile-openai-api     # default baseline + openaiDeveloperDocs
mcp-profile-scratchpad     # default baseline + memory
mcp-profile-onboard <profile> [repo-dir]   # Opt a repo into a profile WITHOUT committing that choice (see below)
mcp-profile-onboard-many <profile> <root-dir>   # Batch-onboard every git repo under a directory
mcp-profile-offboard-codex <profile> [repo-dir]   # Remove repo-local Codex profile entry for one repo
mcp-profile-offboard-codex-many <profile> <root-dir>   # Remove repo-local Codex profile entries under a directory
```

- `context7`, `fetch`, `sequential-thinking`, `time`, `github`, and `headroom` are the universal baseline (`defaultProfileServers` in `hosts/shared/ai-agents.nix`) and stay natively registered for all 4 clients. `codebase-memory` is declared but intentionally `targets = [ ]`; repos should register it only with scoped `CBM_CACHE_DIR` in project-native MCP config to avoid global cross-repo graph bleed.
- `serena`, `chrome-devtools`, `puppeteer`, `crawl4ai`, `atlassian`, `openaiDeveloperDocs`, and `memory` are `targets = [ ]` -- not natively loaded anywhere -- and reachable only through the profile above that carries them.
- `crawl4ai` is profile-only and local tooling is disabled by default. Set `crawl4ai.enable = true`, export `CRAWL4AI_API_TOKEN`, run `crawl4ai-server`, then use `mcp-profile-web-crawl` for crawler-grade site extraction.
- Every non-`default` profile is `defaultProfileServers ++ [ ... ]` in Nix, not a hand-relisted set, so the baseline can't drift between profiles.
- Each `mcp-profile-<name>` binary is a FastMCP proxy (`home/features/ai/mcp-profiles.nix`, `uv run` since FastMCP isn't in nixpkgs) spawned fresh per invocation and exited after -- never a persistent or shared process, so unrelated repos/sessions never multiplex onto the same Serena workspace, browser session, or other stateful backend.
- Opt a repo in with one committed line in its own project-native MCP config, e.g. `.cursor/mcp.json: { "command": "mcp-profile-nix-dotfiles" }` (see this repo's own `.cursor/mcp.json`) -- appropriate when the whole team should get that server.
- **Onboarding without committing** (someone else's shared repo, or just a personal preference you don't want to impose on collaborators): `mcp-profile-onboard <profile> [repo-dir]` wires the profile into that repo's own project-native MCP config per client, entirely privately:
  - **Claude Code**: uses `claude mcp add`'s default `local` scope -- stored in `~/.claude.json` keyed by that repo's path, zero repo footprint, nothing to hide.
  - **Cursor / Codex / Vibe** (no native private-project scope): writes the entry into `.cursor/mcp.json` / `.codex/config.toml` / `.vibe/config.toml` only when that file is untracked, then keeps it out of git for *this clone only* via `.git/info/exclude` (a per-clone ignore list living inside `.git/` itself; never touches the shared `.gitignore`; invisible to `git status`/diffs/PRs).
- **Tracked project config rule**: if `.cursor/mcp.json`, `.codex/config.toml`, or `.vibe/config.toml` is already tracked, onboarding refuses to mutate it privately. Commit MCP changes there only when the team should share them; for personal setup, untrack and ignore the file first. Do not use `--skip-worktree` as a privacy boundary.
  - Verified end-to-end: after running it successfully, `git status` in the target repo shows nothing new.
  - Undo: `claude mcp remove <name>`; or remove the line from `.git/info/exclude` and delete the untracked project file.
- `mcp-profile-onboard` now redirects `claude mcp add` away from stdin and caps it with a 15s timeout, so it no longer steals piped repo lists or hangs indefinitely in batch loops.
- Use `mcp-profile-onboard-many <profile> <root-dir>` for safe batch mode. It discovers git repos with `find -print0`, calls `mcp-profile-onboard` with stdin detached, and prints a final `repos/ok/failed` summary.
- Pass `--skip-claude` to either onboarding command when you want repo-local Codex/Cursor/Vibe wiring only and plan to handle Claude's per-repo local scope separately.
- Use `mcp-profile-offboard-codex` / `mcp-profile-offboard-codex-many` to remove earlier repo-local Codex profile entries when migrating to the stricter policy.
- Codex offboarding is also conservative: if removing the profile entry would empty a tracked `.codex/config.toml`, the helper restores the committed `HEAD` version instead of deleting or blanking the repo-owned file.
- Best practice split:
  Codex: only layer private MCP onto repos that already commit `.codex/config.toml`.
  Claude Code: prefer native `local` scope.
  Cursor / Vibe: repo-local onboarding remains the practical fallback until they gain a private per-project scope.

#### Serena Code Intelligence
```bash
serena-status          # Check pinned Serena package, MCP contexts, and helper commands
serena-init-lsp        # Explicit first-time setup for Serena's default LSP backend
serena-init-jetbrains  # Explicit setup for the JetBrains backend
serena-claude          # Launch Claude Code with Serena's prompt override
```

- Serena is installed declaratively from the pinned upstream flake input.
- Not natively registered for Codex/Claude/Cursor/Vibe by default (heaviest tool surface + slowest startup of any declared server) -- reachable via the `nix-dotfiles` MCP profile (or any other profile that opts in). See "MCP Profiles" above.
- When rendered by a profile, Serena uses its base `aiAgents.mcpServers.serena` definition with client-specific contexts (Vibe inherits the `codex` context, since both are terminal CLIs) -- the `targetOverrides` only apply if native per-client rendering is ever turned back on for this server.
- Nix-language navigation requires the `nixd` binary (`home/features/packages.nix`); without it, Serena falls back to weaker structural-only navigation for Nix files.
- Managed Serena MCP launches keep the dashboard enabled but pass `--open-web-dashboard False`, so agents do not open browser tabs on startup.
- Serena is for live symbol-aware code navigation and refactoring. Graphify remains the durable repo graph for architecture, docs/code relationships, and visualizations.
- Do not run `serena setup codex` or `serena setup claude-code` from activation hooks; those mutate user-owned agent config.
- Project-local `.serena/` files and memories are per-repo decisions and should be committed only when that repo explicitly wants them.
- Claude hooks and auto-approval are not enabled globally; use `serena-claude` when Serena adherence matters.

#### Codebase Memory (Code Knowledge Graph)
```bash
codex-ai-status                     # Active Codex MCPs, repo-scoped codebase-memory, Graphify presence
codebase-memory-status              # Global cache plus current repo-scoped cache details
codebase-memory-mcp cli list_projects
codebase-memory-mcp cli search_graph '{"name_pattern": ".*Handler.*"}'
codebase-memory-mcp cli trace_path '{"function_name": "Search", "direction": "both"}'
codebase-memory-mcp config set auto_index false   # opt-out: default is on
```

- Installed declaratively from the pinned upstream flake input (`github:DeusData/codebase-memory-mcp`), built from source — no upstream `install.sh`/`curl | bash` involved.
- The shared `aiAgents` MCP config declares it, but does not natively register it. Add it per repo through project-native MCP config with scoped `CBM_CACHE_DIR`.
- Zero LLM tokens for indexing: pure tree-sitter + Hybrid LSP static analysis in a single C binary. Upstream's default graph cache is `~/.cache/codebase-memory-mcp/`; this repo pattern uses `.codex/cache/codebase-memory` via `CBM_CACHE_DIR`.
- Keep `auto_index=true` inside each repo-scoped cache. The global upstream cache may be empty or have `auto_index=false`; that does not mean project Codex MCP is broken. The setting lives in the selected cache's mutable SQLite config db, not a Nix-owned file.
- `index_repository` requires an **absolute** `repo_path` — a relative path (e.g. `"."`) triggers a documented upstream bug (`store.corrupt`, self-heals by deleting and requiring a re-index).
- Prefer it for structural questions on indexed repos — call graphs (`trace_path`), regex/label search (`search_graph`), dead code, git-diff blast radius (`detect_changes`), and read-only Cypher queries (`query_graph`) — instead of grepping file-by-file. Indexing quality is language-dependent, not model-dependent (no LLM involved at all): Hybrid LSP semantic resolution only covers Python/TS-JS/PHP/C#/Go/C/C++/Java/Kotlin/Rust — Nix-heavy repos (like this one) fall back to structural/tree-sitter-only edges.
- `codebase-memory.nix` contributes a short "use the graph, not broad reads" section to the same **global**, cross-repo `.codex/AGENTS.md` / `.claude/CLAUDE.md` / `.vibe/AGENTS.md` that `caveman.nix` writes — Home Manager merges multiple modules' `home.file.<path>.text` via `types.lines` (string concatenation), so each feature owns its own section without a shared registry.
- We deliberately did **not** run the upstream `install` command's *other* side effects (Claude Code skills + `PreToolUse` hook, Codex `SessionStart` reminder) since those write into **project-local** files (`.claude/settings.json`, `.codex/config.toml` inside each repo) outside Nix's control — same reasoning as Serena above.
- Complementary to Graphify, not a replacement: Graphify is the cross-modal (code + docs + papers + media), LLM-driven deep-dive with visual/report artifacts, invoked on demand; `codebase-memory-mcp` is the always-on, free, sub-ms structural backend for routine code navigation.

#### Chonkie RAG Chunking

```bash
chonkie-status # Check uv tool install, extras, wrappers, Headroom port boundary
chonkie-rag-smoke # Local recursive chunking smoke test; no provider call
chonkie-serve --port 8000 # Localhost API wrapper with Headroom port guard
chonkie-update # Manual uv tool upgrade
```

- Installed via `uv tool install "chonkie[cli,semantic,code,api,viz]"`, not `chonkie[all]`.
- Use for explicit RAG ingestion, chunking strategy comparisons, code-aware chunking, and local chunking API experiments.
- Keep Graphify/codebase-memory for repo structure, architecture, call graph, and impact questions.
- No default Headroom tuning: do not set global `OPENAI_BASE_URL` / `OPENAI_API_BASE` for Chonkie. Route provider-backed Chonkie pipelines explicitly.
- Codex and Claude subscription auth remain untouched. Chonkie provider-backed features use provider API SDKs/keys, not ChatGPT or Claude Code subscription entitlements.
- `chonkie-serve` defaults to localhost and refuses Headroom proxy ports.

#### Local AI Observability
```bash
ai-observe-status              # Show selected backend, state dir, reachability, hook status
ai-observe-doctor              # Check backend prerequisites, port guardrails, and global env safety
ai-observe-up                  # Start selected backend explicitly
ai-observe-smoke               # Send one metadata-only synthetic OTLP trace
ai-observe-insights            # Summarize metadata traces into local research metrics
ai-observe-down                # Stop selected backend without deleting state

ai-observe-phoenix-up          # Start Docker-free Phoenix package on localhost
ai-observe-phoenix-status      # Show Phoenix pid, state, log, and UI reachability
ai-observe-phoenix-smoke       # Send one metadata-only trace to Phoenix
ai-observe-phoenix-insights    # Show session/tool/permission/error summaries
ai-observe-phoenix-down        # Stop helper-managed Phoenix process
ai-observe-claude              # Run Claude Code with local metadata-only OTel tracing

ai-observe-openlit-up          # Fetch pinned OpenLIT release and start Docker Compose explicitly
ai-observe-openlit-status      # Show OpenLIT release, compose status, and reachability
ai-observe-openlit-smoke       # Send one metadata-only trace to OpenLIT OTLP HTTP
ai-observe-openlit-hook-audit  # Print hook-lab checklist; no mutations
ai-observe-openlit-down        # Stop OpenLIT compose project without deleting state
```

- Default backend is Phoenix because it can run locally without Docker/OrbStack.
- Phoenix server is not fetched at runtime. This repo provides
  `packages.<system>.arize-phoenix` from `packages/arize-phoenix/uv.lock` via
  uv2nix, and `aiObservability.phoenixPackage` defaults to that package.
- Phoenix UI/OTLP HTTP binds to `http://127.0.0.1:6006`; Phoenix OTLP gRPC binds to `127.0.0.1:4317`; state lives outside the repo under `~/.local/state/ai-observability/phoenix`.
- `aiObservability.autoStart = true` installs a macOS user LaunchAgent
  (`org.nix-community.home.ai-observability-phoenix`) with `RunAtLoad` and
  `KeepAlive`, so UI and OTLP ingest are available after login. `ai-observe-up`
  and `ai-observe-down` are launchd-aware.
- The Phoenix server process execs through an `env -i` allowlist containing
  only `HOME`, `PATH`, `PHOENIX_*`, and `OPENINFERENCE_*`; provider credentials
  and MCP tokens are not forwarded into the Phoenix process environment.
- OpenLIT remains available as explicit optional backend/lab; runtime source is pinned to OpenLIT release `openlit-1.23.0`.
- OpenLIT UI binds to `http://127.0.0.1:3010`; OTLP HTTP binds to `http://127.0.0.1:4318`.
- `ai-observe-smoke` uses a Nix-packaged OpenTelemetry Python exporter and
  includes repo-owned signal availability for workflow receipts, Headroom, RTK,
  and hot benchmark scripts.
- `ai-observe-insights` reads local Phoenix SQLite state and reports
  research-oriented metadata summaries. Phoenix built-in token/cost dashboards
  stay empty until real LLM token/model attributes are emitted; helpers do not
  fabricate those metrics.
- Helpers do not set global provider base URLs, `PHOENIX_COLLECTOR_ENDPOINT`, or `OTEL_EXPORTER_OTLP_ENDPOINT`.
- Codex gets a managed metadata-only hook through `/etc/codex/requirements.toml`
  and `/etc/codex/hooks/ai-observe-metadata.py`. It records lifecycle/tool event
  names, repo commit/dirty state, hashed working-directory identifiers, payload
  shape hashes/key counts, size classes, and exit-status classes. Hook events
  share a Phoenix trace per Codex session so UI timelines are inspectable; it
  never records prompts, shell commands, file contents, tool args, or outputs.
- `ai-receipt-log` emits metadata-only workflow outcome spans to Phoenix when
  reachable. It records kind/status/commit/dirty and summary/evidence shape
  only, not summary or evidence text.
- Claude Code subscription auth stays intact. Use `ai-observe-claude` when you
  want official Claude Code OTel traces sent to Phoenix with content gates set
  off (`OTEL_LOG_USER_PROMPTS=0`, `OTEL_LOG_TOOL_DETAILS=0`,
  `OTEL_LOG_TOOL_CONTENT=0`, `OTEL_LOG_RAW_API_BODIES=0`). Plain `claude`
  remains untouched.
- OpenLIT/Cursor coding-agent hooks are still audit-only; use
  `ai-observe-openlit-hook-audit` before any content-capable vendor hook test.
- Capture mode is metadata-only: no prompts, outputs, secrets, cookies, private ticket text, or file contents.

#### Headroom (Context Compression)
```bash
headroom-status                 # Health for every registered proxy, default-routing status, wrapper usage hints
headroom-logs [name]            # Follow one proxy's log (default: shared)
headroom-pause [name]           # Stop one proxy instance (name), or all of them if omitted (opt out -- fails until resumed)
headroom-resume [name]          # Restart one proxy instance (name), or all of them if omitted
```

Claude Code has no local-coding route at all (no wrapper, no native provider): its config schema has no multi-provider concept, and forcing `ANTHROPIC_BASE_URL` globally would silently disable claude.ai subscription connectors/Remote Control. Plain `claude` always uses the real subscription. Use OpenCode (below) for free/local coding instead.

OpenCode needs no wrapper at all: a `local-ollama` provider is merged natively into `~/.config/opencode/opencode.json` -- pick it from OpenCode's own `/models` picker or `opencode --model local-ollama/<id>`. OpenCode is the only tool wired up to the local-coding Ollama backend: it's a single loaded model processing one request at a time, so a second independent consumer risks one app's request silently starving another's.

- Installed via `uvx --from "headroom-ai[...]" headroom ...` (no Nix package exists upstream — it's a fast-moving maturin/Rust+Python build with a large optional-ML dependency surface). `uv`/`uvx` resolves a **prebuilt wheel** on this platform, so no Rust toolchain is pulled in.
- Two integration layers, both declarative:
  1. **MCP tools** (`headroom_compress`, `headroom_retrieve`, `headroom_stats`) — registered for Codex, Claude Code, Cursor, and Vibe via `aiAgents.mcpServers.headroom`, same `uvx`-on-demand pattern as `context7`/`fetch`/`time`. The agent calls these explicitly to shrink large tool output before reasoning over it.
  2. **A declarative registry of persistent local proxies** (`headroom proxy`, `home/features/ai/headroom.nix`) — launchd agents (macOS only) that start at login and stay up, compressing all traffic routed through them before forwarding to their configured upstream. A single `headroom proxy` instance only forwards OpenAI-shaped traffic to *one* `OPENAI_TARGET_API_URL` (and Anthropic-shaped traffic to *one* upstream), so any two tools needing genuinely different upstreams need their own instance. `headroom.nix` itself has **zero per-tool knowledge** — it's a generic engine that just spins up whatever's declared in `aiAgents.headroom.proxies` (`hosts/shared/ai-agents.nix`), so onboarding a future provider needing its own upstream is exactly one new attrset entry there, never a code change in `headroom.nix`. Today's entries:
     | Entry (`aiAgents.headroom.proxies.<name>`) | launchd label | Port | Upstream | Covers |
     | --- | --- | --- | --- | --- |
     | `shared` | `org.nix-community.home.headroom-proxy-shared` | 8787 | real OpenAI route → real OpenAI (Anthropic route unused, left at Headroom's own default) | Codex (default), Cursor (manual opt-in) |
     | `vibe` | `org.nix-community.home.headroom-proxy-vibe` | 8788 | real OpenAI route → real Mistral Cloud | Vibe |

     Every consumer (`headroom.nix`, `vibe.nix`, `agent-configs.nix`, `claude-code.nix`, `codex.nix`) reads its proxy's address via `aiAgents.headroom.proxies.<name>.url` — single source of truth, no hardcoded ports anywhere else. Check both with `headroom-status` / `curl http://127.0.0.1:8787/health` / `curl http://127.0.0.1:8788/health`.
- **Why no separate "gateway" tool (LiteLLM/Portkey/etc.) was needed**: every one of these tools speaks either Anthropic Messages (Claude Code) or an OpenAI-compatible wire format (everyone else, including Mistral Cloud) — and the Headroom proxy already speaks both on the same port (`/v1/messages`, `/v1/chat/completions`, `/v1/responses`). It **is** the protocol-agnostic gateway; no extra layer needed. What differs per tool is only how each one is told to point at it:
  | Tool | Native override mechanism | Auth preserved? | Default routing |
  | --- | --- | --- | --- |
  | Claude Code | `ANTHROPIC_BASE_URL`/`AUTH_TOKEN`/`API_KEY` env vars | yes — plain `claude` never sets these, so claude.ai subscription login/connectors/Remote Control stay intact | **no local-coding route at all** (a global override here would count as "another auth source" and silently disable subscription connectors — see `home/features/ai/agent-configs.nix`; use OpenCode instead) |
  | Codex | `openai_base_url` in the managed `config.toml` | yes — keeps ChatGPT sign-in *or* API key on the built-in `openai` provider | **on by default** (compression only; no local-Ollama route) |
  | Vibe | `api_base` on the "mistral" provider entry, guarded `tomlkit` rewrite in `~/.vibe/config.toml` | yes — same `MISTRAL_API_KEY`/`Authorization: Bearer` passthrough | **on by default**, opt out with `headroom-pause vibe`; no local-Ollama route exists for Vibe at all |
  | OpenCode | `provider.local-ollama` in `opencode.json`, merged in natively | n/a — separate named provider, doesn't touch any other provider's auth | opt-in, no wrapper: pick `local-ollama` from `/models` or `--model`. The only tool with a local-Ollama route. |
  | Cursor | **No config file or env var exists** — Settings ➜ Models ➜ OpenAI API Key ➜ Advanced ➜ Override Base URL | one-time manual step, confirmed by Cursor's own forum/docs; no tool works around this | opt-in (manual) |
- **Codex and Vibe's default routing is fully declarative, no wrapper needed** — both tools' own native base-URL override mechanisms point at a proxy unconditionally for compression, so the plain `codex`/`vibe` commands are compressed automatically with no auth-model change. **OpenCode's local-Ollama route is opt-in** as a real, baked-in named provider (no separate command) — the only tool wired up to that backend, deliberately: it's a single loaded model processing one request at a time, so a second independent consumer risks one app's request silently starving another's. **Claude Code has no local-Ollama route at all** — its config schema has no concept of multiple named providers, so switching providers always means different `ANTHROPIC_*` values at launch, and doing that globally breaks claude.ai subscription auth (see the routing table above).
  - **Codex** already defaulted to real OpenAI (ChatGPT sign-in or API key). The shared proxy's `OPENAI_TARGET_API_URL` is deliberately left untouched (real OpenAI), so Codex's destination and auth are unchanged — just compressed.
  - **Vibe** already defaulted to real Mistral Cloud (`https://api.mistral.ai`) via its `mistral` provider, `api_key_env_var = "MISTRAL_API_KEY"`. Unlike Claude/Codex, Vibe has no config-file/env-var base-URL override — it only ever reads `~/.vibe/config.toml`, which also holds live, interactively-edited user state (model choice, `default_agent`, tool permissions, `/mcp add`-created servers). So the *same* `tomlkit` merge pass that already handles `mcp_servers` (`home/features/ai/vibe.nix`) also rewrites the "mistral" provider's `api_base` to the dedicated Vibe proxy — but only while that field is still holding a value we recognise (the direct Mistral default, or our own proxy URL already); a value you've customized to something else yourself is left alone. End-to-end forwarding to the real Mistral API (route + auth passthrough) was live-verified with a real HTTP request before enabling this by default.
- **OpenCode's `local-ollama` provider is baked into `~/.config/opencode/opencode.json` declaratively** (`home/features/ai/headroom.nix`, `home.activation.mergeOpencodeLocalProvider`) — a `jq`-based merge that only ever touches the `provider.local-ollama` key, so any other provider or setting you (or `opencode auth login`) add to that file is left alone. Its custom-provider config needs every model listed explicitly (no wildcard), but the local-coding route is always exactly one pinned model (`aiAgents.localCoding.model`), so a static entry is all that's needed — no live-generated catalog, no wrapper binary.
- **Claude Code has no local-coding route.** Its config schema has no multi-provider concept at all, so the only way to point it at local Ollama is overriding `ANTHROPIC_BASE_URL`/`AUTH_TOKEN`/`API_KEY`/`MODEL` at process start — globally, that breaks claude.ai subscription auth (above); scoped to a single invocation, it would still share the same single-loaded-model, single-request-at-a-time Ollama backend as OpenCode. OpenCode already covers free/local coding natively.
- **`.claude/settings.json` has no single owner.** Not Nix-managed (see `home/features/ai/agent-configs.nix`), and also written directly by third-party installers (e.g. an IDE's own Claude Code plugin/hook installer) and by Claude Code's own CLI/settings persistence — don't assume Nix controls its contents when debugging it.
- **Opting out of default routing**: `headroom-pause` stops every registered proxy; `headroom-pause <name>` (e.g. `headroom-pause vibe`) stops just one — the same, single mechanism for all tools, no per-tool escape-hatch commands. Since Codex/Vibe point at their proxies unconditionally, whichever instance you stop will fail to connect until `headroom-resume [name]` (or a rebuild that removes the routing); OpenCode's `local-ollama` provider likewise just becomes unusable, with no effect on `claude` or OpenCode's other providers.
- Proxy state/logs live at `~/.local/state/headroom/` (`headroom-proxy-<name>.log`/`.error.log` per registered instance, e.g. `headroom-proxy-shared.log`, `headroom-proxy-vibe.log`); the proxy itself persists savings stats at `~/.headroom/`.

#### Mistral Vibe
```bash
vibe                # Launch Vibe in the current project (first run prompts for MISTRAL_API_KEY)
vibe --setup        # (Re)configure the API key explicitly
vibe-status         # Managed MCP server list, config path, skills note
```

- Installed from nixpkgs (`mistral-vibe`), providing the `vibe` and `vibe-acp` (Agent Client Protocol, for editor/IDE integrations) commands.
- **MCP servers**: the same `aiAgents.mcpServers` set used by Codex (see `targets` defaults and per-server `targets` overrides) is merged declaratively into `~/.vibe/config.toml`'s `mcp_servers` array. Unlike Claude's fully-generated `.claude/settings.json`, this is a **format-preserving merge** — a small `tomlkit`-based Python script (`python3.withPackages` w/ `tomlkit`, run from `home.activation`) parses the existing `config.toml`, replaces only entries whose `name` matches a Nix-managed server, and leaves everything else (model choice, `default_agent`, tool permissions, any server you added yourself via `/mcp add`) untouched. This mirrors `restoreCodexUserConfig`'s surgical-prune approach for Codex, adapted from single-name TOML tables to TOML arrays-of-tables.
- **Skills**: Vibe follows the [Agent Skills spec](https://agentskills.io/specification) and reads `~/.agents/skills/` directly — the exact directory Codex uses (see Caveman below) — so no separate skill install step was needed; Vibe picks up the same skills for free. Project-local `.agents/skills/` and `.vibe/skills/` are also honored in trusted folders.
- **Headroom compression**: on by default (opt-out) via a guarded rewrite of the "mistral" provider's `api_base` in the same `tomlkit` merge pass above — see the Headroom section for the full rationale; opt out with `headroom-pause vibe`, same mechanism Claude/Codex use.
- **Auth**: Vibe has no system-managed config layer (unlike Codex's `/etc/codex/managed_config.toml`), so API key setup stays interactive/manual — `vibe --setup`, the `MISTRAL_API_KEY` env var, or `~/.vibe/.env`.
- **Serena context**: no `targetOverrides.vibe` was added for Serena — Vibe inherits the base `--context=codex` args, since both are terminal-style CLI agents with equivalent tool-schema needs.
- `vibe-status` lists the exact managed server names and the current Headroom routing state, so you can tell a Nix-managed entry apart from anything you've added yourself.

#### Caveman Agent Compression
```bash
caveman-status                  # Check pinned Codex skill install and usage hints
caveman-upstream-dry-run        # Preview Caveman upstream installer actions
caveman-claude-install-minimal  # Explicit Claude plugin install, no hooks/MCP shrink
caveman-claude-install-full     # Explicit Claude plugin + hooks, no MCP shrink
```

- Caveman skills are installed declaratively from the pinned Nix flake input into **both** `~/.agents/skills/` (Codex, Vibe — both follow the [Agent Skills spec](https://agentskills.io/specification)) **and** `~/.cursor/skills/` (Cursor's own equally-documented global skills location, [cursor.com/docs/skills](https://cursor.com/docs/skills)) — same source, same list, fanned out to both prefixes from one place in `caveman.nix` rather than hand-duplicated. No manifest/registration step needed for either; Cursor's own built-in skills stay separate under `~/.cursor/skills-cursor/`.
- **Full-intensity caveman style is on by default** for Codex, Vibe, and Claude Code — each tool's global instructions file (`~/.codex/AGENTS.md`, `~/.vibe/AGENTS.md`, `~/.claude/CLAUDE.md`) gets a short "activate immediately" preamble followed by the pinned `caveman` flake input's own `SKILL.md` embedded **verbatim** (`builtins.readFile`, not a hand-copied paraphrase) — single source of truth, so bumping the flake input is the only thing ever needed to keep the default style current. None of these mutate app-owned settings/MCP state, so — unlike the Claude plugin/hook install below — they're safe to enable unconditionally.
- **Cursor is the one exception to "on by default"**: it has no global-rules file Nix can manage — Cursor's own docs/help confirm "User Rules" live only in opaque local settings state (not exported to disk, no `settings.json` key), unlike its file-based Project Rules (`.cursor/rules/*.mdc`) or the skills directory above. So the skill is *available* in Cursor (invoke with `/caveman` or a matching request, exactly like Cursor's own built-in skills) but not forced on-by-default the way it is for the other three. To force it in Cursor too: Cursor Settings ➜ Rules ➜ User Rules, paste a short pointer at the skill (one-time manual step, per-machine, not automatable).
- Say `stop caveman` / `normal mode` to turn it off for the rest of a session (it resumes as the default next session); switch intensity with `/caveman lite|full|ultra` (Codex/Vibe skill invocation) or plain language.
- Caveman's upstream `/caveman` convention is not registered as a current Codex CLI slash command by this declarative setup.
- Claude's caveman *skill/plugin* install (`caveman-claude-install-minimal`/`-full`, beyond the default `CLAUDE.md` style above) stays explicit because it mutates Claude-managed plugin/hook state.
- `caveman-shrink` and repo-local `--with-init` rules are intentionally not default.

#### Troubleshooting
```bash
# Check service status
llm-status
llm-doctor

# View service logs
llm-logs
llm-logs coding
llm-logs session

# Check disk space (models can be large)
df -h ~/.ollama/
```

#### Local Profile Catalog
| Profile | Model | Use Case | Size |
|--------|-------|----------|------|
| `commit` | `tavernari/git-commit-message:latest` | Fast local commit messages | ~4.4GB |
| `general` | `qwen3:8b-q4_K_M` | Lightweight chat and explanations | ~5.2GB |
| `coding` | `qwen3-coder:30b-a3b-q4_K_M` | Local coding agents and heavier code tasks | ~19GB |

**Total if you install all declared local profiles**: about `28.6 GB`

#### Integration Examples
```bash
# Use with opencommit
git add .
oco                  # Uses configured model for commit messages

# Quick model switching for different local tasks
oco-profile coding   # Temporarily use the coding profile and coding endpoint
git add .
oco                  # Generate commit with coding model

oco-profile commit   # Switch back to the default commit profile
```

#### Advanced Configuration
```bash
# Custom model setup for specific projects
echo 'OCO_MODEL="qwen3-coder:30b-a3b-q4_K_M"' > .env    # Unmanaged ad hoc model override

# Batch commit with different models
oco-profile commit && git add . && oco        # Use commit-optimized model
oco-profile coding && git add . && oco        # Use code-optimized model

# Performance monitoring
time llm-run general "test prompt"
llm-status
```

#### Privacy & Security
- **Local Processing**: All AI processing happens on your machine
- **No API Keys**: No external API calls or data sharing
- **Offline Capable**: Works without internet connection once models are downloaded
- **Data Privacy**: Your code never leaves your machine

---

## 🖥️ Enhanced Tmux

### New Prefix: `Ctrl+A` (instead of Ctrl+B)

### Essential Commands
```bash
# Session management
tmux new-session -s myproject    # Create named session
tmux attach -t myproject         # Attach to session
tmux list-sessions              # List all sessions
tmux kill-session -t myproject  # Kill session

# Your custom function (already configured)
t                               # Fuzzy-find and attach to session
```

### Key Bindings (Prefix = Ctrl+A)
```bash
# Window/Pane Management
Ctrl+A |             # Split horizontally (new!)
Ctrl+A -             # Split vertically (new!)
Ctrl+A c             # Create new window
Ctrl+A &             # Kill window
Ctrl+A x             # Kill pane

# Navigation (No prefix needed!)
Alt + Arrow Keys     # Navigate between panes
Shift + Arrow Keys   # Navigate between windows

# Copy Mode (Vim-style)
Ctrl+A [             # Enter copy mode
v                    # Start selection (in copy mode)
y                    # Copy selection (in copy mode)
Ctrl+A ]             # Paste

# Useful Commands
Ctrl+A r             # Reload tmux config
Ctrl+A z             # Zoom/unzoom current pane
Ctrl+A ,             # Rename window
Ctrl+A $             # Rename session
```

---

## ⚡ Workflow Automation

### Just - Modern Command Runner
```bash
# List available commands
just --list
just -l

# Run commands
just build           # Run build task
just test            # Run test task
just dev             # Run dev server

# Create a justfile example:
# build:
#     echo "Building project..."
#     npm run build
# 
# test:
#     echo "Running tests..."
#     npm test
```

### Hyperfine - Benchmarking
```bash
# Compare command performance
hyperfine 'grep -r "pattern" .' 'rg "pattern"'

# Benchmark with warmup runs
hyperfine --warmup 3 'npm run build'

# Export results
hyperfine --export-markdown results.md 'command1' 'command2'
hyperfine --export-json results.json 'command1' 'command2'

# Multiple runs for statistical accuracy
hyperfine --runs 10 'your-command'
```

---

## 📊 System Monitoring

### Determinate Systems Nix Management

#### Complete System Update Workflow
```bash
# Recommended: Use the comprehensive update script
./scripts/update-system.sh           # Full system update with proper workflow

# Or follow manual steps:
sudo determinate-nixd status         # 1. Check daemon health
sudo determinate-nixd upgrade        # 2. Upgrade Determinate Nix
nix flake update                     # 3. Update configuration inputs
sudo darwin-rebuild switch --flake ~/.config/nix-dotfiles --show-trace  # 4. Apply changes
sudo determinate-nixd status         # 5. Verify system health
```

#### Determinate Systems Management
```bash
# Health checks and status
sudo determinate-nixd status          # Overall daemon status and configuration
determinate-nixd version              # Check installed version
sudo determinate-nixd status --verbose  # Detailed status information

# Upgrades and maintenance
sudo determinate-nixd upgrade         # Upgrade to latest version
sudo determinate-nixd upgrade --version v3.6.8  # Upgrade to specific version
sudo determinate-nixd upgrade --check  # Check if upgrade is available

# Daemon management
sudo launchctl kickstart -k system/org.nixos.nix-daemon  # Restart daemon
sudo determinate-nixd restart        # Restart Determinate daemon

# Authentication (FlakeHub integration)
determinate-nixd login                # Login to FlakeHub
determinate-nixd auth logout          # Logout from FlakeHub
sudo determinate-nixd auth reset      # Reset authentication

# Configuration and troubleshooting
cat /etc/nix/nix.conf                # View managed config (read-only)
cat /etc/nix/nix.custom.conf         # View custom config (if exists)
cat hosts/shared/determinate.nix     # View dotfiles Determinate config

# Support and diagnostics
determinate-nixd help                 # Show available commands
determinate-nixd bug "Issue title" "Description"  # File bug report
```

#### Update System Script

**Primary Update Tool:**
```bash
# Complete system update (recommended)
./scripts/update-system.sh

# Explicit mutable Homebrew upgrades for declared packages only
./scripts/update-system.sh --upgrade-brew

# Preview and explicitly prune undeclared Homebrew packages
./scripts/update-system.sh --prune-brew

# Show available options
./scripts/update-system.sh --help

# Preview operations without executing
./scripts/update-system.sh --dry-run
```

**Script Features:**
- ✅ Automated health checks (before/after)
- ✅ Proper Determinate Systems upgrade sequence
- ✅ Homebrew defaults to declared package convergence with `--no-upgrade`
- ✅ Explicit `--upgrade-brew` path for mutable declared-only Homebrew upgrades
- ✅ Explicit `--prune-brew` path for destructive Homebrew cleanup
- ✅ Interactive prompts with confirmation
- ✅ Colored output and progress indicators
- ✅ Error handling with rollback instructions
- ✅ Optional cleanup of old generations, Nix store GC, store optimisation, and safe cache pruning
- ✅ Platform detection (macOS/Linux)

#### Update Workflows by Scenario

**Daily/Weekly Updates:**
```bash
./scripts/update-system.sh           # Complete system update
```

**Homebrew Version Updates:**
```bash
./scripts/update-system.sh --upgrade-brew  # Opt into mutable declared-only Brew upgrades
```

**Homebrew Pruning:**
```bash
./scripts/update-system.sh --prune-brew    # Preview and confirm undeclared package cleanup
```

**Configuration-Only Changes:**
```bash
sudo darwin-rebuild switch --flake ~/.config/nix-dotfiles --show-trace
```

**Determinate-Only Upgrade:**
```bash
sudo determinate-nixd upgrade
sudo determinate-nixd status
```

**Emergency Health Check:**
```bash
sudo determinate-nixd status
nix flake check
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -3
```

### Bottom - Modern System Monitor
```bash
# Start bottom (better than htop)
btm
bottom

# Key bindings in bottom:
# q            - Quit
# /            - Search processes
# dd           - Kill selected process
# Tab          - Switch between widgets
# +/-          - Zoom in/out on graphs
# e            - Expand/collapse process tree
```

### Duf - Disk Usage (Better df)
```bash
# Show disk usage for all mounted filesystems
duf

# Show specific filesystems
duf /home /var

# Hide specific filesystem types
duf --hide-fs tmpfs,devtmpfs

# JSON output
duf --json
```

### Dust - Directory Size (Better du)
```bash
# Show directory sizes in current directory
dust

# Analyze specific directory
dust ~/Projects

# Limit depth
dust -d 3

# Show sizes in different units
dust -b          # Bytes
dust -k          # Kilobytes
dust -m          # Megabytes
dust -g          # Gigabytes

# Number of files to show
dust -n 20
```

### Ncdu - Visual Disk Usage
```bash
# Analyze current directory (interactive)
ncdu

# Analyze specific directory
ncdu ~/Downloads

# Key bindings in ncdu:
# j/k or ↑/↓   - Navigate
# Enter        - Enter directory
# d            - Delete selected item
# g            - Show item graph
# i            - Show item info
# r            - Recalculate
# q            - Quit
```

---

## 🌐 Network Tools

### Bandwhich - Network Usage by Process
```bash
# Show network usage (requires sudo on some systems)
sudo bandwhich

# Show specific interface
bandwhich -i eth0

# Key bindings:
# q            - Quit
# space        - Pause
# tab          - Switch between views
```

### Ngrok - Secure Tunnels
```bash
# Expose local port to internet
ngrok http 3000                    # Expose port 3000
ngrok http 8080                    # Expose port 8080

# With custom subdomain (paid plans)
ngrok http -subdomain=myapp 3000

# TCP tunneling
ngrok tcp 22                       # Expose SSH

# Configuration file at ~/.ngrok2/ngrok.yml
```

### Nmap - Network Discovery
```bash
# Scan local network
nmap 192.168.1.0/24

# Scan specific host
nmap example.com

# Port scan
nmap -p 22,80,443 example.com

# Service detection
nmap -sV example.com

# OS detection
nmap -O example.com
```

---

## 💻 Development Environment

### Mise - Runtime Version Manager
```bash
# Install runtime versions
mise install node@20              # Install Node.js 20
mise install python@3.11          # Install Python 3.11
mise install go@1.21              # Install Go 1.21

# Use specific versions
mise use node@20                  # Use Node 20 in current project
mise use python@3.11              # Use Python 3.11
mise global node@20               # Set global Node version

# List available versions
mise list-remote node             # Available Node versions
mise list node                    # Installed Node versions

# Current versions
mise current                      # Show all current versions

# Configuration
# Create .mise.toml in project root:
# [tools]
# node = "20"
# python = "3.11"
```

### ASDF-VM - Alternative Runtime Manager
```bash
# Add plugins
asdf plugin add nodejs
asdf plugin add python

# Install versions
asdf install nodejs 20.0.0
asdf install python 3.11.0

# Set versions
asdf local nodejs 20.0.0          # For current project
asdf global nodejs 20.0.0         # Globally

# List versions
asdf list nodejs                  # Installed versions
asdf list all nodejs              # Available versions
```

### Mkcert - Local HTTPS Certificates
```bash
# Install local CA
mkcert -install

# Create certificates
mkcert localhost                   # For localhost
mkcert example.local              # For custom domain
mkcert '*.example.local'          # Wildcard certificate

# Multiple domains
mkcert localhost 127.0.0.1 ::1

# Custom certificate authority
mkcert -CAROOT                     # Show CA location
```

---

## 🧪 Code Quality & Testing

### Shellcheck - Shell Script Analysis
```bash
# Check shell script
shellcheck script.sh

# Check with specific shell
shellcheck -s bash script.sh
shellcheck -s zsh script.sh

# Exclude specific warnings
shellcheck -e SC2034 script.sh     # Exclude unused variable warning

# Different output formats
shellcheck -f json script.sh       # JSON output
shellcheck -f gcc script.sh        # GCC-style output

# Check multiple files
shellcheck *.sh
```

### Shfmt - Shell Script Formatter
```bash
# Format and display
shfmt script.sh

# Format in place
shfmt -w script.sh

# Format with specific options
shfmt -i 2 script.sh               # 2-space indentation
shfmt -ci script.sh                # Indent case statements
shfmt -bn script.sh                # Put binary operators at start of line

# Format all shell files
shfmt -w *.sh

# Check if files are formatted
shfmt -d *.sh
```

### Yamllint - YAML Validation
```bash
# Validate YAML file
yamllint config.yaml

# Validate multiple files
yamllint *.yaml *.yml

# Custom config
yamllint -c .yamllint.yaml file.yml

# Different output formats
yamllint -f parsable config.yaml   # Machine-readable format
yamllint -f colored config.yaml    # Colored output

# Disable specific rules
yamllint -d '{extends: default, rules: {line-length: disable}}' file.yml
```

### K6 - Load Testing
```bash
# Run load test
k6 run script.js

# With virtual users and duration
k6 run --vus 10 --duration 30s script.js

# With different stages
k6 run --stage 5m:10 --stage 10m:20 --stage 5m:0 script.js

# Output results
k6 run --out json=results.json script.js
```

---

## 📝 Documentation & Viewing

### Glow - Markdown Viewer
```bash
# View markdown file
glow README.md

# View with pager
glow -p README.md

# View from URL
glow https://raw.githubusercontent.com/user/repo/main/README.md

# Style options
glow -s dark README.md             # Dark theme
glow -s light README.md            # Light theme

# List available styles
glow -l

# Word wrap
glow -w 80 README.md               # Wrap at 80 characters
```

### Tldr - Simplified Man Pages
```bash
# Get quick examples for commands
tldr git
tldr curl
tldr ssh
tldr docker

# Update tldr database
tldr --update

# List all available pages
tldr --list

# Random example
tldr --random

# Different platforms
tldr -p linux git
tldr -p osx git
```

### Tree - Directory Structure
```bash
# Show directory tree
tree

# Limit depth
tree -L 2                          # Show 2 levels deep
tree -L 3 ~/Projects              # Show 3 levels in specific directory

# Show hidden files
tree -a

# Show only directories
tree -d

# Ignore patterns
tree -I 'node_modules|.git'

# File size information
tree -s

# Output to file
tree > directory_structure.txt
```

---

## 🚀 Productivity Utilities

### Tokei - Code Statistics
```bash
# Count lines of code in current directory
tokei

# Specific directory
tokei ~/Projects/myapp

# Specific languages
tokei --type rust
tokei -t javascript -t typescript

# Exclude files/directories
tokei --exclude '*.json' --exclude node_modules

# Output formats
tokei --output json               # JSON output
tokei --output yaml               # YAML output

# Sort by lines of code
tokei --sort code
```

### Procs - Modern Process Viewer
```bash
# Show all processes
procs

# Search processes
procs nginx                       # Show processes containing "nginx"
procs -c cpu                     # Sort by CPU usage
procs -c mem                     # Sort by memory usage

# Tree view
procs --tree

# Show specific columns
procs --only pid,name,cpu,mem

# Watch mode (like top)
procs --watch
```

### Sd - Find and Replace
```bash
# Basic find and replace
sd 'old_text' 'new_text' file.txt

# In-place replacement
sd -p 'old_text' 'new_text' file.txt

# Regular expressions
sd '\b\d{3}-\d{2}-\d{4}\b' '[REDACTED]' file.txt

# Multiple files
sd 'old_text' 'new_text' *.txt

# Preview changes (dry run)
sd 'old_text' 'new_text' file.txt  # Shows changes without applying

# Case insensitive
sd -s 'Old_Text' 'new_text' file.txt
```

### Fd - Fast File Find (Already in shell config)
```bash
# Find files by name
fd pattern

# Find in specific directory
fd pattern ~/Documents

# Find by extension
fd -e js                          # Find JavaScript files
fd -e md -e txt                   # Find markdown and text files

# Include hidden files
fd -H pattern

# Execute command on results
fd -e js -x wc -l                 # Count lines in JS files
```

### Ripgrep - Fast Text Search (Already configured)
```bash
# Search for text
rg pattern

# Search in specific file types
rg pattern -t js                  # Search in JavaScript files
rg pattern -t py                  # Search in Python files

# Case insensitive
rg -i pattern

# Show context
rg -C 3 pattern                   # 3 lines of context
rg -A 2 -B 2 pattern             # 2 lines after and before

# Search and replace preview
rg pattern --replace replacement
```

---

## 🔄 Integration Examples

### Combining Tools for Powerful Workflows

```bash
# Analyze project structure and size
echo "=== Project Overview ===" && \
tree -I 'node_modules|.git' -L 3 && \
echo -e "\n=== Code Statistics ===" && \
tokei

# Git workflow with enhanced tools
lazygit                           # Interactive git management
# Then use your existing git aliases with delta

# System monitoring combination
btm                              # Overall system view
# In another pane: bandwhich      # Network usage
# In another pane: ncdu           # Disk usage

# Development environment setup
mise use node@20 python@3.11     # Set up runtimes
mkcert localhost                  # Create HTTPS cert
ngrok http 3000                   # Expose to internet if needed
```

---

## 💡 Pro Tips

1. **Tmux + Tools**: Use tmux panes to run multiple monitoring tools simultaneously
2. **Aliases**: Create aliases for frequently used commands in your shell config
3. **Hyperfine**: Use for A/B testing different implementations
4. **Mise**: Prefer over nvm/rbenv for consistent cross-language version management
5. **Glow**: Perfect for reading project READMEs without leaving terminal

---

## 🐟 Fish Shell Plugins

The fish shell configuration includes several productivity-enhancing plugins to improve your command line experience.

### Autopair Plugin
```bash
# Automatically closes parentheses, quotes, brackets
echo "hello    # → automatically adds closing quote: echo "hello"
git log --grep=(    # → automatically adds closing paren: git log --grep=()
```

### Done Plugin
```bash
# Get desktop notifications when long-running commands finish
# Automatically triggers for commands taking longer than 5 seconds
npm install           # You'll get a notification when it completes
./long-running-script.sh   # Desktop notification on completion
```

### Sponge Plugin
```bash
# Automatically removes failed commands from history
# Failed commands won't clutter your command history
invalid-command       # This won't appear in your history if it fails
git pus               # Typos that fail are automatically cleaned up
```

### Colored Man Pages
```bash
# All man pages are automatically colorized for better readability
man git               # Color-coded sections and syntax highlighting
man fish              # Better visual hierarchy in documentation
```

### GRC (Generic Colouriser)
```bash
# Automatically colorizes output of common commands
ping google.com       # Colorized ping output
ps aux               # Color-coded process list
df -h                # Colored disk usage
netstat -tuln        # Colored network connections
```

### Forgit Plugin
```bash
# Interactive git commands using fzf - available after shell restart
glo                  # Interactive git log with fzf
gss                  # Interactive git status
gaa                  # Interactive git add
gcf                  # Interactive git checkout file
gbd                  # Interactive git branch delete
grh                  # Interactive git reset HEAD
```

### Plugin-Git 
```bash
# Enhanced git aliases and functions
gs                   # git status
ga                   # git add
gc                   # git commit
gp                   # git push
gl                   # git pull
gco                  # git checkout
```

### Bass Plugin
```bash
# Run bash utilities in fish shell
bass source ~/.bashrc    # Source bash configuration
bass export VAR=value    # Set environment variables bash-style
```

### Foreign-Env Plugin
```bash
# Source bash/zsh environment files
fenv source ~/.bashrc    # Import bash environment
fenv source some-script.sh   # Source bash scripts
```

### Pisces Plugin
```bash
# Smart auto-matching for quotes and brackets
echo "hello    # → closes quote automatically
git log --grep=(  # → adds closing parenthesis
[1, 2, 3    # → completes bracket
```

### Fish Abbreviation Tips Plugin
```bash
# Get helpful tips when typing commands that have shorter abbreviations
docker ps                # → 💡 dps => docker ps
kubectl get pods         # → 💡 kgp => kubectl get pods
lazygit                  # → 💡 lg => lazygit
```

### Custom Abbreviations Available

#### 🐳 Docker & Containers
```bash
d        # docker
dc       # docker-compose
dps      # docker ps
di       # docker images
dcup     # docker-compose up -d
dcdown   # docker-compose down
```

#### ☸️ Kubernetes
```bash
kc       # kubectl
kgp      # kubectl get pods
kgs      # kubectl get services
kgd      # kubectl get deployments
kdp      # kubectl describe pod
kl       # kubectl logs
```

#### 📁 File Operations
```bash
la       # eza -la --icons
lt       # eza --tree --icons
lz       # eza -la --icons | head -20
```

#### 🔍 Search & Find
```bash
rg       # rg --color=always
fd       # fd --color=always
bat      # bat --style=numbers,changes
```

#### 📦 Package Management
```bash
nr       # nix-rebuild
ns       # nix search nixpkgs
nsh      # nix-shell
nb       # nix build
```

#### 🚀 Development
```bash
v        # nvim
lg       # lazygit
t        # tmux
ta       # tmux attach
tn       # tmux new-session
```

#### 🌐 Network & System
```bash
ping     # ping -c 4
ports    # netstat -tuln
myip     # curl -s ifconfig.me
```

#### 📊 System Monitoring
```bash
btm      # btm --color always
htop     # btm (aliased to bottom)
df       # duf
du       # dust
ps       # procs
```

### Enhanced Features Summary

🔍 **Better Navigation**
- `fzf-fish`: Enhanced fuzzy finding for files, history, processes
- Interactive command history with Ctrl+R

🧠 **Smart Productivity** 
- `autopair`: Auto-close brackets, quotes, parentheses
- `pisces`: Advanced bracket/quote matching
- `sponge`: Auto-remove failed commands from history
- `fish-abbreviation-tips`: Shows helpful tips for available abbreviations

🎨 **Visual Improvements**
- `colored-man-pages`: Colorized documentation

🔧 **Git Workflow**
- `forgit`: Interactive git with fzf integration
- `plugin-git`: Comprehensive git aliases

🚀 **Environment Integration**
- `bass`: Run bash utilities seamlessly
- `foreign-env`: Import bash/zsh configurations

*This cheatsheet covers the enhanced tools added to your nix-dotfiles configuration. All tools are installed and ready to use in your development environment.* 
