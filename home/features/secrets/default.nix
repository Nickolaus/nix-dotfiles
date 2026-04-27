{ sops
, config
, pkgs
, lib
, ...
}:
let
  githubTokenPath = "${config.home.homeDirectory}/.config/nix/github_token";
  mcpEnvExport = pkgs.writeShellScriptBin "hm-export-mcp-env" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    trim_secret() {
      ${pkgs.coreutils}/bin/tr -d '\n' < "$1"
    }

    /bin/launchctl setenv UNIFI_NETWORK_USERNAME "$(trim_secret ${lib.escapeShellArg config.sops.secrets.unifi_mcp_username.path})"
    /bin/launchctl setenv UNIFI_NETWORK_PASSWORD "$(trim_secret ${lib.escapeShellArg config.sops.secrets.unifi_mcp_password.path})"
    /bin/launchctl setenv PROXMOX_MCP_CONFIG ${lib.escapeShellArg config.sops.secrets.proxmox_mcp_config_json.path}
    /bin/launchctl setenv INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET "$(trim_secret ${lib.escapeShellArg config.sops.secrets.infisical_universal_auth_client_secret.path})"
    /bin/launchctl setenv RESEND_API_KEY "$(trim_secret ${lib.escapeShellArg config.sops.secrets.resend_api_key.path})"
    /bin/launchctl setenv CONTEXT7_API_KEY "$(trim_secret ${lib.escapeShellArg config.sops.secrets.context7_api_key.path})"
    github_token="$(trim_secret ${lib.escapeShellArg githubTokenPath})"
    /bin/launchctl setenv GH_TOKEN "$github_token"
    /bin/launchctl setenv GITHUB_TOKEN "$github_token"
    /bin/launchctl setenv GITHUB_PERSONAL_ACCESS_TOKEN "$github_token"
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

    secrets.github_token = {
      path = githubTokenPath;
      format = "yaml";
      mode = "0600";
    };

    secrets.context7_api_key = {
      path = "${config.home.homeDirectory}/.config/mcp/context7_api_key";
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
    set -l github_token_path ${lib.escapeShellArg githubTokenPath}
    if test -r "$github_token_path"
      set -l github_token (${pkgs.coreutils}/bin/tr -d '\n' < "$github_token_path")
      set -gx GH_TOKEN "$github_token"
      set -gx GITHUB_TOKEN "$github_token"
      set -gx GITHUB_PERSONAL_ACCESS_TOKEN "$github_token"
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
        config.sops.secrets.context7_api_key.path
        config.sops.secrets.github_token.path
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
