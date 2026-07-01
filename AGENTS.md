# Agent Instructions

- Inspect before editing. Prefer `rg` and `rg --files` for search.
- Preserve user changes and never revert unrelated work.
- Use Nix/Home Manager for declarative packages. On Darwin, use Homebrew casks for GUI apps that need current macOS app integration.
- Keep Home Manager and nix-darwin activation idempotent. Mutable Homebrew upgrades belong in `scripts/update-system.sh`.
- Manage secrets through sops-nix. Never commit credentials, tokens, or Warp/Oz/MCP secrets.
- Run focused checks after changes, usually `nix eval`, `nix flake check`, or `./scripts/check-config.sh` depending on scope.
- For "who calls X", "what breaks if I change Y", dead code, or other structural code questions, prefer the `codebase-memory-mcp` MCP tools (`trace_path`, `search_graph`, `query_graph`, `detect_changes`) over grepping file-by-file — it's a free, always-on code graph. Reach for the `graphify` skill instead for deep cross-document (code + docs + media) architecture exploration.
- Before pasting very large tool output (long grep/search results, big file dumps, verbose logs) into context, consider `headroom_compress` (MCP) to shrink it first; retrieve the original via `headroom_retrieve` if full detail turns out to be needed.
