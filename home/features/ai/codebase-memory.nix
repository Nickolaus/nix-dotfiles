{ flake, lib, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  codebaseMemoryMcpPackage = flake.inputs.codebase-memory-mcp.packages.${system}.default;
  cbmBin = "${codebaseMemoryMcpPackage}/bin/codebase-memory-mcp";

  # Contributed to the *global*, cross-repo instructions files that caveman.nix
  # also writes (.codex/AGENTS.md, .claude/CLAUDE.md, .vibe/AGENTS.md). Both
  # modules independently set `home.file.<path>.text`, which Home Manager
  # merges via `types.lines` (string concatenation) -- no shared registry
  # needed, each feature just owns its own section. Content focuses on *using*
  # the graph instead of reading/grepping broadly; indexing itself is handled
  # transparently by auto_index below, so it isn't part of the day-to-day
  # workflow this describes.
  codebaseMemoryInstructions = ''

    ## Codebase Memory (structural code graph, zero LLM tokens to index)

    Repo indexes automatically on first MCP connection (background watcher
    keeps it fresh; deterministic tree-sitter + static analysis, no model
    involved). New task: call `get_architecture` or `get_graph_schema` first
    for a token-cheap overview instead of reading files to get oriented.

    For "who calls X", dead code, or "what breaks if I change Y": use
    `trace_path` / `search_graph` / `query_graph` instead of grep+read
    across many files (~120x fewer tokens per upstream benchmarks). Need
    one function, not a whole file: `search_graph` to locate it,
    `get_code_snippet(qualified_name=...)` to pull just that body.
    Before/after edits: `detect_changes` maps the uncommitted diff to
    affected symbols plus a risk-classified blast radius, instead of
    tracing callers by hand.

    Caveat: Hybrid LSP semantic resolution covers Python/TS-JS/PHP/C#/Go/
    C/C++/Java/Kotlin/Rust only; other languages (Nix, shell, etc.) get
    structural/tree-sitter edges only. If `list_projects` is empty for
    this repo, index explicitly: `index_repository(repo_path=<absolute
    path>)` -- relative paths corrupt the store.
  '';
in
{
  home.file.".codex/AGENTS.md".text = codebaseMemoryInstructions;
  home.file.".vibe/AGENTS.md".text = codebaseMemoryInstructions;
  home.file.".claude/CLAUDE.md".text = codebaseMemoryInstructions;

  # auto_index lives in a mutable local SQLite config db
  # (~/.cache/codebase-memory-mcp/_config.db), not a config file Nix can
  # manage declaratively -- so, same pattern as Ollama's managed-state
  # activation scripts, we assert the desired value idempotently on every
  # switch rather than only setting it once by hand. Default-on, opt-out
  # (matches the Headroom/Caveman precedent): new repos get indexed
  # transparently on first connection instead of requiring an explicit
  # index_repository call or a manual "index this project" prompt.
  home.activation.setCodebaseMemoryAutoIndex = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${cbmBin} config set auto_index true >/dev/null 2>&1 \
      || echo "Warning: failed to set codebase-memory-mcp auto_index=true" >&2
  '';

  home.packages = [
    codebaseMemoryMcpPackage

    (pkgs.writeShellScriptBin "codebase-memory-status" ''
      set -euo pipefail

      echo "codebase-memory-mcp source: ${flake.inputs.codebase-memory-mcp}"
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
      echo "Config (auto_index defaults on, opt-out via 'codebase-memory-mcp config set auto_index false'):"
      "$package_path" config list 2>/dev/null | sed 's/^/  /'

      echo
      echo "Cache dir: ''${CBM_CACHE_DIR:-$HOME/.cache/codebase-memory-mcp}"
      echo "Indexed projects:"
      "$package_path" cli list_projects 2>/dev/null | sed 's/^/  /'

      echo
      echo "Global instructions (use the graph instead of reading broadly) are merged into"
      echo "the same .codex/AGENTS.md, .claude/CLAUDE.md, and .vibe/AGENTS.md that caveman-status"
      echo "reports on -- applies across every repo, not just this one."
    '')
  ];
}
