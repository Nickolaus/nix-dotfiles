{ pkgs, lib, ... }:
{

  home.packages = with pkgs; [
    # ═══════════════════════════════════════════════════════════════════════════
    # 📦 DEVELOPMENT ENVIRONMENT & PACKAGE MANAGERS
    # ═══════════════════════════════════════════════════════════════════════════
    cachix       # Binary cache (works on all platforms)
    nixpkgs-fmt
    nh
    nixd         # Nix language server -- also what Serena's LSP backend uses for Nix-aware navigation
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🔐 SECURITY & SECRETS MANAGEMENT
    # ═══════════════════════════════════════════════════════════════════════════
    sops
    age
    _1password-cli

    # ═══════════════════════════════════════════════════════════════════════════
    # 🛠️ SYSTEM UTILITIES & CLI TOOLS
    # ═══════════════════════════════════════════════════════════════════════════
    jq
    jless                    # Interactive JSON viewer/explorer
    gnused
    ripgrep
    choose                   # Human-friendly cut/awk alternative
    unixtools.watch
    entr                     # File watcher for automatic command execution
    htop
    ncdu
    broot                    # Interactive directory tree navigator
    lsof
    upx                      # Binary compression tool
    coreutils
    pigz
    wget
    sshpass

    # ═══════════════════════════════════════════════════════════════════════════
    # 🌐 NETWORK & MONITORING TOOLS
    # ═══════════════════════════════════════════════════════════════════════════
    nmap
    bandwhich
    doggo                    # Modern dig replacement for DNS queries
    tailscale                # VPN mesh network CLI client
  ] ++ [

    # ═══════════════════════════════════════════════════════════════════════════
    # ☁️ CLOUD & INFRASTRUCTURE TOOLS
    # ═══════════════════════════════════════════════════════════════════════════
    kubectl
    kubectx
    kubernetes-helm
    kubent
    stern
    k9s
    istioctl
    kind
    awscli2
    ssm-session-manager-plugin
    terraform

    # ═══════════════════════════════════════════════════════════════════════════
    # 🐳 CONTAINER & DOCKER TOOLS
    # ═══════════════════════════════════════════════════════════════════════════
    docker-client
    docker-buildx
    dive

    # ═══════════════════════════════════════════════════════════════════════════
    # 💻 DEVELOPMENT LANGUAGES & RUNTIMES
    # ═══════════════════════════════════════════════════════════════════════════
    nodejs_24
    cargo
    uv
    (python3.withPackages (ps: with ps; [ pyyaml pytest ]))  # Python with pyyaml and pytest
    bun
    asdf-vm
    gnumake

    # ═══════════════════════════════════════════════════════════════════════════
    # 🔧 DEVELOPMENT TOOLS & VERSION CONTROL
    # ═══════════════════════════════════════════════════════════════════════════
    gh
    gh-dash                  # GitHub dashboard in terminal
    act
    just
    hyperfine
    tldr
    procs
    sd
    glow
    slides                   # Terminal-based presentations
    tokei
    mkcert
    opencommit              # AI-powered commit message generator
    npm-check-updates       # Find newer versions of package dependencies
    (ast-grep.overrideAttrs (old: { doCheck = false; }))  # Structural code search and rewriting (tests broken on macOS)
    buf                      # Protocol Buffers CLI tool
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🧪 TESTING & QUALITY ASSURANCE
    # ═══════════════════════════════════════════════════════════════════════════
    k6
    shellcheck
    shfmt
    yamllint

    # ═══════════════════════════════════════════════════════════════════════════
    # 🏢 ENTERPRISE & IDENTITY TOOLS
    # ═══════════════════════════════════════════════════════════════════════════
    ory
    acli                      # Atlassian Command Line Interface (Jira, Confluence, etc.)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🤖 AI & MACHINE LEARNING
    # ═══════════════════════════════════════════════════════════════════════════
    (lib.lowPrio ollama)     # Local LLM server (lowPrio: conflicts with symfony-cli's bin/generator)
    claude-code              # Agentic coding tool that lives in your terminal
    python3Packages.openai   # OpenAI Python client library with CLI capabilities
    cursor-cli               # Cursor CLI agent for AI-powered code editing
    codex                    # OpenAI's coding agent
    opencode                 # Multi-provider agentic coding CLI (opencode.ai)
    # Mistral's terminal coding agent (vibe, vibe-acp).
    #
    # doCheck/doInstallCheck: the pytestCheckHook suite runs in installCheckPhase
    # and has flaky Textual UI failures in a sandboxed build.
    #
    # vibe-rs buildInputs: rustPlatform's cargoUseSystemLibs exports
    # AWS_LC_SYS_USE_SYSTEM=1, and aws-lc-sys 0.45.0 panics rather than falling
    # back to its vendored copy when no system AWS-LC is present. Upstream
    # vibe-rs.nix does not list aws-lc, so the Rust TUI fails to build. Adding
    # aws-lc matches how every other nixpkgs consumer of aws-lc-sys declares it
    # (monolith, zed-editor), so this drops out once nixpkgs carries the same
    # one-line fix.
    (mistral-vibe.overrideAttrs (old: {
      doCheck = false;
      doInstallCheck = false;
      passthru = old.passthru // {
        vibe-rs = old.passthru.vibe-rs.overrideAttrs (o: {
          buildInputs = o.buildInputs ++ [ aws-lc ];
        });
      };
    }))
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 📊 DATA & ANALYTICS
    # ═══════════════════════════════════════════════════════════════════════════
    graphviz                 # Graph visualization and diagram generation tool
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🎨 MULTIMEDIA & CONTENT
    # ═══════════════════════════════════════════════════════════════════════════
    # Add multimedia tools here

    # ═══════════════════════════════════════════════════════════════════════════
    # 📱 MOBILE DEVELOPMENT
    # ═══════════════════════════════════════════════════════════════════════════
    # Add mobile dev tools here

    # ═══════════════════════════════════════════════════════════════════════════
    # 🌍 WEB DEVELOPMENT
    # ═══════════════════════════════════════════════════════════════════════════
    # Add web-specific tools here
  ];
}
