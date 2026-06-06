# 🛠️ Development Tools Cheatsheet

A comprehensive reference for all the enhanced tools in your nix-dotfiles configuration.

## 📋 Table of Contents

- [🖥️ Monitor Management](#️-monitor-management)
- [🔧 Git Workflow](#-git-workflow)
- [🤖 AI & LLM Tools](#-ai--llm-tools)
- [🖥️ Enhanced Tmux](#️-enhanced-tmux)
- [⚡ Workflow Automation](#-workflow-automation)
- [📊 System Monitoring](#-system-monitoring)
- [🌐 Network Tools](#-network-tools)
- [💻 Development Environment](#-development-environment)
- [🧪 Code Quality & Testing](#-code-quality--testing)
- [📝 Documentation & Viewing](#-documentation--viewing)
- [🚀 Productivity Utilities](#-productivity-utilities)

---

## 🖥️ Monitor Management

### AeroSpace + Hammerspoon Integration

**Automatic monitor detection and window layout management for external displays.**

#### Key Features
- **Intelligent Detection**: Automatically detects LG HDR 4K and other external monitors
- **Dynamic Layouts**: Switches between horizontal and vertical window splits based on display orientation
- **Hot-Plug Support**: Responds to monitor connection/disconnection events
- **Workspace Assignment**: Workspaces 6, 7, 8 are assigned to external monitors

#### Keyboard Shortcuts
```bash
# Manual layout trigger
Alt + Shift + M      # Force re-detect monitors and apply appropriate layouts

# Workspace navigation (External monitor workspaces)
Alt + F1             # Switch to workspace 6 (LG HDR 4K)
Alt + F2             # Switch to workspace 7 (LG HDR 4K)  
Alt + F3             # Switch to workspace 8 (LG HDR 4K)

# Move windows to external monitor workspaces
Alt + Shift + F1     # Move window to workspace 6 and follow
Alt + Shift + F2     # Move window to workspace 7 and follow
Alt + Shift + F3     # Move window to workspace 8 and follow
```

#### Automatic Behavior
```bash
# When LG HDR 4K is connected (Portrait mode):
# - Workspaces 6, 7, 8 use horizontal splits (windows stack vertically)
# - Perfect for rotated 4K displays

# When LG HDR 4K is disconnected (Laptop only):
# - Workspaces 6, 7, 8 use vertical splits (windows arrange side-by-side)
# - Optimized for laptop screen aspect ratio
```

#### Monitoring & Debugging
```bash
# Check AeroSpace status
pgrep -fl aerospace

# View current workspace
/run/current-system/sw/bin/aerospace list-workspaces --focused

# List windows in workspace
/run/current-system/sw/bin/aerospace list-windows --workspace 6

# Hammerspoon Console (for debug logs)
# Open Hammerspoon app → Console
# Look for "MonitorManager" messages
```

#### Configuration Files
- **AeroSpace Config**: `modules/darwin/aerospace/default.nix`
- **Monitor Detection**: `home/features/darwin/keybindings/hammerspoon/config/MonitorManager.lua`
- **Initialization**: `home/features/darwin/keybindings/hammerspoon/config/init.lua`

#### Troubleshooting
```bash
# Force trigger monitor detection
Alt + Shift + M

# Check Hammerspoon console for errors
# Open Hammerspoon → Console

# Test monitor detection manually (in Hammerspoon console)
MonitorManager.applyLayouts()

# Restart AeroSpace service
launchctl kickstart -k gui/$(id -u)/org.nixos.aerospace

# Restart Hammerspoon
# Hammerspoon → Reload Config
```

---

## 🔧 Git Workflow

### Lazygit - Terminal Git UI
```bash
# Start lazygit in current repo
lazygit

# Key bindings inside lazygit:
# j/k          - Navigate up/down
# h/l          - Navigate left/right between panels
# space        - Stage/unstage files
# c            - Commit
# P            - Push
# p            - Pull
# enter        - View diff/details
# q            - Quit
# ?            - Help
```

### Delta - Enhanced Git Diff (Already configured!)
```bash
# Your git is already configured to use delta automatically
git diff              # Shows beautiful syntax-highlighted diffs
git log -p            # Shows commit history with enhanced diffs
git show HEAD         # Shows last commit with delta formatting
```

---

## 🤖 AI & LLM Tools

### OpenCommit - AI-Powered Commit Messages (Tri-Provider System)

**Generate intelligent commit messages using your choice of three AI providers: local Ollama, cloud OpenAI, or advanced Claude.**

#### Quick Start - Any Provider
```bash
# Stage your changes and generate commit message
git add .
oco                   # Generate and commit with current provider

# Dry run (preview without committing)
oco --dry-run        # See what message would be generated
```

#### Provider Management (Core Feature)
```bash
# Switch between providers
oco-local            # Switch to Ollama → tavernari/git-commit-message:latest
oco-cloud            # Switch to OpenAI → gpt-4o-mini  
oco-claude           # Switch to Claude → claude-3-5-haiku-20241022
oco-provider         # Full provider management interface

# Provider status and health
oco-check            # Comprehensive health check for current provider
oco-provider status  # Detailed provider information and diagnostics

# Setup commands
oco-provider setup   # Interactive API key configuration (OpenAI/Claude)
```

#### Local Profile Selection
```bash
# Inspect or switch the local Ollama-backed profiles used by OpenCommit
oco-profile          # Show current provider/model + commit/general/coding profiles
oco-profile status
oco-profile commit   # Reset to the declarative commit profile
oco-profile general  # Use the lightweight general local profile
oco-profile coding   # Use the heavier coding local profile
oco-profile default  # Alias for commit
```

#### Core OpenCommit Commands
```bash
# Main commands (work with any provider)
oco                   # Generate commit message (alias: opencommit)
oc                    # Short alias for opencommit

# Git hook integration  
oco-hook-enable       # Enable automatic commit message generation
oco-hook-disable      # Disable git hook integration

# Configuration and diagnostics
oco-config           # View/edit opencommit settings
oco-config-get       # Show current configuration
```

#### Conventional Commit Types (Work with All Providers)
```bash
# Generate commits with specific types
oco-feat             # feat: commit message
oco-fix              # fix: commit message  
oco-docs             # docs: commit message
oco-style            # style: commit message
oco-refactor         # refactor: commit message
oco-test             # test: commit message
oco-chore            # chore: commit message
```

#### Provider-Specific Features

##### 🏠 Ollama (Local Provider)
```bash
# Switch to local provider
oco-local                    # Automatically sets model: tavernari/git-commit-message:latest

# Configuration:
# - API URL: http://127.0.0.1:11434/api/chat (default local endpoint)
# - Default Model: tavernari/git-commit-message:latest (commit-optimized)
# - Shared local profiles: commit / general / coding
# - Coding profile route: http://127.0.0.1:11436 (raw backend: http://127.0.0.1:11435)
# - Cost: 100% Free
# - Privacy: 100% Local (never leaves your machine)
# - Speed: 2-3 seconds (varies by model size)
```

##### ☁️ OpenAI (Cloud Provider)
```bash
# Switch to OpenAI provider
oco-cloud                    # Automatically sets model: gpt-4o-mini

# Configuration:
# - API URL: https://api.openai.com/v1
# - Default Model: gpt-4o-mini (cost-effective)
# - Alternative: gpt-4o (premium quality)
# - Cost: ~$0.01 per commit message
# - Privacy: Data sent to OpenAI
# - Speed: ~2 seconds
# - API Key: Auto-loaded from SOPS encrypted secrets
```

##### 🧠 Claude (Advanced Provider)
```bash
# Switch to Claude provider 
oco-claude                   # Automatically sets model: claude-3-5-haiku-20241022

# Configuration:
# - API URL: https://api.anthropic.com/v1
# - Default Model: claude-3-5-haiku-20241022 (fast)
# - Alternative: claude-3-5-sonnet-20241022 (advanced reasoning)
# - Cost: ~$0.02 per commit message
# - Privacy: Data sent to Anthropic
# - Speed: ~7 seconds
# - API Key: Auto-loaded from SOPS encrypted secrets
```

#### SOPS Secret Management (Automatic!)
```bash
# API keys are automatically loaded from encrypted secrets
# No manual configuration required!

# To add/update API keys:
sops home/features/secrets/secrets.yaml

# Add these entries:
# openai_api_key: sk-proj-your-openai-key-here
# claude_api_key: sk-ant-your-claude-key-here

# Keys are automatically loaded when switching providers
oco-cloud    # Loads OpenAI key from secrets
oco-claude   # Loads Claude key from secrets
```

#### Performance Comparison
| Provider | Speed | Quality | Cost | Privacy | Best Use Case |
|----------|-------|---------|------|---------|---------------|
| **Ollama** | 2-3s | Very Good | Free | 100% Local | Daily commits, experimentation |
| **OpenAI** | 2s | Excellent | $0.01/commit | Cloud | Production commits, team projects |
| **Claude** | 7s | Advanced | $0.02/commit | Cloud | Complex refactoring, detailed analysis |

#### Optimized Configuration 
Your opencommit system is pre-optimized with:
- **Input Tokens**: 32,768 (4x increase for multi-file context)
- **Output Tokens**: 300 (prevents truncation)
- **Format**: Conventional commits with clear descriptions
- **Language**: English
- **Behavior**: No auto-push, concise messages

### Ollama - Local LLM Server

**Run large language models locally for privacy and offline use.**

#### Service Management
```bash
# Health and status
llm-status           # Check default backend, coding backend, session proxy, and residency
llm-models           # Show declarative local profiles and install state
llm-doctor           # Check endpoints, session proxy, installs, cloud-disable state, codex/claude presence
llm-logs             # Tail default, coding, and session-proxy logs
llm-logs coding      # Tail the coding-endpoint log only
llm-logs session     # Tail the session-proxy log only

# Coding session lifecycle
llm-session start coding    # Preload qwen3-coder and start a warm coding session
llm-session refresh coding  # Refresh the coding idle timer to 10m
llm-session status coding   # Show residency, PROCESSOR, CONTEXT, UNTIL
llm-session finish coding   # Explicitly unload the coding model

# Model management
llm-pull commit      # Pull tavernari/git-commit-message:latest
llm-pull general     # Pull qwen3:8b-q4_K_M
llm-pull coding      # Pull qwen3-coder:30b-a3b-q4_K_M
llm-pull all         # Pull all declared profiles
```

#### Declarative Profiles
```bash
# commit  -> tavernari/git-commit-message:latest via default endpoint (11434)
# general -> qwen3:8b-q4_K_M via default endpoint (11434)
# coding  -> qwen3-coder:30b-a3b-q4_K_M via session endpoint (11436), backed by coding endpoint (11435)
# 480b is intentionally not part of the local profile catalog on this machine
```

#### Interactive Usage
```bash
# Run a declared profile
llm-run general
llm-run coding      # Interactive shell uses the raw coding backend

# One-shot commands
llm-run general "Explain this bash command: ls -la"
llm-run coding "Write a Nix module for an Ollama model pin"

# Smoke tests
llm-smoke general
llm-smoke coding    # Goes through the session-aware coding proxy

# Local coding agents
llm-codex-local      # Uses managed Codex defaults via the session proxy
llm-claude-local     # Uses ~/.claude/settings.json via the session proxy
```

#### Service Configuration
- **Host**: `127.0.0.1` (localhost only for security)
- **Default Endpoint**: `11434` with `32768` context
- **Raw Coding Endpoint**: `11435` with `65536` context
- **Session Proxy Endpoint**: `11436`, forwarding to `11435`
- **Idle Keep-Alive**: `10m` on both backends
- **Parallel Requests**: `1`
- **Max Loaded Models**: `1`
- **Queue Limit**: `32`
- **Coding Proxy Defaults**: injects `think=false` for native Ollama chat/generate and `reasoning_effort=none` for OpenAI-compatible chat unless the client overrides it
- **Cloud Features**: disabled via `OLLAMA_NO_CLOUD=1` and `~/.ollama/server.json`
- **Acceleration**: Apple Silicon Metal via the standard Ollama runtime; not forced to CPU-only
- **Coding Flash Attention**: enabled
- **Coding KV Cache**: `q8_0`
- **Models**: Stored in `~/.ollama/models/`
- **Logs**:
  - default endpoint: `~/.ollama/logs/server.log`
  - coding endpoint: `~/.local/state/ollama/coding-server.log`
  - session proxy: `~/.local/state/ollama/session-proxy.log`

#### Session Behavior
- `keep_alive=10m` means 10 minutes after the last completed request, not after service start
- Submitted coding-agent requests through `11436` refresh residency automatically
- Unsent editor typing does not refresh the model
- The session proxy defaults the coding route to non-thinking mode so Qwen does not spend editor time on hidden reasoning unless a client opts in explicitly
- Use `llm-session finish coding` when a task is done and you want to release memory immediately
- Prefer one local coding agent at a time. Cline and Roo share the same single-request coding backend, so running both together mostly creates queueing, not throughput

#### Agent Config Ownership
- Shared defaults come from `aiAgents`
- Codex shared defaults are rendered to `/etc/codex/managed_config.toml`
- Codex keeps `~/.codex/config.toml` user-owned for trust state and project config layering
- Cursor global MCP config is managed at `~/.cursor/mcp.json`
- Claude Code settings are managed at `~/.claude/settings.json`
- Claude Code global MCPs are merged into the top-level `mcpServers` section of `~/.claude.json`
- Project-specific MCPs should remain project-local:
  - Codex: `.codex/config.toml`
  - Cursor: `.cursor/mcp.json`
  - Claude Code: `.mcp.json`
- MCP transport schema:
  - `type = "http"` uses `url` and optional `headers`
  - `type = "stdio"` uses `command`, optional `args`, and optional `env`
- GitHub MCP is HTTP, not stdio

#### Troubleshooting
```bash
# Check service status
llm-status
llm-doctor

# View service logs
llm-logs
llm-logs coding
llm-logs session

# Check disk space (models can be large)
df -h ~/.ollama/
```

#### Local Profile Catalog
| Profile | Model | Use Case | Size |
|--------|-------|----------|------|
| `commit` | `tavernari/git-commit-message:latest` | Fast local commit messages | ~4.4GB |
| `general` | `qwen3:8b-q4_K_M` | Lightweight chat and explanations | ~5.2GB |
| `coding` | `qwen3-coder:30b-a3b-q4_K_M` | Local coding agents and heavier code tasks | ~19GB |

**Total if you install all declared local profiles**: about `28.6 GB`

#### Integration Examples
```bash
# Use with opencommit
git add .
oco                  # Uses configured model for commit messages

# Quick model switching for different local tasks
oco-profile coding   # Temporarily use the coding profile and coding endpoint
git add .
oco                  # Generate commit with coding model

oco-profile commit   # Switch back to the default commit profile
```

#### Advanced Configuration
```bash
# Custom model setup for specific projects
echo 'OCO_MODEL="qwen3-coder:30b-a3b-q4_K_M"' > .env    # Unmanaged ad hoc model override

# Batch commit with different models
oco-profile commit && git add . && oco        # Use commit-optimized model
oco-profile coding && git add . && oco        # Use code-optimized model

# Performance monitoring
time llm-run general "test prompt"
llm-status
```

#### Privacy & Security
- **Local Processing**: All AI processing happens on your machine
- **No API Keys**: No external API calls or data sharing
- **Offline Capable**: Works without internet connection once models are downloaded
- **Data Privacy**: Your code never leaves your machine

---

## 🖥️ Enhanced Tmux

### New Prefix: `Ctrl+A` (instead of Ctrl+B)

### Essential Commands
```bash
# Session management
tmux new-session -s myproject    # Create named session
tmux attach -t myproject         # Attach to session
tmux list-sessions              # List all sessions
tmux kill-session -t myproject  # Kill session

# Your custom function (already configured)
t                               # Fuzzy-find and attach to session
```

### Key Bindings (Prefix = Ctrl+A)
```bash
# Window/Pane Management
Ctrl+A |             # Split horizontally (new!)
Ctrl+A -             # Split vertically (new!)
Ctrl+A c             # Create new window
Ctrl+A &             # Kill window
Ctrl+A x             # Kill pane

# Navigation (No prefix needed!)
Alt + Arrow Keys     # Navigate between panes
Shift + Arrow Keys   # Navigate between windows

# Copy Mode (Vim-style)
Ctrl+A [             # Enter copy mode
v                    # Start selection (in copy mode)
y                    # Copy selection (in copy mode)
Ctrl+A ]             # Paste

# Useful Commands
Ctrl+A r             # Reload tmux config
Ctrl+A z             # Zoom/unzoom current pane
Ctrl+A ,             # Rename window
Ctrl+A $             # Rename session
```

---

## ⚡ Workflow Automation

### Just - Modern Command Runner
```bash
# List available commands
just --list
just -l

# Run commands
just build           # Run build task
just test            # Run test task
just dev             # Run dev server

# Create a justfile example:
# build:
#     echo "Building project..."
#     npm run build
# 
# test:
#     echo "Running tests..."
#     npm test
```

### Watchexec - File Watcher
```bash
# Watch for changes and run command
watchexec -e .js npm test                    # Run tests when JS files change
watchexec -e .ts -e .tsx npm run build      # Build when TS files change
watchexec -w src npm run dev                 # Watch src directory
watchexec -i node_modules npm test          # Ignore node_modules

# Advanced options
watchexec -r npm run dev                     # Restart long-running processes
watchexec -d 1000 npm test                   # Debounce for 1 second
```

### Hyperfine - Benchmarking
```bash
# Compare command performance
hyperfine 'grep -r "pattern" .' 'rg "pattern"'

# Benchmark with warmup runs
hyperfine --warmup 3 'npm run build'

# Export results
hyperfine --export-markdown results.md 'command1' 'command2'
hyperfine --export-json results.json 'command1' 'command2'

# Multiple runs for statistical accuracy
hyperfine --runs 10 'your-command'
```

---

## 📊 System Monitoring

### Determinate Systems Nix Management

#### Complete System Update Workflow
```bash
# Recommended: Use the comprehensive update script
./scripts/update-system.sh           # Full system update with proper workflow

# Or follow manual steps:
sudo determinate-nixd status         # 1. Check daemon health
sudo determinate-nixd upgrade        # 2. Upgrade Determinate Nix
nix flake update                     # 3. Update configuration inputs
sudo darwin-rebuild switch --flake ~/.config/nix-dotfiles --show-trace  # 4. Apply changes
sudo determinate-nixd status         # 5. Verify system health
```

#### Determinate Systems Management
```bash
# Health checks and status
sudo determinate-nixd status          # Overall daemon status and configuration
determinate-nixd version              # Check installed version
sudo determinate-nixd status --verbose  # Detailed status information

# Upgrades and maintenance
sudo determinate-nixd upgrade         # Upgrade to latest version
sudo determinate-nixd upgrade --version v3.6.8  # Upgrade to specific version
sudo determinate-nixd upgrade --check  # Check if upgrade is available

# Daemon management
sudo launchctl kickstart -k system/org.nixos.nix-daemon  # Restart daemon
sudo determinate-nixd restart        # Restart Determinate daemon

# Authentication (FlakeHub integration)
determinate-nixd login                # Login to FlakeHub
determinate-nixd auth logout          # Logout from FlakeHub
sudo determinate-nixd auth reset      # Reset authentication

# Configuration and troubleshooting
cat /etc/nix/nix.conf                # View managed config (read-only)
cat /etc/nix/nix.custom.conf         # View custom config (if exists)
cat hosts/shared/determinate.nix     # View dotfiles Determinate config

# Support and diagnostics
determinate-nixd help                 # Show available commands
determinate-nixd bug "Issue title" "Description"  # File bug report
```

#### Update System Script

**Primary Update Tool:**
```bash
# Complete system update (recommended)
./scripts/update-system.sh

# Show available options
./scripts/update-system.sh --help

# Preview operations without executing
./scripts/update-system.sh --dry-run
```

**Script Features:**
- ✅ Automated health checks (before/after)
- ✅ Proper Determinate Systems upgrade sequence
- ✅ Interactive prompts with confirmation
- ✅ Colored output and progress indicators
- ✅ Error handling with rollback instructions
- ✅ Optional cleanup of old generations, Nix store GC, store optimisation, and safe cache pruning
- ✅ Platform detection (macOS/Linux)

#### Update Workflows by Scenario

**Daily/Weekly Updates:**
```bash
./scripts/update-system.sh           # Complete system update
```

**Configuration-Only Changes:**
```bash
sudo darwin-rebuild switch --flake ~/.config/nix-dotfiles --show-trace
```

**Determinate-Only Upgrade:**
```bash
sudo determinate-nixd upgrade
sudo determinate-nixd status
```

**Emergency Health Check:**
```bash
sudo determinate-nixd status
nix flake check
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -3
```

### Bottom - Modern System Monitor
```bash
# Start bottom (better than htop)
btm
bottom

# Key bindings in bottom:
# q            - Quit
# /            - Search processes
# dd           - Kill selected process
# Tab          - Switch between widgets
# +/-          - Zoom in/out on graphs
# e            - Expand/collapse process tree
```

### Duf - Disk Usage (Better df)
```bash
# Show disk usage for all mounted filesystems
duf

# Show specific filesystems
duf /home /var

# Hide specific filesystem types
duf --hide-fs tmpfs,devtmpfs

# JSON output
duf --json
```

### Dust - Directory Size (Better du)
```bash
# Show directory sizes in current directory
dust

# Analyze specific directory
dust ~/Projects

# Limit depth
dust -d 3

# Show sizes in different units
dust -b          # Bytes
dust -k          # Kilobytes
dust -m          # Megabytes
dust -g          # Gigabytes

# Number of files to show
dust -n 20
```

### Ncdu - Visual Disk Usage
```bash
# Analyze current directory (interactive)
ncdu

# Analyze specific directory
ncdu ~/Downloads

# Key bindings in ncdu:
# j/k or ↑/↓   - Navigate
# Enter        - Enter directory
# d            - Delete selected item
# g            - Show item graph
# i            - Show item info
# r            - Recalculate
# q            - Quit
```

---

## 🌐 Network Tools

### Bandwhich - Network Usage by Process
```bash
# Show network usage (requires sudo on some systems)
sudo bandwhich

# Show specific interface
bandwhich -i eth0

# Key bindings:
# q            - Quit
# space        - Pause
# tab          - Switch between views
```

### Ngrok - Secure Tunnels
```bash
# Expose local port to internet
ngrok http 3000                    # Expose port 3000
ngrok http 8080                    # Expose port 8080

# With custom subdomain (paid plans)
ngrok http -subdomain=myapp 3000

# TCP tunneling
ngrok tcp 22                       # Expose SSH

# Configuration file at ~/.ngrok2/ngrok.yml
```

### Nmap - Network Discovery
```bash
# Scan local network
nmap 192.168.1.0/24

# Scan specific host
nmap example.com

# Port scan
nmap -p 22,80,443 example.com

# Service detection
nmap -sV example.com

# OS detection
nmap -O example.com
```

---

## 💻 Development Environment

### Mise - Runtime Version Manager
```bash
# Install runtime versions
mise install node@20              # Install Node.js 20
mise install python@3.11          # Install Python 3.11
mise install go@1.21              # Install Go 1.21

# Use specific versions
mise use node@20                  # Use Node 20 in current project
mise use python@3.11              # Use Python 3.11
mise global node@20               # Set global Node version

# List available versions
mise list-remote node             # Available Node versions
mise list node                    # Installed Node versions

# Current versions
mise current                      # Show all current versions

# Configuration
# Create .mise.toml in project root:
# [tools]
# node = "20"
# python = "3.11"
```

### ASDF-VM - Alternative Runtime Manager
```bash
# Add plugins
asdf plugin add nodejs
asdf plugin add python

# Install versions
asdf install nodejs 20.0.0
asdf install python 3.11.0

# Set versions
asdf local nodejs 20.0.0          # For current project
asdf global nodejs 20.0.0         # Globally

# List versions
asdf list nodejs                  # Installed versions
asdf list all nodejs              # Available versions
```

### Mkcert - Local HTTPS Certificates
```bash
# Install local CA
mkcert -install

# Create certificates
mkcert localhost                   # For localhost
mkcert example.local              # For custom domain
mkcert '*.example.local'          # Wildcard certificate

# Multiple domains
mkcert localhost 127.0.0.1 ::1

# Custom certificate authority
mkcert -CAROOT                     # Show CA location
```

---

## 🧪 Code Quality & Testing

### Shellcheck - Shell Script Analysis
```bash
# Check shell script
shellcheck script.sh

# Check with specific shell
shellcheck -s bash script.sh
shellcheck -s zsh script.sh

# Exclude specific warnings
shellcheck -e SC2034 script.sh     # Exclude unused variable warning

# Different output formats
shellcheck -f json script.sh       # JSON output
shellcheck -f gcc script.sh        # GCC-style output

# Check multiple files
shellcheck *.sh
```

### Shfmt - Shell Script Formatter
```bash
# Format and display
shfmt script.sh

# Format in place
shfmt -w script.sh

# Format with specific options
shfmt -i 2 script.sh               # 2-space indentation
shfmt -ci script.sh                # Indent case statements
shfmt -bn script.sh                # Put binary operators at start of line

# Format all shell files
shfmt -w *.sh

# Check if files are formatted
shfmt -d *.sh
```

### Yamllint - YAML Validation
```bash
# Validate YAML file
yamllint config.yaml

# Validate multiple files
yamllint *.yaml *.yml

# Custom config
yamllint -c .yamllint.yaml file.yml

# Different output formats
yamllint -f parsable config.yaml   # Machine-readable format
yamllint -f colored config.yaml    # Colored output

# Disable specific rules
yamllint -d '{extends: default, rules: {line-length: disable}}' file.yml
```

### K6 - Load Testing
```bash
# Run load test
k6 run script.js

# With virtual users and duration
k6 run --vus 10 --duration 30s script.js

# With different stages
k6 run --stage 5m:10 --stage 10m:20 --stage 5m:0 script.js

# Output results
k6 run --out json=results.json script.js
```

---

## 📝 Documentation & Viewing

### Glow - Markdown Viewer
```bash
# View markdown file
glow README.md

# View with pager
glow -p README.md

# View from URL
glow https://raw.githubusercontent.com/user/repo/main/README.md

# Style options
glow -s dark README.md             # Dark theme
glow -s light README.md            # Light theme

# List available styles
glow -l

# Word wrap
glow -w 80 README.md               # Wrap at 80 characters
```

### Tldr - Simplified Man Pages
```bash
# Get quick examples for commands
tldr git
tldr curl
tldr ssh
tldr docker

# Update tldr database
tldr --update

# List all available pages
tldr --list

# Random example
tldr --random

# Different platforms
tldr -p linux git
tldr -p osx git
```

### Tree - Directory Structure
```bash
# Show directory tree
tree

# Limit depth
tree -L 2                          # Show 2 levels deep
tree -L 3 ~/Projects              # Show 3 levels in specific directory

# Show hidden files
tree -a

# Show only directories
tree -d

# Ignore patterns
tree -I 'node_modules|.git'

# File size information
tree -s

# Output to file
tree > directory_structure.txt
```

---

## 🚀 Productivity Utilities

### Tokei - Code Statistics
```bash
# Count lines of code in current directory
tokei

# Specific directory
tokei ~/Projects/myapp

# Specific languages
tokei --type rust
tokei -t javascript -t typescript

# Exclude files/directories
tokei --exclude '*.json' --exclude node_modules

# Output formats
tokei --output json               # JSON output
tokei --output yaml               # YAML output

# Sort by lines of code
tokei --sort code
```

### Procs - Modern Process Viewer
```bash
# Show all processes
procs

# Search processes
procs nginx                       # Show processes containing "nginx"
procs -c cpu                     # Sort by CPU usage
procs -c mem                     # Sort by memory usage

# Tree view
procs --tree

# Show specific columns
procs --only pid,name,cpu,mem

# Watch mode (like top)
procs --watch
```

### Sd - Find and Replace
```bash
# Basic find and replace
sd 'old_text' 'new_text' file.txt

# In-place replacement
sd -p 'old_text' 'new_text' file.txt

# Regular expressions
sd '\b\d{3}-\d{2}-\d{4}\b' '[REDACTED]' file.txt

# Multiple files
sd 'old_text' 'new_text' *.txt

# Preview changes (dry run)
sd 'old_text' 'new_text' file.txt  # Shows changes without applying

# Case insensitive
sd -s 'Old_Text' 'new_text' file.txt
```

### Fd - Fast File Find (Already in shell config)
```bash
# Find files by name
fd pattern

# Find in specific directory
fd pattern ~/Documents

# Find by extension
fd -e js                          # Find JavaScript files
fd -e md -e txt                   # Find markdown and text files

# Include hidden files
fd -H pattern

# Execute command on results
fd -e js -x wc -l                 # Count lines in JS files
```

### Ripgrep - Fast Text Search (Already configured)
```bash
# Search for text
rg pattern

# Search in specific file types
rg pattern -t js                  # Search in JavaScript files
rg pattern -t py                  # Search in Python files

# Case insensitive
rg -i pattern

# Show context
rg -C 3 pattern                   # 3 lines of context
rg -A 2 -B 2 pattern             # 2 lines after and before

# Search and replace preview
rg pattern --replace replacement
```

---

## 🔄 Integration Examples

### Combining Tools for Powerful Workflows

```bash
# Monitor project while developing
watchexec -e .js -e .css 'npm run build && echo "Build complete!"'

# Analyze project structure and size
echo "=== Project Overview ===" && \
tree -I 'node_modules|.git' -L 3 && \
echo -e "\n=== Code Statistics ===" && \
tokei

# Git workflow with enhanced tools
lazygit                           # Interactive git management
# Then use your existing git aliases with delta

# System monitoring combination
btm                              # Overall system view
# In another pane: bandwhich      # Network usage
# In another pane: ncdu           # Disk usage

# Development environment setup
mise use node@20 python@3.11     # Set up runtimes
mkcert localhost                  # Create HTTPS cert
ngrok http 3000                   # Expose to internet if needed
```

---

## 💡 Pro Tips

1. **Tmux + Tools**: Use tmux panes to run multiple monitoring tools simultaneously
2. **Aliases**: Create aliases for frequently used commands in your shell config
3. **Just + Watchexec**: Combine for automatic task running during development
4. **Hyperfine**: Use for A/B testing different implementations
5. **Mise**: Prefer over nvm/rbenv for consistent cross-language version management
6. **Glow**: Perfect for reading project READMEs without leaving terminal

---

## 🐟 Fish Shell Plugins

The fish shell configuration includes several productivity-enhancing plugins to improve your command line experience.

### Autopair Plugin
```bash
# Automatically closes parentheses, quotes, brackets
echo "hello    # → automatically adds closing quote: echo "hello"
git log --grep=(    # → automatically adds closing paren: git log --grep=()
```

### Done Plugin
```bash
# Get desktop notifications when long-running commands finish
# Automatically triggers for commands taking longer than 5 seconds
npm install           # You'll get a notification when it completes
./long-running-script.sh   # Desktop notification on completion
```

### Sponge Plugin
```bash
# Automatically removes failed commands from history
# Failed commands won't clutter your command history
invalid-command       # This won't appear in your history if it fails
git pus               # Typos that fail are automatically cleaned up
```

### Colored Man Pages
```bash
# All man pages are automatically colorized for better readability
man git               # Color-coded sections and syntax highlighting
man fish              # Better visual hierarchy in documentation
```

### GRC (Generic Colouriser)
```bash
# Automatically colorizes output of common commands
ping google.com       # Colorized ping output
ps aux               # Color-coded process list
df -h                # Colored disk usage
netstat -tuln        # Colored network connections
```

### Forgit Plugin
```bash
# Interactive git commands using fzf - available after shell restart
glo                  # Interactive git log with fzf
gss                  # Interactive git status
gaa                  # Interactive git add
gcf                  # Interactive git checkout file
gbd                  # Interactive git branch delete
grh                  # Interactive git reset HEAD
```

### Plugin-Git 
```bash
# Enhanced git aliases and functions
gs                   # git status
ga                   # git add
gc                   # git commit
gp                   # git push
gl                   # git pull
gco                  # git checkout
```

### Bass Plugin
```bash
# Run bash utilities in fish shell
bass source ~/.bashrc    # Source bash configuration
bass export VAR=value    # Set environment variables bash-style
```

### Foreign-Env Plugin
```bash
# Source bash/zsh environment files
fenv source ~/.bashrc    # Import bash environment
fenv source some-script.sh   # Source bash scripts
```

### Pisces Plugin
```bash
# Smart auto-matching for quotes and brackets
echo "hello    # → closes quote automatically
git log --grep=(  # → adds closing parenthesis
[1, 2, 3    # → completes bracket
```

### Fish Abbreviation Tips Plugin
```bash
# Get helpful tips when typing commands that have shorter abbreviations
docker ps                # → 💡 dps => docker ps
kubectl get pods         # → 💡 kgp => kubectl get pods
lazygit                  # → 💡 lg => lazygit
```

### Custom Abbreviations Available

#### 🐳 Docker & Containers
```bash
d        # docker
dc       # docker-compose
dps      # docker ps
di       # docker images
dcup     # docker-compose up -d
dcdown   # docker-compose down
```

#### ☸️ Kubernetes
```bash
kc       # kubectl
kgp      # kubectl get pods
kgs      # kubectl get services
kgd      # kubectl get deployments
kdp      # kubectl describe pod
kl       # kubectl logs
```

#### 📁 File Operations
```bash
la       # eza -la --icons
lt       # eza --tree --icons
lz       # eza -la --icons | head -20
```

#### 🔍 Search & Find
```bash
rg       # rg --color=always
fd       # fd --color=always
bat      # bat --style=numbers,changes
```

#### 📦 Package Management
```bash
nr       # nix-rebuild
ns       # nix search nixpkgs
nsh      # nix-shell
nb       # nix build
```

#### 🚀 Development
```bash
v        # nvim
lg       # lazygit
t        # tmux
ta       # tmux attach
tn       # tmux new-session
```

#### 🌐 Network & System
```bash
ping     # ping -c 4
ports    # netstat -tuln
myip     # curl -s ifconfig.me
```

#### 📊 System Monitoring
```bash
btm      # btm --color always
htop     # btm (aliased to bottom)
df       # duf
du       # dust
ps       # procs
```

### Enhanced Features Summary

🔍 **Better Navigation**
- `fzf-fish`: Enhanced fuzzy finding for files, history, processes
- Interactive command history with Ctrl+R

🧠 **Smart Productivity** 
- `autopair`: Auto-close brackets, quotes, parentheses
- `pisces`: Advanced bracket/quote matching
- `sponge`: Auto-remove failed commands from history
- `fish-abbreviation-tips`: Shows helpful tips for available abbreviations

🎨 **Visual Improvements**
- `colored-man-pages`: Colorized documentation

🔧 **Git Workflow**
- `forgit`: Interactive git with fzf integration
- `plugin-git`: Comprehensive git aliases

🚀 **Environment Integration**
- `bass`: Run bash utilities seamlessly
- `foreign-env`: Import bash/zsh configurations

*This cheatsheet covers the enhanced tools added to your nix-dotfiles configuration. All tools are installed and ready to use in your development environment.* 
