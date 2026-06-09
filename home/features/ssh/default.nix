{ pkgs, ... }: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    # Host-specific configurations for different SSH keys
    # WORK IS DEFAULT - Personal repositories use special hostnames
    settings = {
      # Personal GitHub (requires explicit hostname)
      "github.com-personal" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519_personal"; # Personal key
        IdentitiesOnly = true;
      };

      # Personal GitLab (requires explicit hostname)
      "gitlab.com-personal" = {
        HostName = "gitlab.com";
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519_personal"; # Personal key
        IdentitiesOnly = true;
      };

      # Personal Home Assistant (Production)
      "home-assistant" = {
        HostName = "192.168.2.50";
        User = "root";
        IdentityFile = "~/.ssh/id_ed25519_personal"; # Personal key
        IdentitiesOnly = true;
      };

      # Home Assistant Testing VMs
      "ha-test-vm" = {
        HostName = "192.168.2.40";
        User = "root";
        IdentityFile = "~/.ssh/id_ed25519_personal"; # Personal key
        IdentitiesOnly = true;
        StrictHostKeyChecking = "no";
      };

      "192.168.2.40" = {
        User = "root";
        IdentityFile = "~/.ssh/id_ed25519_personal";
        IdentitiesOnly = true;
        StrictHostKeyChecking = "no";
      };

      # All 192.168.2.* hosts (HA testing network)
      "192.168.2.*" = {
        User = "root";
        IdentityFile = "~/.ssh/id_ed25519_personal";
        IdentitiesOnly = true;
        StrictHostKeyChecking = "no";
      };

      # Work GitHub (default - no special hostname needed)
      "github.com" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519"; # Work key (DEFAULT)
        IdentitiesOnly = true;
      };

      # Work GitLab (default - no special hostname needed)
      "gitlab.com" = {
        HostName = "gitlab.com";
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519"; # Work key (DEFAULT)
        IdentitiesOnly = true;
      };

      # All other hosts use work key (DEFAULT)
      "*" = {
        SetEnv = {
          TERM = "xterm-256color";
        };
        TCPKeepAlive = true;
        ServerAliveInterval = 60;
        ServerAliveCountMax = 1200;
        IdentitiesOnly = true;
        IdentityFile = "~/.ssh/id_ed25519"; # Work key as explicit default
        AddKeysToAgent = "yes";
        ForwardAgent = false;
        Compression = true;
      };
    };
  };
}
