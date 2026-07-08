# Agent Instructions

- Inspect before editing. Prefer `rg` and `rg --files` for search.
- Preserve user changes and never revert unrelated work.
- Use Nix/Home Manager for declarative packages. On Darwin, use Homebrew casks for GUI apps that need current macOS app integration.
- Keep Home Manager and nix-darwin activation idempotent. Mutable Homebrew upgrades belong in `scripts/update-system.sh`.
- Manage secrets through sops-nix. Never commit credentials, tokens, or Warp/Oz/MCP secrets.
- Run checks only for the changed surface. For docs-only changes, do docs/link/format sanity checks, not Nix evals. For Nix module or flake changes, use focused `nix eval`, `nix flake check`, or `./scripts/check-config.sh` depending on scope.
- Prefer compact shell output. Simple Bash calls in Codex may auto-rewrite through managed `rtk`, but non-Bash tools and some richer shell paths still bypass that hook; use explicit `rtk <cmd>` when you need RTK filtering for commands like `git`, `rg`, `find`, or test runners.
- For structural code questions, prefer repo-scoped `codebase-memory-mcp` tools (`trace_path`, `search_graph`, `query_graph`, `detect_changes`) over broad grep. If missing, check `codex mcp list`/tool discovery; clone-local setup is `codebase-memory-onboard <repo>`. Use Graphify for deep code+docs/media exploration.
- If Graphify is requested in a git repo, use the lazy `graphify-auto` skill or run `graphify-ensure` first: it creates `graphify-out/` when missing and updates it when present. Only fall back to codebase-memory/tool discovery if `graphify-ensure` is unavailable or fails. For ticket-driven work, fetch the ticket body first; if Jira/Atlassian returns only app-shell HTML, login pages, or opaque connector output after two attempts, ask for pasted ticket text instead of inferring requirements from branch names. If Atlassian-specific MCP tools are absent, say Codex needs direct Atlassian HTTP MCP plus OAuth: run `mcp-profile-onboard atlassian <repo>`, then `codex mcp login atlassian`, then start a new Codex session.
- Before pasting very large tool output (long grep/search results, big file dumps, verbose logs) into context, consider `headroom_compress` (MCP) to shrink it first; retrieve the original via `headroom_retrieve` if full detail turns out to be needed.
