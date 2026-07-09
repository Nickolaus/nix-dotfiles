{ config, lib, osConfig ? { }, pkgs, ... }:

let
  inherit (lib)
    concatStringsSep
    escapeShellArg
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.crawl4ai;
  aiCfg = if osConfig ? aiAgents then osConfig.aiAgents else null;
  aiCrawl4AI = if aiCfg != null && aiCfg ? crawl4ai then aiCfg.crawl4ai else null;

  uv = "${pkgs.uv}/bin/uv";
  curl = "${pkgs.curl}/bin/curl";
  docker = "${pkgs.docker}/bin/docker";
  openssl = "${pkgs.openssl}/bin/openssl";

  packageSpec = "${cfg.packageName}==${cfg.version}";
  imageRef = "${cfg.dockerImage}:${cfg.version}";
  serverPort = if aiCrawl4AI != null then aiCrawl4AI.port else cfg.port;
  serverUrl = if aiCrawl4AI != null then aiCrawl4AI.serverUrl else "http://127.0.0.1:${toString cfg.port}";
  mcpSseUrl = if aiCrawl4AI != null then aiCrawl4AI.mcpSseUrl else "${serverUrl}/mcp/sse";
  apiTokenEnvVar =
    if aiCrawl4AI != null then
      aiCrawl4AI.apiTokenEnvVar
    else
      cfg.apiTokenEnvVar;
  llmEnvVarsShell = concatStringsSep " " (map escapeShellArg cfg.llmEnvVars);
  findUvToolBinFunction = ''
    find_uv_tool_bin() {
      local name="$1"
      local bin="$(${uv} tool dir --bin 2>/dev/null)/$name"
      if [ ! -x "$bin" ]; then
        bin="$(command -v "$name" 2>/dev/null || true)"
      fi
      printf '%s\n' "$bin"
    }
  '';

  crawl4aiInstructions = ''

    ## Crawl4AI (web crawling and AI-ready extraction)

    Crawl4AI is available for explicit web crawling, site ingestion, dynamic-page
    Markdown extraction, screenshots/PDFs, and structured web extraction. It is
    not a default research path for normal docs/library lookups.

    Default command surface:
    - `crawl4ai-status` reports local CLI, Docker server, MCP endpoint, and profile.
    - `crawl4ai-setup-local` installs/updates Playwright browsers for the local CLI.
    - `crawl4ai-doctor-local` runs Crawl4AI diagnostics.
    - `crawl4ai-cli-smoke` verifies the local `crwl` command without crawling the web.
    - `crawl4ai-server` starts the pinned Docker API/MCP server on ${serverUrl}.
    - `crawl4ai-server-stop` stops and removes that local container.
    - `crawl4ai-mcp-schema` reads `${mcpSseUrl}` schemas through the server API.
    - `crawl4ai-update` manually upgrades the pinned uv tool install.

    Boundary rules:
    - Prefer `context7` for library/framework docs and `fetch` for one static page.
    - Prefer the `web` MCP profile for browser QA of apps you are operating.
    - Use Crawl4AI only when the task needs crawler behavior: JS-rendered page
      extraction, multi-page crawl, structured extraction, screenshots/PDFs, or
      corpus ingestion.
    - For MCP use, start the server explicitly with `crawl4ai-server`, export
      `${apiTokenEnvVar}`, then connect the opt-in `web-crawl` MCP profile.
    - Keep crawls bounded: domain allowlist in the prompt/spec, max pages/depth,
      timeouts, and no credentialed crawling unless the user explicitly asks.
    - Do not put API keys or session cookies in Nix files, prompts, receipts, or
      committed Crawl4AI config. Pass provider keys through the shell environment
      only for the server process that needs them.
    - Do not expose Crawl4AI beyond loopback without a token, TLS-terminating
      reverse proxy, and a task-specific reason.
  '';
