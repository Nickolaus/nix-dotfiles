{ ... }: {
  imports = [
    ./ai-agents.nix
    ./ai-agents-derived.nix
    ./claude-code.nix
    ./codex.nix
  ];
}
