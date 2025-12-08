{ config, pkgs, lib, ... }:

# User configuration for farnsworth
# Separates user management from main system config

{
  # Primary user
  users.users."C.Hessel" = {
    isNormalUser = true;
    description = "C.Hessel";
    
    # Password management:
    # - For testing/VM: Set via nixos-anywhere or leave unset
    # - For production: Use hashedPassword (generated with: mkpasswd -m sha-512)
    # - For secrets: Use SOPS with hashedPasswordFile
    #
    # DO NOT set initialPassword in production - it's a security risk!
    # If no password is set, login via SSH key or set via passwd after install.
    
    extraGroups = [ 
      "wheel"          # sudo access
      "networkmanager" # manage network without sudo
      "docker"         # Docker access
      "video"          # video device access
      "audio"          # audio device access
    ];
    
    shell = pkgs.fish;
    
    # SSH public keys (if using key-based auth)
    # openssh.authorizedKeys.keys = [
    #   "ssh-ed25519 AAAAC3... your-key-here"
    # ];
  };
  
  # Enable Fish shell system-wide
  programs.fish.enable = true;
  
  # Security: Require password for sudo (good practice)
  security.sudo.wheelNeedsPassword = lib.mkDefault true;
}

