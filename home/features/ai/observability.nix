{ config, lib, pkgs, ... }:

let
  inherit (lib)
    concatMapStringsSep
    escapeShellArg
    mkEnableOption
    mkIf
    mkOption
    removePrefix
    types
    ;

  cfg = config.aiObservability;

  curl = "${pkgs.curl}/bin/curl";
  docker = "${pkgs.docker}/bin/docker";
  git = "${pkgs.git}/bin/git";
  grep = "${pkgs.gnugrep}/bin/grep";
  jq = "${pkgs.jq}/bin/jq";
  mkdir = "${pkgs.coreutils}/bin/mkdir";
  mktemp = "${pkgs.coreutils}/bin/mktemp";
  openssl = "${pkgs.openssl}/bin/openssl";
  python = "${pkgs.python3}/bin/python3";

  uiUrl = "http://127.0.0.1:${toString cfg.uiPort}";
  otlpHttpUrl = "http://127.0.0.1:${toString cfg.otlpHttpPort}";
  projectName = "openlit-ai-observability";
  sourceDir = "${cfg.stateDir}/source/openlit";
  composeFile = "${sourceDir}/docker-compose.ai-observe.yml";
  envFile = "${sourceDir}/.env";
  openlitImageTag = removePrefix "openlit-" cfg.openlitRelease;
  openlitImage = "ghcr.io/openlit/openlit:${openlitImageTag}";
  reservedPorts = [ 8787 8788 11434 11435 11436 ];
  managedPorts = [ cfg.uiPort cfg.otlpHttpPort cfg.otlpGrpcPort ];
  reservedPortsShell = concatMapStringsSep " " toString reservedPorts;
  managedPortsShell = concatMapStringsSep " " toString managedPorts;

  commonShell = ''
    release=${escapeShellArg cfg.openlitRelease}
    state_dir=${escapeShellArg cfg.stateDir}
    source_dir=${escapeShellArg sourceDir}
    compose_file=${escapeShellArg composeFile}
    env_file=${escapeShellArg envFile}
    project_name=${escapeShellArg projectName}
    ui_port=${toString cfg.uiPort}
    otlp_http_port=${toString cfg.otlpHttpPort}
    otlp_grpc_port=${toString cfg.otlpGrpcPort}
    ui_url=${escapeShellArg uiUrl}
    otlp_http_url=${escapeShellArg otlpHttpUrl}
    capture_mode=${escapeShellArg cfg.captureMode}
    openlit_image=${escapeShellArg openlitImage}

    compose_cmd() {
      ${docker} compose --project-name "$project_name" --project-directory "$source_dir" -f "$compose_file" "$@"
    }

    port_listeners() {
      local port="$1"
      if command -v lsof >/dev/null 2>&1; then
        lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null || true
      elif [ -x /usr/sbin/lsof ]; then
        /usr/sbin/lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null || true
      fi
    }

    print_hook_status() {
      local found=false
      for path in "$HOME/.codex/config.toml" "$HOME/.claude/settings.json" "$HOME/.cursor/hooks.json"; do
        if [ -f "$path" ] && ${grep} -qi openlit "$path"; then
          echo "  warning OpenLIT reference found in $path"
          found=true
        fi
      done
      if [ "$found" = false ]; then
        echo "  ok      no OpenLIT coding-agent hooks detected in Codex/Claude/Cursor configs"
      fi
    }
  '';

  ensureSourceShell = ''
        ensure_source() {
          ${mkdir} -p "$state_dir/source"
          if [ ! -d "$source_dir/.git" ]; then
            ${git} clone --depth 1 --branch "$release" https://github.com/openlit/openlit.git "$source_dir"
          else
            ${git} -C "$source_dir" fetch --depth 1 origin "refs/tags/$release:refs/tags/$release"
            ${git} -C "$source_dir" checkout --detach "$release"
          fi
        }

        write_runtime_files() {
          cat > "$env_file" <<ENV
    OPENLIT_DB_NAME=openlit
    OPENLIT_DB_USER=default
    OPENLIT_DB_PASSWORD=OPENLIT
    PORT=3000
    DOCKER_PORT=3000
    OPAMP_ENVIRONMENT=production
    OPAMP_TLS_INSECURE_SKIP_VERIFY=false
    OPAMP_TLS_REQUIRE_CLIENT_CERT=true
    OPAMP_TLS_MIN_VERSION=1.2
    OPAMP_TLS_MAX_VERSION=1.3
    OPAMP_LOG_LEVEL=info
    ENV

          ${python} - "$source_dir/docker-compose.yml" "$compose_file" "$openlit_image" "$ui_port" "$otlp_grpc_port" "$otlp_http_port" <<'PY'
    import pathlib
    import sys

    source, target, image, ui_port, grpc_port, http_port = sys.argv[1:]
    content = pathlib.Path(source).read_text()
    content = content.replace("ghcr.io/openlit/openlit:latest", image)
    content = content.replace('"''${PORT:-3000}:''${DOCKER_PORT:-3000}"', f'"127.0.0.1:{ui_port}:3000"')
    content = content.replace('"4317:4317"', f'"127.0.0.1:{grpc_port}:4317"')
    content = content.replace('"4318:4318"', f'"127.0.0.1:{http_port}:4318"')
    required = [
        image,
        f'"127.0.0.1:{ui_port}:3000"',
        f'"127.0.0.1:{grpc_port}:4317"',
        f'"127.0.0.1:{http_port}:4318"',
    ]
    missing = [item for item in required if item not in content]
    if missing:
        raise SystemExit(f"failed to patch OpenLIT compose file; missing expected values: {missing}")
    pathlib.Path(target).write_text(content)
    PY
        }
  '';
