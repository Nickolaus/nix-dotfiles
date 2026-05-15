{ sops
, config
, pkgs
, lib
, ...
}:
let
  cloudflareMcpTokenPath = "${config.home.homeDirectory}/.config/mcp/cloudflare_mcp_token";
  githubMcpPatPath = "${config.home.homeDirectory}/.config/mcp/github_mcp_pat";
  mcpEnvExport = pkgs.writeShellScriptBin "hm-export-mcp-env" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    trim_secret() {
      ${pkgs.coreutils}/bin/tr -d '\n' < "$1"
    }

    wait_for_secret() {
      local path="$1"
      local attempt

      for attempt in {1..20}; do
        if [[ -s "$path" ]]; then
          return 0
        fi
        ${pkgs.coreutils}/bin/sleep 0.25
      done

      return 1
    }

    set_secret_env() {
      local name="$1"
      local path="$2"

      if ! wait_for_secret "$path"; then
        echo "Skipping $name; secret file is not available yet: $path" >&2
        return 0
      fi

      /bin/launchctl setenv "$name" "$(trim_secret "$path")"
    }

    set_file_env() {
      local name="$1"
      local path="$2"

      if ! wait_for_secret "$path"; then
        echo "Skipping $name; secret file is not available yet: $path" >&2
        return 0
      fi

      /bin/launchctl setenv "$name" "$path"
    }

    set_secret_env UNIFI_NETWORK_USERNAME ${lib.escapeShellArg config.sops.secrets.unifi_mcp_username.path}
    set_secret_env UNIFI_NETWORK_PASSWORD ${lib.escapeShellArg config.sops.secrets.unifi_mcp_password.path}
    set_file_env PROXMOX_MCP_CONFIG ${lib.escapeShellArg config.sops.secrets.proxmox_mcp_config_json.path}
    set_secret_env INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET ${lib.escapeShellArg config.sops.secrets.infisical_universal_auth_client_secret.path}
    set_secret_env RESEND_API_KEY ${lib.escapeShellArg config.sops.secrets.resend_api_key.path}
    set_secret_env GRAFANA_SERVICE_ACCOUNT_TOKEN ${lib.escapeShellArg config.sops.secrets.grafana_service_account_token.path}
    set_secret_env CONTEXT7_API_KEY ${lib.escapeShellArg config.sops.secrets.context7_api_key.path}
    set_secret_env CLOUDFLARE_MCP_TOKEN ${lib.escapeShellArg cloudflareMcpTokenPath}
    set_secret_env GITHUB_MCP_PAT ${lib.escapeShellArg githubMcpPatPath}
  '';
in
{
  imports = [
    ./homelab-gpg-signing.nix
  ];

  sops = {
    age.keyFile = "${
    if pkgs.stdenv.hostPlatform.isDarwin
    then "/Users/C.Hessel/Library/Application Support/sops/age/keys.txt"
    else "/home/C.Hessel/.config/sops/age/keys.txt"
    }";

    defaultSopsFile = ./secrets.yaml;

    secrets.ssh_key = {
      path = "${config.home.homeDirectory}/.ssh/id_ed25519";
      format = "yaml";
      mode = "0600";
    };

    secrets.ssh_key_personal = {
      path = "${config.home.homeDirectory}/.ssh/id_ed25519_personal";
      format = "yaml";
      mode = "0600";
    };

    secrets.openai_api_key = {
      path = "${config.home.homeDirectory}/.config/opencommit/openai_api_key";
      format = "yaml";
      mode = "0600";
    };

    secrets.claude_api_key = {
      path = "${config.home.homeDirectory}/.config/opencommit/claude_api_key";
      format = "yaml";
      mode = "0600";
    };

    secrets.context7_api_key = {
      path = "${config.home.homeDirectory}/.config/mcp/context7_api_key";
      format = "yaml";
      mode = "0600";
    };

    secrets.cloudflare_mcp_token = {
      path = cloudflareMcpTokenPath;
      format = "yaml";
      mode = "0600";
    };

    secrets.github_mcp_pat = {
      path = githubMcpPatPath;
      format = "yaml";
      mode = "0600";
    };

    secrets.unifi_mcp_username = {
      path = "${config.home.homeDirectory}/.config/mcp/unifi_username";
      format = "yaml";
      mode = "0600";
    };

    secrets.unifi_mcp_password = {
      path = "${config.home.homeDirectory}/.config/mcp/unifi_password";
      format = "yaml";
      mode = "0600";
    };

    secrets.proxmox_mcp_config_json = {
      path = "${config.home.homeDirectory}/.config/mcp/proxmox-config.json";
      format = "yaml";
      mode = "0600";
    };

    secrets.infisical_universal_auth_client_secret = {
      path = "${config.home.homeDirectory}/.config/mcp/infisical_universal_auth_client_secret";
      format = "yaml";
      mode = "0600";
    };

    secrets.resend_api_key = {
      path = "${config.home.homeDirectory}/.config/mcp/resend_api_key";
      format = "yaml";
      mode = "0600";
    };

    secrets.grafana_service_account_token = {
      path = "${config.home.homeDirectory}/.config/mcp/grafana_service_account_token";
      format = "yaml";
      mode = "0600";
    };

    secrets.homelab_gpg_signing_subkey = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      format = "yaml";
      mode = "0600";
    };
  };

  home.packages = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin [
    mcpEnvExport
  ];

  home.file = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    "Library/Logs/mcp-env/.keep".text = "";
  };

  programs.fish.shellInit = ''
    set -l cloudflare_mcp_token_path ${lib.escapeShellArg cloudflareMcpTokenPath}
    if test -r "$cloudflare_mcp_token_path"
      set -gx CLOUDFLARE_MCP_TOKEN (${pkgs.coreutils}/bin/tr -d '\n' < "$cloudflare_mcp_token_path")
    end

    set -l github_mcp_pat_path ${lib.escapeShellArg githubMcpPatPath}
    if test -r "$github_mcp_pat_path"
      set -gx GITHUB_MCP_PAT (${pkgs.coreutils}/bin/tr -d '\n' < "$github_mcp_pat_path")
    end
  '';

  home.activation.exportMcpEnv = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin
    (lib.hm.dag.entryAfter [ "sops-nix" ] ''
      ${mcpEnvExport}/bin/hm-export-mcp-env
    '');

  launchd.agents.hm-export-mcp-env = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [ "${mcpEnvExport}/bin/hm-export-mcp-env" ];
      RunAtLoad = true;
      KeepAlive = false;
      WatchPaths = [
        config.sops.secrets.unifi_mcp_username.path
        config.sops.secrets.unifi_mcp_password.path
        config.sops.secrets.proxmox_mcp_config_json.path
        config.sops.secrets.infisical_universal_auth_client_secret.path
        config.sops.secrets.resend_api_key.path
        config.sops.secrets.grafana_service_account_token.path
        config.sops.secrets.context7_api_key.path
        config.sops.secrets.cloudflare_mcp_token.path
        config.sops.secrets.github_mcp_pat.path
      ];
      ProcessType = "Background";
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/mcp-env/launchd.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/mcp-env/launchd.error.log";
      EnvironmentVariables = {
        PATH = "/etc/profiles/per-user/${config.home.username}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        HOME = config.home.homeDirectory;
      };
    };
  };
}
