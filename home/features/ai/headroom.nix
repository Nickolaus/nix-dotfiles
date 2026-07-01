{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;

  proxyHost = "127.0.0.1";
  proxyPort = 8787;
  proxyUrl = "http://${proxyHost}:${toString proxyPort}";

  stateDir = "${config.home.homeDirectory}/.local/state/headroom";
  serverLog = "${stateDir}/proxy.log";
  errorLog = "${stateDir}/proxy.error.log";
  launchdPath = "/etc/profiles/per-user/${config.home.username}/bin:/usr/bin:/bin:/usr/sbin:/sbin";

  uvx = "${pkgs.uv}/bin/uvx";
  # [proxy] pulls in everything the always-on compression proxy needs (fastapi/uvicorn,
  # ONNX Kompress model, MCP server, code-graph watcher). Pinned via `--from` so every
  # invocation resolves the same extras set regardless of caller.
  headroomProxyFrom = "headroom-ai[proxy]";

  # `headroom wrap` can also auto-register its own MCP server / tokensave / Serena
  # backup into the target CLI's config. We already declare `headroom`, `serena`, and
  # `codebase-memory` MCP servers ourselves via aiAgents, and don't want a second,
  # imperative registration path mutating agent-owned files outside Nix's control — so
  # every wrap invocation below opts out of all of that and only reuses the persistent
  # proxy for compression.
  wrapSafetyFlags = [ "--no-proxy" "--no-mcp" "--no-tokensave" "--no-serena" "--no-context-tool" ];

  proxyServeScript = pkgs.writeShellScript "headroom-proxy-serve" ''
    set -euo pipefail
    exec ${uvx} --from ${lib.escapeShellArg headroomProxyFrom} headroom proxy \
      --host ${proxyHost} --port ${toString proxyPort}
  '';
in
{
  home.file.".local/state/headroom/.keep".text = "";

  # Codex's built-in "openai" provider accepts `openai_base_url` as a redirect that keeps
  # the provider's own identity (and therefore its existing auth -- ChatGPT sign-in *or* an
  # API key, whichever is already configured) intact. This is safer than a custom
  # `model_providers.*` entry, which requires `env_key` and explicitly cannot use ChatGPT
  # sign-in. See: https://developers.openai.com/codex/config-advanced
  home.file.".codex/headroom.config.toml".text = ''
    openai_base_url = "${proxyUrl}/v1"
  '';

  home.packages = [
    (pkgs.writeShellScriptBin "headroom-status" ''
      set -euo pipefail

      echo "Headroom proxy: ${proxyUrl}"
      if health=$(${pkgs.curl}/bin/curl -fsS "${proxyUrl}/health" 2>/dev/null); then
        echo "  ok      proxy is responding"
        echo "$health" | ${pkgs.jq}/bin/jq -r '"  version " + .version + "  upstream " + .checks.upstream.url'
      else
        echo "  missing proxy is not responding (see: headroom-logs)"
      fi

      echo
      echo "Always-on MCP tools (headroom_compress/retrieve/stats): registered for Codex, Claude Code, and Cursor via aiAgents."
      echo
      echo "Opt-in compressed-cloud wrappers (real Anthropic/OpenAI traffic, routed through the local proxy):"
      echo "  headroom-claude [args...]     - Claude Code through the proxy"
      echo "  headroom-codex [args...]      - Codex through the proxy (openai_base_url override, keeps ChatGPT/API auth)"
      echo "  headroom-opencode [args...]   - OpenCode through the proxy"
      echo
      echo "Cursor has no config file or env var for this -- one-time manual step:"
      echo "  Settings > Models > OpenAI API Key > Advanced > Override Base URL -> ${proxyUrl}/v1"
      echo
      echo "Note: this machine's default 'claude'/'codex' commands are unaffected — 'claude' still"
      echo "routes to the local Ollama backend (llm-claude-local/local-ai), and 'codex' still uses its"
      echo "normal auth, unless you explicitly run the headroom-* wrappers above."
      echo
      echo "Logs: ${serverLog}"
    '')

    (pkgs.writeShellScriptBin "headroom-logs" ''
      set -euo pipefail
      exec tail -n 200 -f ${serverLog}
    '')

    (pkgs.writeShellScriptBin "headroom-claude" ''
      set -euo pipefail
      if ! command -v claude >/dev/null 2>&1; then
        echo "claude command not found. Apply the profile that installs claude-code first." >&2
        exit 1
      fi
      if ! ${pkgs.curl}/bin/curl -fsS "${proxyUrl}/health" >/dev/null 2>&1; then
        echo "Headroom proxy is not responding at ${proxyUrl}." >&2
        echo "Next steps: rebuild/apply Home Manager, then check: headroom-logs" >&2
        exit 1
      fi
      exec ${uvx} --from ${lib.escapeShellArg headroomProxyFrom} headroom wrap claude \
        ${lib.concatStringsSep " " wrapSafetyFlags} -- "$@"
    '')

    (pkgs.writeShellScriptBin "headroom-codex" ''
      set -euo pipefail
      if ! command -v codex >/dev/null 2>&1; then
        echo "codex command not found. Apply the profile that installs codex first." >&2
        exit 1
      fi
      if ! ${pkgs.curl}/bin/curl -fsS "${proxyUrl}/health" >/dev/null 2>&1; then
        echo "Headroom proxy is not responding at ${proxyUrl}." >&2
        echo "Next steps: rebuild/apply Home Manager, then check: headroom-logs" >&2
        exit 1
      fi
      # Declarative: ~/.codex/headroom.config.toml sets openai_base_url, which keeps
      # Codex's normal auth (ChatGPT sign-in or API key) intact -- no uvx/headroom-wrap
      # subprocess or MCP/tokensave/Serena re-registration needed for this path.
      exec codex --profile headroom "$@"
    '')

    (pkgs.writeShellScriptBin "headroom-opencode" ''
      set -euo pipefail
      if ! command -v opencode >/dev/null 2>&1; then
        echo "opencode command not found. Apply the profile that installs opencode first." >&2
        exit 1
      fi
      if ! ${pkgs.curl}/bin/curl -fsS "${proxyUrl}/health" >/dev/null 2>&1; then
        echo "Headroom proxy is not responding at ${proxyUrl}." >&2
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

  launchd.agents.headroom-proxy = mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [ "${proxyServeScript}" ];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Background";
      StandardOutPath = serverLog;
      StandardErrorPath = errorLog;
      EnvironmentVariables = {
        PATH = launchdPath;
        HOME = config.home.homeDirectory;
      };
    };
  };
}
