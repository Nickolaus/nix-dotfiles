{ config, lib, pkgs, ... }:

let
  inherit (lib) filterAttrs mkIf mkMerge optionalAttrs;

  aiAgentsLib = import ./ai-agents-lib.nix { inherit lib pkgs; };
  tomlFormat = pkgs.formats.toml { };
  cfg = config.aiAgents;

  managedHooksDir = "/etc/codex/hooks";

  enabledMcpServers =
    filterAttrs (_: server: server.enabled && builtins.elem "codex" server.targets) cfg.mcpServers;

  renderCodexMcpServer =
    name: rawServer:
    let
      server = aiAgentsLib.effectiveServerFor "codex" rawServer;
    in
    (if aiAgentsLib.isUrlTransport server then
      {
        url = server.url;
      }
      // optionalAttrs (server.headers != { }) {
        http_headers = server.headers;
      }
      // optionalAttrs (server.bearerTokenEnvVar != null) {
        bearer_token_env_var = server.bearerTokenEnvVar;
      }
    else
      aiAgentsLib.renderStdioCommand name server
      // optionalAttrs (server.args != [ ]) {
        args = server.args;
      }
      // optionalAttrs (server.env != { }) {
        env = server.env;
      })
    // optionalAttrs (server.startupTimeoutSec != null) {
      startup_timeout_sec = server.startupTimeoutSec;
    };

  rtkCodexPretoolHook = pkgs.writeText "codex-rtk-pretool.py" ''
    import json
    import subprocess
    import sys


    def main() -> int:
        try:
            payload = json.load(sys.stdin)
        except Exception:
            return 0

        tool_input = payload.get("tool_input") or {}
        command = tool_input.get("command")

        if not isinstance(command, str) or not command.strip():
            return 0

        # Avoid recursive rewrites if the model already prefixed the command.
        if command.lstrip().startswith("rtk "):
            return 0

        try:
            result = subprocess.run(
                ["${pkgs.rtk}/bin/rtk", "rewrite", command],
                check=False,
                capture_output=True,
                text=True,
                timeout=2,
            )
        except Exception:
            return 0

        rewritten = result.stdout.strip()

        if not rewritten or rewritten == command:
            return 0

        json.dump(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "allow",
                    "updatedInput": {
                        "command": rewritten,
                    },
                }
            },
            sys.stdout,
        )
        sys.stdout.write("\n")
        return 0


    raise SystemExit(main())
  '';

  managedConfigSettings = {
    # Redirects the built-in "openai" provider (default `codex`, ChatGPT sign-in *or* an
    # API key -- either stays intact) through the always-on Headroom compression proxy
    # (home/features/ai/headroom.nix, aiAgents.headroom.proxies.shared -- single source of
    # truth). That proxy's own openaiTargetUrl is left at its real-OpenAI default, so this
    # is the same destination and auth as before, just compressed.
    # `openai_base_url` (as opposed to a custom `model_providers.*` entry, which requires
    # `env_key` and can't use ChatGPT sign-in) is what keeps the provider's identity
    # intact -- see https://developers.openai.com/codex/config-advanced.
    # Opt out: `headroom-pause`.
    openai_base_url = "${cfg.headroom.proxies.shared.url}/v1";

    shell_environment_policy.exclude = [
      "GH_TOKEN"
      "GITHUB_TOKEN"
      "GITHUB_PERSONAL_ACCESS_TOKEN"
      "CODEX_GITHUB_TOKEN"
    ];

    mcp_servers =
      lib.mapAttrs renderCodexMcpServer enabledMcpServers;
  };

  existingRequirementHooks = cfg.codex.requirements.settings.hooks or { };

  codexRequirementsSettings = lib.recursiveUpdate cfg.codex.requirements.settings {
    # Codex now supports PreToolUse rewrites with `updatedInput`. Use a managed hook so
    # RTK applies across projects without mutating per-repo `.codex/config.toml`.
    features = {
      hooks = true;
    };

    hooks =
      existingRequirementHooks
      // {
        managed_dir = managedHooksDir;
        PreToolUse = (existingRequirementHooks.PreToolUse or [ ]) ++ [
          {
            matcher = "^Bash$";
            hooks = [
              {
                type = "command";
                command = "${pkgs.python3}/bin/python3 ${managedHooksDir}/rtk-pretool.py";
                timeout = 10;
                statusMessage = "Rewriting Bash through RTK";
              }
            ];
          }
        ];
      };
  };
in
{
  config = mkIf (cfg.enable && cfg.targets.codex.enable && cfg.codex.managed.enable) (mkMerge [
    {
      environment.etc."codex/managed_config.toml".source =
        tomlFormat.generate "codex-managed-config.toml" managedConfigSettings;
    }
    (mkIf cfg.codex.requirements.enable {
      environment.etc."codex/hooks/rtk-pretool.py".source = rtkCodexPretoolHook;
      environment.etc."codex/requirements.toml".source =
        tomlFormat.generate "codex-requirements.toml" codexRequirementsSettings;
    })
  ]);
}
