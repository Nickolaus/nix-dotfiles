{ flake, pkgs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  aiSources = import ../../flake/ai-agent-sources.nix { inherit flake; };
in
{
  imports = [
    ./ai-agent-catalog.nix
    ./ai-agents.nix
    ./ai-agents-derived.nix
    ./claude-code.nix
    ./codex.nix
  ];

  # GUI-launched Codex/Cursor processes do not reliably inherit the Home
  # Manager profile PATH. Put this MCP server in the system profile so
  # project-local MCP config can use /run/current-system/sw/bin consistently.
  environment.systemPackages = [
    aiSources.mcps.codebase-memory.packages.${system}.default
  ];
}
