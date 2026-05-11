{ config, lib, pkgs, ... }:
let
  inherit (lib) escapeShellArg filterAttrs mkIf mkMerge optionalAttrs recursiveUpdate;
in
{
  config = mkIf (config.aiAgents.enable && config.aiAgents.targets.claude.enable && config.aiAgents.claude.managed.enable) (
    let
      cfg = config.aiAgents;

      enabledMcpServers = filterAttrs (_: server: server.enabled && builtins.elem "claude" server.targets) cfg.mcpServers;

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

      renderClaudeMcpServer = name: server:
        if server.type == "http" then
          {
            type = "http";
            url = server.url;
          } // optionalAttrs (server.headers != { }) {
            headers = server.headers;
          }
        else
          {
            type = "stdio";
          } // renderStdioCommand name server
          // optionalAttrs (server.args != [ ]) {
            args = server.args;
          } // optionalAttrs (server.env != { }) {
            env = server.env;
          };

      managedSettingsFile = builtins.toFile "claude-code-managed-settings.json" (builtins.toJSON {
        model = cfg.localCoding.model;
        env = {
          ANTHROPIC_BASE_URL = cfg.localCoding.anthropicBaseUrl;
          ANTHROPIC_AUTH_TOKEN = "ollama";
          ANTHROPIC_API_KEY = "";
        };
      });

      managedMcpFile = builtins.toFile "claude-code-managed-mcp.json" (builtins.toJSON (
        recursiveUpdate
          {
            mcpServers = lib.mapAttrs renderClaudeMcpServer enabledMcpServers;
          }
          cfg.claude.managedMcp.settings
      ));
    in
    mkMerge [
      (mkIf pkgs.stdenv.hostPlatform.isLinux {
        environment.etc = {
          "claude-code/managed-settings.json".source = managedSettingsFile;
        } // optionalAttrs cfg.claude.managedMcp.enable {
          "claude-code/managed-mcp.json".source = managedMcpFile;
        };
      })
      (mkIf pkgs.stdenv.hostPlatform.isDarwin {
        system.activationScripts.postActivation.text = ''
          /bin/mkdir -p "/Library/Application Support/ClaudeCode"
          /bin/ln -sfn "${managedSettingsFile}" "/Library/Application Support/ClaudeCode/managed-settings.json"
        '' + lib.optionalString cfg.claude.managedMcp.enable ''
          /bin/ln -sfn "${managedMcpFile}" "/Library/Application Support/ClaudeCode/managed-mcp.json"
        '';
      })
    ]
  );
}
