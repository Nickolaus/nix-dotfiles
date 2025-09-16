{ pkgs, flake, ... }: {

  home.packages = with pkgs; [
    # ═══════════════════════════════════════════════════════════════════════════
    # 📦 DEVELOPMENT ENVIRONMENT & PACKAGE MANAGERS
    # ═══════════════════════════════════════════════════════════════════════════
    flake.inputs.devenv.packages.${system}.devenv
    cachix
    nixpkgs-fmt
    
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
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🌐 NETWORK & MONITORING TOOLS
    # ═══════════════════════════════════════════════════════════════════════════
    nmap
    bandwhich
    dogdns                   # Modern dig replacement for DNS queries
    httpie                   # User-friendly HTTP client (modern curl)
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
    terraform_1
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🐳 CONTAINER & DOCKER TOOLS
    # ═══════════════════════════════════════════════════════════════════════════
    docker-client
    docker-buildx
    dive
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 💻 DEVELOPMENT LANGUAGES & RUNTIMES
    # ═══════════════════════════════════════════════════════════════════════════
    nodejs_22
    cargo
    uv
    (python3.withPackages (ps: with ps; [ pyyaml ]))  # Python with pyyaml package
    bun
    mise
    asdf-vm
    gnumake
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🔧 DEVELOPMENT TOOLS & VERSION CONTROL
    # ═══════════════════════════════════════════════════════════════════════════
    gh
    gh-dash                  # GitHub dashboard in terminal
    act
    just
    watchexec
    hyperfine
    tldr
    procs
    sd
    glow
    slides                   # Terminal-based presentations
    tokei
    mkcert
    commitizen               # Interactive commit message builder
    opencommit              # AI-powered commit message generator
    npm-check-updates       # Find newer versions of package dependencies
    ast-grep                 # Structural code search and rewriting
    
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
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🤖 AI & MACHINE LEARNING
    # ═══════════════════════════════════════════════════════════════════════════
    ollama                   # Local LLM server
    claude-code              # Agentic coding tool that lives in your terminal
    openai                   # OpenAI Python client library with CLI capabilities
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 📊 DATA & ANALYTICS
    # ═══════════════════════════════════════════════════════════════════════════
    # Add data processing tools here
    
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

