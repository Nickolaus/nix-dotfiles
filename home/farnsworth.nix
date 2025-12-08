{ config, pkgs, lib, ... }:

# Home Manager configuration for farnsworth user (C.Hessel)
# This imports the shared configuration and adds farnsworth-specific settings

{
  # Import shared home configuration
  imports = [
    ./features  # Shared cross-platform configuration
    ./features/linux/hyprland  # Hyprland window manager
    ./features/linux/waybar    # Waybar status bar
  ];

  # User-specific settings
  home = {
    username = "C.Hessel";
    homeDirectory = "/home/C.Hessel";
    stateVersion = "24.11";
  };

  # Enable Home Manager
  programs.home-manager.enable = true;

  # User-specific environment variables (if any)
  home.sessionVariables = {
    # Add farnsworth-specific variables here
  };

  # Farnsworth-specific overrides (if needed)
  # programs.waybar.enable = true; # Already enabled by default
}

