{ config, pkgs, lib, ... }:
let
  llm = config.localAi;
  defaultEndpoint = llm.endpoint;
  codingEndpoint = llm.codingEndpoint;
  localApiUrl = "${defaultEndpoint}/api/chat";
  commitModel = llm.profiles.commit.model;
  generalModel = llm.profiles.general.model;
  codingModel = llm.profiles.coding.model;
  commitService = llm.profiles.commit.service;
  generalService = llm.profiles.general.service;
  codingService = llm.profiles.coding.service;
  commonShell = ''
    set -euo pipefail

    default_endpoint="${defaultEndpoint}"
    coding_endpoint="${codingEndpoint}"
    default_chat_endpoint="${defaultEndpoint}/api/chat"
    coding_chat_endpoint="${codingEndpoint}/api/chat"
    commit_model="${commitModel}"
    general_model="${generalModel}"
    coding_model="${codingModel}"
    commit_service="${commitService}"
    general_service="${generalService}"
    coding_service="${codingService}"

    current_config_value() {
      opencommit config get "$1" 2>/dev/null | sed -n "s/^.*$1=//p" | tail -1
    }

    current_provider() {
      current_config_value OCO_AI_PROVIDER
    }

    profile_model() {
      case "$1" in
        commit) echo "$commit_model" ;;
        general) echo "$general_model" ;;
        coding) echo "$coding_model" ;;
        *)
          echo "Unknown local AI profile: $1" >&2
          return 1
          ;;
      esac
    }

    profile_service() {
      case "$1" in
        commit) echo "$commit_service" ;;
        general) echo "$general_service" ;;
        coding) echo "$coding_service" ;;
        *)
          echo "Unknown local AI profile: $1" >&2
          return 1
          ;;
      esac
    }

    service_endpoint() {
      case "$1" in
        default) echo "$default_endpoint" ;;
        coding) echo "$coding_endpoint" ;;
        *)
          echo "Unknown service: $1" >&2
          return 1
          ;;
      esac
    }

    service_chat_endpoint() {
      case "$1" in
        default) echo "$default_chat_endpoint" ;;
        coding) echo "$coding_chat_endpoint" ;;
        *)
          echo "Unknown service: $1" >&2
          return 1
          ;;
      esac
    }

    endpoint_service() {
      case "$1" in
        "$default_endpoint") echo "default" ;;
        "$coding_endpoint") echo "coding" ;;
        *) echo "unmanaged" ;;
      esac
    }

    current_endpoint() {
      local api_url
      api_url="$(current_config_value OCO_API_URL)"
      if [[ -z "$api_url" ]]; then
        echo ""
      else
        echo "''${api_url%/api/chat}"
      fi
    }

    current_local_service() {
      endpoint_service "$(current_endpoint)"
    }

    service_ready() {
      local service="$1"
      curl -fsS "$(service_endpoint "$service")/api/tags" >/dev/null 2>&1
    }

    installed_model_for_service() {
      local service="$1"
      local model="$2"

      if ! service_ready "$service"; then
        return 2
      fi

      curl -fsS "$(service_endpoint "$service")/api/tags" | ${pkgs.jq}/bin/jq -r '.models[]?.name' | grep -Fx -- "$model" >/dev/null
    }

    profile_for_model() {
      case "$1" in
        "$commit_model") echo "commit" ;;
        "$general_model") echo "general" ;;
        "$coding_model") echo "coding" ;;
        *) echo "" ;;
      esac
    }
  '';
