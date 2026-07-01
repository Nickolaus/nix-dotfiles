{ config, pkgs, lib, ... }:
let
  inherit (lib) mkIf mkMerge mkOption types;
  cfg = config.localAi;

  defaultService = "default";
  codingService = "coding";
  sessionService = "session";

  defaultHostPort = "${cfg.runtime.host}:${toString cfg.runtime.port}";
  codingHostPort = "${cfg.runtime.host}:${toString cfg.runtime.codingPort}";
  sessionHostPort = "${cfg.runtime.host}:${toString cfg.runtime.sessionProxy.port}";

  defaultEndpoint = "http://${defaultHostPort}";
  codingEndpoint = "http://${codingHostPort}";
  sessionEndpoint = "http://${sessionHostPort}";

  defaultChatEndpoint = "${cfg.endpoint}/api/chat";
  codingChatEndpoint = "${cfg.codingEndpoint}/api/chat";
  sessionChatEndpoint = "${cfg.sessionEndpoint}/api/chat";

  defaultServerLog = "${config.home.homeDirectory}/.ollama/logs/server.log";
  ollamaStateDir = "${config.home.homeDirectory}/.local/state/ollama";
  codingServerLog = "${ollamaStateDir}/coding-server.log";
  codingErrorLog = "${ollamaStateDir}/coding-server.error.log";
  sessionServerLog = "${ollamaStateDir}/session-proxy.log";
  sessionErrorLog = "${ollamaStateDir}/session-proxy.error.log";
  launchdPath = "/etc/profiles/per-user/${config.home.username}/bin:/usr/bin:/bin:/usr/sbin:/sbin";

  commitModel = cfg.profiles.commit.model;
  generalModel = cfg.profiles.general.model;
  codingModel = cfg.profiles.coding.model;

  commitSize = cfg.profiles.commit.size;
  generalSize = cfg.profiles.general.size;
  codingSize = cfg.profiles.coding.size;

  commitService = cfg.profiles.commit.service;
  generalService = cfg.profiles.general.service;
  codingProfileService = cfg.profiles.coding.service;
  sessionProxyEnabled = cfg.runtime.sessionProxy.enable;
  codingRequestService = if sessionProxyEnabled then sessionService else codingService;
  activeServices = [ defaultService codingService ] ++ lib.optionals sessionProxyEnabled [ sessionService ];
  activeServicesList = lib.concatStringsSep " " activeServices;
  managedDarwinLaunchAgentLabels = [
    "org.nix-community.home.ollama"
    "org.nix-community.home.local-ai-ollama-coding"
  ] ++ lib.optionals sessionProxyEnabled [
    "org.nix-community.home.local-ai-session-proxy"
  ];
  managedDarwinLaunchAgentLabelsShell =
    lib.concatMapStringsSep " " lib.escapeShellArg managedDarwinLaunchAgentLabels;

  sessionProxyScript = pkgs.writeText "local-ai-session-proxy.py" ''
    import http.client
    import http.server
    import json
    import os
    import socketserver
    import sys
    import urllib.parse

    LISTEN_HOST = os.environ.get("SESSION_PROXY_HOST", "127.0.0.1")
    LISTEN_PORT = int(os.environ.get("SESSION_PROXY_PORT", "11436"))
    UPSTREAM_HOST = os.environ.get("SESSION_PROXY_UPSTREAM_HOST", "127.0.0.1")
    UPSTREAM_PORT = int(os.environ.get("SESSION_PROXY_UPSTREAM_PORT", "11435"))
    DEFAULT_KEEP_ALIVE = os.environ.get("SESSION_PROXY_KEEP_ALIVE", "10m")
    DEFAULT_THINK = os.environ.get("SESSION_PROXY_DEFAULT_THINK", "false").strip().lower()
    DEFAULT_REASONING_EFFORT = os.environ.get("SESSION_PROXY_DEFAULT_REASONING_EFFORT", "none")

    HOP_BY_HOP_HEADERS = {
        "connection",
        "keep-alive",
        "proxy-authenticate",
        "proxy-authorization",
        "te",
        "trailer",
        "transfer-encoding",
        "upgrade",
        "content-length",
    }

    EXACT_PATHS = {
        "/api/chat",
        "/api/generate",
        "/api/show",
        "/api/tags",
        "/api/ps",
        "/api/version",
    }

    EXACT_COMPAT_PATHS = {
        "/v1/chat/completions",
        "/v1/completions",
        "/v1/responses",
        "/v1/messages",
        "/v1/models",
    }

    PREFIX_PATHS = (
        "/v1/models/",
    )


    def path_allowed(path: str) -> bool:
        return path in EXACT_PATHS or path in EXACT_COMPAT_PATHS or any(path.startswith(prefix) for prefix in PREFIX_PATHS)


    def maybe_inject_request_defaults(path: str, body: bytes, content_type: str) -> bytes:
        if "application/json" not in content_type.lower():
            return body

        try:
            payload = json.loads(body.decode("utf-8") if body else "{}")
        except Exception:
            return body

        if not isinstance(payload, dict):
            return body

        changed = False

        if path in {"/api/chat", "/api/generate"}:
            if "keep_alive" not in payload:
                payload["keep_alive"] = DEFAULT_KEEP_ALIVE
                changed = True

            if "think" not in payload and DEFAULT_THINK in {"false", "true"}:
                payload["think"] = DEFAULT_THINK == "true"
                changed = True

        elif path == "/v1/chat/completions":
            if "reasoning_effort" not in payload:
                payload["reasoning_effort"] = DEFAULT_REASONING_EFFORT
                changed = True

        if changed:
            return json.dumps(payload, separators=(",", ":")).encode("utf-8")

        return body


    class ThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
        daemon_threads = True
        allow_reuse_address = True


    class ProxyHandler(http.server.BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"
        server_version = "LocalAISessionProxy/1.0"

        def log_message(self, fmt: str, *args) -> None:
            sys.stderr.write("%s - - [%s] %s\n" % (self.client_address[0], self.log_date_time_string(), fmt % args))

        def do_GET(self) -> None:
            self.forward()

        def do_POST(self) -> None:
            self.forward()

        def do_HEAD(self) -> None:
            self.forward(send_body=False)

        def forward(self, send_body: bool = True) -> None:
            parsed = urllib.parse.urlsplit(self.path)
            path = parsed.path
            if not path_allowed(path):
                self.send_error(404, "Unsupported path")
                return

            content_length = int(self.headers.get("Content-Length", "0") or "0")
            body = self.rfile.read(content_length) if content_length > 0 else b""
            body = maybe_inject_request_defaults(path, body, self.headers.get("Content-Type", "application/json"))

            headers = {}
            for key, value in self.headers.items():
              lower = key.lower()
              if lower in HOP_BY_HOP_HEADERS:
                  continue
              if lower == "host":
                  continue
              headers[key] = value

            headers["Host"] = f"{UPSTREAM_HOST}:{UPSTREAM_PORT}"
            headers["Connection"] = "close"

            if body:
                headers["Content-Length"] = str(len(body))

            conn = http.client.HTTPConnection(UPSTREAM_HOST, UPSTREAM_PORT, timeout=3600)
            try:
                conn.request(self.command, self.path, body=body if body else None, headers=headers)
                response = conn.getresponse()

                self.send_response(response.status, response.reason)

                for key, value in response.getheaders():
                    lower = key.lower()
                    if lower in HOP_BY_HOP_HEADERS:
                        continue
                    self.send_header(key, value)

                self.send_header("Connection", "close")
                if send_body:
                    self.send_header("Transfer-Encoding", "chunked")
                self.end_headers()

                if send_body:
                    while True:
                        chunk = response.read(65536)
                        if not chunk:
                            break
                        try:
                            self.wfile.write(f"{len(chunk):X}\r\n".encode("ascii"))
                            self.wfile.write(chunk)
                            self.wfile.write(b"\r\n")
                            self.wfile.flush()
                        except BrokenPipeError:
                            return
                    try:
                        self.wfile.write(b"0\r\n\r\n")
                        self.wfile.flush()
                    except BrokenPipeError:
                        return
            except BrokenPipeError:
                return
            except Exception as exc:
                try:
                    self.send_error(502, f"Upstream proxy error: {exc}")
                except BrokenPipeError:
                    return
            finally:
                conn.close()


    if __name__ == "__main__":
        server = ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), ProxyHandler)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
        finally:
            server.server_close()
  '';

  defaultOllamaLaunchdPackage = pkgs.symlinkJoin {
    name = "ollama-launchd-clean-env-${pkgs.ollama.version or "wrapped"}";
    paths = [
      (pkgs.writeShellScriptBin "ollama" ''
        set -euo pipefail

        if [ "''${1:-}" = "serve" ]; then
          exec /usr/bin/env -i \
            PATH=${lib.escapeShellArg launchdPath} \
            HOME=${lib.escapeShellArg config.home.homeDirectory} \
            OLLAMA_HOST=${lib.escapeShellArg defaultHostPort} \
            OLLAMA_CONTEXT_LENGTH=${lib.escapeShellArg (toString cfg.runtime.contextLength)} \
            OLLAMA_KEEP_ALIVE=${lib.escapeShellArg cfg.runtime.keepAlive} \
            OLLAMA_NUM_PARALLEL=${lib.escapeShellArg (toString cfg.runtime.numParallel)} \
            OLLAMA_MAX_LOADED_MODELS=${lib.escapeShellArg (toString cfg.runtime.maxLoadedModels)} \
            OLLAMA_MAX_QUEUE=${lib.escapeShellArg (toString cfg.runtime.maxQueue)} \
            OLLAMA_DEBUG=${lib.escapeShellArg (if cfg.runtime.debug then "1" else "0")} \
            OLLAMA_NO_CLOUD=${lib.escapeShellArg (if cfg.runtime.disableCloud then "1" else "0")} \
            ${pkgs.ollama}/bin/ollama "$@"
        fi

        exec ${pkgs.ollama}/bin/ollama "$@"
      '')
    ];
    meta.mainProgram = "ollama";
  };

  codingOllamaLaunchdServe = pkgs.writeShellScript "local-ai-ollama-coding-serve" ''
    set -euo pipefail

    exec /usr/bin/env -i \
      PATH=${lib.escapeShellArg launchdPath} \
      HOME=${lib.escapeShellArg config.home.homeDirectory} \
      OLLAMA_HOST=${lib.escapeShellArg codingHostPort} \
      OLLAMA_CONTEXT_LENGTH=${lib.escapeShellArg (toString cfg.runtime.codingContextLength)} \
      OLLAMA_KEEP_ALIVE=${lib.escapeShellArg cfg.runtime.codingKeepAlive} \
      OLLAMA_FLASH_ATTENTION=${lib.escapeShellArg (if cfg.runtime.codingFlashAttention then "1" else "0")} \
      OLLAMA_KV_CACHE_TYPE=${lib.escapeShellArg cfg.runtime.codingKvCacheType} \
      OLLAMA_NUM_PARALLEL=${lib.escapeShellArg (toString cfg.runtime.numParallel)} \
      OLLAMA_MAX_LOADED_MODELS=${lib.escapeShellArg (toString cfg.runtime.maxLoadedModels)} \
      OLLAMA_MAX_QUEUE=${lib.escapeShellArg (toString cfg.runtime.maxQueue)} \
      OLLAMA_DEBUG=${lib.escapeShellArg (if cfg.runtime.debug then "1" else "0")} \
      OLLAMA_NO_CLOUD=${lib.escapeShellArg (if cfg.runtime.disableCloud then "1" else "0")} \
      ${pkgs.ollama}/bin/ollama serve
  '';

  sessionProxyLaunchdServe = pkgs.writeShellScript "local-ai-session-proxy-serve" ''
    set -euo pipefail

    exec /usr/bin/env -i \
      PATH=${lib.escapeShellArg launchdPath} \
      HOME=${lib.escapeShellArg config.home.homeDirectory} \
      SESSION_PROXY_HOST=${lib.escapeShellArg cfg.runtime.host} \
      SESSION_PROXY_PORT=${lib.escapeShellArg (toString cfg.runtime.sessionProxy.port)} \
      SESSION_PROXY_UPSTREAM_HOST=${lib.escapeShellArg cfg.runtime.host} \
      SESSION_PROXY_UPSTREAM_PORT=${lib.escapeShellArg (toString cfg.runtime.codingPort)} \
      SESSION_PROXY_KEEP_ALIVE=${lib.escapeShellArg cfg.runtime.codingKeepAlive} \
      SESSION_PROXY_DEFAULT_THINK=false \
      SESSION_PROXY_DEFAULT_REASONING_EFFORT=none \
      ${pkgs.python3}/bin/python3 ${sessionProxyScript}
  '';

  commonShell = ''
    set -euo pipefail

    default_service="${defaultService}"
    coding_service="${codingService}"
    session_service="${sessionService}"
    default_endpoint="${cfg.endpoint}"
    coding_endpoint="${cfg.codingEndpoint}"
    session_endpoint="${cfg.sessionEndpoint}"
    default_chat_endpoint="${defaultChatEndpoint}"
    coding_chat_endpoint="${codingChatEndpoint}"
    session_chat_endpoint="${sessionChatEndpoint}"
    default_host_port="${defaultHostPort}"
    coding_host_port="${codingHostPort}"
    default_context_length="${toString cfg.runtime.contextLength}"
    coding_context_length="${toString cfg.runtime.codingContextLength}"
    default_keep_alive="${cfg.runtime.keepAlive}"
    coding_keep_alive="${cfg.runtime.codingKeepAlive}"
    coding_flash_attention="${if cfg.runtime.codingFlashAttention then "1" else "0"}"
    coding_kv_cache_type="${cfg.runtime.codingKvCacheType}"
    session_proxy_enabled="${if sessionProxyEnabled then "1" else "0"}"
    disable_cloud="${if cfg.runtime.disableCloud then "1" else "0"}"
    default_log_path="${defaultServerLog}"
    coding_log_path="${codingServerLog}"
    session_log_path="${sessionServerLog}"
    server_json_path="${config.home.homeDirectory}/.ollama/server.json"

    profile_model() {
      case "$1" in
        commit) echo "${commitModel}" ;;
        general) echo "${generalModel}" ;;
        coding) echo "${codingModel}" ;;
        *)
          echo "Unknown profile: $1" >&2
          return 1
          ;;
      esac
    }

    profile_size() {
      case "$1" in
        commit) echo "${commitSize}" ;;
        general) echo "${generalSize}" ;;
        coding) echo "${codingSize}" ;;
        *)
          echo "unknown" >&2
          return 1
          ;;
      esac
    }

    profile_service() {
      case "$1" in
        commit) echo "${commitService}" ;;
        general) echo "${generalService}" ;;
        coding) echo "${codingProfileService}" ;;
        *)
          echo "Unknown profile: $1" >&2
          return 1
          ;;
      esac
    }

    profile_request_service() {
      case "$1" in
        commit|general) echo "$(profile_service "$1")" ;;
        coding) echo "${codingRequestService}" ;;
        *)
          echo "Unknown profile: $1" >&2
          return 1
          ;;
      esac
    }

    service_backend() {
      case "$1" in
        ${defaultService}) echo "${defaultService}" ;;
        ${codingService}|${sessionService}) echo "${codingService}" ;;
        *)
          echo "Unknown service: $1" >&2
          return 1
          ;;
      esac
    }

    service_endpoint() {
      case "$1" in
        ${defaultService}) echo "$default_endpoint" ;;
        ${codingService}) echo "$coding_endpoint" ;;
        ${sessionService}) echo "$session_endpoint" ;;
        *)
          echo "Unknown service: $1" >&2
          return 1
          ;;
      esac
    }

    service_chat_endpoint() {
      case "$1" in
        ${defaultService}) echo "$default_chat_endpoint" ;;
        ${codingService}) echo "$coding_chat_endpoint" ;;
        ${sessionService}) echo "$session_chat_endpoint" ;;
        *)
          echo "Unknown service: $1" >&2
          return 1
          ;;
      esac
    }

    service_host_port() {
      case "$1" in
        ${defaultService}) echo "$default_host_port" ;;
        ${codingService}|${sessionService}) echo "$coding_host_port" ;;
        *)
          echo "Unknown service: $1" >&2
          return 1
          ;;
      esac
    }

    service_context_length() {
      case "$1" in
        ${defaultService}) echo "$default_context_length" ;;
        ${codingService}|${sessionService}) echo "$coding_context_length" ;;
        *)
          echo "Unknown service: $1" >&2
          return 1
          ;;
      esac
    }

    service_keep_alive() {
      case "$1" in
        ${defaultService}) echo "$default_keep_alive" ;;
        ${codingService}|${sessionService}) echo "$coding_keep_alive" ;;
        *)
          echo "Unknown service: $1" >&2
          return 1
          ;;
      esac
    }

    service_flash_attention() {
      case "$1" in
        ${defaultService}) echo "0" ;;
        ${codingService}|${sessionService}) echo "$coding_flash_attention" ;;
        *)
          echo "Unknown service: $1" >&2
          return 1
          ;;
      esac
    }

    service_kv_cache_type() {
      case "$1" in
        ${defaultService}) echo "default" ;;
        ${codingService}|${sessionService}) echo "$coding_kv_cache_type" ;;
        *)
          echo "Unknown service: $1" >&2
          return 1
          ;;
      esac
    }

    service_log_path() {
      case "$1" in
        ${defaultService}) echo "$default_log_path" ;;
        ${codingService}) echo "$coding_log_path" ;;
        ${sessionService}) echo "$session_log_path" ;;
        *)
          echo "Unknown service: $1" >&2
          return 1
          ;;
      esac
    }

    tags_json_for_service() {
      local service="$1"
      curl -fsS "$(service_endpoint "$service")/api/tags"
    }

    service_ready() {
      local service="$1"
      curl -fsS "$(service_endpoint "$service")/api/tags" >/dev/null 2>&1
    }

    model_installed_for_service() {
      local service="$1"
      local backend model
      model="$2"
      backend="$(service_backend "$service")"
      if ! service_ready "$backend"; then
        return 2
      fi

      tags_json_for_service "$backend" | ${pkgs.jq}/bin/jq -r '.models[]?.name' | grep -Fx -- "$model" >/dev/null
    }

    model_installed_for_profile() {
      local profile="$1"
      local backend model
      backend="$(profile_service "$profile")"
      model="$(profile_model "$profile")"
      model_installed_for_service "$backend" "$model"
    }

    require_service() {
      local service="$1"
      if service_ready "$service"; then
        return 0
      fi

      echo "Local AI service '$service' is not responding at $(service_endpoint "$service")."
      echo "Next steps:"
      echo "  1. Rebuild/apply your Home Manager or nix-darwin config."
      echo "  2. Check logs: llm-logs $service"
      echo "  3. Re-run: llm-status"
      exit 1
    }

    ollama_cli() {
      local service="$1"
      shift
      OLLAMA_HOST="$(service_host_port "$service")" ${pkgs.ollama}/bin/ollama "$@"
    }

    service_ps() {
      local service="$1"
      local backend
      backend="$(service_backend "$service")"
      ollama_cli "$backend" ps 2>/dev/null | sed -n '1,20p'
    }

    server_json_cloud_disabled() {
      [[ -f "$server_json_path" ]] && ${pkgs.jq}/bin/jq -e '.disable_ollama_cloud == true' "$server_json_path" >/dev/null 2>&1
    }

    render_service_block() {
      local service="$1"

      echo "  $service"
      echo "    endpoint=$(service_endpoint "$service")"
      echo "    context_length=$(service_context_length "$service")"
      echo "    keep_alive=$(service_keep_alive "$service")"
      echo "    flash_attention=$(service_flash_attention "$service")"
      echo "    kv_cache_type=$(service_kv_cache_type "$service")"
      echo "    log=$(service_log_path "$service")"

      if [[ "$service" == "${sessionService}" ]]; then
        echo "    forwards_to=$(service_endpoint "${codingService}")"
        echo "    default_think=false"
        echo "    default_reasoning_effort=none"
      fi

      if service_ready "$service"; then
        echo "    health=healthy"
        ps_output="$(service_ps "$service")"
        if [[ -n "$ps_output" ]]; then
          echo "    ollama_ps:"
          echo "$ps_output" | sed 's/^/      /'
        else
          echo "    ollama_ps: no models are currently loaded"
        fi
      else
        echo "    health=unavailable"
        return 1
      fi

      return 0
    }

    coding_ps_validation() {
      local ps_output="$1"
      local problems=0

      if [[ -z "$ps_output" ]]; then
        echo "  no loaded coding models to validate"
        return 1
      fi

      if echo "$ps_output" | grep -q "''${coding_context_length}"; then
        echo "  context_check=ok (found $coding_context_length)"
      else
        echo "  context_check=failed (expected $coding_context_length)"
        problems=$((problems + 1))
      fi

      if echo "$ps_output" | grep -Eq 'GPU|CPU/GPU'; then
        echo "  processor_check=ok ($(echo "$ps_output" | sed -n '2p' | awk '{print $(NF-2), $(NF-1)}' 2>/dev/null || true))"
      elif echo "$ps_output" | grep -q "100% CPU"; then
        echo "  processor_check=failed (model is fully on CPU)"
        problems=$((problems + 1))
      else
        echo "  processor_check=warning (could not confirm GPU participation)"
      fi

      return "$problems"
    }
  '';
