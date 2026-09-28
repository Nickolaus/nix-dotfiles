{ config, pkgs, lib, ... }:
let
  inherit (lib) mkIf mkMerge mkOption types;
  cfg = config.localAi;

  defaultHostPort = "${cfg.runtime.host}:${toString cfg.runtime.port}";
  defaultEndpoint = "http://${defaultHostPort}";

  defaultServerLog = "${config.home.homeDirectory}/.ollama/logs/server.log";
  launchdPath = "/etc/profiles/per-user/${config.home.username}/bin:/usr/bin:/bin:/usr/sbin:/sbin";

  commitModel = cfg.profiles.commit.model;
  generalModel = cfg.profiles.general.model;

  commitSize = cfg.profiles.commit.size;
  generalSize = cfg.profiles.general.size;

  managedDarwinLaunchAgentLabels = [
    "org.nix-community.home.ollama"
  ];
  managedDarwinLaunchAgentLabelsShell =
    lib.concatMapStringsSep " " lib.escapeShellArg managedDarwinLaunchAgentLabels;

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

  commonShell = ''
    set -euo pipefail

    endpoint="${cfg.endpoint}"
    host_port="${defaultHostPort}"
    context_length="${toString cfg.runtime.contextLength}"
    keep_alive="${cfg.runtime.keepAlive}"
    disable_cloud="${if cfg.runtime.disableCloud then "1" else "0"}"
    log_path="${defaultServerLog}"
    server_json_path="${config.home.homeDirectory}/.ollama/server.json"

    profile_model() {
      case "$1" in
        commit) echo "${commitModel}" ;;
        general) echo "${generalModel}" ;;
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
        *)
          echo "unknown" >&2
          return 1
          ;;
      esac
    }

    service_ready() {
      curl -fsS "$endpoint/api/tags" >/dev/null 2>&1
    }

    model_installed() {
      local model="$1"
      if ! service_ready; then
        return 2
      fi

      curl -fsS "$endpoint/api/tags" | ${pkgs.jq}/bin/jq -r '.models[]?.name' | grep -Fx -- "$model" >/dev/null
    }

    require_service() {
      if service_ready; then
        return 0
      fi

      echo "Local AI service is not responding at $endpoint."
      echo "Next steps:"
      echo "  1. Rebuild/apply your Home Manager or nix-darwin config."
      echo "  2. Check logs: llm-logs"
      echo "  3. Re-run: llm-status"
      exit 1
    }

    ollama_cli() {
      OLLAMA_HOST="$host_port" ${pkgs.ollama}/bin/ollama "$@"
    }

    server_json_cloud_disabled() {
      [[ -f "$server_json_path" ]] && ${pkgs.jq}/bin/jq -e '.disable_ollama_cloud == true' "$server_json_path" >/dev/null 2>&1
    }

    render_service_block() {
      echo "  default"
      echo "    endpoint=$endpoint"
      echo "    context_length=$context_length"
      echo "    keep_alive=$keep_alive"
      echo "    log=$log_path"

      if service_ready; then
        echo "    health=healthy"
        ps_output="$(ollama_cli ps 2>/dev/null | sed -n '1,20p')"
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

      contextLength = mkOption {
        type = types.int;
        default = 32768;
        description = "Default Ollama context length for lightweight local usage.";
      };

      keepAlive = mkOption {
        type = types.str;
        default = "10m";
        description = "Default Ollama model idle keep-alive for the lightweight local service.";
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

      home.shellAliases = {
        "ollama-health" = "llm-status";
        "ollama-setup" = "llm-pull all";
        "ollama-setup-minimal" = "llm-pull general";
        "ollama-setup-opencommit" = "llm-pull commit";
        "ollama-list" = "ollama list";
        "ollama-pull" = "ollama pull";
        "ollama-rm" = "ollama rm";
        "ollama-status" = "ollama ps";
      };

      home.packages = with pkgs; [
        (writeShellScriptBin "llm-models" ''
          #!/usr/bin/env bash
          ${commonShell}

          echo "Declared local AI profiles"
          echo ""

          for profile in commit general; do
            model="$(profile_model "$profile")"
            size="$(profile_size "$profile")"

            if model_installed "$model"; then
              installed="yes"
            elif service_ready; then
              installed="no"
            else
              installed="unknown (service unavailable)"
            fi

            printf "%-8s %-36s endpoint=%-22s size=%-6s installed=%s\n" \
              "$profile" "$model" "$endpoint" "$size" "$installed"
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

          if ! render_service_block; then
            overall_status=1
          fi
          echo ""

          exit "$overall_status"
        '')

        (writeShellScriptBin "llm-pull" ''
          #!/usr/bin/env bash
          ${commonShell}

          if [[ $# -ne 1 ]]; then
            echo "Usage: llm-pull <commit|general|all>"
            exit 1
          fi

          pull_profile() {
            local profile="$1"
            local model size
            model="$(profile_model "$profile")"
            size="$(profile_size "$profile")"

            require_service

            echo "Pulling $profile ($model) at $endpoint"
            echo "Approximate download size: $size"
            ollama_cli pull "$model"
          }

          case "$1" in
            all)
              pull_profile commit
              pull_profile general
              ;;
            commit|general)
              pull_profile "$1"
              ;;
            *)
              echo "Unknown profile: $1"
              echo "Usage: llm-pull <commit|general|all>"
              exit 1
              ;;
          esac
        '')

        (writeShellScriptBin "llm-run" ''
          #!/usr/bin/env bash
          ${commonShell}

          if [[ $# -lt 1 ]]; then
            echo "Usage: llm-run <commit|general> [prompt...]"
            exit 1
          fi

          profile="$1"
          shift
          model="$(profile_model "$profile")"

          require_service

          if ! model_installed "$model"; then
            echo "Model not installed for profile '$profile': $model"
            echo "Next step: llm-pull $profile"
            exit 1
          fi

          if [[ $# -eq 0 ]]; then
            exec env OLLAMA_HOST="$host_port" ${pkgs.ollama}/bin/ollama run "$model"
          fi

          exec env OLLAMA_HOST="$host_port" ${pkgs.ollama}/bin/ollama run "$model" "$*"
        '')

        (writeShellScriptBin "llm-smoke" ''
          #!/usr/bin/env bash
          ${commonShell}

          profile="''${1:-general}"
          model="$(profile_model "$profile")"

          require_service

          if ! model_installed "$model"; then
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
            *)
              echo "Unknown profile: $profile"
              exit 1
              ;;
          esac

          echo "Running smoke test for $profile ($model)..."

          env OLLAMA_HOST="$host_port" ${pkgs.ollama}/bin/ollama run "$model" "$prompt"
        '')

        (writeShellScriptBin "llm-logs" ''
          #!/usr/bin/env bash
          ${commonShell}

          echo "== default logs: $log_path =="
          if [[ -f "$log_path" ]]; then
            tail -n 200 "$log_path"
          else
            echo "Log file not found."
          fi
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
          echo "  default -> $endpoint"
          if service_ready; then
            echo "    reachability: ok"
          else
            echo "    reachability: failed"
            problems=$((problems + 1))
          fi

          echo ""
          echo "Runtime policy"
          echo "  keep_alive=$keep_alive"
          echo "  context_length=$context_length"

          echo ""
          echo "Declared profiles"
          for profile in commit general; do
            model="$(profile_model "$profile")"
            if model_installed "$model"; then
              status="installed"
            elif service_ready; then
              status="missing"
              warnings=$((warnings + 1))
            else
              status="unknown (service unavailable)"
            fi
            echo "  $profile -> $model at $endpoint: $status"
          done

          echo ""
          echo "Summary: problems=$problems warnings=$warnings"

          if [[ "$problems" -gt 0 ]]; then
            exit 1
          fi
        '')

      ];
    }

    (mkIf pkgs.stdenv.hostPlatform.isDarwin {
      # Guards the managed port against a stray non-Nix-managed `ollama serve`
      # binding it before launchd bootstrap.
      home.activation.stopUnmanagedOllamaPorts =
        lib.hm.dag.entryBefore [ "setupLaunchAgents" ] ''
          current_user=${lib.escapeShellArg config.home.username}
          uid="$(/usr/bin/id -u "$current_user")"

          stop_unmanaged() {
            local port="$1" label="$2" description="$3"

            # Home Manager's built-in `services.ollama` module sets
            # `LimitLoadToSessionType: Background`, which makes launchd/
            # `setupLaunchAgents` register that label under the `user/<uid>` domain rather
            # than `gui/<uid>` (confirmed via `launchctl dumpstate`); agents without that
            # key live under `gui/<uid>`. Checking both domains is harmless -- the
            # domain a given label isn't registered under just comes up empty.
            #
            # `launchctl print` exits non-zero (e.g. 113) whenever the service isn't
            # currently registered with launchd at all (not just "not running") -- under
            # Home Manager's `set -e -o pipefail` activation runner that would otherwise
            # abort this whole script (and therefore skip `setupLaunchAgents` entirely,
            # silently leaving every managed launchd agent -- Ollama, Headroom, etc. --
            # stale) before it ever gets a chance to detect/kill the unmanaged process
            # below. An absent registration just means "no known managed pid yet", which
            # the loop below already handles correctly via the `-n "$managed_pid"` check.
            managed_pid="$(
              { /bin/launchctl print "user/$uid/$label" 2>/dev/null \
                  || /bin/launchctl print "gui/$uid/$label" 2>/dev/null \
                  || true; } \
                | /usr/bin/awk '/pid =/ { print $3; exit }'
            )"

            for pid in $(${pkgs.lsof}/bin/lsof -nP -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true); do
              if [ -z "$pid" ]; then
                continue
              fi

              if [ -n "$managed_pid" ] && [ "$pid" = "$managed_pid" ]; then
                continue
              fi

              pid_user="$(/bin/ps -p "$pid" -o user= 2>/dev/null | ${pkgs.coreutils}/bin/tr -d '[:space:]' || true)"
              if [ "$pid_user" != "$current_user" ]; then
                continue
              fi

              command_line="$(/bin/ps -p "$pid" -o command= 2>/dev/null || true)"
              case "$command_line" in
                *"/ollama serve"*|*"ollama serve"*)
                  echo "Stopping unmanaged process on $description (port $port) before launchd bootstrap (pid $pid)"
                  /bin/kill -TERM "$pid" 2>/dev/null || true

                  for _ in 1 2 3 4 5; do
                    if ! /bin/kill -0 "$pid" 2>/dev/null; then
                      break
                    fi
                    ${pkgs.coreutils}/bin/sleep 1
                  done

                  if /bin/kill -0 "$pid" 2>/dev/null; then
                    echo "Unmanaged process on $description (port $port) did not exit after TERM; sending KILL (pid $pid)"
                    /bin/kill -KILL "$pid" 2>/dev/null || true
                  fi
                  ;;
              esac
            done
          }

          stop_unmanaged ${lib.escapeShellArg (toString cfg.runtime.port)} org.nix-community.home.ollama ${lib.escapeShellArg defaultHostPort}
        '';

      home.activation.restartManagedOllamaLaunchAgents =
        lib.hm.dag.entryAfter [ "setupLaunchAgents" ] ''
          uid="$(/usr/bin/id -u ${lib.escapeShellArg config.home.username})"
          launch_agents_dir=${lib.escapeShellArg "${config.home.homeDirectory}/Library/LaunchAgents"}

          for label in ${managedDarwinLaunchAgentLabelsShell}; do
            plist="$launch_agents_dir/$label.plist"

            if [ ! -f "$plist" ]; then
              echo "Skipping missing managed Ollama launch agent plist: $plist" >&2
              continue
            fi

            # Agents carrying `LimitLoadToSessionType: Background` (e.g. Home
            # Manager's built-in `services.ollama` module) get bootstrapped by
            # launchd/`setupLaunchAgents` into the `user/<uid>` domain rather than
            # `gui/<uid>`. Targeting the wrong domain here is a no-op for `bootout`
            # (nothing found) and then makes `bootstrap` collide with the
            # already-loaded label in the *other* domain, failing with
            # "Bootstrap failed: 5: Input/output error" -- confirmed via
            # `launchctl dumpstate` showing `org.nix-community.home.ollama` living
            # under `user/<uid>` while agents without `LimitLoadToSessionType`
            # live under `gui/<uid>`.
            session_type="$(/usr/libexec/PlistBuddy -c 'Print :LimitLoadToSessionType' "$plist" 2>/dev/null || true)"
            if [ "$session_type" = "Background" ]; then
              domain="user/$uid"
            else
              domain="gui/$uid"
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
              # Non-fatal: a flaky launchd bootstrap must not abort the rest of
              # Home Manager's activation. Recover with
              # `launchctl kickstart -k "$domain/$label"`.
              echo "Warning: failed to bootstrap managed launch agent $domain/$label after 3 attempts; leaving it as-is." >&2
            fi
          done
        '';
    })
  ]);
}
