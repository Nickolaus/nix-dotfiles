{ config, pkgs, lib, flake, ... }:

# Home Manager configuration for the bender host (NixOS-WSL, C.Hessel)
# Imports: default.nix → features (desktop stack skipped via `desktop = false`,
# passed through extraSpecialArgs by the bender NixOS/standalone builders)

{
  imports = [
    ./default.nix
  ];

  home = {
    username = "C.Hessel";
    homeDirectory = "/home/C.Hessel";
    stateVersion = "26.05";
  };
}
