{ config, lib, pkgs, ... }:

# Disko configuration for Btrfs with LUKS encryption and impermanence
# This provides a declarative disk partitioning scheme

let
  # Disk device - override per deployment
  # Examples: "/dev/nvme0n1", "/dev/sda", "/dev/mmcblk0", "/dev/vda"
  diskDevice = lib.mkDefault "/dev/disk/by-id/OVERRIDE-THIS";
in
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = diskDevice;
        content = {
          type = "gpt";
          partitions = {
            # EFI System Partition
            ESP = {
              size = "512M";
              type = "EF00"; # EFI System Partition
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "defaults"
                  "umask=0077" # Secure permissions
                ];
              };
            };

            # Main encrypted partition with Btrfs
            root = {
              size = "100%"; # Use rest of disk
              content = {
                type = "luks";
                name = "cryptroot";
                
                # Encryption settings
                settings = {
                  # Use LUKS2 with Argon2id (modern, secure)
                  type = "luks2";
                  cipher = "aes-xts-plain64";
                  keySize = 512;
                  hash = "sha512";
                  
                  # Performance optimizations
                  pbkdfForceIterations = 1000000;
                };
                
                # Password file location for automated installation
                # IMPORTANT: Create this file manually during installation
                # passwordFile = "/tmp/secret.key";
                
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ]; # Force overwrite
                  
                  # Btrfs subvolumes for impermanence
                  subvolumes = {
                    # Root subvolume - will be ephemeral via tmpfs overlay
                    "@root" = {
                      mountpoint = "/";
                      mountOptions = [ 
                        "compress=zstd"
                        "noatime"
                        "space_cache=v2"
                      ];
                    };
                    
                    # Nix store - persistent, read-mostly
                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                        "space_cache=v2"
                      ];
                    };
                    
                    # Home directories - persistent
                    "@home" = {
                      mountpoint = "/home";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                        "space_cache=v2"
                      ];
                    };
                    
                    # Persistent system state
                    "@persist" = {
                      mountpoint = "/persist";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                        "space_cache=v2"
                      ];
                    };
                    
                    # System logs - persistent (optional)
                    "@log" = {
                      mountpoint = "/var/log";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                        "space_cache=v2"
                      ];
                    };
                    
                    # Snapshots directory
                    "@snapshots" = {
                      mountpoint = "/.snapshots";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                        "space_cache=v2"
                      ];
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  # Ensure required directories exist
  fileSystems."/persist".neededForBoot = true;
  fileSystems."/var/log".neededForBoot = true;

  # Btrfs-specific options
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  # Note: Actual impermanence configuration is in modules/nixos/impermanence
}

