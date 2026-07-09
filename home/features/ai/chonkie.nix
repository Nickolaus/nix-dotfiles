{ config, lib, osConfig ? { }, pkgs, ... }:

let
  inherit (lib)
    concatMapStringsSep
    concatStringsSep
    escapeShellArg
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.chonkie;
  aiCfg = if osConfig ? aiAgents then osConfig.aiAgents else null;

  uv = "${pkgs.uv}/bin/uv";

  extrasSuffix =
    if cfg.extras == [ ] then
      ""
    else
      "[${concatStringsSep "," cfg.extras}]";
  chonkieFrom = "${cfg.packageName}${extrasSuffix}";

  headroomProxyNames =
    if aiCfg != null then
      builtins.attrNames aiCfg.headroom.proxies
    else
      [ ];
  headroomProxyPorts = map (name: aiCfg.headroom.proxies.${name}.port) headroomProxyNames;
  headroomPortList = concatMapStringsSep " " (port: toString port) headroomProxyPorts;
  headroomPortSummary =
    if headroomProxyPorts == [ ] then
      "none"
    else
      concatMapStringsSep ", " (port: toString port) headroomProxyPorts;

  chonkieInstructions = ''

    ## Chonkie (RAG ingestion and chunking)

    Chonkie is available as explicit-use local RAG ingestion tooling, not as a default
    codebase-analysis path. Use it when the task explicitly needs document/text
    chunking, chunking strategy comparison, RAG ingestion, code-aware chunking,
    or a local chunking API.

    Default command surface:
    - `chonkie-status` reports the installed uv tool and Headroom boundary notes.
    - `chonkie-rag-smoke` runs a local recursive chunking smoke test.
    - `chonkie-serve` starts the Chonkie API on localhost by default and refuses
      ports reserved by Headroom proxies.
    - `chonkie-update` manually upgrades the uv tool install.

    Boundary rules:
    - Keep Graphify/codebase-memory for repo structure, architecture, callers,
      and impact questions.
    - Use Chonkie for content segmentation and ingestion pipelines.
    - Do not globally set `OPENAI_BASE_URL`, `OPENAI_API_BASE`, or provider
      base-url variables for Chonkie. If a Chonkie pipeline needs provider calls,
      route that pipeline explicitly in code/config.
    - Codex and Claude subscription auth must stay untouched. Chonkie local
      chunkers do not need those subscriptions; Chonkie provider-backed
      embeddings/genie features use provider API SDKs/keys, not ChatGPT or
      Claude Code subscription entitlements.
    - Prefer local `recursive`, `token`, `sentence`, `code`, or `semantic`
      chunkers first. Use OpenAI/genie/LLM-backed Chonkie features only when
      the task explicitly needs them.
    - Do not bind Chonkie API servers to Headroom ports (${headroomPortSummary}).
      Use `chonkie-serve` instead of raw `chonkie serve` for local experiments.
    - The upstream Chonkie agent skill is external-experimental here. Invoke or
      install it explicitly when needed; do not treat it as an implicit default.
  '';