in
{
  imports = [
    (lib.mkRenamedOptionModule [ "localAI" ] [ "localAi" ])
  ];

  options.localAi = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable the declarative local AI stack built around Ollama.";
    };

    endpoint = mkOption {
      type = types.str;
      default = defaultEndpoint;
      description = "Base HTTP endpoint for the default Ollama service.";
    };

    codingEndpoint = mkOption {
      type = types.str;
      default = codingEndpoint;
      description = "Base HTTP endpoint for the coding-focused Ollama service.";
    };

    sessionEndpoint = mkOption {
      type = types.str;
      default = sessionEndpoint;
      description = "Base HTTP endpoint for the session-aware coding proxy.";
    };

    runtime = {
      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Bind address for local Ollama services.";
      };

      port = mkOption {
        type = types.port;
        default = 11434;
        description = "Port for the default Ollama service.";
      };

      codingPort = mkOption {
        type = types.port;
        default = 11435;
        description = "Port for the coding-focused Ollama service.";
      };

      contextLength = mkOption {
        type = types.int;
        default = 32768;
        description = "Default Ollama context length for lightweight local usage.";
      };

      codingContextLength = mkOption {
        type = types.int;
        default = 65536;
        description = "Ollama context length for coding-agent sessions.";
      };

      keepAlive = mkOption {
        type = types.str;
        default = "10m";
        description = "Default Ollama model idle keep-alive for the lightweight local service.";
      };

      codingKeepAlive = mkOption {
        type = types.str;
        default = "10m";
        description = "Default Ollama model idle keep-alive for the coding service.";
      };

      codingFlashAttention = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Flash Attention on the coding service.";
      };

      codingKvCacheType = mkOption {
        type = types.enum [ "f16" "q8_0" "q4_0" ];
        default = "q8_0";
        description = "K/V cache quantization used by the coding service.";
      };

      numParallel = mkOption {
        type = types.int;
        default = 1;
        description = "Maximum parallel requests per loaded model.";
      };

      maxLoadedModels = mkOption {
        type = types.int;
        default = 1;
        description = "Maximum number of simultaneously loaded models.";
      };

      maxQueue = mkOption {
        type = types.int;
        default = 32;
        description = "Maximum queued Ollama requests before overload.";
      };

      debug = mkOption {
        type = types.bool;
        default = false;
        description = "Enable verbose Ollama server logging.";
      };

      disableCloud = mkOption {
        type = types.bool;
        default = true;
        description = "Disable Ollama cloud features for predictable local-only behavior.";
      };

      sessionProxy = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable the session-aware coding proxy.";
        };

        port = mkOption {
          type = types.port;
          default = 11436;
          description = "Port for the session-aware coding proxy.";
        };
      };
    };

    profiles = {
      commit = {
        model = mkOption {
          type = types.str;
          default = "tavernari/git-commit-message:latest";
          description = "Commit-generation model used by OpenCommit.";
        };

        size = mkOption {
          type = types.str;
          default = "4.4GB";
          description = "Approximate download size for the commit profile.";
        };

        service = mkOption {
          type = types.enum [ defaultService codingService ];
          default = defaultService;
          description = "Ollama backend used for the commit profile.";
        };
      };

      general = {
        model = mkOption {
          type = types.str;
          default = "qwen3:8b-q4_K_M";
          description = "General-purpose local model.";
        };

        size = mkOption {
          type = types.str;
          default = "5.2GB";
          description = "Approximate download size for the general profile.";
        };

        service = mkOption {
          type = types.enum [ defaultService codingService ];
          default = defaultService;
          description = "Ollama backend used for the general profile.";
        };
      };

      coding = {
        model = mkOption {
          type = types.str;
          default = "qwen3-coder:30b-a3b-q4_K_M";
          description = "Coding-focused local model.";
        };

        size = mkOption {
          type = types.str;
          default = "19GB";
          description = "Approximate download size for the coding profile.";
        };

        service = mkOption {
          type = types.enum [ defaultService codingService ];
          default = codingService;
          description = "Ollama backend used for the coding profile.";
        };
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = cfg.runtime.contextLength > 0;
          message = "localAi.runtime.contextLength must be positive.";
        }
        {
          assertion = cfg.runtime.codingContextLength > 0;
          message = "localAi.runtime.codingContextLength must be positive.";
        }
        {
          assertion = cfg.runtime.numParallel > 0;
          message = "localAi.runtime.numParallel must be positive.";
        }
        {
          assertion = cfg.runtime.maxLoadedModels > 0;
          message = "localAi.runtime.maxLoadedModels must be positive.";
        }
        {
          assertion = cfg.runtime.maxQueue > 0;
          message = "localAi.runtime.maxQueue must be positive.";
        }
        {
          assertion = cfg.runtime.port != cfg.runtime.codingPort;
          message = "localAi.runtime.port and localAi.runtime.codingPort must differ.";
        }
        {
          assertion = cfg.runtime.port != cfg.runtime.sessionProxy.port;
          message = "localAi.runtime.port and localAi.runtime.sessionProxy.port must differ.";
        }
        {
          assertion = cfg.runtime.codingPort != cfg.runtime.sessionProxy.port;
          message = "localAi.runtime.codingPort and localAi.runtime.sessionProxy.port must differ.";
        }
        {
          assertion = cfg.runtime.sessionProxy.enable || cfg.profiles.coding.service != defaultService;
          message = "When localAi.runtime.sessionProxy.enable is false, the coding profile must remain on the coding backend.";
        }
      ];

      services.ollama = {
        enable = true;
        package = defaultOllamaLaunchdPackage;
        host = cfg.runtime.host;
        port = cfg.runtime.port;
        environmentVariables = {
          OLLAMA_CONTEXT_LENGTH = toString cfg.runtime.contextLength;
          OLLAMA_KEEP_ALIVE = cfg.runtime.keepAlive;
          OLLAMA_NUM_PARALLEL = toString cfg.runtime.numParallel;
          OLLAMA_MAX_LOADED_MODELS = toString cfg.runtime.maxLoadedModels;
          OLLAMA_MAX_QUEUE = toString cfg.runtime.maxQueue;
          OLLAMA_DEBUG = if cfg.runtime.debug then "1" else "0";
          OLLAMA_NO_CLOUD = if cfg.runtime.disableCloud then "1" else "0";
        };
      };

      home.file.".ollama/server.json".text = builtins.toJSON {
        disable_ollama_cloud = cfg.runtime.disableCloud;
      };
      home.file.".local/state/ollama/.keep".text = "";

      # Codex CLI >= 0.134 no longer reads `[profiles.<name>]` from config.toml;
      # `--profile <name>` now layers `$CODEX_HOME/<name>.config.toml` on top of the
      # base config instead. `model_providers.local_coding_ollama` itself still lives
      # in the managed config (hosts/shared/codex.nix) since that key isn't ignored
      # there; only the profile *selector* needs to move to this per-user file.
      home.file.".codex/local-coding.config.toml".text = ''
        model = "${codingModel}"
        model_provider = "local_coding_ollama"
      '';

      home.shellAliases = {
        "ollama-health" = "llm-status";
        "ollama-setup" = "llm-pull all";
        "ollama-setup-minimal" = "llm-pull general";
        "ollama-setup-opencommit" = "llm-pull commit";
        "ollama-setup-large" = "llm-pull coding";
        "ollama-list" = "ollama list";
        "ollama-pull" = "ollama pull";
        "ollama-rm" = "ollama rm";
        "ollama-status" = "ollama ps";
        "llm-codex" = "llm-codex-local";
      };

      home.packages = with pkgs; [
        (writeShellScriptBin "llm-models" ''
          #!/usr/bin/env bash
          ${commonShell}

          echo "Declared local AI profiles"
          echo ""

          for profile in commit general coding; do
            model="$(profile_model "$profile")"
            size="$(profile_size "$profile")"
            backend="$(profile_service "$profile")"
            request_service="$(profile_request_service "$profile")"
            endpoint="$(service_endpoint "$request_service")"
            backend_endpoint="$(service_endpoint "$backend")"

            if model_installed_for_service "$backend" "$model"; then
              installed="yes"
            elif service_ready "$backend"; then
              installed="no"
            else
              installed="unknown (service unavailable)"
            fi

            printf "%-8s %-36s route=%-7s endpoint=%-22s backend=%-7s raw=%-22s size=%-6s installed=%s\n" \
              "$profile" "$model" "$request_service" "$endpoint" "$backend" "$backend_endpoint" "$size" "$installed"
          done
        '')

        (writeShellScriptBin "llm-status" ''
          #!/usr/bin/env bash
          ${commonShell}

          overall_status=0

          echo "Local AI status"
          echo "Cloud disabled: $disable_cloud"
          if server_json_cloud_disabled; then
            echo "Managed server.json: disable_ollama_cloud=true"
          else
            echo "Managed server.json: missing or not set to disable_ollama_cloud=true"
            overall_status=1
          fi
          echo ""
          llm-models
          echo ""
          echo "Services"

          for service in ${activeServicesList}; do
            if ! render_service_block "$service"; then
              overall_status=1
            fi
            echo ""
          done

          exit "$overall_status"
        '')

        (writeShellScriptBin "llm-pull" ''
          #!/usr/bin/env bash
          ${commonShell}

          if [[ $# -ne 1 ]]; then
            echo "Usage: llm-pull <commit|general|coding|all>"
            exit 1
          fi

          pull_profile() {
            local profile="$1"
            local model size backend
            model="$(profile_model "$profile")"
            size="$(profile_size "$profile")"
            backend="$(profile_service "$profile")"

            require_service "$backend"

            echo "Pulling $profile ($model) via backend '$backend' at $(service_endpoint "$backend")"
            echo "Approximate download size: $size"
            ollama_cli "$backend" pull "$model"
          }

          case "$1" in
            all)
              pull_profile commit
              pull_profile general
              pull_profile coding
              ;;
            commit|general|coding)
              pull_profile "$1"
              ;;
            *)
              echo "Unknown profile: $1"
              echo "Usage: llm-pull <commit|general|coding|all>"
              exit 1
              ;;
          esac
        '')

        (writeShellScriptBin "llm-run" ''
          #!/usr/bin/env bash
          ${commonShell}

          if [[ $# -lt 1 ]]; then
            echo "Usage: llm-run <commit|general|coding> [prompt...]"
            exit 1
          fi

          profile="$1"
          shift
          backend="$(profile_service "$profile")"
          request_service="$(profile_request_service "$profile")"
          model="$(profile_model "$profile")"

          require_service "$backend"

          if [[ "$request_service" != "$backend" ]]; then
            require_service "$request_service"
          fi

          if ! model_installed_for_service "$backend" "$model"; then
            echo "Model not installed for profile '$profile': $model"
            echo "Next step: llm-pull $profile"
            exit 1
          fi

          if [[ $# -eq 0 ]]; then
            exec env OLLAMA_HOST="$(service_host_port "$backend")" ${pkgs.ollama}/bin/ollama run "$model"
          fi

            if [[ "$request_service" == "${sessionService}" ]]; then
              prompt="$*"
              payload="$(${pkgs.jq}/bin/jq -nc --arg model "$model" --arg prompt "$prompt" '{model:$model,prompt:$prompt,stream:false}')"
              response="$(curl -fsS -H 'Content-Type: application/json' -d "$payload" "$(service_endpoint "$request_service")/api/generate")"
            echo "$response" | ${pkgs.jq}/bin/jq -r '.response // .message.content // empty'
            exit 0
          fi

          exec env OLLAMA_HOST="$(service_host_port "$backend")" ${pkgs.ollama}/bin/ollama run "$model" "$*"
        '')

        (writeShellScriptBin "llm-smoke" ''
          #!/usr/bin/env bash
          ${commonShell}

          profile="''${1:-general}"
          backend="$(profile_service "$profile")"
          request_service="$(profile_request_service "$profile")"
          model="$(profile_model "$profile")"

          require_service "$backend"
          if [[ "$request_service" != "$backend" ]]; then
            require_service "$request_service"
          fi

          if ! model_installed_for_service "$backend" "$model"; then
            echo "Model not installed for profile '$profile': $model"
            echo "Next step: llm-pull $profile"
            exit 1
          fi

          case "$profile" in
            commit)
              prompt="Summarize this change in one conventional commit title: add a local AI profile catalog"
              ;;
            general)
              prompt="Reply with exactly: local-ai-ok"
              ;;
            coding)
              prompt="Reply with exactly one Nix attribute assignment for an Ollama model name."
              ;;
            *)
              echo "Unknown profile: $profile"
              exit 1
              ;;
          esac

          echo "Running smoke test for $profile ($model) via route '$request_service'..."

          if [[ "$request_service" == "${sessionService}" ]]; then
            payload="$(${pkgs.jq}/bin/jq -nc --arg model "$model" --arg prompt "$prompt" '{model:$model,prompt:$prompt,stream:false}')"
            response="$(curl -fsS -H 'Content-Type: application/json' -d "$payload" "$(service_endpoint "$request_service")/api/generate")"
            echo "$response" | ${pkgs.jq}/bin/jq -r '.response // .message.content // empty'
            exit 0
          fi

          env OLLAMA_HOST="$(service_host_port "$backend")" ${pkgs.ollama}/bin/ollama run "$model" "$prompt"
        '')

        (writeShellScriptBin "llm-session" ''
          #!/usr/bin/env bash
          ${commonShell}

          if [[ $# -lt 2 ]]; then
            echo "Usage: llm-session <start|refresh|finish|status> <coding>"
            exit 1
          fi

          action="$1"
          profile="$2"

          if [[ "$profile" != "coding" ]]; then
            echo "Only the coding profile currently supports llm-session."
            exit 1
          fi

          model="$(profile_model coding)"

          require_service "${codingService}"

          if [[ "$session_proxy_enabled" == "1" ]]; then
            require_service "${sessionService}"
          fi

          if [[ "$action" != "status" ]] && ! model_installed_for_service "${codingService}" "$model"; then
            echo "Coding profile is not installed: $model"
            echo "Next step: llm-pull coding"
            exit 1
          fi

          preload() {
            payload="$(${pkgs.jq}/bin/jq -nc --arg model "$model" --arg keepAlive "$coding_keep_alive" '{model:$model,keep_alive:$keepAlive}')"
            curl -fsS -H 'Content-Type: application/json' -d "$payload" "${codingEndpoint}/api/generate" >/dev/null
          }

          print_status() {
            echo "Coding session status"
            echo "  backend=${codingEndpoint}"
            echo "  request_route=$(service_endpoint "${codingRequestService}")"
            if [[ "$session_proxy_enabled" == "1" ]]; then
              echo "  session_proxy=${sessionEndpoint}"
            else
              echo "  session_proxy=disabled"
            fi
            echo "  keep_alive=$coding_keep_alive"
            echo "  flash_attention=$coding_flash_attention"
            echo "  kv_cache_type=$coding_kv_cache_type"
            ps_output="$(service_ps "${codingService}")"
            if [[ -n "$ps_output" ]]; then
              echo "  ollama_ps:"
              echo "$ps_output" | sed 's/^/    /'
            else
              echo "  ollama_ps: no models are currently loaded"
            fi
          }

          case "$action" in
            start)
              preload
              print_status
              ;;
            refresh)
              preload
              print_status
              ;;
            finish)
              if model_installed_for_service "${codingService}" "$model"; then
                ollama_cli "${codingService}" stop "$model" >/dev/null 2>&1 || true
                payload="$(${pkgs.jq}/bin/jq -nc --arg model "$model" '{model:$model,keep_alive:0}')"
                curl -fsS -H 'Content-Type: application/json' -d "$payload" "${codingEndpoint}/api/generate" >/dev/null 2>&1 || true
              fi
              print_status
              ;;
            status)
              print_status
              ;;
            *)
              echo "Usage: llm-session <start|refresh|finish|status> <coding>"
              exit 1
              ;;
          esac
        '')

        (writeShellScriptBin "llm-logs" ''
          #!/usr/bin/env bash
          ${commonShell}

          show_logs() {
            local service="$1"
            local log_path
            log_path="$(service_log_path "$service")"
            echo "== $service logs: $log_path =="
            if [[ -f "$log_path" ]]; then
              tail -n 200 "$log_path"
            else
              echo "Log file not found."
            fi
            echo ""
          }

          case "''${1:-all}" in
            default|coding|session)
              show_logs "$1"
              ;;
            all)
              show_logs ${defaultService}
              show_logs ${codingService}
              if [[ "$session_proxy_enabled" == "1" ]]; then
                show_logs ${sessionService}
              fi
              ;;
            *)
              echo "Usage: llm-logs [default|coding|session]"
              exit 1
              ;;
          esac
        '')

        (writeShellScriptBin "llm-doctor" ''
          #!/usr/bin/env bash
          ${commonShell}

          problems=0
          warnings=0

          echo "Local AI doctor"
          echo ""

          if [[ "$disable_cloud" == "1" ]]; then
            echo "Cloud policy: declared disabled"
            if server_json_cloud_disabled; then
              echo "Cloud policy file: server.json confirms disable_ollama_cloud=true"
            else
              echo "Cloud policy file: server.json does not confirm disable_ollama_cloud=true"
              problems=$((problems + 1))
            fi
          else
            echo "Cloud policy: declared enabled"
          fi

          echo ""
          echo "CLI presence"
          for tool in codex claude; do
            if command -v "$tool" >/dev/null 2>&1; then
              echo "  $tool: present"
            else
              echo "  $tool: missing"
              warnings=$((warnings + 1))
            fi
          done

          echo ""
          echo "Endpoint checks"
          for service in ${activeServicesList}; do
            echo "  $service -> $(service_endpoint "$service")"
            if service_ready "$service"; then
              echo "    reachability: ok"
            else
              echo "    reachability: failed"
              problems=$((problems + 1))
            fi
          done

          echo ""
          echo "Runtime policy"
          echo "  default_keep_alive=$default_keep_alive"
          echo "  coding_keep_alive=$coding_keep_alive"
          echo "  coding_flash_attention=$coding_flash_attention"
          echo "  coding_kv_cache_type=$coding_kv_cache_type"

          echo ""
          echo "Declared profiles"
          for profile in commit general coding; do
            backend="$(profile_service "$profile")"
            request_service="$(profile_request_service "$profile")"
            model="$(profile_model "$profile")"
            endpoint="$(service_endpoint "$request_service")"
            if model_installed_for_service "$backend" "$model"; then
              status="installed"
            elif service_ready "$backend"; then
              status="missing"
              warnings=$((warnings + 1))
            else
              status="unknown (backend unavailable)"
            fi
            echo "  $profile -> $model via route $request_service at $endpoint: $status"
          done

          if [[ "$session_proxy_enabled" == "1" ]] && service_ready "${sessionService}"; then
            if curl -fsS "${sessionEndpoint}/api/version" >/dev/null 2>&1; then
              echo ""
              echo "Session proxy forwarding: ok"
            else
              echo ""
              echo "Session proxy forwarding: failed"
              problems=$((problems + 1))
            fi
          fi

          echo ""
          echo "Coding residency"
          ps_output="$(service_ps "${codingService}")"
          if [[ -n "$ps_output" ]]; then
            echo "$ps_output" | sed 's/^/  /'
            if ! coding_ps_validation "$ps_output"; then
              warnings=$((warnings + 1))
            fi
          else
            echo "  no models currently loaded"
            warnings=$((warnings + 1))
          fi

          echo ""
          echo "Summary: problems=$problems warnings=$warnings"

          if [[ "$problems" -gt 0 ]]; then
            exit 1
          fi
        '')

        (writeShellScriptBin "llm-codex-local" ''
          #!/usr/bin/env bash
          ${commonShell}

          if ! command -v codex >/dev/null 2>&1; then
            echo "Codex CLI is not available in PATH."
            echo "Next step: ensure the nix profile containing 'codex' is applied."
            exit 1
          fi

          if [[ $# -gt 0 && ( "$1" == "--help" || "$1" == "-h" || "$1" == "help" ) ]]; then
            exec codex "$@"
          fi

          require_service "${codingService}"

          if [[ "$session_proxy_enabled" == "1" ]]; then
            require_service "${sessionService}"
          fi

          if ! model_installed_for_service "${codingService}" "${codingModel}"; then
            echo "Coding profile is not installed: ${codingModel}"
            echo "Next step: llm-pull coding"
            exit 1
          fi

          # Profile selector lives at ~/.codex/local-coding.config.toml (see home.file above).
          exec codex --profile local-coding "$@"
        '')

        (writeShellScriptBin "llm-claude-local" ''
          #!/usr/bin/env bash
          ${commonShell}

          if ! command -v claude >/dev/null 2>&1; then
            echo "Claude Code is not available in PATH."
            echo "Next step: ensure the nix profile containing 'claude-code' is applied."
            exit 1
          fi

          if [[ $# -gt 0 && ( "$1" == "--help" || "$1" == "-h" || "$1" == "help" ) ]]; then
            exec claude "$@"
          fi

          require_service "${codingService}"

          if [[ "$session_proxy_enabled" == "1" ]]; then
            require_service "${sessionService}"
          fi

          if ! model_installed_for_service "${codingService}" "${codingModel}"; then
            echo "Coding profile is not installed: ${codingModel}"
            echo "Next step: llm-pull coding"
            exit 1
          fi

          # Claude Code's local route now comes from the user-level Claude config.
          exec claude "$@"
        '')
      ];
    }

    (mkIf pkgs.stdenv.hostPlatform.isDarwin {
      home.activation.stopUnmanagedOllamaDefaultPort =
        lib.hm.dag.entryBefore [ "setupLaunchAgents" ] ''
          port=${lib.escapeShellArg (toString cfg.runtime.port)}
          current_user=${lib.escapeShellArg config.home.username}
          domain="gui/$(/usr/bin/id -u "$current_user")"
          managed_default_pid="$(
            /bin/launchctl print "$domain/org.nix-community.home.ollama" 2>/dev/null \
              | /usr/bin/awk '/pid =/ { print $3; exit }'
          )"

          for pid in $(${pkgs.lsof}/bin/lsof -nP -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true); do
            if [ -z "$pid" ]; then
              continue
            fi

            if [ -n "$managed_default_pid" ] && [ "$pid" = "$managed_default_pid" ]; then
              continue
            fi

            pid_user="$(/bin/ps -p "$pid" -o user= 2>/dev/null | ${pkgs.coreutils}/bin/tr -d '[:space:]' || true)"
            if [ "$pid_user" != "$current_user" ]; then
              continue
            fi

            command_line="$(/bin/ps -p "$pid" -o command= 2>/dev/null || true)"
            case "$command_line" in
              *"/ollama serve"*|*"ollama serve"*)
                echo "Stopping unmanaged Ollama server on ${defaultHostPort} before launchd bootstrap (pid $pid)"
                /bin/kill -TERM "$pid" 2>/dev/null || true

                for _ in 1 2 3 4 5; do
                  if ! /bin/kill -0 "$pid" 2>/dev/null; then
                    break
                  fi
                  ${pkgs.coreutils}/bin/sleep 1
                done

                if /bin/kill -0 "$pid" 2>/dev/null; then
                  echo "Unmanaged Ollama server on ${defaultHostPort} did not exit after TERM; sending KILL (pid $pid)"
                  /bin/kill -KILL "$pid" 2>/dev/null || true
                fi
                ;;
            esac
          done
        '';

      home.activation.restartManagedOllamaLaunchAgents =
        lib.hm.dag.entryAfter [ "setupLaunchAgents" ] ''
          domain="gui/$(/usr/bin/id -u ${lib.escapeShellArg config.home.username})"
          launch_agents_dir=${lib.escapeShellArg "${config.home.homeDirectory}/Library/LaunchAgents"}

          for label in ${managedDarwinLaunchAgentLabelsShell}; do
            plist="$launch_agents_dir/$label.plist"

            if [ ! -f "$plist" ]; then
              echo "Skipping missing managed Ollama launch agent plist: $plist" >&2
              continue
            fi

            /bin/launchctl bootout "$domain/$label" >/dev/null 2>&1 || true

            for _ in 1 2 3 4 5; do
              if ! /bin/launchctl print "$domain/$label" >/dev/null 2>&1; then
                break
              fi
              ${pkgs.coreutils}/bin/sleep 1
            done

            bootstrapped=0
            for attempt in 1 2 3; do
              if /bin/launchctl bootstrap "$domain" "$plist"; then
                bootstrapped=1
                break
              fi

              ${pkgs.coreutils}/bin/sleep "$attempt"
            done

            if [ "$bootstrapped" != "1" ]; then
              echo "Failed to bootstrap managed Ollama launch agent: $domain/$label" >&2
              exit 1
            fi
          done
        '';

      launchd.agents = {
        local-ai-ollama-coding = {
          enable = true;
          config = {
            ProgramArguments = [ "${codingOllamaLaunchdServe}" ];
            RunAtLoad = true;
            KeepAlive = true;
            ProcessType = "Background";
            StandardOutPath = codingServerLog;
            StandardErrorPath = codingErrorLog;
            EnvironmentVariables = {
              PATH = "/etc/profiles/per-user/${config.home.username}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
              HOME = config.home.homeDirectory;
              OLLAMA_HOST = codingHostPort;
              OLLAMA_CONTEXT_LENGTH = toString cfg.runtime.codingContextLength;
              OLLAMA_KEEP_ALIVE = cfg.runtime.codingKeepAlive;
              OLLAMA_FLASH_ATTENTION = if cfg.runtime.codingFlashAttention then "1" else "0";
              OLLAMA_KV_CACHE_TYPE = cfg.runtime.codingKvCacheType;
              OLLAMA_NUM_PARALLEL = toString cfg.runtime.numParallel;
              OLLAMA_MAX_LOADED_MODELS = toString cfg.runtime.maxLoadedModels;
              OLLAMA_MAX_QUEUE = toString cfg.runtime.maxQueue;
              OLLAMA_DEBUG = if cfg.runtime.debug then "1" else "0";
              OLLAMA_NO_CLOUD = if cfg.runtime.disableCloud then "1" else "0";
            };
          };
        };

        local-ai-session-proxy = mkIf cfg.runtime.sessionProxy.enable {
          enable = true;
          config = {
            ProgramArguments = [ "${sessionProxyLaunchdServe}" ];
            RunAtLoad = true;
            KeepAlive = true;
            ProcessType = "Background";
            StandardOutPath = sessionServerLog;
            StandardErrorPath = sessionErrorLog;
            EnvironmentVariables = {
              PATH = "/etc/profiles/per-user/${config.home.username}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
              HOME = config.home.homeDirectory;
              SESSION_PROXY_HOST = cfg.runtime.host;
              SESSION_PROXY_PORT = toString cfg.runtime.sessionProxy.port;
              SESSION_PROXY_UPSTREAM_HOST = cfg.runtime.host;
              SESSION_PROXY_UPSTREAM_PORT = toString cfg.runtime.codingPort;
              SESSION_PROXY_KEEP_ALIVE = cfg.runtime.codingKeepAlive;
              SESSION_PROXY_DEFAULT_THINK = "false";
              SESSION_PROXY_DEFAULT_REASONING_EFFORT = "none";
            };
          };
        };
      };
    })
  ]);
}
