{ config, lib, osConfig ? { }, pkgs, ... }:
let
  inherit (lib) escapeShellArg filterAttrs optionalAttrs;

  aiCfg =
    if osConfig ? aiAgents then
      osConfig.aiAgents
    else
      null;

  cursorEnvRef = name: "\${env:${name}}";
  enabledMcpServers =
    if aiCfg != null then
      filterAttrs (_: server: server.enabled) aiCfg.mcpServers
    else
      { };

  serverEnabledFor = target: server: builtins.elem target server.targets;

  renderEnvForCursor = server:
    server.env
    // builtins.listToAttrs (map (name: {
      inherit name;
      value = cursorEnvRef name;
    }) server.inheritEnv);

  renderEnvForInheritedSession = server: server.env;

  isolatedStdioLauncher = name: server:
    pkgs.writeShellScript "ai-agent-mcp-${name}" (
      ''
        set -eu

        if [ -n "''${AI_AGENTS_MCP_STATE_DIR:-}" ]; then
          state_root="$AI_AGENTS_MCP_STATE_DIR"
        else
          if [ -z "''${HOME:-}" ]; then
            echo "HOME must be set to derive the MCP state directory" >&2
            exit 1
          fi

          case "$(${pkgs.coreutils}/bin/uname -s 2>/dev/null || uname -s)" in
            Darwin)
              state_root="$HOME/Library/Logs/ai-agents/mcp"
              ;;
            *)
              state_root="''${XDG_STATE_HOME:-$HOME/.local/state}/ai-agents/mcp"
              ;;
          esac
        fi

        server_name=${escapeShellArg name}
      '' + (
        if server.workingDirectory != null then
          ''
            run_dir=${escapeShellArg server.workingDirectory}
          ''
        else
          ''
            run_dir="$state_root/$server_name"
          ''
      ) + ''

        ${pkgs.coreutils}/bin/mkdir -p "$run_dir"
        cd "$run_dir"
        exec ${escapeShellArg server.command} "$@"
      ''
    );

  renderStdioCommand = name: server:
    let
      useIsolatedWorkingDirectory = server.isolateWorkingDirectory || server.workingDirectory != null;
    in
    {
      command =
        if useIsolatedWorkingDirectory then
          "${isolatedStdioLauncher name server}"
        else
          server.command;
    };

  renderMcpServerForJson = envRenderer: name: server:
    if server.type == "http" then
      {
        type = "http";
        url = server.url;
      } // optionalAttrs (server.headers != { }) {
        headers = server.headers;
      }
    else
      renderStdioCommand name server
      // optionalAttrs (server.args != [ ]) {
        args = server.args;
      } // optionalAttrs ((envRenderer server) != { }) {
        env = envRenderer server;
      };

  claudeSettings = {
    model = aiCfg.localCoding.model;
    env = {
      ANTHROPIC_BASE_URL = aiCfg.localCoding.anthropicBaseUrl;
      ANTHROPIC_AUTH_TOKEN = "ollama";
      ANTHROPIC_API_KEY = "";
    };
  };

  cursorMcpSettings = {
    mcpServers = lib.mapAttrs (renderMcpServerForJson renderEnvForCursor) (
      filterAttrs (_: server: serverEnabledFor "cursor" server) enabledMcpServers
    );
  };

  claudeMcpSettings = {
    mcpServers = lib.mapAttrs (renderMcpServerForJson renderEnvForInheritedSession) (
      filterAttrs (_: server: serverEnabledFor "claude" server) enabledMcpServers
    );
  };
in
{
  home.file =
    lib.optionalAttrs (aiCfg != null && aiCfg.enable && aiCfg.targets.claude.enable) {
      ".claude/settings.json".text = builtins.toJSON claudeSettings;
      ".claude/ai-agents-mcp.json".text = builtins.toJSON claudeMcpSettings;
    }
    // lib.optionalAttrs (aiCfg != null && aiCfg.enable && aiCfg.targets.cursor.enable) {
      ".cursor/mcp.json".text = builtins.toJSON cursorMcpSettings;
    };

  home.activation.mergeClaudeUserMcp =
    lib.mkIf (aiCfg != null && aiCfg.enable && aiCfg.targets.claude.enable)
      (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        claude_state_file="${config.home.homeDirectory}/.claude.json"
        generated_mcp_file="${config.home.homeDirectory}/.claude/ai-agents-mcp.json"
        tmp_file="$(mktemp)"

        if [ -f "$claude_state_file" ]; then
          if ! ${pkgs.jq}/bin/jq empty "$claude_state_file" >/dev/null 2>&1; then
            echo "warning: $claude_state_file is not valid JSON; skipping aiAgents MCP merge for Claude Code" >&2
            rm -f "$tmp_file"
          else
            ${pkgs.jq}/bin/jq --slurpfile generated "$generated_mcp_file" \
              '.mcpServers = ($generated[0].mcpServers // {})' \
              "$claude_state_file" > "$tmp_file"
            mv "$tmp_file" "$claude_state_file"
          fi
        else
          ${pkgs.jq}/bin/jq -n --slurpfile generated "$generated_mcp_file" \
            '{ mcpServers: ($generated[0].mcpServers // {}) }' > "$tmp_file"
          mv "$tmp_file" "$claude_state_file"
        fi
      '');

  home.activation.restoreCodexUserConfig =
    lib.mkIf (aiCfg != null && aiCfg.enable && aiCfg.targets.codex.enable)
      (lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        codex_dir="${config.home.homeDirectory}/.codex"
        codex_config="$codex_dir/config.toml"
        codex_backup="$codex_dir/config.toml.backup"

        mkdir -p "$codex_dir"

        if [ ! -e "$codex_config" ] && [ -f "$codex_backup" ]; then
          cp "$codex_backup" "$codex_config"
        fi
      '');
}
