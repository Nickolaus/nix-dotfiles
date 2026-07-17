{ config, lib, osConfig ? { }, pkgs, ... }:
let
  inherit (lib) escapeShellArg mkIf optionalAttrs;

  aiAgentsLib = import ../../../hosts/shared/ai-agents-lib.nix { inherit lib pkgs; };

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
  uvRuntimeDir = "/private/tmp/${config.home.username}/headroom-install";
  launchdPath = "/etc/profiles/per-user/${config.home.username}/bin:/usr/bin:/bin:/usr/sbin:/sbin";

  uvx = "${pkgs.uv}/bin/uvx";
  # [proxy] pulls in everything the always-on compression proxy needs (fastapi/uvicorn,
  # ONNX Kompress model, MCP server, code-graph watcher). Pinned via `--from` so every
  # invocation resolves the same extras set regardless of caller.
  headroomProxyFrom = "headroom-ai[proxy]";

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

  # Native, baked-in local-coding provider for OpenCode: a permanent, named entry in
  # OpenCode's own config, selectable from its `/models` picker or `--model
  # local-ollama/<id>`, no wrapper binary needed. OpenCode's custom-provider schema
  # requires every model to be listed explicitly (no wildcard "any model" support), but
  # the local-coding route is always exactly one pinned model (`aiAgents.localCoding.model`),
  # so a static entry needs no live generation at all. OpenCode is the only integration
  # this repo wires up to the local-coding Ollama backend -- that backend is a single
  # loaded model processing one request at a time (`localAi.runtime`, ollama.nix), so
  # adding a second independent consumer risks one app's request silently starving
  # another's with no shared visibility between them.
  localCodingModel = if aiCfg != null then aiCfg.localCoding.model else null;
  opencodeLocalProvider = optionalAttrs (sharedProxyUrl != null && localCodingModel != null) {
    local-ollama = {
      npm = "@ai-sdk/openai-compatible";
      name = "Local Ollama (Headroom)";
      options = {
        baseURL = "${sharedProxyUrl}/v1";
        apiKey = "ollama";
      };
      models = {
        "${localCodingModel}" = { name = localCodingModel; };
      };
    };
  };
  opencodeLocalProviderFile = pkgs.writeText "opencode-local-provider.json" (builtins.toJSON opencodeLocalProvider);
in
{
  home.file.".local/state/headroom/.keep".text = "";

  home.activation.ensureHeadroomInstalled = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export UV_CACHE_DIR=${escapeShellArg "${uvRuntimeDir}/uv-cache"}
    mkdir -p "$UV_CACHE_DIR"

    headroom_bin="$(${pkgs.uv}/bin/uv tool dir --bin 2>/dev/null)/headroom"
    [ -x "$headroom_bin" ] \
      || ${pkgs.uv}/bin/uv tool install ${escapeShellArg headroomProxyFrom} >/dev/null 2>&1 \
      || echo "Warning: failed to install headroom (${headroomProxyFrom})" >&2
  '';

  home.packages = [
    (pkgs.writeShellScriptBin "headroom-status" ''
      set -euo pipefail

      headroom_bin="$(${pkgs.uv}/bin/uv tool dir --bin 2>/dev/null)/headroom"
      if [ -x "$headroom_bin" ]; then
        echo "Headroom CLI: ok      $headroom_bin"
      else
        echo "Headroom CLI: missing $headroom_bin"
      fi
      echo

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
      echo "Default routing is ON (opt-out, not opt-in) for Codex and Vibe -- their normal"
      echo "config already points straight at one of the proxies above, no wrapper command"
      echo "needed."
      echo
      echo "OpenCode has a native 'local-ollama' provider baked into"
      echo "~/.config/opencode/opencode.json -- opt-in, no wrapper needed: pick it from"
      echo "OpenCode's /models picker, or 'opencode --model local-ollama/${toString localCodingModel}'."
      echo "It's the only integration wired up to the local-coding Ollama backend, by design:"
      echo "that backend is a single loaded model processing one request at a time."
      echo
      echo "Claude Code has no local-coding route: it has no native multi-provider config"
      echo "(unlike Codex/OpenCode), and forcing ANTHROPIC_BASE_URL globally would count as"
      echo "\"another auth source\" and silently disable claude.ai subscription connectors/"
      echo "Remote Control -- so plain 'claude' always uses your real subscription."
      echo
      echo "Cursor has no config file or env var for this -- one-time manual step:"
      echo "  Settings > Models > OpenAI API Key > Advanced > Override Base URL -> ${toString sharedProxyUrl}/v1"
      echo
      echo "Opt out of default routing (Codex/Vibe will fail to connect until resumed or"
      echo "rebuilt; OpenCode's local-ollama provider just becomes unusable):"
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
        echo "Stopping all managed Headroom proxy instances -- Codex and Vibe are hardwired"
        echo "to them by default, so both will fail to connect until you run"
        echo "'headroom-resume' (or rebuild). OpenCode's local-ollama provider also stops"
        echo "working; the default 'claude' command (claude.ai subscription) and OpenCode's"
        echo "other providers are unaffected."
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

  ];

  launchd.agents = mkIf pkgs.stdenv.hostPlatform.isDarwin (
    builtins.listToAttrs (lib.mapAttrsToList mkProxyAgent proxies)
  );

  # Merges (never fully overwrites) the `local-ollama` provider into OpenCode's own
  # ~/.config/opencode/opencode.json -- any other provider, model default, or setting the
  # user (or `opencode auth login`) has added stays untouched; only the `provider.
  # local-ollama` key is owned by Nix here, same restraint restoreCodexUserConfig and the
  # Vibe config merge (this directory) take with their respective tools' user-editable
  # config files.
  home.activation.mergeOpencodeLocalProvider = mkIf (opencodeLocalProvider != { }) (
    lib.hm.dag.entryAfter [ "writeBoundary" ] (aiAgentsLib.mkJsonMergeActivation {
      configPath = "${config.home.homeDirectory}/.config/opencode/opencode.json";
      defaultContent = builtins.toJSON { "$schema" = "https://opencode.ai/config.json"; };
      jqArgName = "provider";
      jqFilter = ".provider = ((.provider // {}) + $provider[0])";
      valueFile = "${opencodeLocalProviderFile}";
      invalidJsonWarning = "warning: ~/.config/opencode/opencode.json is not valid JSON; skipping local-ollama provider merge for OpenCode";
    })
  );
}
