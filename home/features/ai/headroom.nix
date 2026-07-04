{ config, lib, osConfig ? { }, pkgs, ... }:
let
  inherit (lib) mkIf optionalAttrs;

  aiCfg = if osConfig ? aiAgents then osConfig.aiAgents else null;

  # Single source of truth for every proxy instance lives in
  # hosts/shared/ai-agents.nix (aiAgents.headroom.proxies) so system modules
  # (claude-code.nix, codex.nix) and home-manager modules (agent-configs.nix,
  # vibe.nix, this file) never disagree. This module is deliberately generic:
  # it has no idea "vibe" or "mistral" exist -- it just spins up whatever's
  # declared in that attrset. Onboarding a future provider that needs its own
  # upstream is a data entry there, never a code change here.
  proxies = if aiCfg != null then aiCfg.headroom.proxies else { };
  proxyNames = builtins.attrNames proxies;

  stateDir = "${config.home.homeDirectory}/.local/state/headroom";
  launchdPath = "/etc/profiles/per-user/${config.home.username}/bin:/usr/bin:/bin:/usr/sbin:/sbin";

  uvx = "${pkgs.uv}/bin/uvx";
  # [proxy] pulls in everything the always-on compression proxy needs (fastapi/uvicorn,
  # ONNX Kompress model, MCP server, code-graph watcher). Pinned via `--from` so every
  # invocation resolves the same extras set regardless of caller.
  headroomProxyFrom = "headroom-ai[proxy]";

  # `headroom wrap` can also auto-register its own MCP server / tokensave / Serena
  # backup into the target CLI's config. We already declare `headroom`, `serena`, and
  # `codebase-memory` MCP servers ourselves via aiAgents, and don't want a second,
  # imperative registration path mutating agent-owned files outside Nix's control -- so
  # every wrap invocation below opts out of all of that and only reuses the persistent
  # proxy for compression.
  wrapSafetyFlags = [ "--no-proxy" "--no-mcp" "--no-tokensave" "--no-serena" "--no-context-tool" ];

  labelFor = name: "org.nix-community.home.headroom-proxy-${name}";
  logFileFor = name: "${stateDir}/headroom-proxy-${name}.log";
  errorLogFileFor = name: "${stateDir}/headroom-proxy-${name}.error.log";

  mkProxyServeScript = name: proxy:
    pkgs.writeShellScript "headroom-proxy-serve-${name}" ''
      set -euo pipefail
      exec ${uvx} --from ${lib.escapeShellArg headroomProxyFrom} headroom proxy \
        --host 127.0.0.1 --port ${toString proxy.port}
    '';

  mkProxyAgent = name: proxy: {
    name = "headroom-proxy-${name}";
    value = {
      enable = true;
      config = {
        ProgramArguments = [ "${mkProxyServeScript name proxy}" ];
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Background";
        StandardOutPath = logFileFor name;
        StandardErrorPath = errorLogFileFor name;
        EnvironmentVariables =
          {
            PATH = launchdPath;
            HOME = config.home.homeDirectory;
          }
          // optionalAttrs (proxy.anthropicTargetUrl != null) { ANTHROPIC_TARGET_API_URL = proxy.anthropicTargetUrl; }
          // optionalAttrs (proxy.openaiTargetUrl != null) { OPENAI_TARGET_API_URL = proxy.openaiTargetUrl; };
      };
    };
  };

  allLabelsShell = lib.concatMapStringsSep " " labelFor proxyNames;
  knownNamesShell = builtins.concatStringsSep " " proxyNames;
  # "shared" is just the well-known key for the general-purpose instance most tools
  # (Claude, Codex, OpenCode) use -- a naming convention in the data, not special-cased
  # machinery. Falls back gracefully if a from-scratch config ever omits it.
  sharedProxyUrl = if proxies ? shared then proxies.shared.url else null;
