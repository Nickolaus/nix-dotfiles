{ pkgs, ... }: {
  programs.ssh = {
    enable = true;
    
    # SSH settings that integrate with Home Manager's base config
    addKeysToAgent = "yes";
    forwardAgent = false;
    compression = true;
    
    # Add the SSH configuration with the user's requested settings
    extraConfig = ''
      Host *
        IdentityFile ~/.ssh/id_ed225519
        SetEnv TERM=xterm-256color
        TCPKeepAlive yes
        ServerAliveInterval 60
        ServerAliveCountMax 1200
    '';
    
    # You can also add specific host configurations here if needed
    # matchBlocks = {
    #   "example.com" = {
    #     hostname = "example.com";
    #     user = "username";
    #     port = 22;
    #   };
    # };
  };
} 