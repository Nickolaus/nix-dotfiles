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

  # Generic, opt-in local-coding surface for GUI apps and IDE/extensions (VS Code, Orca,
  # Continue, Cline, ...) -- CLI tools already reach this via inherited shell env, but GUI
  # apps only see the macOS *login session* environment, set once here via
  # `launchctl setenv`. Deliberately namespaced
  # (`LOCAL_CODING_*`) rather than the reserved names (ANTHROPIC_BASE_URL, OPENAI_API_KEY,
  # ...) real tools auto-detect: those reserved names have tool-specific side effects we
  # don't want session-wide (e.g. Claude Code treats ANTHROPIC_BASE_URL as "another auth
  # source" and silently disables claude.ai subscription connectors -- see
  # home/features/ai/agent-configs.nix). Any tool wants this, it opts in with one manual,
  # one-time step pointing its own Base URL / API key setting at these vars (same shape as
  # the existing Cursor step below) -- consistent single source of truth, no code change
  # needed to onboard a future tool.
  localCodingEnvVars = optionalAttrs (sharedProxyUrl != null) {
    LOCAL_CODING_ANTHROPIC_BASE_URL = sharedProxyUrl;
    LOCAL_CODING_OPENAI_BASE_URL = "${sharedProxyUrl}/v1";
    LOCAL_CODING_API_KEY = "ollama";
    LOCAL_CODING_MODEL = if aiCfg != null then aiCfg.localCoding.model else "";
  };

  setLocalCodingEnvScript = pkgs.writeShellScript "set-local-coding-env" (
    ''
      set -euo pipefail
    '' + lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "/bin/launchctl setenv ${name} ${lib.escapeShellArg value}") localCodingEnvVars
    )
  );

  # Native, baked-in local-coding provider for OpenCode -- same shape as Codex's
  # `model_providers.local_coding_ollama` (hosts/shared/codex.nix): a permanent, named
  # entry in OpenCode's own config, selectable from its `/models` picker or `--model
  # local-ollama/<id>`, no wrapper binary needed. OpenCode's custom-provider schema
  # requires every model to be listed explicitly (no wildcard "any model" support) --
  # that's what previously justified a wrap-based, live-generated config instead
  # (`headroom wrap opencode`), but the local-coding route is always exactly one pinned
  # model (`aiAgents.localCoding.model`), so a static entry needs no live generation at
  # all.
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
      echo "Default routing is ON (opt-out, not opt-in) for Codex and Vibe -- their normal"
      echo "config already points straight at one of the proxies above, no wrapper command"
      echo "needed."
      echo
      echo "OpenCode has a native 'local-ollama' provider baked into"
      echo "~/.config/opencode/opencode.json (same shape as Codex's local_coding_ollama) --"
      echo "opt-in, no wrapper needed: pick it from OpenCode's /models picker, or"
      echo "'opencode --model local-ollama/${toString localCodingModel}'."
      echo
      echo "Claude Code has no local-coding route: it has no native multi-provider config"
      echo "(unlike Codex/OpenCode), and forcing ANTHROPIC_BASE_URL globally would count as"
      echo "\"another auth source\" and silently disable claude.ai subscription connectors/"
      echo "Remote Control -- so plain 'claude' always uses your real subscription."
      echo
      echo "Cursor has no config file or env var for this -- one-time manual step:"
      echo "  Settings > Models > OpenAI API Key > Advanced > Override Base URL -> ${toString sharedProxyUrl}/v1"
      echo
      echo "Any other GUI app or IDE/extension (VS Code, Orca, Continue, Cline, ...) can opt"
      echo "in the same way, via a generic session-wide env surface (launchctl setenv, set at"
      echo "login and re-applied on every rebuild -- see LOCAL_CODING_* below) instead of a"
      echo "per-tool code change. One-time step: point that tool's own Base URL / API key"
      echo "setting at \''${env:LOCAL_CODING_ANTHROPIC_BASE_URL} (Anthropic-wire tools) or"
      echo "\''${env:LOCAL_CODING_OPENAI_BASE_URL} (OpenAI-wire tools), API key"
      echo "\''${env:LOCAL_CODING_API_KEY}, model \''${env:LOCAL_CODING_MODEL} -- exact"
      echo "placeholder syntax (\''${env:VAR}, \\\$VAR, ...) depends on the tool."
      echo "Current values:"
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: value: "      echo \"  ${name}=${value}\"") localCodingEnvVars
      )}
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
    // optionalAttrs (localCodingEnvVars != { }) {
      local-coding-env = {
        enable = true;
        config = {
          ProgramArguments = [ "${setLocalCodingEnvScript}" ];
          RunAtLoad = true;
          KeepAlive = false;
          StandardOutPath = "${stateDir}/local-coding-env.log";
          StandardErrorPath = "${stateDir}/local-coding-env.error.log";
        };
      };
    }
  );

  # `launchctl setenv` only affects the *current* login session -- RunAtLoad above covers
  # every login going forward, but a `home-manager switch`/`darwin-rebuild switch` between
  # logins wouldn't otherwise apply a first-time or changed value until next login. Run the
  # same script immediately on activation so it takes effect right away too.
  home.activation.applyLocalCodingEnv = mkIf (pkgs.stdenv.hostPlatform.isDarwin && localCodingEnvVars != { }) (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${setLocalCodingEnvScript} || true
    ''
  );

  # Merges (never fully overwrites) the `local-ollama` provider into OpenCode's own
  # ~/.config/opencode/opencode.json -- any other provider, model default, or setting the
  # user (or `opencode auth login`) has added stays untouched; only the `provider.
  # local-ollama` key is owned by Nix here, same restraint restoreCodexUserConfig and the
  # Vibe config merge (this directory) take with their respective tools' user-editable
  # config files.
  home.activation.mergeOpencodeLocalProvider = mkIf (opencodeLocalProvider != { }) (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      opencode_dir="${config.home.homeDirectory}/.config/opencode"
      opencode_config="$opencode_dir/opencode.json"
      mkdir -p "$opencode_dir"
      if [ ! -f "$opencode_config" ]; then
        echo '{"$schema":"https://opencode.ai/config.json"}' > "$opencode_config"
      fi
      if ${pkgs.jq}/bin/jq empty "$opencode_config" >/dev/null 2>&1; then
        tmp_file="$(mktemp)"
        ${pkgs.jq}/bin/jq --slurpfile provider ${opencodeLocalProviderFile} \
          '.provider = ((.provider // {}) + $provider[0])' \
          "$opencode_config" > "$tmp_file"
        mv "$tmp_file" "$opencode_config"
      else
        echo "warning: $opencode_config is not valid JSON; skipping local-ollama provider merge for OpenCode" >&2
      fi
    ''
  );
}
