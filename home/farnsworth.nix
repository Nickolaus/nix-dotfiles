{ config, pkgs, lib, flake, ... }:

# Home Manager configuration for farnsworth user (C.Hessel)
# Imports: default.nix → features → linux (includes hyprland, waybar, packages)

{
  imports = [
    ./default.nix  # Imports SOPS + ./features (which imports ./linux automatically)
  ];

  # User-specific settings
  home = {
    username = "C.Hessel";
    homeDirectory = "/home/C.Hessel";
    stateVersion = "24.11";  # NixOS 24.11 release
  };

  # User-specific environment variables (if any)
  home.sessionVariables = {
    # Add farnsworth-specific variables here
  };

  # Farnsworth-specific overrides (if needed)
  # programs.waybar.enable = true; # Already enabled by default
}

