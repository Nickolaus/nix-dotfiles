{ pkgs, lib, desktop ? true, ... }:
{
  imports = [
    ./packages.nix
    ./shell.nix
  ] ++ lib.optionals desktop [
    ./hyprland     # Wayland compositor
    ./waybar       # Status bar
  ];
}