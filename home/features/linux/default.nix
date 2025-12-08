{ pkgs, lib, ... }:
{
  imports = [
    ./packages.nix
    ./shell.nix
    ./hyprland     # Wayland compositor
    ./waybar       # Status bar
  ];
} 