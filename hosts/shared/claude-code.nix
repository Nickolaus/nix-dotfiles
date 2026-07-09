{ config, lib, pkgs, ... }:
let
  inherit (lib) filterAttrs mkIf mkMerge optionalAttrs recursiveUpdate;

  aiAgentsLib = import ./ai-agents-lib.nix { inherit lib pkgs; };

  cfg = config.aiAgents;

  claudeManagedActive =
    cfg.enable && cfg.targets.claude.enable && cfg.claude.managed.enable;

  enabledMcpServers = filterAttrs (_: server: server.enabled && builtins.elem "claude" server.targets) cfg.mcpServers;

  renderClaudeMcpServer = name: rawServer:
    let
      server = aiAgentsLib.effectiveServerFor "claude" rawServer;
    in
    if aiAgentsLib.isUrlTransport server then
      {
        type = server.type;
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

  # Content lives entirely in `cfg.claude.managed.settings` (empty by default -- see
  # its description in hosts/shared/ai-agents.nix: a managed policy overrides even
  # user settings, so forcing ANTHROPIC_BASE_URL/AUTH_TOKEN/API_KEY/model here for
  # local-Ollama routing would silently break claude.ai subscription connectors/Remote
  # Control for anyone the policy applies to, with no easy opt-out.
  managedSettingsFile = builtins.toFile "claude-code-managed-settings.json" (builtins.toJSON cfg.claude.managed.settings);

  managedMcpFile = builtins.toFile "claude-code-managed-mcp.json" (builtins.toJSON (
    recursiveUpdate
      {
        mcpServers = lib.mapAttrs renderClaudeMcpServer enabledMcpServers;
      }
      cfg.claude.managedMcp.settings
  ));

  darwinManagedSettingsPath = "/Library/Application Support/ClaudeCode/managed-settings.json";
  darwinManagedMcpPath = "/Library/Application Support/ClaudeCode/managed-mcp.json";
in
{
  config = mkMerge [
    (mkIf (claudeManagedActive && pkgs.stdenv.hostPlatform.isLinux) {
      environment.etc = {
        "claude-code/managed-settings.json".source = managedSettingsFile;
      } // optionalAttrs cfg.claude.managedMcp.enable {
        "claude-code/managed-mcp.json".source = managedMcpFile;
      };
    })
    # Unconditional on Darwin (not gated on claudeManagedActive) so that turning
    # `claude.managed.enable` off actually undoes what turning it on created. Unlike
    # the Linux branch above, which uses `environment.etc` -- something NixOS/
    # nix-darwin already diffs and cleans up stale entries for automatically -- this
    # writes a plain `ln -sfn` via `system.activationScripts`, which has no such
    # tracking: previously, disabling `claude.managed.enable` just stopped this script
    # from running, leaving a symlink permanently dangling at a since-garbage-collected
    # store path (found and confirmed during this session's verification). Now the
    # script always runs and explicitly removes both files when the feature is off.
    (mkIf pkgs.stdenv.hostPlatform.isDarwin {
      system.activationScripts.postActivation.text =
        if claudeManagedActive then
          ''
            /bin/mkdir -p "/Library/Application Support/ClaudeCode"
            /bin/ln -sfn "${managedSettingsFile}" "${darwinManagedSettingsPath}"
          '' + (
            if cfg.claude.managedMcp.enable then
              ''
                /bin/ln -sfn "${managedMcpFile}" "${darwinManagedMcpPath}"
              ''
            else
              ''
                /bin/rm -f "${darwinManagedMcpPath}"
              ''
          )
        else
          ''
            /bin/rm -f "${darwinManagedSettingsPath}" "${darwinManagedMcpPath}"
          '';
    })
  ];
}
