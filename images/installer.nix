{ config, pkgs, lib, modulesPath, ... }:

# Custom NixOS installer ISO with SSH pre-enabled
# Location: images/installer.nix
# Build with: nix build .#isoImages.farnsworth-installer-arm.config.system.build.isoImage
# Or use: ./images/build-images.sh
# Write to USB: dd if=result/iso/*.iso of=/dev/diskX bs=4m

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  # Disable ZFS to avoid kernel compatibility issues in unstable
  boot.supportedFilesystems = lib.mkForce [ "btrfs" "ext4" "vfat" "ntfs" "xfs" ];

  # Enable SSH by default (no manual configuration needed)
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };

  # Set known passwords for installer (only for installation phase)
  users.users.root = {
    initialHashedPassword = lib.mkForce null;
    initialPassword = "nixos";
  };
  users.users.nixos = {
    initialHashedPassword = lib.mkForce null;
    initialPassword = "nixos";
  };

  # Auto-start SSH on boot
  systemd.services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];

  # Show helpful information on console
  services.getty.helpLine = lib.mkAfter ''
    
    ╔═══════════════════════════════════════════════════════════╗
    ║  [1;32mFarnsworth NixOS Installer[0m                              ║
    ║  SSH is enabled with known credentials                    ║
    ╚═══════════════════════════════════════════════════════════╝
    
    📡 IP Addresses:
    [1;36m$(ip -4 addr | grep inet | grep -v 127.0.0.1 | awk '{print "   " $2}')[0m
    
    🔑 Login credentials:
       Username: nixos or root
       Password: nixos
    
    🚀 Install from your Mac with nixos-anywhere:
       [1;33mnix run github:nix-community/nixos-anywhere -- \
         --flake /path/to/dotfiles#farnsworth \
         root@<IP_FROM_ABOVE>[0m
    
    📚 Docs: ~/.config/nix-dotfiles/FARNSWORTH_INSTALLATION.md
    
  '';

  # Include useful tools in installer
  environment.systemPackages = with pkgs; [
    git
    vim
    htop
    tmux
    wget
    curl
  ];

  # Use latest kernel for best hardware support
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Ensure network works out of the box
  networking.wireless.enable = lib.mkForce false; # Use NetworkManager instead
  networking.networkmanager.enable = true;
}
