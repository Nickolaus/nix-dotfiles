{ pkgs, ... }: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    
    # Global SSH settings
    extraConfig = ''
      Host *
        SetEnv TERM=xterm-256color
        TCPKeepAlive yes
        ServerAliveInterval 60
        ServerAliveCountMax 1200
        IdentitiesOnly yes
    '';
    
    # Host-specific configurations for different SSH keys
    # WORK IS DEFAULT - Personal repositories use special hostnames
    matchBlocks = {
      # Personal GitHub (requires explicit hostname)
      "github.com-personal" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519_personal";  # Personal key
        identitiesOnly = true;
      };
      
      # Personal GitLab (requires explicit hostname)
      "gitlab.com-personal" = {
        hostname = "gitlab.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519_personal";  # Personal key
        identitiesOnly = true;
      };
      
      # Personal Home Assistant (Production)
      "home-assistant" = {
        hostname = "192.168.2.50";
        user = "root";
        identityFile = "~/.ssh/id_ed25519_personal";  # Personal key
        identitiesOnly = true;
      };
      
      # Home Assistant Testing VMs
      "ha-test-vm" = {
        hostname = "192.168.2.40";
        user = "root";
        identityFile = "~/.ssh/id_ed25519_personal";  # Personal key
        identitiesOnly = true;
        extraOptions = {
          StrictHostKeyChecking = "no";
        };
      };
      
      "192.168.2.40" = {
        user = "root";
        identityFile = "~/.ssh/id_ed25519_personal";
        identitiesOnly = true;
        extraOptions = {
          StrictHostKeyChecking = "no";
        };
      };
      
      # All 192.168.2.* hosts (HA testing network)
      "192.168.2.*" = {
        user = "root";
        identityFile = "~/.ssh/id_ed25519_personal";
        identitiesOnly = true;
        extraOptions = {
          StrictHostKeyChecking = "no";
        };
      };
      
      # Work GitHub (default - no special hostname needed)
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519";  # Work key (DEFAULT)
        identitiesOnly = true;
      };
      
      # Work GitLab (default - no special hostname needed)
      "gitlab.com" = {
        hostname = "gitlab.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519";  # Work key (DEFAULT)
        identitiesOnly = true;
      };
      
      # All other hosts use work key (DEFAULT)
      "*" = {
        identityFile = "~/.ssh/id_ed25519";  # Work key as explicit default
        addKeysToAgent = "yes";
        forwardAgent = false;
        compression = true;
      };
    };
  };
} 