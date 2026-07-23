{ flake, lib, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  aiSources = import ../../../flake/ai-agent-sources.nix { inherit flake; };
  codebaseMemoryMcpSource = aiSources.mcps.codebase-memory;
  codebaseMemoryMcpPackage = codebaseMemoryMcpSource.packages.${system}.default;
  cbmBin = "${codebaseMemoryMcpPackage}/bin/codebase-memory-mcp";

  # Mirrors the slug+hash scheme `codebaseMemoryScopedWrapper` in
  # hosts/shared/ai-agents.nix uses to pick a repo's live cache dir, so these
  # status tools inspect exactly the same path the actual MCP process used.
  # Kept as a literal duplicate (not a shared function) because the wrapper
  # must stay self-contained with pinned absolute tool paths for GUI-launched
  # clients that don't reliably inherit PATH -- these status tools run
  # user-invoked from an interactive shell, which always has git/coreutils on
  # PATH, so bare names are fine here. Inlined text, not a shell function --
  # expects `git_root` already set at the call site and defines `cache_dir`.
  cbmCacheDirForRoot = ''
    slug="$(basename "$git_root" | tr -c 'A-Za-z0-9_-' '-')"
    hash="$(printf '%s' "$git_root" | sha256sum | cut -c1-12)"
    cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/codebase-memory-mcp/repos/$slug-$hash"
  '';

  # Contributed to the *global* instructions files that caveman.nix also writes
  # (.codex/AGENTS.md, .claude/CLAUDE.md, .vibe/AGENTS.md). Both modules
  # independently set `home.file.<path>.text`, which Home Manager merges via
  # `types.lines` (string concatenation) -- no shared registry needed, each
  # feature just owns its own section.
  codebaseMemoryInstructions = ''

    ## Codebase Memory (repo-scoped structural graph)

    codebase-memory MCP is natively registered for Codex, Claude Code, and
    Vibe -- no per-repo setup needed. It resolves its own cache per git repo
    automatically (`hosts/shared/ai-agents.nix`, `codebaseMemoryScopedWrapper`)
    and refuses to start outside a git repo rather than fall back to a shared
    cache, so tools never mix graphs across repos.

    On structural code tasks, first `list_projects`; the current repo is the
    only project entry that should exist for this session. If it is missing,
    empty, or has `nodes=0`, call `index_repository(repo_path=<absolute git
    root>, mode="fast")`, then re-check before using graph tools.

    Orient with `get_architecture` or `get_graph_schema`. For callers, dead
    code, impact, or "what breaks if I change X", use `trace_path`,
    `search_graph`, `query_graph`, and `detect_changes` instead of broad grep.
    Use `get_code_snippet` only after `search_graph` identifies the symbol.

    If MCP tools are not visible, check tool discovery (`codex mcp list` or
    the client's own tool list) and restart the session -- MCP servers load at
    session start. Run `codex-ai-status` for a full diagnostic.
  '';
in
{
  home.file.".codex/AGENTS.md".text = codebaseMemoryInstructions;
  home.file.".vibe/AGENTS.md".text = codebaseMemoryInstructions;
  home.file.".claude/CLAUDE.md".text = codebaseMemoryInstructions;

  home.packages = [
    codebaseMemoryMcpPackage

    (pkgs.writeShellScriptBin "codebase-memory-status" ''
      set -euo pipefail

      echo "codebase-memory-mcp source: ${codebaseMemoryMcpSource}"
      echo "codebase-memory-mcp package: ${codebaseMemoryMcpPackage}"
      echo

      package_path="${cbmBin}"
      if [ -x "$package_path" ]; then
        echo "  ok      $package_path"
      else
        echo "  missing $package_path"
      fi

      if command -v codebase-memory-mcp >/dev/null 2>&1; then
        echo "  profile $(command -v codebase-memory-mcp)"
      else
        echo "  profile missing: codebase-memory-mcp"
      fi

      echo
      echo "Global cache config (upstream default, intentionally cross-repo,"
      echo "not used by the natively-registered MCP server -- see below):"
      "$package_path" config list 2>/dev/null | sed 's/^/  /'

      echo
      echo "Update model:"
      echo "  binary: Nix-managed from flake input codebase-memory-mcp; do not run upstream self-update"
      echo "  repo graph: auto_index runs on MCP session start, or force via MCP index_repository"

      echo
      if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
        ${cbmCacheDirForRoot}
        echo "Repo-scoped cache for $git_root:"
        echo "  $cache_dir"
        if [ -d "$cache_dir" ]; then
          CBM_CACHE_DIR="$cache_dir" "$package_path" config list 2>/dev/null | sed 's/^/  /'
          echo
          echo "  CLI cache view below is diagnostic only and can lag/diverge from the live MCP process."
          echo "  Inside Codex/Claude/Vibe, MCP list_projects/index_status is authoritative."
          CBM_CACHE_DIR="$cache_dir" "$package_path" cli list_projects 2>/dev/null | sed 's/^/  /'
        else
          echo "  not created yet -- the MCP server creates it on first session start in this repo"
        fi
      else
        echo "Not inside a git repo -- the natively-registered codebase-memory MCP refuses to"
        echo "start here rather than fall back to the shared global cache above."
      fi
    '')

    (pkgs.writeShellScriptBin "codex-ai-status" ''
      set -euo pipefail

      echo "Codex AI setup status"
      echo

      in_git_repo=0
      if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
        in_git_repo=1
        echo "Git root: $git_root"
      else
        git_root="$(pwd)"
        echo "Git root: n/a (using cwd $git_root)"
      fi

      echo
      echo "Project Codex config:"
      if [ -f "$git_root/.codex/config.toml" ]; then
        sed -n '1,120p' "$git_root/.codex/config.toml" | sed 's/^/  /'
      else
        echo "  missing: $git_root/.codex/config.toml"
      fi

      echo
      echo "Active Codex MCP servers:"
      if command -v codex >/dev/null 2>&1; then
        codex_mcp_output="$(codex mcp list 2>&1 || true)"
        printf '%s\n' "$codex_mcp_output" | sed 's/^/  /'
      else
        codex_mcp_output=""
        echo "  codex not on PATH"
      fi

      echo
      echo "Ticket tooling:"
      if [ -f "$git_root/.codex/config.toml" ] && grep -q '^\[mcp_servers\.atlassian\]' "$git_root/.codex/config.toml"; then
        echo "  Atlassian/Jira MCP is configured as a direct Codex HTTP server."
        echo "  If ticket fetch still returns login/app-shell HTML, run:"
        echo "    codex mcp login atlassian"
        echo "  Then start a new Codex session."
      elif [ -f "$git_root/.codex/config.toml" ] && grep -q '^\[mcp_servers\.mcp-profile-atlassian\]' "$git_root/.codex/config.toml"; then
        echo "  legacy mcp-profile-atlassian stdio entry found."
        echo "  Codex OAuth needs a direct [mcp_servers.atlassian] HTTP entry instead."
        echo "  Run:"
        echo "    mcp-profile-onboard atlassian $git_root"
        echo "    codex mcp login atlassian"
        echo "  Then start a new Codex session."
      else
        echo "  Atlassian/Jira MCP not visible. For Jira-ticket repos, run:"
        echo "    mcp-profile-onboard atlassian $git_root"
        echo "    codex mcp login atlassian"
        echo "  Then start a new Codex session so project MCP config is loaded."
      fi

      echo
      echo "Codebase-memory (natively registered, no per-repo onboarding needed):"
      if printf '%s\n' "$codex_mcp_output" | grep -qi 'codebase-memory'; then
        echo "  visible in codex mcp list"
      else
        echo "  not visible in codex mcp list -- restart the Codex session (MCP servers load at startup)"
      fi
      if [ "$in_git_repo" = "1" ]; then
        ${cbmCacheDirForRoot}
        echo "  scoped cache dir: $cache_dir"
        if [ -d "$cache_dir" ]; then
          CBM_CACHE_DIR="$cache_dir" ${cbmBin} config list 2>/dev/null | sed 's/^/  /'
          echo "  CLI cache view below is diagnostic only and can lag/diverge from the live MCP process."
          echo "  Inside Codex, MCP list_projects/index_status is authoritative."
          CBM_CACHE_DIR="$cache_dir" ${cbmBin} cli list_projects 2>/dev/null | sed 's/^/  /'
        else
          echo "  not created yet -- created on first MCP session start in this repo"
        fi
      else
        echo "  not in a git repo -- codebase-memory refuses to start here"
      fi

      echo
      echo "Graphify:"
      if [ -f "$git_root/graphify-out/graph.json" ] || [ -f "$git_root/graphify-out/graph.json.gz" ]; then
        echo "  project graph present: $git_root/graphify-out"
      else
        echo "  no project graph. Create/update it now: graphify-ensure"
        echo "  Ready-to-ship setup (same graph + project skill files + hooks): graphify-onboard"
      fi
    '')
  ];
}
