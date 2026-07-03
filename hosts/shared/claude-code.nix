{ config, lib, pkgs, ... }:
let
  inherit (lib) filterAttrs mkIf mkMerge optionalAttrs recursiveUpdate;

  aiAgentsLib = import ./ai-agents-lib.nix { inherit lib pkgs; };
in
{
  config = mkIf (config.aiAgents.enable && config.aiAgents.targets.claude.enable && config.aiAgents.claude.managed.enable) (
    let
      cfg = config.aiAgents;

      enabledMcpServers = filterAttrs (_: server: server.enabled && builtins.elem "claude" server.targets) cfg.mcpServers;

      renderClaudeMcpServer = name: rawServer:
        let
          server = aiAgentsLib.effectiveServerFor "claude" rawServer;
        in
        if server.type == "http" then
          {
            type = "http";
            url = server.url;
          } // optionalAttrs (server.headers != { } || server.bearerTokenEnvVar != null) {
            # Claude Code expands `${VAR}` in .mcp.json headers from the shell
            # environment at startup -- this is the only way to give it the same
            # bearer-token auth Codex gets natively via `bearer_token_env_var`.
            headers = server.headers // optionalAttrs (server.bearerTokenEnvVar != null) {
              Authorization = "Bearer \${${server.bearerTokenEnvVar}}";
            };
          }
        else
          {
            type = "stdio";
          } // aiAgentsLib.renderStdioCommand name server
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
