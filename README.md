# nix-dotfiles

<!-- Badges -->
<div align="center">

<!-- Core Technologies -->
![Nix](https://img.shields.io/badge/Nix-5277C3.svg?style=for-the-badge&logo=NixOS&logoColor=white)
![nix-darwin](https://img.shields.io/badge/nix--darwin-5277C3?style=for-the-badge&logo=apple&logoColor=white)
![Home Manager](https://img.shields.io/badge/Home_Manager-5277C3?style=for-the-badge&logo=home&logoColor=white)
![Determinate Systems](https://img.shields.io/badge/Determinate_Systems-5277C3?style=for-the-badge&logo=nix&logoColor=white)

<!-- Platform Support -->
![macOS](https://img.shields.io/badge/macOS_Monterey+-000000?style=for-the-badge&logo=apple&logoColor=white)
![Linux](https://img.shields.io/badge/NixOS_Ready-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Cross Platform](https://img.shields.io/badge/Cross_Platform-00D9FF?style=for-the-badge&logo=platform.sh&logoColor=white)

<!-- Security & Infrastructure -->
![SOPS Encrypted](https://img.shields.io/badge/SOPS_Encrypted-FF6B6B?style=for-the-badge&logo=keybase&logoColor=white)
![Age Encryption](https://img.shields.io/badge/Age_Keys-FF6B6B?style=for-the-badge&logo=key&logoColor=white)
![Secrets Management](https://img.shields.io/badge/Secrets_Managed-FF6B6B?style=for-the-badge&logo=vault&logoColor=white)

<!-- AI & Automation -->
![AI Commits](https://img.shields.io/badge/AI_Commits-4ECDC4?style=for-the-badge&logo=robot&logoColor=white)
![Multiple Providers](https://img.shields.io/badge/Multiple_Providers-4ECDC4?style=for-the-badge&logo=openai&logoColor=white)
![Local LLM](https://img.shields.io/badge/Local_LLM-4ECDC4?style=for-the-badge&logo=meta&logoColor=white)

<!-- Repository Stats -->
![License MIT](https://img.shields.io/github/license/Nickolaus/nix-dotfiles?style=for-the-badge&color=green)
![Last Commit](https://img.shields.io/github/last-commit/Nickolaus/nix-dotfiles?style=for-the-badge&color=blue)
![Contributors](https://img.shields.io/github/contributors/Nickolaus/nix-dotfiles?style=for-the-badge&color=orange)
![Repo Size](https://img.shields.io/github/repo-size/Nickolaus/nix-dotfiles?style=for-the-badge&color=purple)
![Lines of Code](https://img.shields.io/tokei/lines/github/Nickolaus/nix-dotfiles?style=for-the-badge&color=red)

<!-- Development Tools -->
![Fish Shell](https://img.shields.io/badge/Fish_Shell-00D4AA?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Neovim](https://img.shields.io/badge/Neovim-57A143?style=for-the-badge&logo=neovim&logoColor=white)
![tmux](https://img.shields.io/badge/tmux-1BB91F?style=for-the-badge&logo=tmux&logoColor=white)
![WezTerm](https://img.shields.io/badge/WezTerm-4E49EE?style=for-the-badge&logo=windows-terminal&logoColor=white)

<!-- macOS Specific -->
![AeroSpace WM](https://img.shields.io/badge/AeroSpace_WM-FF69B4?style=for-the-badge&logo=apple&logoColor=white)
![Hammerspoon](https://img.shields.io/badge/Hammerspoon-FF8C00?style=for-the-badge&logo=lua&logoColor=white)
![Homebrew](https://img.shields.io/badge/Homebrew_Integrated-FBB040?style=for-the-badge&logo=homebrew&logoColor=black)

<!-- AI Providers -->
![Ollama](https://img.shields.io/badge/Ollama-Local-2ECC71?style=for-the-badge&logo=meta&logoColor=white)
![OpenAI](https://img.shields.io/badge/OpenAI-Cloud-412991?style=for-the-badge&logo=openai&logoColor=white)
![Claude](https://img.shields.io/badge/Claude-Advanced-FF9500?style=for-the-badge&logo=anthropic&logoColor=white)

<!-- Quality & Maintenance -->
![Flake Check](https://img.shields.io/badge/Flake_Check-Passing-brightgreen?style=for-the-badge&logo=checkmark&logoColor=white)
![Auto Updates](https://img.shields.io/badge/Auto_Updates-Enabled-blue?style=for-the-badge&logo=dependabot&logoColor=white)
![Documentation](https://img.shields.io/badge/Documentation-Complete-success?style=for-the-badge&logo=gitbook&logoColor=white)

</div>

---

**A cross-platform Nix configuration for macOS (nix-darwin) and Linux (NixOS) with Home Manager integration.**

### 🚀 **Key Features**: AI Commit Messages • SOPS Encryption • Cross-Platform • Modern Tools

## ✨ Features

- 🍎 **macOS Support**: nix-darwin with AeroSpace window manager, Homebrew integration
- 🐧 **Linux Ready**: NixOS configuration structure (example included)
- 🏠 **Home Manager**: User-level configuration management
- 🔒 **Secrets Management**: SOPS-encrypted secrets with age
- 📦 **Package Management**: Organized cross-platform and platform-specific packages
- 🛠️ **Development Tools**: Go, PHP, Neovim, tmux, and more
- 🤖 **AI Commit Messages**: Multiple provider support (local, cloud) via opencommit
- 🎨 **Modern Terminal**: WezTerm with custom configuration
- ⌨️ **Automation**: Hammerspoon-based macOS window management and shortcuts

## 📋 Requirements

### Nix Installation
You need to install Nix, but we are not using their official installer. Instead, we are using the Determinate Systems Nix Installer. You can download it [here](https://install.determinate.systems/determinate-pkg/stable/Universal)!

**Important**: Determinate Systems provides two separate operations:
- **Configuration Application**: Use `sudo darwin-rebuild switch` to apply your dotfiles changes
- **System Upgrades**: Use `sudo determinate-nixd upgrade` to upgrade the Determinate Nix system itself

To update your Determinate Nix system to the latest release:
```bash
sudo determinate-nixd upgrade
```

To apply your configuration changes:
```bash
sudo darwin-rebuild switch --flake ~/.config/nix-dotfiles --show-trace
```

### Platform-Specific Requirements

#### macOS
- **Homebrew**: Some applications require Homebrew installation
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```

#### SOPS Secrets Management (Optional)

SOPS (Secrets OPerationS) encrypts secrets using age keys for secure storage in the repository.

##### Initial Setup

1. **Install required tools**:
   ```bash
   # SOPS and age are included in the nix packages, but for initial setup you might need:
   nix-shell -p sops age
   ```

2. **Generate age key pair**:
   ```bash
   # macOS (follows Apple's Application Support directory convention)
   mkdir -p "~/Library/Application Support/sops/age"
   age-keygen -o "~/Library/Application Support/sops/age/keys.txt"
   
   # Linux (follows XDG Base Directory specification)
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

3. **Note your public key**:
   ```bash
   # Your public key will be displayed during generation, save it!
   # It looks like: age1abc123def456...
   ```

4. **Configure .sops.yaml** (already configured in this repo):
   ```yaml
   keys:
     - &admin_key age1abc123def456...  # Your public key here
   creation_rules:
     - path_regex: secrets/.*\.yaml$
       key_groups:
         - age:
           - *admin_key
   ```

##### Managing Secrets

**Adding new secrets**:
```bash
# Create/edit encrypted file
sops home/features/secrets/example.yaml

# The file will open in your editor, add secrets in YAML format:
# api_key: "your-secret-value"
# database_password: "another-secret"
```

**Editing existing secrets**:
```bash
# Edit encrypted secrets file
sops home/features/secrets/example.yaml
```

**Viewing secrets** (for debugging):
```bash
# Decrypt and view (don't commit output!)
sops -d home/features/secrets/example.yaml
```

**Adding secrets to your configuration**:
```nix
# In any nix file where you need secrets:
sops.secrets.api_key = {
  sopsFile = ./secrets/example.yaml;
  owner = "C.Hessel";
};

# Use in configuration:
programs.some-app.apiKey = config.sops.secrets.api_key.path;
```

##### Key Management

**Backup your private key**:
```bash
# IMPORTANT: Backup your private key securely!
# Without it, you cannot decrypt your secrets
cp ~/.config/sops/age/keys.txt ~/backup-location/
# Or on macOS:
cp "~/Library/Application Support/sops/age/keys.txt" ~/backup-location/
```

**Adding team members**:
1. Get their age public key
2. Add to `.sops.yaml` keys section
3. Re-encrypt all secrets:
   ```bash
   # Re-encrypt all secrets with new keys
   find . -name "*.yaml" -path "./home/features/secrets/*" -exec sops updatekeys {} \;
   ```

**Key Locations by Platform**:
- **macOS**: `~/Library/Application Support/sops/age/keys.txt`
- **Linux**: `~/.config/sops/age/keys.txt`

##### Troubleshooting

**Common Issues**:
- **"no key could decrypt"**: Check if your private key is in the correct location
- **"failed to decrypt"**: Ensure your public key is in `.sops.yaml` and secrets were encrypted with it
- **"age: error"**: Verify age is installed and keys.txt has correct permissions (600)

**Verify setup**:
```bash
# Check if age key exists and has correct permissions
ls -la ~/.config/sops/age/keys.txt  # Linux
ls -la "~/Library/Application Support/sops/age/keys.txt"  # macOS

# Test encryption/decryption
echo "test: secret" | sops -e /dev/stdin
```

## 🚀 Quick Start

### 1. Clone Repository
```bash
git clone <your-repo-url> ~/.config/nix-dotfiles
cd ~/.config/nix-dotfiles
```

### 2. Initial Setup

#### Using the Install Script (Recommended)
```bash
./install.sh
```

#### Manual Setup (macOS)
```bash
nix run nix-darwin -- switch --flake ~/.config/nix-dotfiles
```

#### Manual Setup (Linux)
```bash
sudo nixos-rebuild switch --flake ~/.config/nix-dotfiles/
```

### 3. System Updates

Use the comprehensive update workflow to keep your system current:

#### Complete System Update (Recommended)
```bash
# Run the complete update workflow
./scripts/update-system.sh

# Or follow the manual steps below:
```

#### Manual Update Workflow

**Step 1: Check System Health**
```bash
# Check Determinate Systems daemon status
sudo determinate-nixd status

# Verify current configuration is valid
nix flake check
```

**Step 2: Update Determinate Systems (if needed)**
```bash
# Upgrade Determinate Nix to latest version
sudo determinate-nixd upgrade

# Verify upgrade completed successfully
sudo determinate-nixd status
```

**Step 3: Update Configuration**
```bash
# Update flake inputs to latest versions
nix flake update

# Validate updated configuration
nix flake check
```

**Step 4: Apply Changes**
```bash
# macOS: Apply configuration changes
sudo darwin-rebuild switch --flake ~/.config/nix-dotfiles/ --show-trace

# Linux: Apply configuration changes  
sudo nixos-rebuild switch --flake ~/.config/nix-dotfiles/ --show-trace
```

**Step 5: Verify System Health**
```bash
# Confirm Determinate Systems is healthy
sudo determinate-nixd status

# Test new functionality
# ... test your applications and tools
```

#### Quick Updates (Configuration Only)
```bash
# When you only need to apply configuration changes:
sudo darwin-rebuild switch --flake ~/.config/nix-dotfiles/ --show-trace  # macOS
sudo nixos-rebuild switch --flake ~/.config/nix-dotfiles/ --show-trace   # Linux
```

## 🤖 AI Tools Quick Start

After installation, you have AI commit message tools with **multiple provider support**:

### OpenCommit - AI Commit Messages
```bash
# Generate AI commit messages with your preferred provider
git add .
oco                    # Generate and commit with current provider

# Preview messages without committing
oco --dry-run         # See what message would be generated

# Provider Management (Multiple Provider System) - Auto-configures models!
oco-local             # Switch to Ollama (local)
oco-cloud             # Switch to OpenAI (cloud)
oco-claude            # Switch to Claude (cloud)
oco-provider status   # Show detailed provider information

# Health checks and configuration
oco-check             # Validate setup and service status
oco-provider          # Full provider management interface

# Conventional commit types (works with any provider)
oco-feat              # Generate feat: commit
oco-fix               # Generate fix: commit
oco-docs              # Generate docs: commit
```

### Ollama - Local LLM Server (Provider 1: Local & Private)
```bash
# Check if local AI server is running
ollama-health         # Service status and available models
ollama-setup          # Initial setup and model download

# Interactive AI chat
ollama run [model] "Explain this code:"
ollama run [model] "Help me debug this function:"

# Model management
ollama list           # Show downloaded models
ollama pull [model]   # Download model
```

### OpenAI & Claude - Cloud Providers (Providers 2 & 3: Premium Quality)
```bash
# SOPS-Encrypted API Key Management (Automatic!)
# 1. Add your API keys to encrypted secrets:
sops home/features/secrets/secrets.yaml

# Add these keys:
# openai_api_key: sk-proj-your-openai-key
# claude_api_key: sk-ant-your-claude-key

# 2. API keys are automatically loaded when switching providers:
oco-cloud             # Auto-loads OpenAI key from encrypted secrets
oco-claude            # Auto-loads Claude key from encrypted secrets

# No manual configuration needed - everything is automated!
```

### Provider Comparison
| Provider | Speed | Quality | Cost | Privacy | Best For |
|----------|-------|---------|------|---------|----------|
| **Ollama** | ⚡ 2-3s | 🎯 Very Good | 🆓 Free | 🔒 100% Private | Daily commits, experimentation |
| **OpenAI** | ⚡ 2s | 🌟 Excellent | 💰 ~$0.01/commit | ☁️ Cloud API | Production, complex changes |
| **Claude** | ⚡ 7s | 🧠 Advanced | 💰 ~$0.02/commit | ☁️ Cloud API | Complex reasoning, refactoring |

### Model Selection by Provider
- **Ollama**: Local models optimized for different tasks (coding, commits, general purpose)
- **OpenAI**: Range from cost-effective to premium models  
- **Claude**: Fast and advanced reasoning models available

**🔧 For detailed AI tools usage, see [TOOLS_CHEATSHEET.md](./TOOLS_CHEATSHEET.md#-ai--llm-tools)**

## 📊 AI Model Performance

**Performance testing demonstrates provider capabilities:**

<!-- BENCHMARK_RESULTS_START -->
### 🏆 Provider Performance Overview

**Provider Performance Characteristics:**
- **Ollama (Local)**: 2-4 second response times, no API costs
- **OpenAI**: ~2 second response times, excellent quality  
- **Claude**: ~7 second response times, advanced reasoning capabilities

### 📈 Benchmarking Tools

The configuration includes comprehensive benchmarking tools for testing different models and providers:
- Use `scripts/hot-benchmark.sh` for automated performance testing
- Compare models with `oco-model-switch` for optimal selection
- Provider-specific optimization built into each configuration

**📋 For detailed analysis and recommendations, see:** `results/benchmark-results-all.md`
<!-- BENCHMARK_RESULTS_END -->

**🎯 Run your own benchmarks:**
```bash
# Test all available models
scripts/hot-benchmark.sh

# Test specific models
scripts/hot-benchmark.sh -m [model1],[model2]
```

## 🔧 Git Integration & Workflow

**⚠️ CRITICAL: Nix is Git-aware - New files MUST be added before applying configuration!**

Nix flakes ignore untracked files, so any new configuration files won't be included in your build until they're added to git. This is a safety feature but can be confusing for new users.

### Pre-Apply Git Workflow

Always follow this sequence before applying configuration changes:

```bash
# 1. Check git status first
git status

# 2. Add any new files (REQUIRED)
git add .

# 3. Validate configuration
nix flake check

# 4. Apply changes
sudo darwin-rebuild switch --flake ~/.config/nix-dotfiles --show-trace
```

### Common Git-Related Issues

- **New files ignored**: If you created new `.nix` files but they're not taking effect, check `git status` and add them
- **Partial builds**: Configuration seems incomplete or missing features → likely untracked files
- **"File not found" errors**: Nix references files that exist but aren't tracked by git

### Git Status Check

Make it a habit to check git status before every configuration change:

```bash
# Quick status check
git status --porcelain

# If you see untracked files, add them:
git add .
```

**Remember**: Nix can only see what git can see. When in doubt, check `git status` first!

## 🏗️ Architecture

This configuration is organized using a modular, cross-platform architecture:

```
├── hosts/           # System configurations per machine
├── home/            # Home Manager user configurations  
├── modules/         # System-level modules (darwin/nixos/shared)
├── lib/             # Helper functions
└── overlays/        # Package overlays
```

**📖 For detailed architecture documentation, see [ARCHITECTURE.md](./ARCHITECTURE.md)**

## ⚙️ Configuration

### Adding a New Host
1. Create `hosts/new-host/default.nix`
2. Add host configuration to `flake.nix`
3. Create user-specific file `home/new-host.nix` if needed

### Adding Features
1. Create feature module:
   - **Simple feature**: `home/features/feature-name.nix`
   - **Complex feature**: `home/features/feature-name/default.nix`
2. Add import to `home/features/default.nix`
3. Configure feature-specific settings

### Adding Packages
Packages are organized by categories with emoji headers for easy navigation:

#### Cross-Platform Packages (`home/features/packages.nix`)
Add to appropriate category:
- 📦 Development Environment & Package Managers
- 🔐 Security & Secrets Management
- 🛠️ System Utilities & CLI Tools
- ☁️ Cloud & Infrastructure Tools
- 💻 Development Languages & Runtimes
- 🔧 Development Tools & Version Control
- And more categorized sections...

#### Platform-Specific Packages
- **macOS**: Add to `home/features/darwin/packages.nix` (Communication, AI Tools, IDEs, Design, etc.)
- **Linux**: Add to `home/features/linux/packages.nix` (Browsers, Desktop Environment, Games, etc.)

### Platform-Specific Customization
- **System Level**: Add modules to `modules/darwin/` or `modules/nixos/`
- **User Level**: Add features to `home/features/darwin/` or `home/features/linux/`
- **Conditional Logic**: Use `lib.mkIf pkgs.stdenv.isDarwin` for conditional activation

## 🍎 macOS-Specific Setup

### Keyboard Layout
1. Go to "System Settings > Keyboard > Text Input"
2. Click "Edit" to change layout
3. Add "German - Standard" layout if using German keyboard

### Key Remapping (Per-Keyboard Configuration)

This configuration uses a **hybrid approach**: nix-darwin provides basic Option ↔ Command swap for Windows keyboard compatibility, while System Settings handles per-keyboard customization for optimal workflow.

#### Automatic Configuration (nix-darwin)
The configuration automatically swaps Option ↔ Command via `userKeyMapping` to align Windows keyboards with Mac expectations:
- **Physical Alt key** (Windows) → **Option key** (Mac)
- **Physical Windows key** → **Command key** (Mac)

#### Manual System Settings Configuration
For optimal per-keyboard behavior, configure modifier keys manually:

**Path:** System Settings > Keyboard > Keyboard Shortcuts > Modifier Keys

##### Internal MacBook Keyboard
- **Control** → **Command** (⌘) - enables Ctrl+C/V for copy/paste
- **Command** → **Control** - makes Cmd key useful for terminal
- **Option** → **Option** (unchanged) - preserves AeroSpace shortcuts (Alt+1, Alt+2, etc.)
- **Caps Lock** → **Caps Lock** (unchanged)

**Result:** Simple Control ↔ Command swap while preserving AeroSpace workspace shortcuts

##### External Windows Keyboard (CHERRY/Generic)
- **Control** → **Command** (⌘) - enables Ctrl+C/V for copy/paste  
- **Option** → **Control** - useful for terminal commands
- **Command** → **Option** (⌥) - enables AeroSpace shortcuts via Windows key
- **Caps Lock** → **Caps Lock** (unchanged)

**Result:** Full Windows-to-Mac key mapping with consistent shortcuts across both keyboards

#### Verification
Test your setup:
```bash
# Internal keyboard: Ctrl+C, Option+2 (workspace switch)
# External keyboard: Ctrl+C, Win+2 (workspace switch)
# Both keyboards: Consistent copy/paste behavior
```

### Shell Configuration
Change default shell to the Nix-managed version:
```bash
# Find your shell path (look for Nix-managed shells)
cat /etc/shells

# Change default shell
chsh -s /run/current-system/sw/bin/fish  # or your preferred shell
```

### 🖥️ Monitor Management (AeroSpace + Hammerspoon)

This configuration includes intelligent monitor detection and automatic window layout management for external displays.

#### Features
- **Automatic Detection**: Detects when external monitors are connected/disconnected
- **Smart Layouts**: Automatically applies appropriate window layouts based on monitor orientation
- **LG HDR 4K Support**: Special handling for portrait-oriented displays

#### How It Works
- **Portrait Display (LG HDR 4K)**: Automatically uses horizontal splits (windows stack vertically)
- **Laptop Display**: Uses vertical splits (windows arrange side-by-side)
- **Hot-Plugging**: Detects monitor changes and reapplies layouts automatically

#### Manual Control
- **`Alt + Shift + M`**: Manually trigger layout detection and application
- **Debug**: Check Hammerspoon console for detailed monitoring logs

#### Configuration Files
- **AeroSpace**: `modules/darwin/aerospace/default.nix` (keyboard shortcuts)
- **Monitor Logic**: `home/features/darwin/keybindings/hammerspoon/config/MonitorManager.lua`
- **Workspaces**: Workspaces 6, 7, 8 are assigned to external monitors

#### Troubleshooting
```bash
# Check if AeroSpace is running
pgrep -fl aerospace

# View Hammerspoon console logs
# Open Hammerspoon app → Console (to see monitor detection messages)

# Test manual trigger
# Press Alt + Shift + M or run in Hammerspoon console:
MonitorManager.applyLayouts()
```

## 🧪 Testing

### Validate Configuration
```bash
nix flake check
```

### Test Build (Dry Run)
```bash
# macOS
nix build .#darwinConfigurations.zoidberg.system --dry-run

# Linux  
nix build .#nixosConfigurations.example-linux.config.system.build.toplevel --dry-run
```

## 🔧 Troubleshooting

### 🛡️ Safety First: Nix Cannot Break Your System

**Nix is designed to be extremely safe** - you cannot break your macOS system with these configurations:

#### ✅ What CANNOT Be Broken:
- **Core macOS system** - Nix doesn't touch `/System/`, `/usr/`, etc.
- **Boot process** - Your Mac will always boot normally
- **Existing applications** - Non-Nix apps remain untouched
- **User data** - Documents, photos, etc. are completely safe
- **System recovery** - macOS recovery mode always works

### 🔄 Rollback Mechanisms

If anything doesn't work as expected, you have multiple safety nets:

#### System (nix-darwin) Rollback
```bash
# List available system generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous generation
sudo nix-env --rollback --profile /nix/var/nix/profiles/system

# Switch to specific generation (replace 42 with desired number)
sudo nix-env --switch-generation 42 --profile /nix/var/nix/profiles/system
```

#### Home Manager Rollback
```bash
# List Home Manager generations
home-manager generations

# Rollback to previous generation (copy the path from generations output)
/nix/store/[hash]-home-manager-generation/activate
```

#### Emergency Fallback
```bash
# Use original shell if new shell doesn't work
/bin/bash

# Check system status
launchctl list | grep nix-daemon
```

### 🔍 Common Issues & Solutions

| **Issue** | **Symptoms** | **Solution** |
|-----------|--------------|--------------|
| **Build Failures** | `nix flake check` fails | Run with `--show-trace` for details |
| **Shell Issues** | Terminal doesn't start properly | Use `/bin/bash`, then rollback |
| **Missing Secrets** | SOPS decryption errors | Check age key location and permissions |
| **Platform Detection** | Wrong packages installed | Verify `pkgs.stdenv.isDarwin` logic |
| **Determinate Daemon Issues** | Service not responding | Check with `sudo determinate-nixd status` |
| **Permission Errors** | `/nix/store` access denied | Restart daemon: `sudo launchctl kickstart -k system/org.nixos.nix-daemon` |
| **Generation Not Found** | Rollback fails | List generations first, use valid number |

### 🚨 Step-by-Step Recovery

#### 1. Configuration Won't Build
```bash
# Check for syntax errors
nix flake check --show-trace

# Try building without applying
nix build .#darwinConfigurations.zoidberg.system --show-trace

# If successful, apply normally
sudo darwin-rebuild switch --flake . --show-trace
```

#### 2. System Feels Broken After Apply
```bash
# Check current generation
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous (second-to-last) generation
sudo nix-env --rollback --profile /nix/var/nix/profiles/system

# Reboot if necessary (usually not required)
sudo reboot
```

#### 3. Terminal/Shell Issues
```bash
# Use safe shell
/bin/bash

# Check what shell is set
echo $SHELL

# Reset to bash temporarily
chsh -s /bin/bash

# After fixing config, switch back
chsh -s /run/current-system/sw/bin/fish
```

#### 4. Home Manager Issues
```bash
# Check Home Manager status
home-manager generations

# Rollback Home Manager only
/nix/store/[previous-generation-hash]/activate

# Or rebuild Home Manager separately
home-manager switch --flake .
```

### 🔧 Determinate Systems Troubleshooting

#### Daemon Management
```bash
# Check daemon status and configuration
sudo determinate-nixd status

# Check current version
determinate-nixd version

# Upgrade to latest version
sudo determinate-nixd upgrade

# Restart daemon if needed
sudo launchctl kickstart -k system/org.nixos.nix-daemon
```

#### Configuration Issues
```bash
# Check Determinate Systems configuration
cat /etc/nix/nix.conf                    # Managed by Determinate (read-only)
cat /etc/nix/nix.custom.conf             # Your custom settings (if any)

# View your dotfiles Determinate config
cat hosts/shared/determinate.nix

# Test configuration validity
nix eval .#darwinConfigurations.zoidberg.system.config.system.stateVersion
```

#### Service Diagnostics
```bash
# Check if daemon is running
launchctl list | grep nix-daemon

# Check nix store integrity
nix store verify --all

# View daemon logs (if available)
sudo launchctl print system/org.nixos.nix-daemon
```

### 🆘 Recovery Options

#### Safe Recovery (Recommended)
```bash
# 1. Rollback system generation
sudo nix-env --rollback --profile /nix/var/nix/profiles/system

# 2. If daemon issues, restart Determinate service
sudo launchctl kickstart -k system/org.nixos.nix-daemon

# 3. Check daemon status
sudo determinate-nixd status
```

#### Advanced Recovery (If needed)
```bash
# Reset Determinate authentication (if auth issues)
sudo determinate-nixd auth reset

# Reinstall Determinate Nix (preserves configurations)
# Download latest from: https://install.determinate.systems/determinate-pkg/stable/Universal
# Or use command line:
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

### 📊 Health Check Commands

```bash
# Complete system health check
echo "=== Determinate Systems Status ===" && \
sudo determinate-nixd status && \
echo -e "\n=== Nix Store Health ===" && \
nix store verify --all && \
echo -e "\n=== Configuration Validity ===" && \
nix flake check --show-trace && \
echo -e "\n=== Current Generation ===" && \
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -3
```

### 📞 Getting Help

- **Configuration Errors**: Use `--show-trace` for detailed error messages
- **Architecture Questions**: Review [ARCHITECTURE.md](./ARCHITECTURE.md)
- **Determinate Issues**: Check daemon status with `sudo determinate-nixd status`
- **Platform Problems**: Verify platform detection logic with `uname -a`

**Remember**: 
- **Determinate Systems manages** `/etc/nix/nix.conf` - never modify it manually
- **Use** `/etc/nix/nix.custom.conf` for custom Nix configuration
- **Your dotfiles config** is in `hosts/shared/determinate.nix`
- **Nix is designed for safe experimentation** - you can always roll back!

## 📚 Resources

- [Nix Manual](https://nixos.org/manual/nix/stable/)
- [Home Manager Options](https://nix-community.github.io/home-manager/options.html)
- [nix-darwin Options](https://daiderd.com/nix-darwin/manual/index.html)
- [NixOS Options](https://search.nixos.org/options)
