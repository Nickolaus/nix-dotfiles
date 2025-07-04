# nix-dotfiles Architecture

This document describes the architecture and organization of this cross-platform Nix configuration.

## 🏗️ Directory Structure

```
nix-dotfiles/
├── flake.nix              # Main flake configuration with outputs
├── install.sh             # Cross-platform installation script
├── scripts/               # Utility scripts and tools
│   └── hot-benchmark.sh   # AI model performance benchmarking tool
├── 
├── hosts/                 # System configurations per machine
│   ├── zoidberg/          # Primary macOS system (nix-darwin)
│   ├── example-linux/     # Example Linux configuration (NixOS)
│   └── shared/            # Shared system configurations
│
├── home/                  # Home Manager configurations
│   ├── default.nix        # Base user configuration (imports ./features)
│   ├── zoidberg.nix       # User-specific config for zoidberg (platform-specific)
│   └── features/          # Modular user feature configurations
│       ├── default.nix    # Imports all feature modules
│       ├── packages.nix   # Cross-platform packages (categorized)
│       ├── shell/         # Shell configuration (fish, aliases, etc.)
│       ├── git/           # Git configuration
│       ├── secrets/       # SOPS-encrypted secrets
│       ├── editors/       # Text editors
│       │   ├── default.nix # Imports ./nvim
│       │   └── nvim/      # Neovim configuration
│       ├── terminals/     # Terminal applications
│       │   ├── default.nix # Imports ./tmux, ./wezterm
│       │   ├── tmux/      # Terminal multiplexer
│       │   └── wezterm/   # Terminal emulator
│       ├── development/   # Development tools
│       │   ├── default.nix # Imports language modules
│       │   └── languages/ # Programming language configurations
│       │       ├── go/    # Go development setup
│       │       └── php/   # PHP development setup
│       ├── ai/            # AI & Machine Learning tools
│       │   ├── default.nix # Imports AI modules
│       │   └── ollama.nix # Local LLM server configuration
│       ├── darwin/        # macOS-specific user configurations
│       │   ├── default.nix # Imports darwin features and packages
│       │   ├── packages.nix # macOS-specific packages (categorized)
│       │   └── keybindings/ # Keyboard shortcuts and window management
│       │       ├── default.nix # Keyboard configuration
│       │       ├── DefaultKeyBinding.dict # macOS key bindings
│       │       └── hammerspoon/ # Lua-based automation
│       └── linux/         # Linux-specific user configurations
│           ├── default.nix # Imports linux features and packages
│           └── packages.nix # Linux-specific packages (categorized)
│
├── modules/               # System-level modules and configurations
│   ├── darwin/            # macOS system modules (nix-darwin)
│   │   ├── aerospace.nix  # Window manager configuration
│   │   ├── brew.nix       # Homebrew package management
│   │   └── system.nix     # System-level settings
│   ├── nixos/             # Linux system modules (NixOS) 
│   └── shared/            # Cross-platform system modules
│
├── scripts/               # Utility scripts and development tools
├── lib/                   # Helper functions and utilities
├── overlays/              # Package overlays and custom packages
└── [config files]        # .sops.yaml, .gitignore, etc.
```

## 🎯 Design Principles

### 1. **Cross-Platform Support**
- **Platform Detection**: Configurations automatically adapt based on `pkgs.stdenv.isDarwin`/`isLinux`
- **Conditional Imports**: Platform-specific modules are only loaded when appropriate
- **Shared Foundation**: Maximum code reuse through common configurations

### 2. **Scalable Organization**
- **Two-Layer Rule**: Main configs import only second-layer (e.g., `./features` not `./features/packages.nix`)
- **Default Entry Points**: Every folder has a `default.nix` that imports its components
- **Simple vs Complex**: Files for simple configs (packages), folders for complex features (editors)
- **Categorized Packages**: All packages organized by application categories with future-ready sections

### 3. **Clear Separation of Concerns**
- **System vs User**: Clear distinction between system-level (`modules/`, `hosts/`) and user-level (`home/`) configurations
- **Host-Specific**: Machine-specific customizations are isolated in `hosts/` and user-specific files
- **Feature Isolation**: Each feature (editor, shell, etc.) is self-contained
- **Platform Separation**: OS-specific packages and features clearly separated

## 🔧 Configuration Flow

### System Configuration (nix-darwin/NixOS)
```
flake.nix → hosts/zoidberg/default.nix → modules/darwin/*.nix
```

### User Configuration (Home Manager)
```
hosts/zoidberg/default.nix → home/zoidberg.nix → home/default.nix → home/features/default.nix → individual features
```

### Platform-Specific Logic
- **System Level**: Handled in `hosts/` configurations and `modules/darwin/` vs `modules/nixos/`
- **User Level**: Platform-specific imports in user files (e.g., `home/zoidberg.nix`)
- **Packages**: Platform-specific packages in `home/features/darwin/packages.nix` and `home/features/linux/packages.nix`