in
{
  options.aiObservability = {
    enable = mkEnableOption "explicit local OpenLIT AI observability helpers" // {
      default = true;
    };

    backend = mkOption {
      type = types.enum [ "openlit" ];
      default = "openlit";
      description = "AI observability backend managed by the helper command surface.";
    };

    openlitRelease = mkOption {
      type = types.str;
      default = "openlit-1.23.0";
      description = "OpenLIT GitHub release tag used by ai-observe-up.";
    };

    uiPort = mkOption {
      type = types.port;
      default = 3010;
      description = "Loopback host port for the OpenLIT UI.";
    };

    otlpHttpPort = mkOption {
      type = types.port;
      default = 4318;
      description = "Loopback host port for the OpenLIT OTLP HTTP receiver.";
    };

    otlpGrpcPort = mkOption {
      type = types.port;
      default = 4317;
      description = "Loopback host port for the OpenLIT OTLP gRPC receiver.";
    };

    stateDir = mkOption {
      type = types.str;
      default = "${config.xdg.stateHome}/ai-observability/openlit";
      description = "Repo-independent local state directory for OpenLIT source, compose files, and runtime state.";
    };

    captureMode = mkOption {
      type = types.enum [ "metadata-only" "sampled-content" "full-content" ];
      default = "metadata-only";
      description = ''
        Intended capture mode for local observability helpers. The initial
        implementation emits only structured metadata; content modes require a
        separate hook audit before use.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      (pkgs.writeShellScriptBin "ai-observe-status" ''
        set -euo pipefail
        ${commonShell}

        echo "AI observability backend: ${cfg.backend}"
        echo "OpenLIT release: $release"
        echo "OpenLIT image:   $openlit_image"
        echo "State dir:       $state_dir"
        echo "Compose file:    $compose_file"
        echo "UI:              $ui_url"
        echo "OTLP HTTP:       $otlp_http_url"
        echo "OTLP gRPC:       127.0.0.1:$otlp_grpc_port"
        echo "Capture mode:    $capture_mode"
        echo

        if [ -x ${escapeShellArg docker} ]; then
          echo "Docker client:   ok (${pkgs.docker})"
          if [ -f "$compose_file" ]; then
            echo
            echo "OpenLIT compose services:"
            compose_cmd ps 2>/dev/null || echo "  compose project not running"
          else
            echo "OpenLIT compose: not initialized; run ai-observe-up"
          fi
        else
          echo "Docker client:   missing"
        fi

        echo
        if ${curl} -fsS "$ui_url" >/dev/null 2>&1; then
          echo "UI reachability: ok"
        else
          echo "UI reachability: not reachable"
        fi

        if ${curl} -fsS "$otlp_http_url" >/dev/null 2>&1; then
          echo "OTLP HTTP:       reachable"
        else
          echo "OTLP HTTP:       not reachable or returns non-2xx without OTLP payload"
        fi

        echo
        echo "Coding-agent hooks:"
        print_hook_status
      '')

      (pkgs.writeShellScriptBin "ai-observe-doctor" ''
        set -euo pipefail
        ${commonShell}

        if [ "''${1:-}" = "--help" ] || [ "''${1:-}" = "-h" ]; then
          echo "Usage: ai-observe-doctor"
          echo "Checks local OpenLIT helper prerequisites and guardrails without starting Docker."
          exit 0
        fi

        failed=false

        echo "AI observability doctor"
        echo

        for bin in ${escapeShellArg docker} ${escapeShellArg git} ${escapeShellArg curl} ${escapeShellArg jq}; do
          if [ -x "$bin" ]; then
            echo "ok      $bin"
          else
            echo "missing $bin"
            failed=true
          fi
        done

        echo
        echo "Port guardrails:"
        for port in ${managedPortsShell}; do
          case " ${reservedPortsShell} " in
            *" $port "*)
              echo "fail    configured port $port conflicts with reserved Headroom/Ollama ports"
              failed=true
              ;;
            *)
              if listeners="$(port_listeners "$port")" && [ -n "$listeners" ]; then
                echo "warning port $port already has listener:"
                printf '%s\n' "$listeners" | sed 's/^/        /'
              else
                echo "ok      port $port has no listener"
              fi
              ;;
          esac
        done

        echo
        echo "Global environment guardrails:"
        for name in OPENAI_BASE_URL OPENAI_API_BASE ANTHROPIC_BASE_URL OTEL_EXPORTER_OTLP_ENDPOINT; do
          if [ -n "''${!name-}" ]; then
            echo "warning $name is set in this shell; ai-observe helpers do not set it globally"
          else
            echo "ok      $name unset"
          fi
        done

        echo
        echo "Coding-agent hooks:"
        print_hook_status

        echo
        if [ "$failed" = true ]; then
          echo "Doctor result: failed"
          exit 1
        fi
        echo "Doctor result: passed with any warnings shown above"
      '')

      (pkgs.writeShellScriptBin "ai-observe-up" ''
        set -euo pipefail
        ${commonShell}
        ${ensureSourceShell}

        echo "Preparing OpenLIT $release under $state_dir"
        ensure_source
        write_runtime_files
        echo "Starting OpenLIT on $ui_url with OTLP HTTP $otlp_http_url"
        compose_cmd up -d
        echo
        echo "OpenLIT UI: $ui_url"
        echo "Coding-agent hooks are not installed by this command."
      '')

      (pkgs.writeShellScriptBin "ai-observe-down" ''
        set -euo pipefail
        ${commonShell}

        if [ ! -f "$compose_file" ]; then
          echo "No OpenLIT compose file found at $compose_file"
          echo "Nothing to stop."
          exit 0
        fi

        compose_cmd down
      '')

      (pkgs.writeShellScriptBin "ai-observe-smoke" ''
        set -euo pipefail
        ${commonShell}

        if [ "$capture_mode" != "metadata-only" ]; then
          echo "Refusing smoke: capture mode '$capture_mode' is not enabled by this PoC." >&2
          echo "Hook audit must happen before sampled-content or full-content telemetry." >&2
          exit 1
        fi

        if ! ${curl} -fsS "$ui_url" >/dev/null 2>&1; then
          echo "OpenLIT UI is not reachable at $ui_url. Run ai-observe-up first." >&2
          exit 1
        fi

        git_root="$(${git} -c core.fsmonitor=false rev-parse --show-toplevel 2>/dev/null || true)"
        if [ -n "$git_root" ]; then
          config_commit="$(${git} -c core.fsmonitor=false -C "$git_root" rev-parse HEAD 2>/dev/null || echo unknown)"
          if [ -n "$(${git} -c core.fsmonitor=false -C "$git_root" status --short --untracked-files=all 2>/dev/null)" ]; then
            dirty=true
          else
            dirty=false
          fi
        else
          config_commit=unknown
          dirty=false
        fi

        if command -v headroom-status >/dev/null 2>&1; then
          headroom_enabled=true
          headroom_proxy="''${AI_OBSERVE_HEADROOM_PROXY:-shared}"
        else
          headroom_enabled=false
          headroom_proxy="none"
        fi

        if command -v rtk >/dev/null 2>&1; then
          rtk_enabled=true
        else
          rtk_enabled=false
        fi

        trace_id="$(${openssl} rand -hex 16)"
        span_id="$(${openssl} rand -hex 8)"
        start_ns="$(${python} -c 'import time; print(time.time_ns())')"
        end_ns="$(${python} -c 'import time; print(time.time_ns())')"
        payload_file="$(${mktemp})"

        ${jq} -n \
          --arg trace_id "$trace_id" \
          --arg span_id "$span_id" \
          --arg start_ns "$start_ns" \
          --arg end_ns "$end_ns" \
          --arg config_commit "$config_commit" \
          --arg mcp_profile "''${MCP_PROFILE:-unknown}" \
          --arg headroom_proxy "$headroom_proxy" \
          --arg capture_mode "$capture_mode" \
          --argjson dirty "$dirty" \
          --argjson headroom_enabled "$headroom_enabled" \
          --argjson rtk_enabled "$rtk_enabled" \
          '
          def strattr($key; $value): {key: $key, value: {stringValue: $value}};
          def boolattr($key; $value): {key: $key, value: {boolValue: $value}};
          {
            resourceSpans: [
              {
                resource: {
                  attributes: [
                    strattr("service.name"; "nix-dotfiles-ai-observability-smoke"),
                    strattr("service.version"; "1")
                  ]
                },
                scopeSpans: [
                  {
                    scope: {
                      name: "nix-dotfiles.ai-observability",
                      version: "1"
                    },
                    spans: [
                      {
                        traceId: $trace_id,
                        spanId: $span_id,
                        name: "ai.observe.smoke",
                        kind: 1,
                        startTimeUnixNano: $start_ns,
                        endTimeUnixNano: $end_ns,
                        attributes: [
                          strattr("ai.setup.agent"; "benchmark"),
                          strattr("ai.setup.config_commit"; $config_commit),
                          boolattr("ai.setup.dirty"; $dirty),
                          strattr("ai.setup.mcp_profile"; $mcp_profile),
                          boolattr("ai.setup.headroom.enabled"; $headroom_enabled),
                          strattr("ai.setup.headroom.proxy"; $headroom_proxy),
                          boolattr("ai.setup.rtk.enabled"; $rtk_enabled),
                          strattr("ai.setup.backend"; "openlit"),
                          strattr("ai.setup.workflow_kind"; "benchmark"),
                          strattr("ai.setup.capture_mode"; $capture_mode)
                        ]
                      }
                    ]
                  }
                ]
              }
            ]
          }
          ' > "$payload_file"

        ${curl} -fsS \
          -H 'Content-Type: application/json' \
          --data-binary "@$payload_file" \
          "$otlp_http_url/v1/traces" >/dev/null

        rm -f "$payload_file"
        echo "Sent metadata-only OTLP smoke trace to $otlp_http_url/v1/traces"
      '')
    ];
  };
}
