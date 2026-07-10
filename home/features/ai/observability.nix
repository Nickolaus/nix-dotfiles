{ config, lib, pkgs, flake ? null, ... }:

let
  inherit (lib)
    concatMapStringsSep
    escapeShellArg
    mkEnableOption
    mkIf
    mkOption
    optional
    removePrefix
    types
    unique
    ;

  cfg = config.aiObservability;
  system = pkgs.stdenv.hostPlatform.system;
  flakePackages = if flake == null then { } else flake.packages.${system} or { };

  bash = "${pkgs.bash}/bin/bash";
  curl = "${pkgs.curl}/bin/curl";
  docker = "${pkgs.docker}/bin/docker";
  git = "${pkgs.git}/bin/git";
  grep = "${pkgs.gnugrep}/bin/grep";
  kill = "${pkgs.coreutils}/bin/kill";
  mkdir = "${pkgs.coreutils}/bin/mkdir";
  nohup = "${pkgs.coreutils}/bin/nohup";
  python = "${pkgs.python3}/bin/python3";
  rm = "${pkgs.coreutils}/bin/rm";
  sleep = "${pkgs.coreutils}/bin/sleep";
  otelSmokePython = pkgs.python3.withPackages (pythonPackages: [
    pythonPackages.opentelemetry-sdk
    pythonPackages.opentelemetry-exporter-otlp-proto-http
  ]);
  otelSmokePythonBin = "${otelSmokePython}/bin/python3";

  phoenixUrl = "http://127.0.0.1:${toString cfg.phoenixPort}";
  phoenixLogFile = "${cfg.phoenixStateDir}/phoenix.log";
  phoenixPidFile = "${cfg.phoenixStateDir}/phoenix.pid";
  phoenixSqlDatabaseUrl = "sqlite:///${cfg.phoenixStateDir}/phoenix.db";
  phoenixPackageConfigured = cfg.phoenixPackage != null;
  phoenixPackageLabel = if phoenixPackageConfigured then cfg.phoenixPackage.name else "not configured";
  phoenixCommand = if phoenixPackageConfigured then "${cfg.phoenixPackage}/bin/${cfg.phoenixBinaryName}" else "";

  openlitUiUrl = "http://127.0.0.1:${toString cfg.openlitUiPort}";
  openlitOtlpHttpUrl = "http://127.0.0.1:${toString cfg.openlitOtlpHttpPort}";
  openlitProjectName = "openlit-ai-observability";
  openlitSourceDir = "${cfg.openlitStateDir}/source/openlit";
  openlitComposeFile = "${openlitSourceDir}/docker-compose.ai-observe.yml";
  openlitEnvFile = "${openlitSourceDir}/.env";
  openlitImageTag = removePrefix "openlit-" cfg.openlitRelease;
  openlitImage = "ghcr.io/openlit/openlit:${openlitImageTag}";

  reservedPorts = [ 8787 8788 11434 11435 11436 ];
  phoenixManagedPorts = unique [
    cfg.phoenixPort
    cfg.phoenixGrpcPort
  ];
  openlitManagedPorts = unique [
    cfg.openlitUiPort
    cfg.openlitOtlpHttpPort
    cfg.openlitOtlpGrpcPort
  ];
  reservedPortsShell = concatMapStringsSep " " toString reservedPorts;
  phoenixManagedPortsShell = concatMapStringsSep " " toString phoenixManagedPorts;
  openlitManagedPortsShell = concatMapStringsSep " " toString openlitManagedPorts;

  commonShell = ''
    backend=${escapeShellArg cfg.backend}
    capture_mode=${escapeShellArg cfg.captureMode}

    phoenix_package=${escapeShellArg phoenixPackageLabel}
    phoenix_package_configured=${if phoenixPackageConfigured then "true" else "false"}
    phoenix_command=${escapeShellArg phoenixCommand}
    phoenix_state_dir=${escapeShellArg cfg.phoenixStateDir}
    phoenix_port=${toString cfg.phoenixPort}
    phoenix_grpc_port=${toString cfg.phoenixGrpcPort}
    phoenix_url=${escapeShellArg phoenixUrl}
    phoenix_log_file=${escapeShellArg phoenixLogFile}
    phoenix_pid_file=${escapeShellArg phoenixPidFile}
    phoenix_sql_database_url=${escapeShellArg phoenixSqlDatabaseUrl}

    openlit_release=${escapeShellArg cfg.openlitRelease}
    openlit_state_dir=${escapeShellArg cfg.openlitStateDir}
    openlit_source_dir=${escapeShellArg openlitSourceDir}
    openlit_compose_file=${escapeShellArg openlitComposeFile}
    openlit_env_file=${escapeShellArg openlitEnvFile}
    openlit_project_name=${escapeShellArg openlitProjectName}
    openlit_ui_port=${toString cfg.openlitUiPort}
    openlit_otlp_http_port=${toString cfg.openlitOtlpHttpPort}
    openlit_otlp_grpc_port=${toString cfg.openlitOtlpGrpcPort}
    openlit_ui_url=${escapeShellArg openlitUiUrl}
    openlit_otlp_http_url=${escapeShellArg openlitOtlpHttpUrl}
    openlit_image=${escapeShellArg openlitImage}

    dispatch_backend_command() {
      local command_name="$1"
      shift
      case "$backend" in
        phoenix)
          exec "$script_dir/ai-observe-phoenix-$command_name" "$@"
          ;;
        openlit)
          exec "$script_dir/ai-observe-openlit-$command_name" "$@"
          ;;
      esac
    }

    openlit_compose_cmd() {
      ${docker} compose --project-name "$openlit_project_name" --project-directory "$openlit_source_dir" -f "$openlit_compose_file" "$@"
    }

    port_listeners() {
      local port="$1"
      if command -v lsof >/dev/null 2>&1; then
        lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null || true
      elif [ -x /usr/sbin/lsof ]; then
        /usr/sbin/lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null || true
      fi
    }

    wait_http_ready() {
      local url="$1"
      local pid_file="$2"
      local log_file="$3"
      local timeout_seconds="''${4:-30}"

      if ${curl} \
        --fail \
        --silent \
        --show-error \
        --output /dev/null \
        --max-time 2 \
        --retry 999 \
        --retry-delay 1 \
        --retry-max-time "$timeout_seconds" \
        --retry-connrefused \
        --retry-all-errors \
        "$url" >/dev/null 2>&1; then
        return 0
      fi

      if ! pid_running "$pid_file"; then
        echo "Process exited during startup; recent log:" >&2
        tail -n 80 "$log_file" >&2 || true
      else
        echo "Process is running but $url did not become reachable within ''${timeout_seconds}s." >&2
        echo "Inspect $log_file" >&2
      fi
      return 1
    }

    pid_running() {
      local pid_file="$1"
      if [ ! -f "$pid_file" ]; then
        return 1
      fi
      local pid
      pid="$(cat "$pid_file" 2>/dev/null || true)"
      if [ -z "$pid" ]; then
        return 1
      fi
      ${kill} -0 "$pid" >/dev/null 2>&1
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

    print_openlit_hook_audit_checklist() {
      echo "OpenLIT hook audit checklist:"
      echo "  1. Inspect exact files touched by OpenLIT installer for one vendor only."
      echo "  2. Run installer only with disposable Codex/Claude/Cursor config paths."
      echo "  3. Force OPENLIT_CODING_CONTENT_CAPTURE=metadata_only or minimal."
      echo "  4. Confirm uninstall restores or removes every installer mutation."
      echo "  5. Confirm provider credentials and private content never leave localhost."
      echo "  6. Confirm redaction/capture behavior before any sampled/full content mode."
      echo "  7. Document rollback commands before enabling hooks outside the lab."
    }

    gather_repo_context() {
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

      if command -v ai-receipt-status >/dev/null 2>&1; then
        receipts_enabled=true
      else
        receipts_enabled=false
      fi

      if command -v headroom-status >/dev/null 2>&1; then
        headroom_status_available=true
      else
        headroom_status_available=false
      fi

      if command -v rtk >/dev/null 2>&1; then
        rtk_gain_available=true
      else
        rtk_gain_available=false
      fi

      if [ -n "$git_root" ] && [ -x "$git_root/scripts/hot-benchmark.sh" ]; then
        hot_benchmark_available=true
      else
        hot_benchmark_available=false
      fi
    }

    send_smoke_trace() {
      local target_url="$1"
      local backend_name="$2"

      if [ "$capture_mode" != "metadata-only" ]; then
        echo "Refusing smoke: capture mode '$capture_mode' is not enabled by this PoC." >&2
        echo "Hook audit must happen before sampled-content or full-content telemetry." >&2
        exit 1
      fi

      gather_repo_context

      ${otelSmokePythonBin} - \
        "$target_url/v1/traces" \
        "$backend_name" \
        "$config_commit" \
        "$dirty" \
        "''${MCP_PROFILE:-unknown}" \
        "$headroom_enabled" \
        "$headroom_proxy" \
        "$rtk_enabled" \
        "$capture_mode" \
        "$receipts_enabled" \
        "$headroom_status_available" \
        "$rtk_gain_available" \
        "$hot_benchmark_available" <<'PY'
    import sys

    from opentelemetry import trace
    from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
    from opentelemetry.sdk.resources import Resource
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import SimpleSpanProcessor

    (
        endpoint,
        backend_name,
        config_commit,
        dirty,
        mcp_profile,
        headroom_enabled,
        headroom_proxy,
        rtk_enabled,
        capture_mode,
        receipts_enabled,
        headroom_status_available,
        rtk_gain_available,
        hot_benchmark_available,
    ) = sys.argv[1:]

    def as_bool(value: str) -> bool:
        return value.lower() == "true"

    provider = TracerProvider(
        resource=Resource.create(
            {
                "service.name": "nix-dotfiles-ai-observability-smoke",
                "service.version": "1",
            }
        )
    )
    provider.add_span_processor(SimpleSpanProcessor(OTLPSpanExporter(endpoint=endpoint)))
    trace.set_tracer_provider(provider)
    tracer = trace.get_tracer("nix-dotfiles.ai-observability", "1")

    with tracer.start_as_current_span("ai.observe.smoke") as span:
        span.set_attribute("ai.setup.agent", "benchmark")
        span.set_attribute("ai.setup.config_commit", config_commit)
        span.set_attribute("ai.setup.dirty", as_bool(dirty))
        span.set_attribute("ai.setup.mcp_profile", mcp_profile)
        span.set_attribute("ai.setup.headroom.enabled", as_bool(headroom_enabled))
        span.set_attribute("ai.setup.headroom.proxy", headroom_proxy)
        span.set_attribute("ai.setup.rtk.enabled", as_bool(rtk_enabled))
        span.set_attribute("ai.setup.backend", backend_name)
        span.set_attribute("ai.setup.workflow_kind", "benchmark")
        span.set_attribute("ai.setup.capture_mode", capture_mode)
        span.set_attribute("ai.signal.workflow_receipts.available", as_bool(receipts_enabled))
        span.set_attribute("ai.signal.headroom_status.available", as_bool(headroom_status_available))
        span.set_attribute("ai.signal.rtk_gain.available", as_bool(rtk_gain_available))
        span.set_attribute("ai.signal.hot_benchmark.available", as_bool(hot_benchmark_available))

    provider.shutdown()
    PY

      echo "Sent metadata-only OTLP smoke trace to $target_url/v1/traces"
    }
  '';

  ensureOpenlitSourceShell = ''
        ensure_openlit_source() {
          ${mkdir} -p "$openlit_state_dir/source"
          if [ ! -d "$openlit_source_dir/.git" ]; then
            ${git} clone --depth 1 --branch "$openlit_release" https://github.com/openlit/openlit.git "$openlit_source_dir"
          else
            ${git} -C "$openlit_source_dir" fetch --depth 1 origin "refs/tags/$openlit_release:refs/tags/$openlit_release"
            ${git} -C "$openlit_source_dir" checkout --detach "$openlit_release"
          fi
        }

        write_openlit_runtime_files() {
          cat > "$openlit_env_file" <<ENV
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

          ${python} - "$openlit_source_dir/docker-compose.yml" "$openlit_compose_file" "$openlit_image" "$openlit_ui_port" "$openlit_otlp_grpc_port" "$openlit_otlp_http_port" <<'PY'
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
    enable = mkEnableOption "explicit local AI observability helpers" // {
      default = true;
    };

    backend = mkOption {
      type = types.enum [ "phoenix" "openlit" ];
      default = "phoenix";
      description = "AI observability backend used by generic ai-observe helper commands.";
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

    phoenixPackage = mkOption {
      type = types.nullOr types.package;
      default = flakePackages.arize-phoenix or null;
      description = ''
        Nix package that provides the Phoenix server binary. Defaults to this
        repo's uv2nix-built arize-phoenix package when available. Helpers never
        fetch Phoenix from PyPI at runtime.
      '';
    };

    phoenixBinaryName = mkOption {
      type = types.str;
      default = "phoenix";
      description = "Binary name inside aiObservability.phoenixPackage used to run the Phoenix server.";
    };

    phoenixPort = mkOption {
      type = types.port;
      default = 6006;
      description = "Loopback host port for the Phoenix UI and collector.";
    };

    phoenixGrpcPort = mkOption {
      type = types.port;
      default = 4317;
      description = "Loopback host port for the Phoenix OTLP gRPC collector.";
    };

    phoenixStateDir = mkOption {
      type = types.str;
      default = "${config.xdg.stateHome}/ai-observability/phoenix";
      description = "Repo-independent local state directory for Phoenix SQLite data, pid, and logs.";
    };

    openlitRelease = mkOption {
      type = types.str;
      default = "openlit-1.23.0";
      description = "OpenLIT GitHub release tag used by ai-observe-openlit-up.";
    };

    openlitUiPort = mkOption {
      type = types.port;
      default = 3010;
      description = "Loopback host port for the OpenLIT UI.";
    };

    openlitOtlpHttpPort = mkOption {
      type = types.port;
      default = 4318;
      description = "Loopback host port for the OpenLIT OTLP HTTP receiver.";
    };

    openlitOtlpGrpcPort = mkOption {
      type = types.port;
      default = 4317;
      description = "Loopback host port for the OpenLIT OTLP gRPC receiver.";
    };

    openlitStateDir = mkOption {
      type = types.str;
      default = "${config.xdg.stateHome}/ai-observability/openlit";
      description = "Repo-independent local state directory for OpenLIT source, compose files, and runtime state.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = (optional phoenixPackageConfigured cfg.phoenixPackage) ++ [
      (pkgs.writeShellScriptBin "ai-observe-status" ''
        set -euo pipefail
        ${commonShell}
        script_dir="$(${pkgs.coreutils}/bin/dirname "$0")"

        dispatch_backend_command status "$@"
      '')

      (pkgs.writeShellScriptBin "ai-observe-doctor" ''
        set -euo pipefail
        ${commonShell}

        if [ "''${1:-}" = "--help" ] || [ "''${1:-}" = "-h" ]; then
          echo "Usage: ai-observe-doctor"
          echo "Checks local AI observability prerequisites and guardrails without starting services."
          exit 0
        fi

        failed=false

        echo "AI observability doctor"
        echo "Backend: $backend"
        echo

        required_bins="${curl} ${git} ${otelSmokePythonBin}"
        if [ "$backend" = "phoenix" ]; then
          if [ "$phoenix_package_configured" = true ]; then
            required_bins="$required_bins $phoenix_command"
          else
            echo "missing Phoenix package: set aiObservability.phoenixPackage to a Nix package that provides '${cfg.phoenixBinaryName}'"
            failed=true
          fi
        else
          required_bins="$required_bins ${docker}"
        fi

        for bin in $required_bins; do
          if [ -x "$bin" ]; then
            echo "ok      $bin"
          else
            echo "missing $bin"
            failed=true
          fi
        done

        echo
        echo "Port guardrails:"
        case "$backend" in
          phoenix)
            managed_ports="${phoenixManagedPortsShell}"
            ;;
          openlit)
            managed_ports="${openlitManagedPortsShell}"
            ;;
        esac

        for port in $managed_ports; do
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
        for name in OPENAI_BASE_URL OPENAI_API_BASE ANTHROPIC_BASE_URL OTEL_EXPORTER_OTLP_ENDPOINT PHOENIX_COLLECTOR_ENDPOINT; do
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
        script_dir="$(${pkgs.coreutils}/bin/dirname "$0")"

        dispatch_backend_command up "$@"
      '')

      (pkgs.writeShellScriptBin "ai-observe-down" ''
        set -euo pipefail
        ${commonShell}
        script_dir="$(${pkgs.coreutils}/bin/dirname "$0")"

        dispatch_backend_command down "$@"
      '')

      (pkgs.writeShellScriptBin "ai-observe-smoke" ''
        set -euo pipefail
        ${commonShell}
        script_dir="$(${pkgs.coreutils}/bin/dirname "$0")"

        dispatch_backend_command smoke "$@"
      '')

      (pkgs.writeShellScriptBin "ai-observe-phoenix-status" ''
        set -euo pipefail
        ${commonShell}

        echo "AI observability backend: phoenix"
        echo "Phoenix package: $phoenix_package"
        echo "State dir:       $phoenix_state_dir"
        echo "UI/collector:    $phoenix_url"
        echo "OTLP gRPC:       127.0.0.1:$phoenix_grpc_port"
        echo "Capture mode:    $capture_mode"
        echo "Log file:        $phoenix_log_file"
        echo

        if [ "$phoenix_package_configured" = true ] && [ -x "$phoenix_command" ]; then
          echo "Phoenix binary:  ok ($phoenix_command)"
        elif [ "$phoenix_package_configured" = true ]; then
          echo "Phoenix binary:  missing ($phoenix_command)"
        else
          echo "Phoenix binary:  not configured; set aiObservability.phoenixPackage"
        fi

        if pid_running "$phoenix_pid_file"; then
          echo "Phoenix process: running (pid $(cat "$phoenix_pid_file"))"
        else
          echo "Phoenix process: not running"
        fi

        if ${curl} -fsS "$phoenix_url" >/dev/null 2>&1; then
          echo "UI reachability: ok"
        else
          echo "UI reachability: not reachable"
        fi

        echo
        echo "Coding-agent hooks:"
        print_hook_status
      '')

      (pkgs.writeShellScriptBin "ai-observe-phoenix-up" ''
        set -euo pipefail
        ${commonShell}

        if [ "''${1:-}" = "--help" ] || [ "''${1:-}" = "-h" ]; then
          echo "Usage: ai-observe-phoenix-up"
          echo "Starts the declaratively packaged Phoenix server in the background on $phoenix_url."
          exit 0
        fi

        ${mkdir} -p "$phoenix_state_dir"

        if [ "$phoenix_package_configured" != true ] || [ ! -x "$phoenix_command" ]; then
          echo "Phoenix server package is not declaratively configured." >&2
          echo "Set aiObservability.phoenixPackage to a Nix package that provides '${cfg.phoenixBinaryName}'." >&2
          exit 1
        fi

        if pid_running "$phoenix_pid_file"; then
          echo "Phoenix already running at $phoenix_url (pid $(cat "$phoenix_pid_file"))"
          exit 0
        fi

        if listeners="$(port_listeners "$phoenix_port")" && [ -n "$listeners" ]; then
          echo "Refusing to start Phoenix: port $phoenix_port already has a listener:" >&2
          printf '%s\n' "$listeners" >&2
          exit 1
        fi

        echo "Starting Phoenix on $phoenix_url"
        echo "State dir: $phoenix_state_dir"
        echo "Log file:  $phoenix_log_file"

        ${nohup} ${bash} -c '
          set -euo pipefail
          state_dir="$1"
          sql_database_url="$2"
          port="$3"
          grpc_port="$4"
          phoenix_bin="$5"

          cd "$state_dir"
          export PHOENIX_WORKING_DIR="$state_dir"
          export PHOENIX_SQL_DATABASE_URL="$sql_database_url"
          export PHOENIX_HOST=127.0.0.1
          export PHOENIX_PORT="$port"
          export PHOENIX_GRPC_PORT="$grpc_port"
          export PHOENIX_TELEMETRY_ENABLED=false
          export OPENINFERENCE_HIDE_INPUTS=true
          export OPENINFERENCE_HIDE_OUTPUTS=true
          export OPENINFERENCE_HIDE_INPUT_MESSAGES=true
          export OPENINFERENCE_HIDE_OUTPUT_MESSAGES=true
          export OPENINFERENCE_HIDE_LLM_PROMPTS=true
          export OPENINFERENCE_HIDE_LLM_TOOLS=true
          exec "$phoenix_bin" serve
        ' ai-observe-phoenix \
          "$phoenix_state_dir" \
          "$phoenix_sql_database_url" \
          "$phoenix_port" \
          "$phoenix_grpc_port" \
          "$phoenix_command" \
          >> "$phoenix_log_file" 2>&1 &
        echo "$!" > "$phoenix_pid_file"

        if wait_http_ready "$phoenix_url" "$phoenix_pid_file" "$phoenix_log_file" 30; then
          echo "Phoenix started (pid $(cat "$phoenix_pid_file"))"
          echo "Phoenix UI: $phoenix_url"
        else
          exit 1
        fi
      '')

      (pkgs.writeShellScriptBin "ai-observe-phoenix-down" ''
        set -euo pipefail
        ${commonShell}

        if ! pid_running "$phoenix_pid_file"; then
          if [ -f "$phoenix_pid_file" ]; then
            ${rm} -f "$phoenix_pid_file"
            echo "Phoenix is not running; removed stale pid file $phoenix_pid_file"
          else
            echo "Phoenix is not running from $phoenix_pid_file"
          fi
          exit 0
        fi

        pid="$(cat "$phoenix_pid_file")"
        echo "Stopping Phoenix pid $pid"
        ${kill} "$pid"

        for _ in 1 2 3 4 5; do
          if ! ${kill} -0 "$pid" >/dev/null 2>&1; then
            ${rm} -f "$phoenix_pid_file"
            echo "Phoenix stopped"
            exit 0
          fi
          ${sleep} 1
        done

        echo "Phoenix still appears to be running; inspect pid $pid" >&2
        exit 1
      '')

      (pkgs.writeShellScriptBin "ai-observe-phoenix-smoke" ''
        set -euo pipefail
        ${commonShell}

        if ! ${curl} -fsS "$phoenix_url" >/dev/null 2>&1; then
          echo "Phoenix UI is not reachable at $phoenix_url. Run ai-observe-phoenix-up first." >&2
          exit 1
        fi

        send_smoke_trace "$phoenix_url" "phoenix"
      '')

      (pkgs.writeShellScriptBin "ai-observe-openlit-status" ''
        set -euo pipefail
        ${commonShell}

        echo "AI observability backend: openlit"
        echo "OpenLIT release: $openlit_release"
        echo "OpenLIT image:   $openlit_image"
        echo "State dir:       $openlit_state_dir"
        echo "Compose file:    $openlit_compose_file"
        echo "UI:              $openlit_ui_url"
        echo "OTLP HTTP:       $openlit_otlp_http_url"
        echo "OTLP gRPC:       127.0.0.1:$openlit_otlp_grpc_port"
        echo "Capture mode:    $capture_mode"
        echo "Runtime:         Docker Compose (explicit/manual)"
        echo

        if [ -x ${escapeShellArg docker} ]; then
          echo "Docker client:   ok (${pkgs.docker})"
          if [ -f "$openlit_compose_file" ]; then
            echo
            echo "OpenLIT compose services:"
            openlit_compose_cmd ps 2>/dev/null || echo "  compose project not running"
          else
            echo "OpenLIT compose: not initialized; run ai-observe-openlit-up"
          fi
        else
          echo "Docker client:   missing"
        fi

        echo
        if ${curl} -fsS "$openlit_ui_url" >/dev/null 2>&1; then
          echo "UI reachability: ok"
        else
          echo "UI reachability: not reachable"
        fi

        if ${curl} -fsS "$openlit_otlp_http_url" >/dev/null 2>&1; then
          echo "OTLP HTTP:       reachable"
        else
          echo "OTLP HTTP:       not reachable or returns non-2xx without OTLP payload"
        fi

        echo
        echo "Coding-agent hooks:"
        print_hook_status
      '')

      (pkgs.writeShellScriptBin "ai-observe-openlit-hook-audit" ''
        set -euo pipefail
        ${commonShell}

        print_openlit_hook_audit_checklist
        echo
        echo "This command does not install hooks or mutate agent configs."
      '')

      (pkgs.writeShellScriptBin "ai-observe-openlit-up" ''
        set -euo pipefail
        ${commonShell}
        ${ensureOpenlitSourceShell}

        echo "Preparing OpenLIT $openlit_release under $openlit_state_dir"
        ensure_openlit_source
        write_openlit_runtime_files
        echo "Starting OpenLIT on $openlit_ui_url with OTLP HTTP $openlit_otlp_http_url"
        openlit_compose_cmd up -d
        echo
        echo "OpenLIT UI: $openlit_ui_url"
        echo "Coding-agent hooks are not installed by this command."
      '')

      (pkgs.writeShellScriptBin "ai-observe-openlit-down" ''
        set -euo pipefail
        ${commonShell}

        if [ ! -f "$openlit_compose_file" ]; then
          echo "No OpenLIT compose file found at $openlit_compose_file"
          echo "Nothing to stop."
          exit 0
        fi

        openlit_compose_cmd down
      '')

      (pkgs.writeShellScriptBin "ai-observe-openlit-smoke" ''
        set -euo pipefail
        ${commonShell}

        if ! ${curl} -fsS "$openlit_ui_url" >/dev/null 2>&1; then
          echo "OpenLIT UI is not reachable at $openlit_ui_url. Run ai-observe-openlit-up first." >&2
          exit 1
        fi

        send_smoke_trace "$openlit_otlp_http_url" "openlit"
      '')
    ];
  };
}
