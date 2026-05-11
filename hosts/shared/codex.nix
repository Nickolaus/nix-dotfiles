{ config, lib, pkgs, ... }:
let
  inherit (lib) escapeShellArg filterAttrs mkIf mkMerge optionalAttrs;

  tomlFormat = pkgs.formats.toml { };
  cfg = config.aiAgents;

  enabledMcpServers = filterAttrs (_: server: server.enabled && builtins.elem "codex" server.targets) cfg.mcpServers;

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

  renderCodexMcpServer = name: server:
    if server.type == "http" then
      {
        url = server.url;
      } // optionalAttrs (server.headers != { }) {
        http_headers = server.headers;
      } // optionalAttrs (server.bearerTokenEnvVar != null) {
        bearer_token_env_var = server.bearerTokenEnvVar;
      }
    else
      renderStdioCommand name server
      // optionalAttrs (server.args != [ ]) {
        args = server.args;
      } // optionalAttrs (server.env != { }) {
        env = server.env;
      };

  managedConfigSettings = {
    shell_environment_policy.exclude = [
      "GH_TOKEN"
      "GITHUB_TOKEN"
      "GITHUB_PERSONAL_ACCESS_TOKEN"
    ];

    model_providers.local_coding_ollama = {
      name = "Ollama";
      base_url = cfg.localCoding.openaiBaseUrl;
    };

    profiles.local-coding = {
      model = cfg.localCoding.model;
      model_provider = "local_coding_ollama";
    };

    mcp_servers = lib.mapAttrs renderCodexMcpServer enabledMcpServers;
  };
in
{
  config = mkIf (cfg.enable && cfg.targets.codex.enable && cfg.codex.managed.enable) (mkMerge [
    {
      environment.etc."codex/managed_config.toml".source =
        tomlFormat.generate "codex-managed-config.toml" managedConfigSettings;
    }
    (mkIf cfg.codex.requirements.enable {
      environment.etc."codex/requirements.toml".source =
        tomlFormat.generate "codex-requirements.toml" cfg.codex.requirements.settings;
    })
  ]);
}
