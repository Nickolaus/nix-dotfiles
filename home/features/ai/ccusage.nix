{ config, flake, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.aiUsageReports;
  system = pkgs.stdenv.hostPlatform.system;
  ccusagePackage =
    flake.inputs.ccusage.packages.${system}.ccusage
      or flake.inputs.ccusage.packages.${system}.default;

  ccusageBin = "${ccusagePackage}/bin/ccusage";

  aiUsage = pkgs.writeShellScriptBin "ai-usage" ''
    set -euo pipefail

    if [ "$#" -eq 0 ]; then
      exec ${ccusageBin} daily --all
    fi

    exec ${ccusageBin} "$@"
  '';

  aiUsageCodex = pkgs.writeShellScriptBin "ai-usage-codex" ''
    set -euo pipefail
    exec ${ccusageBin} codex daily "$@"
  '';

  aiUsageClaude = pkgs.writeShellScriptBin "ai-usage-claude" ''
    set -euo pipefail
    exec ${ccusageBin} claude daily "$@"
  '';

  aiUsageOpenCode = pkgs.writeShellScriptBin "ai-usage-opencode" ''
    set -euo pipefail
    exec ${ccusageBin} opencode daily "$@"
  '';

  usageInstructions = ''

    ## AI Usage Reporting

    Use `ai-usage` for local token/cost reports via ccusage.
    - `ai-usage` shows a daily report for all detected coding-agent sources.
    - `ai-usage codex daily|weekly|monthly|session` focuses Codex.
    - `ai-usage claude daily|weekly|monthly|session` focuses Claude Code.
    - `ai-usage-codex`, `ai-usage-claude`, and `ai-usage-opencode` are daily shortcuts.

    ccusage reads local CLI usage files. It does not run a server, bind ports,
    install hooks, or export prompts/tool payloads.
  '';
in
{
  options.aiUsageReports.enable = mkEnableOption "local coding-agent usage reports via ccusage" // {
    default = true;
  };

  config = mkIf cfg.enable {
    home.packages = [
      ccusagePackage
      aiUsage
      aiUsageCodex
      aiUsageClaude
      aiUsageOpenCode
    ];

    home.file.".codex/AGENTS.md".text = usageInstructions;
    home.file.".vibe/AGENTS.md".text = usageInstructions;
    home.file.".claude/CLAUDE.md".text = usageInstructions;
  };
}
