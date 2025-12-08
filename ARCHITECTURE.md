# Architecture

This document describes the organization and design principles of this cross-platform Nix configuration.

## Directory Structure

```
nix-dotfiles/
├── flake.nix                      # Main flake configuration with outputs
├── install.sh                     # Cross-platform installation script
│
├── images/                        # System images (ISOs, VM images, disk images)
│   ├── README.md                  # Images directory documentation
│   ├── installer.nix              # NixOS installer configuration with SSH
│   ├── build-images.sh            # Build script for system images
│   └── (result*, *.iso, *.qcow2)  # Build outputs (gitignored)
│
├── scripts/                       # Utility scripts and tools
│   ├── update-system.sh           # System update automation
│   └── hot-benchmark.sh           # AI model benchmarking
│
├── hosts/                         # System configurations per machine
│   ├── zoidberg/                  # macOS system (nix-darwin)
│   │   └── ...
│   ├── farnsworth/                # Linux laptop (NixOS, multi-arch)
│   │   ├── default.nix            # Main system configuration
│   │   ├── disko.nix              # Declarative disk layout
│   │   ├── users.nix              # User configuration
│   │   ├── docs/                  # Host-specific documentation
│   │   │   ├── README.md          # Documentation index
│   │   │   ├── INSTALLATION.md    # Production installation guide
│   │   │   └── VM_TESTING.md      # VM testing guide
│   │   └── scripts/               # Host-specific scripts
│   │       ├── README.md          # Script documentation
│   │       └── vm-test-setup.sh   # VM testing automation
│   └── shared/                    # Shared system configurations
│       ├── determinate.nix        # Nix daemon configuration
│       └── fonts.nix              # Font configuration
│
├── home/                          # Home Manager configurations
│   ├── default.nix                # Base user configuration (imports ./features)
│   ├── zoidberg.nix               # macOS user config
│   ├── farnsworth.nix             # Linux user config
│   └── features/                  # Modular user feature configurations
│       ├── default.nix            # Imports all feature modules
│       ├── packages.nix           # Cross-platform packages
│       ├── shell/                 # Shell configuration
│       ├── git/                   # Git configuration
│       ├── secrets/               # SOPS-encrypted secrets
│       ├── editors/               # Text editors (nvim)
│       ├── terminals/             # Terminal applications (tmux, wezterm)
│       ├── development/           # Development tools (go, php)
│       ├── ai/                    # AI & ML tools (ollama)
│       ├── darwin/                # macOS-specific user configurations
│       │   ├── default.nix        # Imports darwin features and packages
│       │   ├── packages.nix       # macOS-specific packages
│       │   ├── shell.nix          # macOS shell additions
│       │   └── keybindings/       # Keyboard shortcuts and automation
│       └── linux/                 # Linux-specific user configurations
│           ├── default.nix        # Imports linux features and packages
│           ├── packages.nix       # Linux-specific packages
│           ├── hyprland/          # Hyprland window manager config
│           └── waybar/            # Waybar status bar config
│
└── modules/                       # System-level modules
    ├── darwin/                    # macOS system modules (nix-darwin)
    │   ├── aerospace/             # Window manager configuration
    │   ├── brew/                  # Homebrew package management
    │   └── system/                # System-level settings
    └── nixos/                     # NixOS system modules
        ├── hyprland/              # Hyprland system configuration
        ├── hardware/              # Hardware support (GPU drivers)
        ├── impermanence/          # Tmpfs root configuration
        ├── flatpak/               # Declarative Flatpak management
        └── btrfs-maintenance/     # Automated Btrfs maintenance
```

## Design Principles

### 1. Cross-Platform Support

**Platform Detection:**
Configurations adapt based on `pkgs.stdenv.isDarwin` / `pkgs.stdenv.isLinux`:
```nix
lib.mkIf pkgs.stdenv.isDarwin {
  # macOS-specific config
}
```

**Conditional Imports:**
Platform-specific modules loaded at user level:
```nix
# home/zoidberg.nix (macOS user):
imports = [
  ./default.nix        # Shared base
  ./features/darwin    # macOS features
];
```

**Shared Foundation:**
Maximum code reuse through common configurations in `home/features/`.

### 2. Scalable Organization

**Two-Layer Import Rule:**
Main configs import only second-layer directories:
```nix
# Good: home/default.nix imports ./features
imports = [ ./features ];

# Not: home/default.nix imports ./features/packages.nix
```

**Default Entry Points:**
Every folder has `default.nix` that imports its components:
```nix
# home/features/default.nix
imports = [
  ./packages.nix
  ./shell
  ./editors
  # ...
];
```

**Simple vs Complex:**
- Simple configs: Single `.nix` files (e.g., `packages.nix`)
- Complex features: Folders with `default.nix` (e.g., `editors/`)

**Categorized Packages:**
All packages organized by application categories with emoji headers.

### 3. Clear Separation of Concerns

**System vs User:**
- System level: `modules/`, `hosts/` - OS configuration, daemons
- User level: `home/` - User packages, dotfiles

**Package Placement:**
- GUI applications: Home Manager (`home/features/*/packages.nix`)
- System tools: Only `environment.systemPackages` for daemons, core CLI tools

**Host-Specific:**
Machine-specific customizations isolated in `hosts/` and user-specific files.

**Feature Isolation:**
Each feature (editor, shell, etc.) is self-contained in its own module.

**Platform Separation:**
OS-specific packages and features clearly separated in `darwin/` and `linux/` directories.

## Configuration Flow

