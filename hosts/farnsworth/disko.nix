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

                # Password provided via nixos-anywhere: --disk-encryption-keys flag
                #
                # Modern LUKS2 defaults (automatically applied by cryptsetup):
                # - Format: LUKS2
                # - Cipher: aes-xts-plain64 (256-bit key, XTS mode)
                # - Key size: 512 bits (for XTS: 2x256)
                # - Hash: SHA-256
                # - PBKDF: Argon2id (memory-hard, GPU-resistant)
                #
                # Advanced LUKS options (if needed, use extraFormatArgs):
                # extraFormatArgs = [
                #   "--cipher aes-xts-plain64"
                #   "--key-size 512"
                #   "--hash sha512"
                #   "--pbkdf argon2id"
                #   "--pbkdf-memory 1048576"  # 1GB RAM for key derivation
                # ];
                #
                # Note: Defaults are secure for most use cases. Only customize
                # if you have specific compliance or performance requirements.

                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ]; # Force overwrite

                  # Btrfs subvolumes for impermanence
                  subvolumes = {
                    # Root subvolume - persistent unless a separate ephemeral-root
                    # strategy is added outside this disko layout.
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

  # Note: Actual impermanence configuration is in modules/nixos/impermanence
  # Note: Btrfs maintenance is in modules/nixos/btrfs-maintenance
}
