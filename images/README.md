# Images Directory

This directory contains configurations and scripts for building system images (ISOs, VM images, disk images).

## Structure

```
images/
├── README.md                    # This file
├── installer.nix                # NixOS installer configuration with SSH
├── build-images.sh              # Script to build system images
├── result*                      # Nix build result symlinks (gitignored)
├── *.iso                        # ISO images (gitignored)
├── *.qcow2                      # QEMU/UTM VM disk images (gitignored)
└── *.img                        # Raw disk images (gitignored)
```

## Usage

### Build Installer ISOs

```bash
./images/build-images.sh
```

This creates custom NixOS installer ISOs for both ARM (aarch64) and x86_64 architectures with SSH pre-enabled.

**Options:**
```bash
./images/build-images.sh arm     # Build ARM installer only
./images/build-images.sh x86     # Build x86_64 installer only
./images/build-images.sh both    # Build both architectures
./images/build-images.sh         # Auto-detect current architecture
```

### Build from Flake

```bash
# ARM installer
nix build .#isoImages.farnsworth-installer-arm.config.system.build.isoImage

# x86_64 installer
nix build .#isoImages.farnsworth-installer-x86.config.system.build.isoImage
```

## Outputs

All build outputs are gitignored to keep the repository clean. Built artifacts include:
- `result*` - Nix build result symlinks
- `*.iso` - Bootable installer ISO images
- `*.qcow2` - QEMU/UTM VM disk images
- `*.img` - Raw disk images (for dd, cloud providers, etc.)

## Writing ISOs to USB

```bash
# macOS
sudo dd if=./images/farnsworth-installer-arm-YYYYMMDD.iso of=/dev/diskX bs=4m status=progress

# Linux
sudo dd if=./images/farnsworth-installer-arm-YYYYMMDD.iso of=/dev/sdX bs=4M status=progress
```

**Warning:** Replace `/dev/diskX` or `/dev/sdX` with your actual USB device. This will erase all data on the device.

## Building from macOS

**Important:** ISO images cannot be built directly on macOS due to Nix's cross-platform limitations.

### Options for Building Linux ISOs from macOS:

#### Option 1: Use a Linux Remote Builder (Recommended)
Set up a remote Linux builder in your Nix configuration. This requires a Linux machine accessible via SSH.

#### Option 2: Use nixos-anywhere (Easiest)
Skip ISO building entirely and deploy directly to hardware:
```bash
# See hosts/farnsworth/docs/INSTALLATION.md for details
```

#### Option 3: Build on Linux
Build the ISO on any Linux machine:
```bash
git clone <your-repo>
cd nix-dotfiles
nix build '.#isoImages.farnsworth-installer-arm.config.system.build.isoImage'
```

#### Option 4: Use GitHub Actions / CI
Set up automated builds using Linux runners in CI/CD.

### Configuration Validation

You can still validate the ISO configuration from macOS:
```bash
# Validate all configurations (including ISO)
nix flake check

# Evaluate ISO configuration (without building)
nix eval '.#isoImages.farnsworth-installer-arm.config.system.build.isoImage.name'
```

The configuration has been validated and will build successfully on Linux systems.