in {
  home.activation.opencommitConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_AI_PROVIDER=ollama
    $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_API_URL=${localApiUrl}
    $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_API_KEY=ollama
    $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_MODEL=${commitModel}
    $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_TOKENS_MAX_INPUT=32768
    $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_TOKENS_MAX_OUTPUT=300
    $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_DESCRIPTION=false
    $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_EMOJI=false
    $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_LANGUAGE=en
    $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_GITPUSH=false
    $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_ONE_LINE_COMMIT=true
    $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_PROMPT_MODULE=conventional-commit
  '';

  home.sessionVariables = {
    OCO_DEFAULT_MODEL = commitModel;
  };

  home.shellAliases = {
    "oco" = "opencommit";
    "oco-jira" = "oco-jira-commit";
    "oco-ticket" = "oco-jira-commit";
    "oco-feat" = "opencommit --context='feat: feature implementation'";
    "oco-fix" = "opencommit --context='fix: bug fix'";
    "oco-docs" = "opencommit --context='docs: documentation update'";
    "oco-refactor" = "opencommit --context='refactor: code refactoring'";
    "oco-test" = "opencommit --context='test: testing changes'";
    "oco-chore" = "opencommit --context='chore: maintenance task'";
    "oco-local" = "oco-provider ollama";
    "oco-cloud" = "oco-provider openai";
    "oco-claude" = "oco-provider claude";
    "oco-setup" = "oco-provider setup";
    "oco-config" = "opencommit config";
    "oco-config-get" = "opencommit config get";
    "oco-status" = "oco-config-get";
    "oco-model" = "oco-profile";
  };

  home.packages = with pkgs; [
    (writeShellScriptBin "oco-check" ''
      #!/usr/bin/env bash
      ${commonShell}

      provider="$(current_provider)"
      model="$(current_config_value OCO_MODEL)"
      api_url="$(current_config_value OCO_API_URL)"
      current_endpoint_value="$(current_endpoint)"
      current_service="$(current_local_service)"
      declared_profile="$(profile_for_model "$model")"

      echo "OpenCommit health check"
      echo ""
      echo "Provider: ''${provider:-unknown}"
      echo "Model: ''${model:-unset}"
      echo "API URL: ''${api_url:-unset}"
      if [[ -n "$current_endpoint_value" ]]; then
        echo "Endpoint: $current_endpoint_value"
      fi
      echo ""

      if [[ "$provider" == "ollama" ]] || [[ "$api_url" == "$default_chat_endpoint" ]] || [[ "$api_url" == "$coding_chat_endpoint" ]]; then
        echo "Declared local AI profiles"
        for profile in commit general coding; do
          service="$(profile_service "$profile")"
          echo "  $profile -> $(profile_model "$profile") via $service at $(service_endpoint "$service")"
        done
        echo ""

        if [[ "$current_service" == "unmanaged" ]]; then
          echo "Current endpoint is unmanaged by the declarative local AI catalog."
          echo "Next step: oco-profile commit"
          exit 1
        fi

        if service_ready "$current_service"; then
          echo "Ollama: reachable on $current_service"
          if [[ -n "$declared_profile" ]] && installed_model_for_service "$(profile_service "$declared_profile")" "$model"; then
            echo "Model availability: installed"
          elif [[ -n "$declared_profile" ]]; then
            echo "Model availability: missing"
            echo "Next step: llm-pull $declared_profile"
          elif [[ -n "$model" ]] && installed_model_for_service "$current_service" "$model"; then
            echo "Model availability: installed (unmanaged model)"
          elif [[ -n "$model" ]]; then
            echo "Model availability: missing (unmanaged model)"
            echo "Next step: ollama pull $model"
          fi
        else
          echo "Ollama: unavailable on $current_service"
          echo "Next steps:"
          echo "  1. Check the local AI service: llm-status"
          echo "  2. Inspect logs: llm-logs $current_service"
          exit 1
        fi
      elif [[ "$provider" == "openai" ]]; then
        api_key="$(current_config_value OCO_API_KEY)"
        if [[ -n "$api_key" && "$api_key" != "undefined" ]]; then
          echo "OpenAI key: configured"
        else
          echo "OpenAI key: missing"
          echo "Next step: oco-provider setup"
          exit 1
        fi
      elif [[ "$provider" == "claude" ]] || [[ "$api_url" == *"anthropic"* ]]; then
        api_key="$(current_config_value OCO_API_KEY)"
        if [[ -n "$api_key" && "$api_key" != "undefined" ]]; then
          echo "Claude key: configured"
        else
          echo "Claude key: missing"
          echo "Next step: add claude_api_key to secrets and rerun oco-claude"
          exit 1
        fi
      else
        echo "OpenCommit is not configured for a supported provider."
        echo "Next step: oco-provider ollama"
        exit 1
      fi

      echo ""
      if git rev-parse --git-dir >/dev/null 2>&1; then
        echo "Git repository: yes"
        if git diff --cached --quiet; then
          echo "Staged changes: none"
        else
          echo "Staged changes: ready"
        fi
      else
        echo "Git repository: no"
      fi
    '')

    (writeShellScriptBin "oco-profile" ''
      #!/usr/bin/env bash
      ${commonShell}

      show_status() {
        current="$(current_config_value OCO_MODEL)"
        provider="$(current_provider)"
        api_url="$(current_config_value OCO_API_URL)"

        echo "OpenCommit local model profiles"
        echo ""
        echo "Current provider: ''${provider:-unknown}"
        echo "Current model: ''${current:-unset}"
        echo "Current API URL: ''${api_url:-unset}"
        echo "Default local model: $commit_model"
        echo ""
        echo "Profiles"

        for profile in commit general coding; do
          service="$(profile_service "$profile")"
          endpoint="$(service_endpoint "$service")"
          model="$(profile_model "$profile")"
          printf "  %-7s -> %-36s service=%-7s endpoint=%s\n" "$profile" "$model" "$service" "$endpoint"

          if installed_model_for_service "$service" "$model"; then
            echo "           installed"
          elif service_ready "$service"; then
            echo "           missing (llm-pull $profile)"
          else
            echo "           unknown (service unavailable)"
          fi
        done
      }

      if [[ $# -eq 0 ]]; then
        show_status
        exit 0
      fi

      case "$1" in
        status)
          show_status
          ;;
        reset|default|commit|general|coding)
          case "$1" in
            reset|default)
              profile="commit"
              ;;
            *)
              profile="$1"
              ;;
          esac

          service="$(profile_service "$profile")"
          model="$(profile_model "$profile")"
          api_url="$(service_chat_endpoint "$service")"

          opencommit config set OCO_AI_PROVIDER=ollama
          opencommit config set OCO_API_URL="$api_url"
          opencommit config set OCO_API_KEY=ollama
          opencommit config set OCO_MODEL="$model"

          echo "OpenCommit local profile set to $profile -> $model"
          echo "Service: $service"
          echo "Endpoint: $(service_endpoint "$service")"
          if service_ready "$service" && ! installed_model_for_service "$service" "$model"; then
            echo "Model is not installed yet."
            echo "Next step: llm-pull $profile"
          fi
          ;;
        *)
          echo "Usage: oco-profile [status|default|reset|commit|general|coding]"
          exit 1
          ;;
      esac
    '')

    (writeShellScriptBin "oco-provider" ''
      #!/usr/bin/env bash
      ${commonShell}

      show_status() {
        provider="$(current_provider)"
        url="$(current_config_value OCO_API_URL)"
        model="$(current_config_value OCO_MODEL)"
        local_service="$(current_local_service)"

        echo "OpenCommit provider status"
        echo ""
        echo "Provider: ''${provider:-unknown}"
        echo "API URL: ''${url:-unset}"
        echo "Model: ''${model:-unset}"

        if [[ "$provider" == "ollama" ]] || [[ "$url" == "$default_chat_endpoint" ]] || [[ "$url" == "$coding_chat_endpoint" ]]; then
          echo "Local service: $local_service"
          if [[ "$local_service" != "unmanaged" ]] && service_ready "$local_service"; then
            echo "Ollama: reachable"
          else
            echo "Ollama: unavailable"
            echo "Next step: llm-status"
          fi
        fi
      }

      if [[ $# -eq 0 ]]; then
        show_status
        echo ""
        echo "Commands:"
        echo "  oco-provider ollama"
        echo "  oco-provider openai"
        echo "  oco-provider claude"
        echo "  oco-provider status"
        echo "  oco-provider setup"
        exit 0
      fi

      case "$1" in
        ollama)
          opencommit config set OCO_AI_PROVIDER=ollama
          opencommit config set OCO_API_URL="$default_chat_endpoint"
          opencommit config set OCO_API_KEY=ollama
          opencommit config set OCO_MODEL="$commit_model"
          echo "OpenCommit switched to Ollama."
          echo "Default local profile: commit -> $commit_model"
          echo "Endpoint: $default_endpoint"
          if ! service_ready "default"; then
            echo "Ollama is not reachable yet."
            echo "Next step: llm-status"
          fi
          ;;
        openai)
          api_key="$(current_config_value OCO_OPENAI_API_KEY)"
          if [[ -z "$api_key" || "$api_key" == "undefined" ]]; then
            if [[ -f "${config.home.homeDirectory}/.config/opencommit/openai_api_key" ]]; then
              api_key=$(tr -d '\n' < "${config.home.homeDirectory}/.config/opencommit/openai_api_key")
              if [[ -n "$api_key" && "$api_key" == sk-* ]]; then
                opencommit config set OCO_OPENAI_API_KEY="$api_key"
              fi
            fi
          fi

          if [[ -z "$api_key" || "$api_key" == "undefined" ]]; then
            echo "OpenAI API key is not configured."
            echo "Next step: oco-provider setup"
            exit 1
          fi

          opencommit config set OCO_AI_PROVIDER=openai
          opencommit config set OCO_API_URL=https://api.openai.com/v1
          opencommit config set OCO_API_KEY="$api_key"
          opencommit config set OCO_MODEL=gpt-4o-mini
          echo "OpenCommit switched to OpenAI."
          ;;
        claude)
          if [[ -f "${config.home.homeDirectory}/.config/opencommit/claude_api_key" ]]; then
            claude_key=$(tr -d '\n' < "${config.home.homeDirectory}/.config/opencommit/claude_api_key")
          else
            claude_key=""
          fi

          if [[ -z "$claude_key" || "$claude_key" != sk-ant-* ]]; then
            echo "Claude API key is not configured."
            echo "Next step: add claude_api_key to secrets and rerun oco-claude"
            exit 1
          fi

          opencommit config set OCO_AI_PROVIDER=claude
          opencommit config set OCO_API_URL=https://api.anthropic.com/v1
          opencommit config set OCO_API_KEY="$claude_key"
          opencommit config set OCO_MODEL=claude-3-5-haiku-20241022
          echo "OpenCommit switched to Claude."
          ;;
        status)
          show_status
          ;;
        setup)
          echo "OpenAI API key setup"
          echo ""
          echo "Get a key from https://platform.openai.com/account/api-keys"
          read -r -p "Enter your OpenAI API key: " api_key
          if [[ -n "$api_key" && "$api_key" == sk-* ]]; then
            opencommit config set OCO_OPENAI_API_KEY="$api_key"
            echo "Stored the OpenAI API key."
            echo "Next step: oco-provider openai"
          else
            echo "Invalid OpenAI key format."
            exit 1
          fi
          ;;
        *)
          echo "Unknown command: $1"
          echo "Run: oco-provider"
          exit 1
          ;;
      esac
    '')

    (writeShellScriptBin "oco-jira-commit" ''
      #!/usr/bin/env bash
      ${commonShell}

      branch=$(git rev-parse --abbrev-ref HEAD)
      jira_ticket=$(echo "$branch" | grep -oE '[A-Z]+-[0-9]+' | head -1 || true)

      if [[ -z "$jira_ticket" ]]; then
        echo "No Jira ticket found in branch name: $branch"
        echo "Expected something like PROJ-123 in the branch name."
        exit 1
      fi

      provider="$(current_provider)"
      local_service="$(current_local_service)"
      if [[ "$provider" == "ollama" ]] && [[ "$local_service" != "unmanaged" ]] && ! service_ready "$local_service"; then
        echo "OpenCommit is configured for Ollama but the local service is unavailable."
        echo "Next step: llm-status"
        exit 1
      fi

      opencommit "$jira_ticket - \$msg"
    '')

    (writeShellScriptBin "opencommit-setup" ''
      #!/usr/bin/env bash
      ${commonShell}

      opencommit config set OCO_AI_PROVIDER=ollama
      opencommit config set OCO_API_URL="$default_chat_endpoint"
      opencommit config set OCO_API_KEY=ollama
      opencommit config set OCO_MODEL="$commit_model"

      echo "OpenCommit is configured for the local commit profile."
      echo "Commit profile: $commit_model"
      echo "Endpoint: $default_endpoint"

      if ! service_ready "default"; then
        echo "Ollama is not reachable."
        echo "Next step: llm-status"
        exit 1
      fi

      if ! installed_model_for_service "$(profile_service commit)" "$commit_model"; then
        echo "Commit profile is not installed."
        echo "Next step: llm-pull commit"
        exit 1
      fi

      echo "Ready."
      echo "Usage:"
      echo "  1. git add ."
      echo "  2. oco"
      echo "  3. oco-jira"
    '')
  ];
}
