{ config, lib, pkgs, ... }:

let
  inherit (lib) filterAttrs mkIf mkMerge optional optionalAttrs;

  aiAgentsLib = import ./ai-agents-lib.nix { inherit lib pkgs; };
  tomlFormat = pkgs.formats.toml { };
  cfg = config.aiAgents;

  managedHooksDir = "/etc/codex/hooks";
  codexObservabilityEnabled =
    cfg.observability.enable
    && cfg.codex.observability.enable
    && cfg.observability.captureMode == "metadata-only";
  codexObservePython = pkgs.python3.withPackages (pythonPackages: [
    pythonPackages.opentelemetry-sdk
    pythonPackages.opentelemetry-exporter-otlp-proto-http
  ]);

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

  codexObserveHook = pkgs.writeText "codex-ai-observe-metadata.py" ''
    import hashlib
    import json
    import logging
    import os
    import subprocess
    import sys

    from opentelemetry import trace
    from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
    from opentelemetry.sdk.resources import Resource
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import SimpleSpanProcessor


    def safe_str(value):
        return value if isinstance(value, str) else ""


    def safe_bool(value):
        return isinstance(value, bool) and value


    def hash_value(value):
        if not value:
            return "unknown"
        return hashlib.sha256(value.encode("utf-8", "replace")).hexdigest()[:16]


    def git_value(args, cwd):
        try:
            result = subprocess.run(
                ["${pkgs.git}/bin/git", "-c", "core.fsmonitor=false", *args],
                cwd=cwd or None,
                check=False,
                capture_output=True,
                text=True,
                timeout=2,
            )
        except Exception:
            return ""
        if result.returncode != 0:
            return ""
        return result.stdout.strip()


    def main() -> int:
        endpoint_base, backend, capture_mode, hook_event = sys.argv[1:5]
        if capture_mode != "metadata-only":
            return 0

        try:
            payload = json.load(sys.stdin)
        except Exception:
            payload = {}

        cwd = safe_str(payload.get("cwd")) or safe_str(payload.get("working_directory")) or os.environ.get("PWD", "")
        git_root = git_value(["rev-parse", "--show-toplevel"], cwd)
        git_commit = git_value(["rev-parse", "HEAD"], git_root or cwd) or "unknown"
        dirty = bool(git_value(["status", "--short", "--untracked-files=all"], git_root or cwd))

        attributes = {
            "ai.setup.agent": "codex",
            "ai.setup.backend": backend,
            "ai.setup.capture_mode": capture_mode,
            "ai.setup.config_commit": git_commit,
            "ai.setup.dirty": dirty,
            "ai.agent.vendor": "openai",
            "ai.agent.client": "codex",
            "ai.agent.hook_event": hook_event,
            "ai.agent.tool_name": safe_str(payload.get("tool_name")) or "none",
            "ai.agent.session_id": safe_str(payload.get("session_id")) or "unknown",
            "ai.agent.turn_id": safe_str(payload.get("turn_id")) or "unknown",
            "ai.agent.cwd_hash": hash_value(cwd),
            "ai.agent.git_root_hash": hash_value(git_root),
            "ai.agent.has_tool_input": isinstance(payload.get("tool_input"), dict),
            "ai.agent.has_tool_output": payload.get("tool_output") is not None,
            "ai.agent.permission_requested": hook_event == "PermissionRequest",
            "ai.agent.success": not safe_bool(payload.get("error")),
        }

        try:
            logging.disable(logging.CRITICAL)
            provider = TracerProvider(
                resource=Resource.create(
                    {
                        "service.name": "nix-dotfiles-codex-hooks",
                        "service.version": "1",
                    }
                )
            )
            provider.add_span_processor(
                SimpleSpanProcessor(
                    OTLPSpanExporter(endpoint=endpoint_base.rstrip("/") + "/v1/traces", timeout=1)
                )
            )
            trace.set_tracer_provider(provider)
            tracer = trace.get_tracer("nix-dotfiles.ai-observability.codex", "1")
            with tracer.start_as_current_span("ai.agent.codex." + hook_event) as span:
                for key, value in attributes.items():
                    span.set_attribute(key, value)
            provider.shutdown()
        except Exception:
            return 0

        return 0


    raise SystemExit(main())
  '';

  codexObserveHookEntry = eventName: {
    hooks = [
      {
        type = "command";
        command = "${codexObservePython}/bin/python3 ${managedHooksDir}/ai-observe-metadata.py ${lib.escapeShellArg cfg.observability.phoenixUrl} ${lib.escapeShellArg cfg.observability.backend} ${lib.escapeShellArg cfg.observability.captureMode} ${eventName}";
        timeout = 5;
        statusMessage = "Recording metadata-only AI observability event";
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
        SessionStart = (existingRequirementHooks.SessionStart or [ ]) ++ optional codexObservabilityEnabled (codexObserveHookEntry "SessionStart");
        UserPromptSubmit = (existingRequirementHooks.UserPromptSubmit or [ ]) ++ optional codexObservabilityEnabled (codexObserveHookEntry "UserPromptSubmit");
        Stop = (existingRequirementHooks.Stop or [ ]) ++ optional codexObservabilityEnabled (codexObserveHookEntry "Stop");
        SubagentStart = (existingRequirementHooks.SubagentStart or [ ]) ++ optional codexObservabilityEnabled (codexObserveHookEntry "SubagentStart");
        SubagentStop = (existingRequirementHooks.SubagentStop or [ ]) ++ optional codexObservabilityEnabled (codexObserveHookEntry "SubagentStop");
        PostToolUse = (existingRequirementHooks.PostToolUse or [ ]) ++ optional codexObservabilityEnabled (codexObserveHookEntry "PostToolUse");
        PermissionRequest = (existingRequirementHooks.PermissionRequest or [ ]) ++ optional codexObservabilityEnabled (codexObserveHookEntry "PermissionRequest");
        PreToolUse = (existingRequirementHooks.PreToolUse or [ ]) ++ optional codexObservabilityEnabled (codexObserveHookEntry "PreToolUse") ++ [
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
      environment.etc."codex/hooks/ai-observe-metadata.py".source = codexObserveHook;
      environment.etc."codex/requirements.toml".source =
        tomlFormat.generate "codex-requirements.toml" codexRequirementsSettings;
    })
  ]);
}
