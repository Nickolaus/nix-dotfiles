{ lib, pkgs }:
let
  inherit (lib) escapeShellArg;
in
rec {
  # Shared by every script that reads/edits TOML via tomlkit (Vibe's config.toml merge,
  # the MCP-profile onboarding scripts) -- one derivation instead of each caller declaring
  # its own identical `pkgs.python3.withPackages (ps: [ ps.tomlkit ])`.
  tomlkitPython = pkgs.python3.withPackages (ps: [ ps.tomlkit ]);

  # Shared by every activation script that owns exactly one top-level key in a JSON config
  # file a third-party tool also writes to (Claude's `.claude.json` mcpServers, OpenCode's
  # opencode.json provider.local-ollama) -- identical mechanics (create-if-missing, validate,
  # `jq --slurpfile` merge, atomic `mv`), differing only in the one jq filter each caller
  # actually needs. Not used for TOML mergers (Codex/Vibe): those need genuinely different
  # control flow (delete-only vs. full merge with a state sidecar), not just a different
  # filter string, so forcing them through this same shape would add coupling instead of
  # removing duplication.
  mkJsonMergeActivation =
    { configPath
    , defaultContent ? "{}"
    , jqArgName
    , jqFilter
    , valueFile
    , invalidJsonWarning
    }:
    ''
      config_file=${escapeShellArg configPath}
      mkdir -p "$(dirname "$config_file")"
      if [ ! -f "$config_file" ]; then
        echo ${escapeShellArg defaultContent} > "$config_file"
      fi
      if ${pkgs.jq}/bin/jq empty "$config_file" >/dev/null 2>&1; then
        tmp_file="$(mktemp)"
        ${pkgs.jq}/bin/jq --slurpfile ${jqArgName} ${escapeShellArg valueFile} \
          ${escapeShellArg jqFilter} \
          "$config_file" > "$tmp_file"
        mv "$tmp_file" "$config_file"
      else
        echo ${escapeShellArg invalidJsonWarning} >&2
      fi
    '';

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
