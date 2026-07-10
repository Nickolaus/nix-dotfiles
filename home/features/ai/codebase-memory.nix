{ flake, lib, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  aiSources = import ../../../flake/ai-agent-sources.nix { inherit flake; };
  codebaseMemoryMcpSource = aiSources.mcps.codebase-memory;
  codebaseMemoryMcpPackage = codebaseMemoryMcpSource.packages.${system}.default;
  cbmBin = "${codebaseMemoryMcpPackage}/bin/codebase-memory-mcp";
  aiAgentsLib = import ../../../hosts/shared/ai-agents-lib.nix { inherit lib pkgs; };
  tomlkitPython = aiAgentsLib.tomlkitPython;

  codebaseMemoryOnboardCodexScript = pkgs.writeText "codebase-memory-onboard-codex.py" ''
    import sys

    import tomlkit

    config_path, command, cache_dir = sys.argv[1], sys.argv[2], sys.argv[3]

    try:
        with open(config_path) as f:
            doc = tomlkit.parse(f.read())
    except FileNotFoundError:
        doc = tomlkit.document()

    servers = doc.get("mcp_servers")
    if servers is None:
        servers = tomlkit.table()
        doc["mcp_servers"] = servers

    table = tomlkit.table()
    table["command"] = command
    env = tomlkit.table()
    env["CBM_CACHE_DIR"] = cache_dir
    table["env"] = env
    servers["codebase-memory"] = table

    with open(config_path, "w") as f:
        f.write(tomlkit.dumps(doc))
  '';

  # Contributed to the *global* instructions files that caveman.nix also writes
  # (.codex/AGENTS.md, .claude/CLAUDE.md, .vibe/AGENTS.md). Both modules
  # independently set `home.file.<path>.text`, which Home Manager merges via
  # `types.lines` (string concatenation) -- no shared registry needed, each
  # feature just owns its own section. Content focuses on using codebase-memory
  # only through a repo-scoped cache, because upstream's default cache is
  # intentionally cross-repo.
  codebaseMemoryInstructions = ''

    ## Codebase Memory (repo-scoped structural graph)

    Use codebase-memory only when its MCP is visible for the current repo with
    repo-scoped `CBM_CACHE_DIR` (usually `.codex/cache/codebase-memory`). Never
    use the upstream/global cache or another `list_projects` entry as context.

    On structural code tasks, first `list_projects`; choose only the project
    whose `root_path` equals the current Git root. If it is missing, empty, or
    has `nodes=0`, call `index_repository(repo_path=<absolute git root>,
    mode="fast")`, then re-check before using graph tools.

    Orient with `get_architecture` or `get_graph_schema`. For callers, dead
    code, impact, or "what breaks if I change X", use `trace_path`,
    `search_graph`, `query_graph`, and `detect_changes` instead of broad grep.
    Use `get_code_snippet` only after `search_graph` identifies the symbol.

    If MCP is not visible, run `codex-ai-status`. For clone-local Codex setup,
    run `codebase-memory-onboard <repo>` and restart Codex; keep personal MCP
    config out of commits.
  '';
in
{
  home.file.".codex/AGENTS.md".text = codebaseMemoryInstructions;
  home.file.".vibe/AGENTS.md".text = codebaseMemoryInstructions;
  home.file.".claude/CLAUDE.md".text = codebaseMemoryInstructions;

  home.packages = [
    codebaseMemoryMcpPackage

    (pkgs.writeShellScriptBin "codebase-memory-onboard" ''
      set -euo pipefail

      case "''${1:-}" in
        --help|-h)
          echo "Usage: codebase-memory-onboard [repo-dir]" >&2
          echo "Adds repo-scoped Codex MCP config with local-only git hiding." >&2
          exit 0
          ;;
      esac

      repo_dir="''${1:-.}"
      cd "$repo_dir"
      git_cmd="git -c core.fsmonitor=false"
      root="$($git_cmd rev-parse --show-toplevel 2>/dev/null)" || {
        echo "$(pwd) is not inside a git repo -- refusing to create repo-local config." >&2
        exit 1
      }
      cd "$root"

      config_rel=".codex/config.toml"
      cache_rel=".codex/cache/codebase-memory"
      mkdir -p .codex "$cache_rel" .git/info

      require_private_file() {
        rel="$1"
        if $git_cmd ls-files --error-unmatch "$rel" >/dev/null 2>&1; then
          echo "$rel is tracked by this repo; refusing to hide personal MCP edits with --skip-worktree." >&2
          echo "Tracked project config must be a team decision. For personal setup, untrack and ignore $rel first." >&2
          exit 1
        else
          if ! grep -qxF "$rel" .git/info/exclude 2>/dev/null; then
            echo "$rel" >> .git/info/exclude
          fi
          echo "  $rel added to .git/info/exclude"
        fi
      }

      keep_private_path() {
        rel="$1"
        if ! grep -qxF "$rel" .git/info/exclude 2>/dev/null; then
          echo "$rel" >> .git/info/exclude
        fi
        if ! grep -qxF "$rel/" .git/info/exclude 2>/dev/null; then
          echo "$rel/" >> .git/info/exclude
        fi
        echo "  $rel excluded via .git/info/exclude"
      }

      echo "==> Adding repo-scoped codebase-memory MCP to $root"
      require_private_file "$config_rel"
      ${tomlkitPython}/bin/python3 ${codebaseMemoryOnboardCodexScript} \
        "$config_rel" "/run/current-system/sw/bin/codebase-memory-mcp" "$cache_rel"

      echo
      echo "==> Keeping personal setup out of commits"
      keep_private_path "$cache_rel"

      echo
      echo "==> Enabling scoped auto-index"
      CBM_CACHE_DIR="$cache_rel" ${cbmBin} config set auto_index true >/dev/null

      echo
      echo "==> Scoped cache status"
      CBM_CACHE_DIR="$cache_rel" ${cbmBin} config list 2>/dev/null | sed 's/^/  /'
      CBM_CACHE_DIR="$cache_rel" ${cbmBin} cli list_projects 2>/dev/null | sed 's/^/  /'

      echo
      echo "Done. Start a new Codex session in this repo so MCP tools are loaded."
      echo "Git should not show personal setup; verify with: git status --short -- $config_rel $cache_rel"
    '')

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
      echo "Global cache config (upstream default, intentionally cross-repo):"
      "$package_path" config list 2>/dev/null | sed 's/^/  /'
      echo
      echo "Update model:"
      echo "  binary: Nix-managed from flake input codebase-memory-mcp; do not run upstream self-update"
      echo "  repo graph: repo-scoped auto_index/watch, or force via MCP index_repository if needed"

      echo
      echo "Global cache dir: ''${CBM_CACHE_DIR:-$HOME/.cache/codebase-memory-mcp}"
      echo "Global indexed projects:"
      "$package_path" cli list_projects 2>/dev/null | sed 's/^/  /'

      echo
      if git_root="$(git rev-parse --show-toplevel 2>/dev/null)" && [ -f "$git_root/.codex/config.toml" ]; then
        scoped_cache="$(
          awk -F= '
            /^[[:space:]]*CBM_CACHE_DIR[[:space:]]*=/ {
              gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
              gsub(/^"|"$/, "", $2)
              print $2
              exit
            }
          ' "$git_root/.codex/config.toml"
        )"

        if [ -n "$scoped_cache" ]; then
          echo "Repo-scoped cache config ($git_root):"
          (cd "$git_root" && CBM_CACHE_DIR="$scoped_cache" "$package_path" config list 2>/dev/null) | sed 's/^/  /'

          echo
          echo "Repo-scoped CLI cache view (active MCP list_projects/index_status is authoritative):"
          (cd "$git_root" && CBM_CACHE_DIR="$scoped_cache" "$package_path" cli list_projects 2>/dev/null) | sed 's/^/  /'
        else
          echo "Repo .codex/config.toml exists but has no CBM_CACHE_DIR."
        fi
      else
        echo "No repo-scoped Codex codebase-memory config found from current directory."
      fi

      echo
      echo "Expected repo-scoped Codex setup:"
      echo "  codebase-memory-onboard <repo>"
      echo "or manually:"
      echo '  command = "/run/current-system/sw/bin/codebase-memory-mcp"'
      echo '  CBM_CACHE_DIR = ".codex/cache/codebase-memory"'
      echo '  CBM_CACHE_DIR=.codex/cache/codebase-memory codebase-memory-mcp config set auto_index true'
      echo
      echo "Global instructions (scoped graph usage and boundary rules) are merged into"
      echo "the same .codex/AGENTS.md, .claude/CLAUDE.md, and .vibe/AGENTS.md that caveman-status"
      echo "reports on -- applies across every repo, not just this one."
    '')

    (pkgs.writeShellScriptBin "codex-ai-status" ''
      set -euo pipefail

      echo "Codex AI setup status"
      echo

      if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
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
      echo "Codebase-memory cache:"
      if [ -f "$git_root/.codex/config.toml" ]; then
        scoped_cache="$(
          awk -F= '
            /^[[:space:]]*CBM_CACHE_DIR[[:space:]]*=/ {
              gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
              gsub(/^"|"$/, "", $2)
              print $2
              exit
            }
          ' "$git_root/.codex/config.toml"
        )"

        if [ -n "$scoped_cache" ]; then
          echo "  scoped dir: $scoped_cache"
          (cd "$git_root" && CBM_CACHE_DIR="$scoped_cache" ${cbmBin} config list 2>/dev/null) | sed 's/^/  /'
          echo "  CLI cache view below is diagnostic only and can lag/diverge from the live MCP process."
          echo "  Inside Codex, MCP list_projects/index_status is authoritative."
          (cd "$git_root" && CBM_CACHE_DIR="$scoped_cache" ${cbmBin} cli list_projects 2>/dev/null) | sed 's/^/  /'
        else
          echo "  no CBM_CACHE_DIR found in project config"
          echo "  run: codebase-memory-onboard $git_root"
        fi
      else
        echo "  no project config"
        echo "  run: codebase-memory-onboard $git_root"
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