### System Configuration
```
flake.nix → hosts/{zoidberg,farnsworth} → modules/{darwin,nixos}
```

### User Configuration
```
hosts/*/default.nix → home/*-user.nix → home/default.nix → home/features/default.nix → individual features
```

### Platform-Specific Loading

**System Level:**
Handled in `hosts/` configurations and separate `modules/darwin/` vs `modules/nixos/` directories.

**User Level:**
Platform-specific imports in user files:
```nix
# home/zoidberg.nix (macOS):
imports = [
  ./default.nix
  ./features/darwin    # macOS features only
];

# Future home/linux-user.nix:
imports = [
  ./default.nix
  ./features/linux     # Linux features only
];
```

**Defensive Programming:**
Even with platform-specific imports, feature modules use `lib.mkIf` for safety:
```nix
# home/features/darwin/packages.nix
lib.mkIf pkgs.stdenv.isDarwin {
  home.packages = [ /* macOS packages */ ];
}
```

## Package Organization

### Cross-Platform (`packages.nix`)
CLI tools, development runtimes, cloud/infrastructure tools that work identically across platforms:
- 🛠️ Development Environment
- 🔒 Security & Encryption
- ☁️ Cloud & Infrastructure
- 🔧 Languages & Runtimes
- 🤖 AI & Machine Learning

### Platform-Specific

**macOS (`darwin/packages.nix`):**
GUI applications, macOS-specific utilities:
- 💬 Communication & Collaboration
- 🤖 AI & Productivity Tools
- 💻 Development Environments & IDEs
- 🎨 Design & Creative Tools
- 🛠️ System Utilities

**Linux (`linux/packages.nix`):**
Desktop environment tools, Linux-specific applications:
- 🌐 Browsers & Web Tools
- 💻 Development Environments & IDEs
- 🖥️ Desktop Environment & Window Managers
- 🎮 Games & Entertainment

## Adding Features

### New User Feature
1. Create module:
   - Simple: `home/features/feature-name.nix`
   - Complex: `home/features/feature-name/default.nix`
2. Add import to `home/features/default.nix`
3. Implement feature-specific configuration

### Platform-Specific Features
1. Create in `home/features/darwin/` or `home/features/linux/`
2. Add import to respective platform's `default.nix`
3. Use `lib.mkIf pkgs.stdenv.isDarwin` if needed (defensive programming)

### Packages
1. **Cross-platform**: Add to `home/features/packages.nix`
2. **macOS-specific**: Add to `home/features/darwin/packages.nix`
3. **Linux-specific**: Add to `home/features/linux/packages.nix`
4. **New categories**: Follow pattern with emoji headers

**Package Placement Rules:**
- GUI Applications → Home Manager (`home/features/*/packages.nix`)
- System Tools → Only use `environment.systemPackages` for system daemons, core CLI tools
- User Tools → Prefer Home Manager for better user-specific configuration

### System-Level Modules
1. Create `modules/darwin/new-module/` or `modules/nixos/new-module/`
2. Import in appropriate host configuration (`hosts/*/default.nix`)

## Secrets Management

SOPS (Secrets OPerationS) for encrypted secrets:

**Configuration:** `.sops.yaml` defines encryption rules

**Key Locations:**
- macOS: `~/Library/Application Support/sops/age/keys.txt`
- Linux: `~/.config/sops/age/keys.txt`

**Usage:**
```nix
sops.secrets.api_key = {
  sopsFile = ./secrets/secrets.yaml;
  owner = "C.Hessel";
};

# Reference in config:
programs.some-app.apiKey = config.sops.secrets.api_key.path;
```

## System Updates

Two-component update model:

**1. Nix Installation:**
```bash
sudo determinate-nixd upgrade
```

**2. Configuration:**
```bash
nix flake update
sudo darwin-rebuild switch --flake . --show-trace  # macOS
sudo nixos-rebuild switch --flake . --show-trace   # Linux
```

See README.md for complete workflow.

## Validation & Testing

```bash
# Validate syntax
nix flake check

# Test build
nix build .#darwinConfigurations.zoidberg.system --dry-run  # macOS

# Check daemon
sudo determinate-nixd status
```

## Platform Support

### macOS (Darwin)
- **Status:** ✅ Fully implemented and operational
- **System:** nix-darwin
- **Host:** `hosts/zoidberg/`
- **User:** `home/zoidberg.nix` → `home/features/darwin/`

### Linux (NixOS)
- **Status:** ⚠️ Template provided, ready for activation
- **System:** NixOS
- **Host:** `hosts/farnsworth/` (production-ready)
- **User:** Create `home/linux-user.nix` → `home/features/linux/`

### Standalone Home Manager
- **Status:** ✅ Configured
- **Use Case:** Non-NixOS Linux systems
- **Config:** `homeConfigurations."C.Hessel"` in `flake.nix`

## Configuration Files

**Nix Daemon:**
- System config: `/etc/nix/nix.conf` (managed by Determinate Systems)
- Custom settings: `/etc/nix/nix.custom.conf`
- Dotfiles config: `hosts/shared/determinate.nix`

**Flake:**
- Main entry: `flake.nix`
- Lock file: `flake.lock` (auto-generated)

## Best Practices

1. **Follow two-layer import rule**
2. **Use emoji categories for package organization**
3. **Keep platform-specific code in platform folders**
4. **Document complex configurations with comments**
5. **Use SOPS for sensitive data**
6. **Prefer Home Manager over system-level when possible**
7. **Stage files with git before applying Nix configuration**

This architecture provides a scalable, maintainable foundation for managing configurations across multiple platforms.