in
{
  options.chonkie = {
    enable = mkEnableOption "Chonkie local RAG chunking tooling" // {
      default = true;
    };

    packageName = mkOption {
      type = types.str;
      default = "chonkie";
      description = "PyPI package name used for the uv tool install.";
    };

    extras = mkOption {
      type = types.listOf types.str;
      default = [
        "cli"
        "semantic"
        "code"
        "api"
        "viz"
      ];
      description = ''
        Chonkie extras installed into the global uv tool environment. The
        default keeps the CLI useful for recursive/semantic/code chunking and
        local API experiments. The `viz` extra is included because the current
        CLI imports the Visualizer for chunk output. Provider SDKs, vector DB
        clients, torch, and the upstream `all` bundle stay excluded.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.file.".codex/AGENTS.md".text = chonkieInstructions;
    home.file.".vibe/AGENTS.md".text = chonkieInstructions;
    home.file.".claude/CLAUDE.md".text = chonkieInstructions;

    home.activation.ensureChonkieInstalled = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${uv} tool install ${escapeShellArg chonkieFrom} >/dev/null 2>&1 \
        || echo "Warning: failed to install chonkie (uv tool install ${chonkieFrom})" >&2
    '';

    home.packages = [
      (pkgs.writeShellScriptBin "chonkie-status" ''
        set -euo pipefail

        echo "Chonkie install source: ${chonkieFrom}"
        echo "Chonkie extras: ${concatStringsSep ", " cfg.extras}"
        echo

        chonkie_bin="$(${uv} tool dir --bin 2>/dev/null)/chonkie"
        if [ ! -x "$chonkie_bin" ]; then
          chonkie_bin="$(command -v chonkie 2>/dev/null || true)"
        fi

        if [ -n "$chonkie_bin" ] && [ -x "$chonkie_bin" ]; then
          echo "  ok      $chonkie_bin"
          if "$chonkie_bin" --help >/dev/null 2>&1; then
            echo "  ok      CLI help renders"
          else
            echo "  warning CLI exists but '--help' failed"
          fi
        else
          echo "  missing chonkie -- run: uv tool install ${escapeShellArg chonkieFrom}"
        fi

        echo
        echo "Local wrappers:"
        echo "  chonkie-rag-smoke   recursive chunking smoke test; no provider call"
        echo "  chonkie-serve       localhost API server wrapper with Headroom port guard"
        echo "  chonkie-update      manual uv tool upgrade"
        echo
        echo "Headroom boundary:"
        echo "  reserved proxy ports: ${headroomPortSummary}"
        echo "  no Chonkie/Headroom tuning is applied by default"
        echo "  do not set global OPENAI_BASE_URL or OPENAI_API_BASE for Chonkie"
      '')

      (pkgs.writeShellScriptBin "chonkie-rag-smoke" ''
        set -euo pipefail

        chonkie_bin="$(${uv} tool dir --bin 2>/dev/null)/chonkie"
        if [ ! -x "$chonkie_bin" ]; then
          chonkie_bin="$(command -v chonkie 2>/dev/null || true)"
        fi

        if [ -z "$chonkie_bin" ] || [ ! -x "$chonkie_bin" ]; then
          echo "chonkie not found on PATH. Run 'home-manager switch' first." >&2
          exit 1
        fi

        exec "$chonkie_bin" chunk \
          "Chonkie smoke test. Split this short local document into retrieval chunks." \
          --chunker recursive \
          --chunk-size 128
      '')

      (pkgs.writeShellScriptBin "chonkie-serve" ''
        set -euo pipefail

        chonkie_bin="$(${uv} tool dir --bin 2>/dev/null)/chonkie"
        if [ ! -x "$chonkie_bin" ]; then
          chonkie_bin="$(command -v chonkie 2>/dev/null || true)"
        fi

        if [ -z "$chonkie_bin" ] || [ ! -x "$chonkie_bin" ]; then
          echo "chonkie not found on PATH. Run 'home-manager switch' first." >&2
          exit 1
        fi

        reserved_ports="${headroomPortList}"
        has_host=0
        port=""
        previous_was_port=0

        for arg in "$@"; do
          if [ "$previous_was_port" = "1" ]; then
            port="$arg"
            previous_was_port=0
            continue
          fi

          case "$arg" in
            --host)
              has_host=1
              ;;
            --host=*)
              has_host=1
              ;;
            --port)
              previous_was_port=1
              ;;
            --port=*)
              port="''${arg#--port=}"
              ;;
          esac
        done

        if [ -n "$port" ]; then
          case " $reserved_ports " in
            *" $port "*)
              echo "Refusing to start Chonkie on Headroom-reserved port $port (${headroomPortSummary})." >&2
              exit 1
              ;;
          esac
        fi

        if [ "$has_host" = "1" ]; then
          exec "$chonkie_bin" serve "$@"
        fi

        exec "$chonkie_bin" serve --host 127.0.0.1 "$@"
      '')

      (pkgs.writeShellScriptBin "chonkie-update" ''
        set -euo pipefail

        echo "Upgrading global Chonkie uv tool install..."
        ${uv} tool install --upgrade ${escapeShellArg chonkieFrom}
        echo
        chonkie-status
      '')
    ];
  };
}
