{ config, lib, pkgs, ... }:

let
  inherit (lib) escapeShellArg filterAttrs mkIf mkMerge optional optionalAttrs optionalString;

  aiAgentsLib = import ./ai-agents-lib.nix { inherit lib pkgs; };
  tomlFormat = pkgs.formats.toml { };
  cfg = config.aiAgents;

  managedHooksDir = "/etc/codex/hooks";
  codexHeadroomProxy = cfg.headroom.proxies.shared;
  codexHeadroomLabel = "org.nix-community.home.headroom-proxy-shared";
  codexHeadroomProxyFrom = aiAgentsLib.mkUvxPackageSpec {
    package = "headroom-ai";
    version = aiAgentsLib.mcpPackageVersions.pypi.headroom;
    extras = [ "proxy" ];
  };

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

  codexHeadroomEnsureHook = pkgs.writeShellScript "codex-headroom-ensure" ''
    set -eu

    url=${escapeShellArg codexHeadroomProxy.url}
    label=${escapeShellArg codexHeadroomLabel}
    plist="$HOME/Library/LaunchAgents/$label.plist"
    domain="gui/$(${pkgs.coreutils}/bin/id -u)"

    healthy() {
      ${pkgs.curl}/bin/curl -fsS "$url/health" >/dev/null 2>&1
    }

    if healthy; then
      exit 0
    fi

    if [ -f "$plist" ]; then
      /bin/launchctl bootstrap "$domain" "$plist" >/dev/null 2>&1 || true
      /bin/launchctl kickstart -k "$domain/$label" >/dev/null 2>&1 || true
    fi

    i=0
    while [ "$i" -lt 10 ]; do
      if healthy; then
        exit 0
      fi
      i=$((i + 1))
      ${pkgs.coreutils}/bin/sleep 0.5
    done

    runtime_dir="/private/tmp/$(${pkgs.coreutils}/bin/id -un)/headroom"
    log_dir="$runtime_dir/logs"
    ${pkgs.coreutils}/bin/mkdir -p "$log_dir" "$runtime_dir/uv-cache" "$runtime_dir/cache" "$runtime_dir/state" "$runtime_dir/data"
    (
      export HOME="$HOME"
      export UV_CACHE_DIR="$runtime_dir/uv-cache"
      export XDG_CACHE_HOME="$runtime_dir/cache"
      export XDG_STATE_HOME="$runtime_dir/state"
      export XDG_DATA_HOME="$runtime_dir/data"
      ${optionalString (codexHeadroomProxy.anthropicTargetUrl != null) ''
        export ANTHROPIC_TARGET_API_URL=${escapeShellArg codexHeadroomProxy.anthropicTargetUrl}
      ''}
      ${optionalString (codexHeadroomProxy.openaiTargetUrl != null) ''
        export OPENAI_TARGET_API_URL=${escapeShellArg codexHeadroomProxy.openaiTargetUrl}
      ''}
      headroom_bin="$HOME/.local/bin/headroom"
      if [ -x "$headroom_bin" ]; then
        exec "$headroom_bin" proxy --host 127.0.0.1 --port ${toString codexHeadroomProxy.port}
      fi
      exec ${pkgs.uv}/bin/uvx --from ${escapeShellArg codexHeadroomProxyFrom} headroom proxy \
        --host 127.0.0.1 --port ${toString codexHeadroomProxy.port}
    ) >>"$log_dir/headroom-proxy-shared.log" 2>>"$log_dir/headroom-proxy-shared.error.log" &

    i=0
    while [ "$i" -lt 30 ]; do
      if healthy; then
        exit 0
      fi
      i=$((i + 1))
      ${pkgs.coreutils}/bin/sleep 0.5
    done

    echo "Warning: Codex is hard-routed through Headroom, but $url is not healthy." >&2
    echo "Run 'headroom-status' or 'headroom-resume shared' in a shell." >&2
    exit 0
  '';

  codexHeadroomEnsureHookEntry = {
    hooks = [
      {
        type = "command";
        command = "${managedHooksDir}/headroom-ensure";
        timeout = 20;
        statusMessage = "Ensuring Codex Headroom proxy is running";
      }
    ];
  };

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
        SessionStart = (existingRequirementHooks.SessionStart or [ ]) ++ [
          codexHeadroomEnsureHookEntry
        ];
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
      environment.etc."codex/hooks/headroom-ensure".source = codexHeadroomEnsureHook;
      environment.etc."codex/requirements.toml".source =
        tomlFormat.generate "codex-requirements.toml" codexRequirementsSettings;
    })
  ]);
}
