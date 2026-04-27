{ config, pkgs, lib, ... }:

# Impermanence configuration for persistent state under /persist
# This module currently manages persistence bindings only.
# It does not make the root filesystem ephemeral on reboot.
# 
# Note: impermanence.nixosModules.impermanence is imported in flake.nix
# This module only configures the options it provides

{

  # Persistent directories that survive reboots
  environment.persistence."/persist" = {
    hideMounts = true;

    # System directories that need to persist
    directories = [
      "/var/lib/bluetooth" # Bluetooth pairings
      "/var/lib/nixos" # NixOS state
      "/var/lib/systemd/coredump" # System crash dumps
      "/etc/NetworkManager/system-connections" # WiFi passwords
      "/etc/ssh" # SSH host keys (IMPORTANT!)
      "/var/lib/docker" # Docker state

      # Add more as needed
      # "/var/lib/postgresql"   # Database data
      # "/var/lib/mysql"        # Database data
    ];

    # System files that need to persist
    files = [
      "/etc/machine-id" # Machine ID (required for systemd)
      "/etc/adjtime" # Hardware clock adjustment
    ];

    # User-specific persistence (per user)
    users."C.Hessel" = {
      directories = [
        # User directories already in /home (persistent subvolume)
        # Add additional state here if needed

        ".local/share/docker" # User Docker state
        ".local/share/keyrings" # Keychains
        ".cache" # User cache
        ".config" # User config (already in /home)

        # Development
        ".local/share/direnv" # Direnv state

        # Add application-specific state as needed
        # ".local/share/Steam"  # Steam library
        # ".mozilla"            # Firefox profiles
      ];

      files = [
        # Add specific files to persist
        # ".screenrc"
      ];
    };
  };

  # Bind mount /home directly (it's already a persistent Btrfs subvolume)
  # No need to manage it through impermanence since it's naturally persistent
  fileSystems."/home" = {
    neededForBoot = true;
  };

  # Create /persist if it doesn't exist
  systemd.tmpfiles.rules = [
    "d /persist 0755 root root -"
    "d /persist/home 0755 root root -"
    "d /persist/home/C.Hessel 0700 C.Hessel users -"
  ];

  # Note: /nix is a separate persistent Btrfs subvolume (configured in disko.nix)
  # Note: /var/log is a separate persistent Btrfs subvolume (configured in disko.nix)
  # Note: /home is a separate persistent Btrfs subvolume (configured in disko.nix)
  # Note: Root persistence/ephemerality is defined by the filesystem layout in disko.nix.
}
