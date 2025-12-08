{ config, pkgs, lib, impermanence, ... }:

# Impermanence configuration - tmpfs root with persistent directories
# Provides enhanced security by wiping root filesystem on reboot
# Only selected directories persist via Btrfs subvolumes

{
  imports = [
    impermanence.nixosModules.impermanence
  ];

  # Enable impermanence using tmpfs overlay
  # Root filesystem (/) is mounted as tmpfs, overlaid with Btrfs subvolumes
  
  # Persistent directories that survive reboots
  environment.persistence."/persist" = {
    hideMounts = true;
    
    # System directories that need to persist
    directories = [
      "/var/lib/bluetooth"      # Bluetooth pairings
      "/var/lib/nixos"          # NixOS state
      "/var/lib/systemd/coredump" # System crash dumps
      "/etc/NetworkManager/system-connections" # WiFi passwords
      "/etc/ssh"                # SSH host keys (IMPORTANT!)
      "/var/lib/docker"         # Docker state
      
      # Add more as needed
      # "/var/lib/postgresql"   # Database data
      # "/var/lib/mysql"        # Database data
    ];
    
    # System files that need to persist
    files = [
      "/etc/machine-id"         # Machine ID (required for systemd)
      "/etc/adjtime"            # Hardware clock adjustment
    ];
    
    # User-specific persistence (per user)
    users."C.Hessel" = {
      directories = [
        # User directories already in /home (persistent subvolume)
        # Add additional state here if needed
        
        ".local/share/docker"   # User Docker state
        ".local/share/keyrings" # Keychains
        ".cache"                # User cache
        ".config"               # User config (already in /home)
        
        # Development
        ".local/share/direnv"   # Direnv state
        
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
  
  # Boot-time script to set up tmpfs root overlay
  boot.initrd.postDeviceCommands = lib.mkAfter ''
    # Clean up /tmp on boot
    mkdir -p /mnt
    
    # Mount the Btrfs root to clean it up
    mount -o subvol=@root /dev/mapper/cryptroot /mnt
    
    # Remove everything except /nix, /home, /persist (which are separate subvolumes)
    if [ -d /mnt ]; then
      # Delete old root files (be careful!)
      btrfs subvolume list -o /mnt | cut -f9- -d' ' | \
        while read subvolume; do
          echo "Deleting /$subvolume subvolume..."
          btrfs subvolume delete "/mnt/$subvolume"
        done || true
      
      # Clean up root directory
      find /mnt -mindepth 1 -maxdepth 1 -not -name 'nix' -not -name 'home' -not -name 'persist' -not -name 'var' -not -name '.snapshots' -delete
    fi
    
    umount /mnt
  '';

  # Warning message about impermanence
  warnings = [
    ''
      Impermanence is enabled. The root filesystem will be wiped on reboot.
      Only /nix, /home, /persist, and /var/log will survive reboots.
      Ensure critical data is in one of these locations.
    ''
  ];
}

