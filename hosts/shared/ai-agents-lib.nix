{ lib, pkgs }:
let
  inherit (lib) escapeShellArg;
in
rec {
  effectiveServerFor = target: server:
    let
      override = server.targetOverrides.${target};
    in
    server // {
      type = if override.type != null then override.type else server.type;
      url = if override.url != null then override.url else server.url;
      command = if override.command != null then override.command else server.command;
      args = if override.args != null then override.args else server.args;
      env = server.env // override.env;
      isolateWorkingDirectory =
        if override.isolateWorkingDirectory != null then override.isolateWorkingDirectory else server.isolateWorkingDirectory;
      workingDirectory =
        if override.workingDirectory != null then override.workingDirectory else server.workingDirectory;
      headers = server.headers // override.headers;
      bearerTokenEnvVar =
        if override.bearerTokenEnvVar != null then override.bearerTokenEnvVar else server.bearerTokenEnvVar;
      inheritEnv = if override.inheritEnv != null then override.inheritEnv else server.inheritEnv;
      startupTimeoutSec =
        if override.startupTimeoutSec != null then override.startupTimeoutSec else server.startupTimeoutSec;
    };

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
}
