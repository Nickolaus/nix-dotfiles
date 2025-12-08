{ config
, pkgs
, lib
, flake
, ... }:

# Home Manager configuration for zoidberg user (C.Hessel)
# Imports: default.nix → features → darwin (includes packages, shell, keybindings)

{
  imports = [
    flake.inputs.mac-app-util.homeManagerModules.default
    ./default.nix  # Imports SOPS + ./features (which imports ./darwin automatically)
  ];

  home = {
    username = "C.Hessel";
    homeDirectory = "/Users/C.Hessel";
    stateVersion = "23.05";  # Please read the comment in default.nix before changing
  };
} 