in
{
  home.file.".local/state/headroom/.keep".text = "";

  home.packages = [
    (pkgs.writeShellScriptBin "headroom-status" ''
      set -euo pipefail

      check_proxy() {
        local name="$1" url="$2"
        echo "Headroom proxy '$name': $url"
        if health=$(${pkgs.curl}/bin/curl -fsS "$url/health" 2>/dev/null); then
          echo "  ok      proxy is responding"
          # .checks.upstream.url always reports the Anthropic-backend health check
          # regardless of which target env var this instance actually overrides, so
          # read the real target(s) straight out of .config instead (whichever of
          # anthropic_api_url/openai_api_url is non-null for this instance).
          echo "$health" | ${pkgs.jq}/bin/jq -r '
            ([.config.anthropic_api_url, .config.openai_api_url] | map(select(. != null))) as $urls
            | "  version " + .version + "  upstream " + (if ($urls | length) > 0 then ($urls | join(", ")) else "real Anthropic/OpenAI defaults" end)
          '
        else
          echo "  missing proxy is not responding (see: headroom-logs $name)"
        fi
      }

      ${lib.concatMapStringsSep "\n" (name: "check_proxy ${lib.escapeShellArg name} ${lib.escapeShellArg proxies.${name}.url}") proxyNames}

      echo
      echo "Registered instances: ${builtins.concatStringsSep " " proxyNames} (aiAgents.headroom.proxies)"
      echo
      echo "Always-on MCP tools (headroom_compress/retrieve/stats): registered for Codex, Claude Code, Cursor, and Vibe via aiAgents."
      echo
      echo "Default routing is ON (opt-out, not opt-in) for Claude, Codex, and Vibe -- their"
      echo "normal config already points straight at one of the proxies above, no wrapper"
      echo "command needed."
      echo
      echo "Still opt-in (needs a live-generated model catalog, so it stays wrap-based):"
      echo "  headroom-opencode [args...]   - OpenCode through the shared proxy"
      echo
      echo "Cursor has no config file or env var for this -- one-time manual step:"
      echo "  Settings > Models > OpenAI API Key > Advanced > Override Base URL -> ${toString sharedProxyUrl}/v1"
      echo
      echo "Opt out of default routing (Claude/Codex/Vibe will fail to connect until resumed"
      echo "or rebuilt -- same accepted risk as Claude's local Ollama routing already carries):"
      echo "  headroom-pause [name]   - stop one instance (name), or all of them if omitted"
      echo "  headroom-resume [name]  - restart one instance (name), or all of them if omitted"
      echo
      echo "Logs: headroom-logs [name]  (default: shared)"
    '')

    (pkgs.writeShellScriptBin "headroom-logs" ''
      set -euo pipefail
      name="''${1:-shared}"
      log="${stateDir}/headroom-proxy-$name.log"
      if [ ! -f "$log" ]; then
        echo "No log file for proxy '$name'. Known instances: ${builtins.concatStringsSep " " proxyNames}" >&2
        exit 1
      fi
      exec tail -n 200 -f "$log"
    '')

    (pkgs.writeShellScriptBin "headroom-pause" ''
      set -euo pipefail
      domain="gui/$(id -u)"
      name="''${1:-}"
      if [ -n "$name" ]; then
        case " ${knownNamesShell} " in
          *" $name "*) : ;;
          *) echo "Unknown proxy '$name'. Known instances: ${knownNamesShell}" >&2; exit 1 ;;
        esac
        labels="org.nix-community.home.headroom-proxy-$name"
        echo "Stopping Headroom proxy '$name' -- anything routed through it will fail to"
        echo "connect until you run 'headroom-resume $name' (or rebuild)."
      else
        labels="${allLabelsShell}"
        echo "Stopping all managed Headroom proxy instances -- Claude, Codex, and Vibe are"
        echo "hardwired to them by default, so all three will fail to connect until you run"
        echo "'headroom-resume' (or rebuild)."
      fi
      for label in $labels; do
        launchctl bootout "$domain/$label" 2>/dev/null || echo "$label: already stopped."
      done
    '')

    (pkgs.writeShellScriptBin "headroom-resume" ''
      set -euo pipefail
      domain="gui/$(id -u)"
      name="''${1:-}"
      if [ -n "$name" ]; then
        case " ${knownNamesShell} " in
          *" $name "*) : ;;
          *) echo "Unknown proxy '$name'. Known instances: ${knownNamesShell}" >&2; exit 1 ;;
        esac
        labels="org.nix-community.home.headroom-proxy-$name"
      else
        labels="${allLabelsShell}"
      fi
      for label in $labels; do
        plist="${config.home.homeDirectory}/Library/LaunchAgents/$label.plist"
        if [ ! -f "$plist" ]; then
          continue
        fi
        launchctl bootstrap "$domain" "$plist" 2>/dev/null || echo "$label: already running."
      done
      if [ -n "$name" ]; then
        echo "Headroom proxy '$name' restarted."
      else
        echo "Headroom proxies restarted."
      fi
    '')

    (pkgs.writeShellScriptBin "headroom-opencode" ''
      set -euo pipefail
      if ! command -v opencode >/dev/null 2>&1; then
        echo "opencode command not found. Apply the profile that installs opencode first." >&2
        exit 1
      fi
      if ! ${pkgs.curl}/bin/curl -fsS "${toString sharedProxyUrl}/health" >/dev/null 2>&1; then
        echo "Headroom proxy is not responding at ${toString sharedProxyUrl}." >&2
        echo "Next steps: rebuild/apply Home Manager, then check: headroom-logs" >&2
        exit 1
      fi
      # OpenCode's custom-provider config requires an explicit, versioned model catalog
      # (no wildcard "any model" support), so unlike Codex/Claude we let `headroom wrap`
      # generate and inject that config at launch time (OPENCODE_CONFIG_CONTENT) rather
      # than hand-maintaining a model list in Nix that would go stale.
      exec ${uvx} --from ${lib.escapeShellArg headroomProxyFrom} headroom wrap opencode \
        ${lib.concatStringsSep " " wrapSafetyFlags} -- "$@"
    '')
  ];

  launchd.agents = mkIf pkgs.stdenv.hostPlatform.isDarwin (builtins.listToAttrs (lib.mapAttrsToList mkProxyAgent proxies));
}
