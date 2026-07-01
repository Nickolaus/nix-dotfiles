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
![OpenCommit](https://img.shields.io/badge/OpenCommit-Integrated-4ECDC4?style=for-the-badge&logo=git&logoColor=white)

<!-- Repository Stats -->|
![License MIT](https://img.shields.io/github/license/Nickolaus/nix-dotfiles?style=for-the-badge&color=green)
![Last Commit](https://img.shields.io/github/last-commit/Nickolaus/nix-dotfiles?style=for-the-badge&color=blue)
![Contributors](https://img.shields.io/github/contributors/Nickolaus/nix-dotfiles?style=for-the-badge&color=orange)
![Repo Size](https://img.shields.io/github/repo-size/Nickolaus/nix-dotfiles?style=for-the-badge&color=purple)


<!-- Development Tools -->
![Fish Shell](https://img.shields.io/badge/Fish_Shell-00D4AA?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Neovim](https://img.shields.io/badge/Neovim-57A143?style=for-the-badge&logo=neovim&logoColor=white)
![tmux](https://img.shields.io/badge/tmux-1BB91F?style=for-the-badge&logo=tmux&logoColor=white)
![WezTerm](https://img.shields.io/badge/WezTerm-4E49EE?style=for-the-badge&logo=windows-terminal&logoColor=white)

<!-- macOS Specific -->
![AeroSpace WM](https://img.shields.io/badge/AeroSpace_WM-FF69B4?style=for-the-badge&logo=apple&logoColor=white)
![Hammerspoon](https://img.shields.io/badge/Hammerspoon-FF8C00?style=for-the-badge&logo=lua&logoColor=white)
![Homebrew](https://img.shields.io/badge/Homebrew_Integrated-FBB040?style=for-the-badge&logo=homebrew&logoColor=black)


<!-- Configuration -->
![Flake Check](https://img.shields.io/badge/Flake_Check-Passing-brightgreen?style=for-the-badge&logo=checkmark&logoColor=white)

</div>

---

**A cross-platform Nix configuration for macOS (nix-darwin) and Linux (NixOS) with Home Manager integration.**

### **Key Features**: Automated Commits • Encrypted Secrets • Cross-Platform • Development Tools

## ✨ Features

- 🍎 **macOS Support**: nix-darwin with AeroSpace window manager, Homebrew integration
- 🐧 **Linux Ready**: NixOS configuration structure (example included)
- 🏠 **Home Manager**: User-level configuration management
- 🔒 **Secrets Management**: SOPS-encrypted secrets with age
- 📦 **Package Management**: Organized cross-platform and platform-specific packages
- 🛠️ **Development Tools**: Go, PHP, Neovim, tmux, and more
- 🤖 **Automated Commits**: AI-generated commit messages via opencommit
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

**SSH key management example**:
```bash
# Work repositories under ~/Programming/work use ~/.ssh/id_ed25519
mkdir -p ~/Programming/work
cd ~/Programming/work
git clone git@github.com:company/repo.git

# Personal repositories under ~/Programming/personal use ~/.ssh/id_ed25519_personal
mkdir -p ~/Programming/personal
cd ~/Programming/personal
git clone git@github.com:user/repo.git
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

# Explicitly opt into mutable Homebrew upgrades for declared packages
./scripts/update-system.sh --upgrade-brew

# Explicitly preview and prune undeclared Homebrew packages
./scripts/update-system.sh --prune-brew

# Or follow the manual steps below:
```

By default the update script keeps Homebrew activation idempotent: it renders
the nix-darwin Brewfile, updates Homebrew metadata, and installs missing
declared packages with `brew bundle --no-upgrade`. Existing Homebrew versions
are only upgraded when `--upgrade-brew` is passed, and undeclared packages are
only removed when `--prune-brew` is passed.

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

**Step 4: Converge Homebrew Declarations (macOS)**
```bash
# Rendered by nix-darwin during activation; shown here for manual workflows
nix eval --raw .#darwinConfigurations.zoidberg.config.homebrew.brewfile > /tmp/nix-dotfiles-Brewfile
brew update
HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --file=/tmp/nix-dotfiles-Brewfile --no-upgrade --jobs=1

# Optional mutable upgrades for declared packages only
./scripts/update-system.sh --upgrade-brew

# Optional destructive pruning after preview and confirmation
./scripts/update-system.sh --prune-brew
```

**Step 5: Apply Changes**
```bash
# macOS: Apply configuration changes
sudo darwin-rebuild switch --flake ~/.config/nix-dotfiles/ --show-trace

# Linux: Apply configuration changes  
sudo nixos-rebuild switch --flake ~/.config/nix-dotfiles/ --show-trace
```

**Step 6: Verify System Health**
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

# Provider management
oco-local             # Switch to Ollama (local)
oco-cloud             # Switch to OpenAI (cloud)
oco-claude            # Switch to Claude (cloud)
oco-provider status   # Show detailed provider information

# Health checks and configuration
oco-check             # Validate setup and service status
oco-provider          # Full provider management interface
oco-profile           # Inspect or switch the local commit/general/coding profiles

# Conventional commit types (works with any provider)
oco-feat              # Generate feat: commit
oco-fix               # Generate fix: commit
oco-docs              # Generate docs: commit
```

### Local AI - Declarative Ollama Profiles
```bash
# Service and profile status
llm-status            # Default backend, coding backend, session proxy, contexts, residency
llm-models            # Declared profiles, service mapping, endpoints, install status
llm-doctor            # Reachability, cloud-disable state, session proxy, profile/install checks
llm-logs              # Tail all local AI logs
llm-logs coding       # Tail only the coding-endpoint log
llm-logs session      # Tail only the session-proxy log

# Coding-session lifecycle
llm-session start coding    # Preload qwen3-coder on the coding backend
llm-session refresh coding  # Extend the current coding idle window
llm-session status coding   # Show residency, PROCESSOR, CONTEXT, UNTIL
llm-session finish coding   # Explicitly unload the coding model

# Explicit model installation
llm-pull commit       # tavernari/git-commit-message:latest
llm-pull general      # qwen3:8b-q4_K_M
llm-pull coding       # qwen3-coder:30b-a3b-q4_K_M
llm-pull all          # Pull all declared profiles

# Interactive and one-shot usage
llm-run general "Explain this code"
llm-run coding        # Interactive coding shell on the raw 64k coding backend
llm-smoke coding      # Sanity-check the coding profile through the session proxy

# Local coding agents
llm-codex-local       # Launch Codex via managed defaults against the session proxy
llm-claude-local      # Launch Claude Code via ~/.claude/settings.json against the session proxy
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
- **Ollama**: Shared declarative local profiles for commit, general, and coding tasks
- **OpenAI**: Range from cost-effective to premium models  
- **Claude**: Fast and advanced reasoning models available

### Local Profile Catalog
- **`commit`**: `tavernari/git-commit-message:latest` for fast local commit generation
- **`general`**: `qwen3:8b-q4_K_M` for lightweight local chat and explanations
- **`coding`**: `qwen3-coder:30b-a3b-q4_K_M` for heavier local coding workflows on the dedicated 64k coding stack
- **Unsupported locally on this machine**: `qwen3-coder:480b`
- **Expected disk for declared models**: about `28.6 GB`

### Session-Aware Coding Endpoint
- **Default backend**: `http://127.0.0.1:11434`
- **Raw coding backend**: `http://127.0.0.1:11435`
- **Session-aware coding proxy**: `http://127.0.0.1:11436`
- The proxy exists so coding-agent traffic refreshes model residency through real requests instead of relying only on a long static timeout.
- The proxy also defaults Qwen coding traffic to non-thinking mode unless the client explicitly asks for reasoning.
- `keep_alive=10m` means 10 minutes after the last completed request, not 10 minutes after startup.
- Unsent typing in Cursor or Cline does not refresh residency; submitted requests do.
- `llm-session finish coding` is the intended task-finished path when you want memory back immediately.
- Codex, Claude Code, and Cursor all derive shared defaults from `aiAgents`.
- Ownership is tool-specific:
  - Codex shared defaults: `/etc/codex/managed_config.toml`
  - Codex user state and trust: `~/.codex/config.toml`
  - Cursor global MCP config: `~/.cursor/mcp.json`
  - Claude Code settings: `~/.claude/settings.json`
  - Claude Code global MCPs are merged into the top-level `mcpServers` section of `~/.claude.json`
- Project-specific MCPs should stay tool-native and local to the project:
  - Codex: `.codex/config.toml`
  - Cursor: `.cursor/mcp.json`
  - Claude Code: `.mcp.json`
- MCP transport schema in `aiAgents`:
  - `type = "http"` uses `url` and optional `headers`
  - `type = "stdio"` uses `command`, optional `args`, and optional `env`
  - `targetOverrides.<codex|claude|cursor>` customizes one logical MCP server per client
- GitHub MCP is HTTP, not stdio.
- Serena is installed from a pinned upstream flake and exposed through `aiAgents` for Codex, Claude Code, and Cursor. Use it for live symbol-aware code navigation/refactoring; keep Graphify for durable repo graphs and visualizations.
- Serena's dashboard remains enabled for diagnostics, but managed MCP launches pass `--open-web-dashboard False` so agents do not open browser tabs on startup.
- Serena initialization is explicit via `serena-init-lsp` or `serena-init-jetbrains`. Project-local `.serena/` files are per-repo decisions, not globally managed dotfiles.
- `codebase-memory-mcp` is built from its pinned upstream flake and exposed through `aiAgents` for Codex, Claude Code, and Cursor. It's a zero-token, always-on structural code graph (call graphs, dead code, Cypher queries, git-diff impact) — prefer it over grep for "who calls X" / "what breaks if I change Y" questions on indexed repos. Graphify remains the tool for deep, cross-document (code + docs + papers + media) architecture exploration invoked on demand.
- `codebase-memory-mcp` indexes lazily on first tool call (or via `config set auto_index true`) and persists its graph at `~/.cache/codebase-memory-mcp/`; run `codebase-memory-status` to check the pinned package and PATH resolution.
- `headroom` (context compression) runs as an `uvx`-resolved MCP server (`headroom_compress`/`headroom_retrieve`/`headroom_stats`, exposed via `aiAgents`) plus a persistent local proxy (launchd, port 8787, macOS) that speaks both the Anthropic and OpenAI-compatible wire protocols and compresses real cloud LLM traffic before forwarding it — no separate gateway tool needed since it already covers Claude Code, Codex, OpenCode, and (manually, via Cursor's own Settings — it has no config file/env var for this) Cursor. Run `headroom-status` for health; use `headroom-claude` / `headroom-codex` / `headroom-opencode` to opt a session into compressed cloud traffic — the default `claude`/`codex`/`opencode` commands are untouched (see `TOOLS_CHEATSHEET.md`).
- `opencode` (opencode.ai) is installed from nixpkgs as a general multi-provider coding CLI, in addition to its Headroom wrapper above.
- For Cline or Cursor local coding, point the provider to `http://127.0.0.1:11436`.
- Prefer one local coding agent at a time on this machine. The coding endpoint is single-request (`NUM_PARALLEL=1`), so running Cline and Roo together turns waits into queue time very quickly.

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
- Compare local profiles with `llm-models`, `llm-smoke`, `llm-status`, and `oco-profile status`
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
3. Add "German - Standard" layout for German external keyboards

Check the active input source:
```bash
defaults read com.apple.HIToolbox AppleCurrentKeyboardLayoutInputSourceID
```

### Key Remapping (Per-Keyboard Configuration)

This configuration uses **per-keyboard modifier mappings** written by Home Manager. It does not use `userKeyMapping` because that overrides per-device mappings.

#### Automatic Configuration (Home Manager)
Per-keyboard modifier mappings are applied in `home/features/darwin/keybindings/default.nix`:

- **All Keyboards (default 0-0-0)**:
  - **Command** -> **Option**
  - **Option** -> **Control**
  - **Control** -> **Command**
- **Home-office CHERRY keyboard (`046A:00DF`, macOS profile `1130-223-0`)**:
  - **Control** <-> **Command**
  - **Alt/Option** unchanged
- **Office Logitech MX Keys (`046D:B35B`, macOS profile `1133-45915-0`)**:
  - **Control** <-> **Command**
  - **Alt/Option** unchanged
  - **Caps Lock** explicitly remains **Caps Lock**

#### Notes
- Built-in modifier changes may require **logout/login** to take effect.
- System Settings can be used to inspect the active modifier keys, but changes should be made in Nix for persistence.
- The `zoidberg` host enables these mappings with `remapKeys = true`.
- Global `hidutil UserKeyMapping` should remain unset. If `ioreg` shows a live per-device `UserKeyMapping` for MX Keys, check Logi Options+ or reconnect the keyboard after activation.

#### Verification
Inspect the declared per-device mappings:
```bash
defaults -currentHost read -g com.apple.keyboard.modifiermapping.1130-223-0
defaults -currentHost read -g com.apple.keyboard.modifiermapping.1133-45915-0
hidutil property --get UserKeyMapping
hidutil list --matching '{"Product":"MX Keys"}'
```

### Shell Configuration
Change default shell to the Nix-managed version:
```bash
# Find your shell path (look for Nix-managed shells)
cat /etc/shells

# Change default shell
chsh -s /run/current-system/sw/bin/fish  # or your preferred shell
```

### Application Configuration
#### PhpStorm Keymap
This setup expects the **XWin Keymap** plugin to be installed in PhpStorm (JetBrains Marketplace). The keymap CSV is managed in `home/features/editors/phpstorm/winx_keymap.csv`, but the plugin still needs a one-time manual install.

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

### 🖱️ Mouse Gesture Automation (Logitech MX Master 3S)

Configure your MX Master 3S gesture button to trigger workspace and window management using existing keyboard shortcuts.

#### ✅ Recommended Setup

**In Logitech Options+:**
1. **Open Logitech Options+** and select your MX Master 3S
2. **Go to "Buttons" or "Gestures" tab**
3. **Configure the Gesture Button (thumb button):**

| **Gesture** | **Action** | **Keystroke** | **Function** |
|-------------|------------|---------------|--------------|
| **← Left**  | Send Keys  | `Alt+Shift+P` | Previous workspace |
| **→ Right** | Send Keys  | `Alt+Shift+N` | Next workspace |
| **↑ Up**    | Send Keys  | `Cmd+Ctrl+F` | **Toggle Fullscreen** |
| **↓ Down**  | Send Keys  | `Cmd+Shift+X` | **Shottr area capture** |
| **Click Only** | Send Keys  | `Ctrl+↑` | **Mission Control** (window overview) |

#### 🎯 Why This Setup Works Great

**Perfect for any display orientation:**
- **Left/Right**: Workspace navigation (direction-independent)
- **Up**: Fullscreen toggle - works in all macOS apps, intuitive (up = bigger)
- **Down**: Screenshot selection - incredibly useful for documentation/sharing
- **Click**: Mission Control - quick window overview without accidental screenshots

**No spatial confusion** with rotated displays - these are app-level and system-level actions.

#### 🔄 Alternative Options (If You Prefer Different Actions)

**Screenshot Alternatives:**
- **Down**: `Cmd+Ctrl+Shift+X` → Full screen Shottr capture
- **Down**: `Cmd+Ctrl+Shift+W` → Window Shottr capture
- **Down**: `Cmd+Shift+4` → Native macOS screenshot selection

#### Screenshot Shortcuts

**macOS (Shottr via Hammerspoon):**
- `Cmd+Shift+X`: area capture
- `Cmd+Ctrl+Shift+X`: fullscreen capture
- `Cmd+Ctrl+Shift+W`: window capture
- `Cmd+Ctrl+Shift+S`: scrolling capture
- `Cmd+Ctrl+Shift+R`: repeat previous area capture
- `Cmd+Ctrl+Shift+O`: OCR

These are logical macOS shortcuts as seen by Hammerspoon after the keyboard modifier mappings in `home/features/darwin/keybindings/default.nix` have been applied. Logitech Options+ should send the shortcut shown in macOS, for example `Cmd+Shift+X` for the mouse down gesture, even if the physical keyboard has Control and Command remapped.

Configuration lives in:
- `home/features/darwin/keybindings/hammerspoon/config/ScreenshotShortcuts.lua`: Shottr URL bindings
- `home/features/darwin/keybindings/hammerspoon/config/init.lua`: loads the screenshot shortcut module
- `home/features/darwin/keybindings/hammerspoon/default.nix`: links `~/.hammerspoon` and reloads Hammerspoon when the config source changes

The Hammerspoon activation hook reloads through `hs.ipc` when available. If IPC is unavailable, it restarts Hammerspoon and only records the reload marker after IPC responds again. This prevents a failed reload from being treated as successfully applied.

Useful checks:
```bash
# Confirm the generated Hammerspoon files are linked
ls -la ~/.hammerspoon/init.lua ~/.hammerspoon/ScreenshotShortcuts.lua

# Confirm Hammerspoon IPC is available
hs -c 'return "hammerspoon-ok"'

# List active Shottr hotkeys
hs -c 'for _, h in ipairs(hs.hotkey.getHotkeys()) do if h.msg and string.match(h.msg, "Shottr") then print(h.idx .. " " .. h.msg) end end'
```

**Linux (Hyprland):**
- `Print`: area capture to clipboard
- `Shift+Print`: area capture to Swappy for annotation
- `Super+Print`: area capture saved to `~/Pictures`

**Window Management Alternatives:**
- **Up**: `Alt+Shift+Space` → Toggle floating/tiling layout (Aerospace-specific)
- **Down**: `Cmd+H` → Hide current app (more reversible than minimize)

**Quick Access Alternatives:**
- **Up**: `Alt+Enter` → Open new terminal
- **Down**: `Alt+B` → Open Chrome browser

**Click-Only Alternatives:**
- **Click**: `Alt+Tab` → App switcher
- **Click**: `F3` → Mission Control (alternative shortcut)

#### 🚫 What NOT to Configure

**Avoid conflicts by keeping Options+ simple:**
- Don't use gesture button for "Default" mouse actions
- Don't enable "Smart Actions" that might interfere
- Use Options+ **only** for DPI, polling rate, and battery settings
- Keep gesture detection **only** for the thumb button

#### ✅ Why This Works

1. **Display-agnostic**: No directional confusion with rotated/portrait monitors
2. **Universal shortcuts**: `Cmd+Ctrl+F` and `Ctrl+↑` work system-wide in all apps
3. **Intuitive mapping**: Up = bigger (fullscreen), Down = overview (Mission Control)
4. **Reliable**: Uses standard HID keyboard events
5. **Integrated**: Leverages existing Aerospace workspace shortcuts  
6. **Conflict-free**: No event interception issues
7. **Persistent**: Survives system updates and reboots

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
nix build .#nixosConfigurations.farnsworth.config.system.build.toplevel --dry-run
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