## 📁 Key Configuration Files

### Core Files
- **`flake.nix`**: Defines inputs, outputs, and system configurations
- **`home/default.nix`**: Base Home Manager configuration (imports `./features`)
- **`home/zoidberg.nix`**: User-specific configuration with platform-specific imports

### Entry Points (All follow two-layer import rule)
- **`home/features/default.nix`**: Imports all feature modules
- **`home/features/editors/default.nix`**: Imports `./nvim`
- **`home/features/terminals/default.nix`**: Imports `./tmux`, `./wezterm`
- **`home/features/development/default.nix`**: Imports `./languages/go`, `./languages/php`
- **`home/features/ai/default.nix`**: Imports `./ollama.nix`
- **`home/features/darwin/default.nix`**: Imports `./packages.nix`, `./keybindings`
- **`home/features/linux/default.nix`**: Imports `./packages.nix` (and future features)

### Package Files (Organized by Categories)
- **`home/features/packages.nix`**: Cross-platform packages organized by:
  - 📦 Development Environment & Package Managers
  - 🔐 Security & Secrets Management  
  - 🛠️ System Utilities & CLI Tools
  - ☁️ Cloud & Infrastructure Tools
  - 💻 Development Languages & Runtimes
  - 🔧 Development Tools & Version Control
  - 🤖 AI & Machine Learning (ollama, opencommit)
  - And more...

- **`home/features/darwin/packages.nix`**: macOS-specific packages organized by:
  - 💬 Communication & Collaboration
  - 🤖 AI & Productivity Tools
  - 💻 Development Environments & IDEs
  - Plus prepared sections for design, mobile dev, utilities, etc.

- **`home/features/linux/packages.nix`**: Linux-specific packages organized by:
  - 🌐 Browsers & Web Tools
  - 💬 Communication & Collaboration
  - 💻 Development Environments & IDEs
  - 🖥️ Desktop Environment & Window Managers
  - Plus prepared sections for design, productivity, gaming, etc.

## 🚀 Adding New Features

### Adding a New User Feature
1. Create `home/features/new-feature/default.nix` (if complex) or `home/features/new-feature.nix` (if simple)
2. Add import to `home/features/default.nix`
3. Implement feature-specific configuration

### Adding Platform-Specific Features
1. Create feature in `home/features/darwin/` or `home/features/linux/`
2. Add import to respective platform's `default.nix`
3. Use `lib.mkIf pkgs.stdenv.isDarwin` for conditional activation if needed

### Adding Packages
1. **Cross-platform**: Add to appropriate category in `home/features/packages.nix`
2. **macOS-specific**: Add to appropriate category in `home/features/darwin/packages.nix`
3. **Linux-specific**: Add to appropriate category in `home/features/linux/packages.nix`
4. **New categories**: Follow the established pattern with emoji headers and comment blocks

### Adding System-Level Modules
1. Create `modules/darwin/new-module.nix` or `modules/nixos/new-module.nix`
2. Import in appropriate host configuration (`hosts/*/default.nix`)

## 🛠️ Utility Scripts

The `scripts/` directory contains development and maintenance tools:
- **`hot-benchmark.sh`**: AI model performance benchmarking tool for comparing ollama models with OpenCommit
- Future utility scripts for configuration management, testing, and automation

These scripts are not part of the Nix configuration but provide helpful tools for managing and testing the dotfiles setup.

## 🔒 Secrets Management

Uses **SOPS** (Secrets OPerationS) for encrypted secrets:
- **Configuration**: `.sops.yaml` defines encryption rules
- **Key Location**: 
  - macOS: `~/Library/Application Support/sops/age/keys.txt`
  - Linux: `~/.config/sops/age/keys.txt`
- **Usage**: Secrets are imported via `home/features/secrets/`

## 📦 Package Management Philosophy

### Package Organization Strategy
- **Cross-Platform First**: Common CLI tools and development dependencies in main `packages.nix`
- **Platform-Specific GUI**: Desktop applications and OS-specific tools in platform folders
- **Categorized Organization**: All packages grouped by purpose with clear emoji headers
- **Future-Ready**: Prepared sections for easy expansion

### Package Categories
#### Cross-Platform (`packages.nix`)
Focus on CLI tools, development runtimes, and cloud/infrastructure tools that work identically across platforms.

#### Platform-Specific (`darwin/packages.nix`, `linux/packages.nix`)
Focus on GUI applications, OS-specific utilities, and platform-optimized versions of cross-platform tools.

## 🧪 Testing & Validation

### Check Configuration
```bash
nix flake check
```

### Dry Run Build
```bash
nix build .#darwinConfigurations.zoidberg.system --dry-run
```

### Apply Changes
```bash
sudo darwin-rebuild switch --flake ~/.config/nix-dotfiles/ --show-trace
```

---

This architecture provides a scalable, maintainable foundation for managing configurations across multiple platforms while keeping complexity manageable through clear organizational principles and consistent categorization. 
