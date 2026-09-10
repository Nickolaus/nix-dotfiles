{ config, pkgs, lib, ... }:

# NixOS-WSL host - bender
# NixOS-WSL supplies boot/disk/interop for the WSL2 VM directly, so unlike
# farnsworth this host has no disko, hardware, hyprland, or impermanence
# modules - there's no physical disk, GPU, or Wayland session to configure.

{
  imports = [
    ../shared/ai-agents-default.nix
    ../shared/determinate.nix
    ../shared/fonts.nix
  ];

  wsl.enable = true;
  wsl.defaultUser = "C.Hessel";
  wsl.docker-desktop.enable = true;

  system.stateVersion = "26.05";
  networking.hostName = "bender";

  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "C.Hessel" ];
  };

  users.users."C.Hessel" = {
    isNormalUser = true;
    description = "C.Hessel";
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
  };
  programs.fish.enable = true;
  # NixOS-WSL's wsl-distro.nix sets this to `false` at mkDefault priority, so a
  # mkDefault here would collide instead of winning. Requiring the password
  # keeps an unattended process inside the VM from escalating silently.
  security.sudo.wheelNeedsPassword = lib.mkForce true;

  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    curl
    htop
  ];
}
