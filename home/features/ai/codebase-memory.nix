{ flake, lib, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  codebaseMemoryMcpPackage = flake.inputs.codebase-memory-mcp.packages.${system}.default;
  cbmBin = "${codebaseMemoryMcpPackage}/bin/codebase-memory-mcp";

  # Contributed to the *global* instructions files that caveman.nix also writes
  # (.codex/AGENTS.md, .claude/CLAUDE.md, .vibe/AGENTS.md). Both modules
  # independently set `home.file.<path>.text`, which Home Manager merges via
  # `types.lines` (string concatenation) -- no shared registry needed, each
  # feature just owns its own section. Content focuses on using codebase-memory
  # only through a repo-scoped cache, because upstream's default cache is
  # intentionally cross-repo.
  codebaseMemoryInstructions = ''

    ## Codebase Memory (structural code graph, zero LLM tokens to index)

    Use codebase-memory only when it is registered for the current repo with a
    repo-scoped `CBM_CACHE_DIR`. Upstream's default cache is global and
    intentionally supports cross-repo graphs; do not treat projects from other
    repos as current context.

    Scoped repo setup should keep `auto_index=true` inside that scoped cache, so
    the repo indexes automatically on first MCP connection and the background
    watcher keeps it fresh. Prefer repo-relative cache paths like
    `.codex/cache/codebase-memory` with that cache ignored by git.

    In GUI-launched clients, use the system-profile command path
    `/run/current-system/sw/bin/codebase-memory-mcp` from project sessions.
    GUI processes may not inherit the shell or Home Manager profile `PATH`.

    New task: call `get_architecture` or `get_graph_schema` first for a
    token-cheap overview instead of reading files to get oriented.

    For "who calls X", dead code, or "what breaks if I change Y": use
    `trace_path` / `search_graph` / `query_graph` instead of grep+read
    across many files (~120x fewer tokens per upstream benchmarks). Need
    one function, not a whole file: `search_graph` to locate it,
    `get_code_snippet(qualified_name=...)` to pull just that body.
    Before/after edits: `detect_changes` maps the uncommitted diff to
    affected symbols plus a risk-classified blast radius, instead of
    tracing callers by hand.

    Boundary rule: after `list_projects`, select only the project whose
    `root_path` equals the current Git root. Never use other listed projects as
    context, examples, assumptions, or search targets. If no exact project
    exists, index the current Git root explicitly with an absolute path.

    Session-review rule: do not rely on thread/session title alone. Identify a
    Codex session by session id plus `cwd` plus git remote/branch.

    Attachment rule: pasted attachment state can outlive repo switches. Read
    only attachments explicitly listed in the current user turn and relevant to
    the current repo. Ask the user to clear stale pasted attachments when
    switching repos if unrelated attachments are visible.

    Caveat: Hybrid LSP semantic resolution covers Python/TS-JS/PHP/C#/Go/
    C/C++/Java/Kotlin/Rust only; other languages (Nix, shell, etc.) get
    structural/tree-sitter edges only.
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
      echo "Current cache config:"
      "$package_path" config list 2>/dev/null | sed 's/^/  /'

      echo
      echo "Cache dir: ''${CBM_CACHE_DIR:-$HOME/.cache/codebase-memory-mcp}"
      echo "Indexed projects:"
      "$package_path" cli list_projects 2>/dev/null | sed 's/^/  /'

      echo
      echo "Scoped repo setup keeps auto_index but avoids cross-repo graph bleed:"
      echo '  command = "/run/current-system/sw/bin/codebase-memory-mcp"'
      echo '  CBM_CACHE_DIR = ".codex/cache/codebase-memory"'
      echo '  CBM_CACHE_DIR=.codex/cache/codebase-memory codebase-memory-mcp config set auto_index true'
      echo
      echo "Global instructions (scoped graph usage and boundary rules) are merged into"
      echo "the same .codex/AGENTS.md, .claude/CLAUDE.md, and .vibe/AGENTS.md that caveman-status"
      echo "reports on -- applies across every repo, not just this one."
    '')
  ];
}
