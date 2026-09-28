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
  # Same Darwin/Linux split as rtk.nix and workflow-receipts.nix: macOS
  # symlinks /tmp -> /private/tmp and Codex's sandbox needs the canonical
  # path there; Linux (and WSL) has no /private, so use XDG state home.
  uvRuntimeDir =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "/private/tmp/${config.home.username}/headroom-install"
    else "${config.xdg.stateHome}/headroom-install";
  launchdPath = "/etc/profiles/per-user/${config.home.username}/bin:/usr/bin:/bin:/usr/sbin:/sbin";

  uvx = "${pkgs.uv}/bin/uvx";
  # [proxy] pulls in everything the always-on compression proxy needs (fastapi/uvicorn,
  # ONNX Kompress model, MCP server, code-graph watcher). Pinned via `--from` so every
  # invocation resolves the same extras set regardless of caller.
  headroomProxyFrom = aiAgentsLib.mkUvxPackageSpec {
    package = "headroom-ai";
    version = aiAgentsLib.mcpPackageVersions.pypi.headroom;
    extras = [ "proxy" ];
  };

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
  # (Claude, Codex) use -- a naming convention in the data, not special-cased
  # machinery. Falls back gracefully if a from-scratch config ever omits it.
  sharedProxyUrl = if proxies ? shared then proxies.shared.url else null;
in
{
  home.file.".local/state/headroom/.keep".text = "";

  home.activation.ensureHeadroomInstalled = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export UV_CACHE_DIR=${escapeShellArg "${uvRuntimeDir}/uv-cache"}
    mkdir -p "$UV_CACHE_DIR"

    ${pkgs.uv}/bin/uv tool install ${escapeShellArg headroomProxyFrom} >/dev/null 2>&1 \
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
      echo "Claude Code is not routed through Headroom: forcing ANTHROPIC_BASE_URL globally"
      echo "would count as \"another auth source\" and silently disable claude.ai subscription"
      echo "connectors/Remote Control -- so plain 'claude' always uses your real subscription."
      echo
      echo "Cursor has no config file or env var for this -- one-time manual step:"
      echo "  Settings > Models > OpenAI API Key > Advanced > Override Base URL -> ${toString sharedProxyUrl}/v1"
      echo
      echo "Opt out of default routing (Codex/Vibe will fail to connect until resumed or"
      echo "rebuilt):"
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
        echo "'headroom-resume' (or rebuild). The default 'claude' command (claude.ai"
        echo "subscription) is unaffected."
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

  # Keeps OpenCode free of the `local-ollama` provider id, which has no backend. Touches only
  # that provider, `model`/`small_model` values anywhere in opencode.json that point at it,
  # and its entries in the TUI's recent/favorite/variant model state. Each file is rewritten
  # in place (same directory, same mode) only when it references `local-ollama`; unreadable
  # or non-JSON files are left alone.
  home.activation.removeOpencodeLocalProvider = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    jq=${pkgs.jq}/bin/jq

    opencode_scrub() {
      local file="$1" check="$2" filter="$3" tmp mode
      [ -f "$file" ] || return 0
      "$jq" -e "$check" "$file" >/dev/null 2>&1 || return 0
      if [[ -v DRY_RUN ]]; then
        echo "Would remove local-ollama references from $file"
        return 0
      fi
      mode="$(${pkgs.coreutils}/bin/stat -c %a "$file")"
      tmp="$(${pkgs.coreutils}/bin/mktemp "$file.XXXXXX")"
      if "$jq" "$filter" "$file" > "$tmp" && ${pkgs.coreutils}/bin/chmod "$mode" "$tmp"; then
        ${pkgs.coreutils}/bin/mv "$tmp" "$file"
        verboseEcho "Removed local-ollama references from $file"
      else
        ${pkgs.coreutils}/bin/rm -f "$tmp"
        echo "Warning: could not clean local-ollama references from $file; leaving it as-is." >&2
      fi
    }

    opencode_scrub ${escapeShellArg "${config.home.homeDirectory}/.config/opencode/opencode.json"} '
      def local: type == "string" and startswith("local-ollama/");
      ((.provider? | type) == "object" and (.provider | has("local-ollama")))
      or ([.. | objects | (.model?, .small_model?) | select(local)] | length > 0)
    ' '
      def local: type == "string" and startswith("local-ollama/");
      (if (.provider | type) == "object" then del(.provider."local-ollama") else . end)
      | (if .provider == {} then del(.provider) else . end)
      | walk(if type == "object"
          then with_entries(select((.key == "model" or .key == "small_model") and (.value | local) | not))
          else . end)
    '

    opencode_scrub ${escapeShellArg "${config.home.homeDirectory}/.local/state/opencode/model.json"} '
      ([(.recent?, .favorite?) | arrays | .[] | select(.providerID? == "local-ollama")] | length > 0)
      or ((.variant? | type) == "object" and ([.variant | keys[] | select(startswith("local-ollama/"))] | length > 0))
    ' '
      (if (.recent | type) == "array" then .recent |= map(select(.providerID? != "local-ollama")) else . end)
      | (if (.favorite | type) == "array" then .favorite |= map(select(.providerID? != "local-ollama")) else . end)
      | (if (.variant | type) == "object" then .variant |= with_entries(select(.key | startswith("local-ollama/") | not)) else . end)
    '
  '';
}
