# Farnsworth Documentation

Documentation specific to the **farnsworth** NixOS configuration (multi-architecture laptop setup).

## Documents

- **[INSTALLATION.md](./INSTALLATION.md)** - Complete installation guide for production hardware
  - Covers both ARM (primary) and x86_64 (secondary) architectures
  - Uses `nixos-anywhere` for automated deployment
  - Includes hardware detection and initial setup

- **[VM_TESTING.md](./VM_TESTING.md)** - VM testing guide using UTM
  - Test configuration before production deployment
  - Step-by-step VM setup and installation
  - Validation and troubleshooting

## Quick Links

- Scripts: [`../scripts/`](../scripts/)
- Configuration: [`../default.nix`](../default.nix)
- Disk Layout: [`../disko.nix`](../disko.nix)
- User Config: [`../users.nix`](../users.nix)
