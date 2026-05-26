# Agent Instructions

- Inspect before editing. Prefer `rg` and `rg --files` for search.
- Preserve user changes and never revert unrelated work.
- Use Nix/Home Manager for declarative packages. On Darwin, use Homebrew casks for GUI apps that need current macOS app integration.
- Keep Home Manager and nix-darwin activation idempotent. Mutable Homebrew upgrades belong in `scripts/update-system.sh`.
- Manage secrets through sops-nix. Never commit credentials, tokens, or Warp/Oz/MCP secrets.
- Run focused checks after changes, usually `nix eval`, `nix flake check`, or `./scripts/check-config.sh` depending on scope.