in
{
  options.crawl4ai = {
    enable = mkEnableOption "Crawl4AI local web crawling tooling" // {
      default = false;
    };

    packageName = mkOption {
      type = types.str;
      default = "crawl4ai";
      description = "PyPI package name used for the uv tool install.";
    };

    version = mkOption {
      type = types.str;
      default = "0.9.1";
      description = "Pinned Crawl4AI version used for the uv tool and Docker image.";
    };

    dockerImage = mkOption {
      type = types.str;
      default = "unclecode/crawl4ai";
      description = "Docker image repository used by crawl4ai-server.";
    };

    containerName = mkOption {
      type = types.str;
      default = "crawl4ai";
      description = "Local Docker container name managed by crawl4ai-server.";
    };

    port = mkOption {
      type = types.port;
      default = 11235;
      description = ''
        Standalone Home Manager fallback loopback port for the local Crawl4AI
        Docker API/MCP server. When nix-darwin/NixOS supplies aiAgents, use
        aiAgents.crawl4ai.port instead so the MCP profile and helper scripts
        share one source of truth.
      '';
    };

    apiTokenEnvVar = mkOption {
      type = types.str;
      default = "CRAWL4AI_API_TOKEN";
      description = "Environment variable containing the Crawl4AI API bearer token.";
    };

    llmEnvVars = mkOption {
      type = types.listOf types.str;
      default = [
        "OPENAI_API_KEY"
        "ANTHROPIC_API_KEY"
        "DEEPSEEK_API_KEY"
        "GROQ_API_KEY"
        "TOGETHER_API_KEY"
        "MISTRAL_API_KEY"
        "GEMINI_API_KEY"
        "GEMINI_API_TOKEN"
        "LLM_PROVIDER"
        "LLM_TEMPERATURE"
        "LLM_BASE_URL"
        "OPENAI_BASE_URL"
        "ANTHROPIC_BASE_URL"
        "GROQ_BASE_URL"
      ];
      description = ''
        Provider/runtime environment variables forwarded to `crawl4ai-server`
        when present in the calling shell. Values are never evaluated by Nix.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.file.".codex/AGENTS.md".text = crawl4aiInstructions;
    home.file.".vibe/AGENTS.md".text = crawl4aiInstructions;
    home.file.".claude/CLAUDE.md".text = crawl4aiInstructions;

    home.activation.ensureCrawl4AIInstalled = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${uv} tool install ${escapeShellArg packageSpec} >/dev/null 2>&1 \
        || echo "Warning: failed to install crawl4ai (uv tool install ${packageSpec})" >&2
    '';

    home.packages = [
      (pkgs.writeShellScriptBin "crawl4ai-status" ''
        set -euo pipefail

        ${findUvToolBinFunction}

        echo "Crawl4AI package: ${packageSpec}"
        echo "Crawl4AI Docker image: ${imageRef}"
        echo "Crawl4AI server URL: ${serverUrl}"
        echo "Crawl4AI MCP SSE URL: ${mcpSseUrl}"
        echo "Crawl4AI token env: ${apiTokenEnvVar}"
        echo

        crwl_bin="$(find_uv_tool_bin crwl)"
        setup_bin="$(find_uv_tool_bin crawl4ai-setup)"
        doctor_bin="$(find_uv_tool_bin crawl4ai-doctor)"

        if [ -n "$crwl_bin" ] && [ -x "$crwl_bin" ]; then
          echo "  ok      crwl: $crwl_bin"
          if "$crwl_bin" --help >/dev/null 2>&1; then
            echo "  ok      CLI help renders"
          else
            echo "  warning CLI exists but '--help' failed"
          fi
        else
          echo "  missing crwl -- run: uv tool install ${escapeShellArg packageSpec}"
        fi

        if [ -x "$setup_bin" ]; then
          echo "  ok      setup: $setup_bin"
        fi
        if [ -x "$doctor_bin" ]; then
          echo "  ok      doctor: $doctor_bin"
        fi

        echo
        if [ -x ${escapeShellArg docker} ]; then
          if ${docker} ps --format '{{.Names}}' | ${pkgs.gnugrep}/bin/grep -qx ${escapeShellArg cfg.containerName}; then
            echo "Docker server: running (${cfg.containerName})"
          elif ${docker} ps -a --format '{{.Names}}' | ${pkgs.gnugrep}/bin/grep -qx ${escapeShellArg cfg.containerName}; then
            echo "Docker server: stopped (${cfg.containerName})"
          else
            echo "Docker server: not created"
          fi
        else
          echo "Docker server: docker client not found"
        fi

        echo
        echo "Opt-in MCP profile: web-crawl"
        echo "Start server: export ${apiTokenEnvVar}=<secret>; crawl4ai-server"
        echo "Schema:       crawl4ai-mcp-schema"
      '')

      (pkgs.writeShellScriptBin "crawl4ai-setup-local" ''
        set -euo pipefail

        ${findUvToolBinFunction}

        setup_bin="$(find_uv_tool_bin crawl4ai-setup)"

        if [ -z "$setup_bin" ] || [ ! -x "$setup_bin" ]; then
          echo "crawl4ai-setup not found. Run 'home-manager switch' first." >&2
          exit 1
        fi

        exec "$setup_bin" "$@"
      '')

      (pkgs.writeShellScriptBin "crawl4ai-doctor-local" ''
        set -euo pipefail

        ${findUvToolBinFunction}

        doctor_bin="$(find_uv_tool_bin crawl4ai-doctor)"

        if [ -z "$doctor_bin" ] || [ ! -x "$doctor_bin" ]; then
          echo "crawl4ai-doctor not found. Run 'home-manager switch' first." >&2
          exit 1
        fi

        exec "$doctor_bin" "$@"
      '')

      (pkgs.writeShellScriptBin "crawl4ai-cli-smoke" ''
        set -euo pipefail

        ${findUvToolBinFunction}

        crwl_bin="$(find_uv_tool_bin crwl)"

        if [ -z "$crwl_bin" ] || [ ! -x "$crwl_bin" ]; then
          echo "crwl not found. Run 'home-manager switch' first." >&2
          exit 1
        fi

        exec "$crwl_bin" --help
      '')

      (pkgs.writeShellScriptBin "crawl4ai-server" ''
        set -euo pipefail

        token="$(printenv ${escapeShellArg apiTokenEnvVar} 2>/dev/null || true)"
        if [ -z "$token" ]; then
          echo "Set ${apiTokenEnvVar} before starting Crawl4AI server." >&2
          echo "Example: export ${apiTokenEnvVar}=\"$(${openssl} rand -hex 32)\"" >&2
          exit 1
        fi

        if ${docker} ps --format '{{.Names}}' | ${pkgs.gnugrep}/bin/grep -qx ${escapeShellArg cfg.containerName}; then
          echo "Crawl4AI container '${cfg.containerName}' is already running."
          exit 0
        fi

        if ${docker} ps -a --format '{{.Names}}' | ${pkgs.gnugrep}/bin/grep -qx ${escapeShellArg cfg.containerName}; then
          echo "Crawl4AI container '${cfg.containerName}' already exists but is stopped." >&2
          echo "Run 'crawl4ai-server-stop' to remove it before starting with fresh env/image." >&2
          exit 1
        fi

        env_args=(--env ${escapeShellArg apiTokenEnvVar})
        for var in ${llmEnvVarsShell}; do
          if printenv "$var" >/dev/null 2>&1; then
            env_args+=(--env "$var")
          fi
        done

        exec ${docker} run -d \
          --name ${escapeShellArg cfg.containerName} \
          --pull missing \
          --publish 127.0.0.1:${toString serverPort}:11235 \
          --shm-size 1g \
          --memory 4g \
          --pids-limit 512 \
          --cap-drop ALL \
          --security-opt no-new-privileges:true \
          --read-only \
          --tmpfs /tmp \
          --tmpfs /var/lib/redis:uid=999,gid=999,mode=0700 \
          --tmpfs /var/lib/crawl4ai/outputs:uid=999,gid=999,mode=0700 \
          --tmpfs /home/appuser/.crawl4ai:uid=999,gid=999,mode=0700 \
          --tmpfs /home/appuser/.cache/url_seeder:uid=999,gid=999,mode=0700 \
          --tmpfs /home/appuser/.gunicorn:uid=999,gid=999,mode=0700 \
          "''${env_args[@]}" \
          ${escapeShellArg imageRef}
      '')

      (pkgs.writeShellScriptBin "crawl4ai-server-stop" ''
        set -euo pipefail

        if ${docker} ps --format '{{.Names}}' | ${pkgs.gnugrep}/bin/grep -qx ${escapeShellArg cfg.containerName}; then
          ${docker} stop ${escapeShellArg cfg.containerName} >/dev/null
        fi

        if ${docker} ps -a --format '{{.Names}}' | ${pkgs.gnugrep}/bin/grep -qx ${escapeShellArg cfg.containerName}; then
          ${docker} rm ${escapeShellArg cfg.containerName} >/dev/null
          echo "Removed Crawl4AI container '${cfg.containerName}'."
        else
          echo "No Crawl4AI container '${cfg.containerName}' exists."
        fi
      '')

      (pkgs.writeShellScriptBin "crawl4ai-health" ''
        set -euo pipefail
        exec ${curl} -fsS ${escapeShellArg "${serverUrl}/health"}
      '')

      (pkgs.writeShellScriptBin "crawl4ai-mcp-schema" ''
        set -euo pipefail

        token="$(printenv ${escapeShellArg apiTokenEnvVar} 2>/dev/null || true)"
        headers=()
        if [ -n "$token" ]; then
          headers=(-H "Authorization: Bearer $token")
        fi

        exec ${curl} -fsS "''${headers[@]}" ${escapeShellArg "${serverUrl}/mcp/schema"}
      '')

      (pkgs.writeShellScriptBin "crawl4ai-update" ''
        set -euo pipefail

        echo "Refreshing pinned global Crawl4AI uv tool install (${packageSpec})..."
        ${uv} tool install --upgrade ${escapeShellArg packageSpec}
        echo
        crawl4ai-status
      '')
    ];
  };
}
