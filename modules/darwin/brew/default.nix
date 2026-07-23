{ pkgs
, ...
}: {
  # Homebrew configuration for packages not available or problematic in Nix on Darwin
  # Priority: Always try Nix first, use Homebrew as fallback
  # 
  # Use Homebrew when:
  # - Package not available in nixpkgs for Darwin
  # - Package exists but doesn't work properly (GUI apps, system integrations)
  # - Package requires system-level permissions or integrations
  # - Package is proprietary and not redistributable through Nix

  homebrew = {
    enable = true;
    global = {
      autoUpdate = false;
    };
    onActivation = {
      autoUpdate = false;
      cleanup = "none";
      upgrade = false;
    };

    # nix-darwin's cask submodule does not expose Homebrew Bundle's
    # `trusted: true` field. Keep this third-party cask fully qualified and
    # trust only that cask, not the whole tap.
    extraConfig = ''
      cask "TheBoredTeam/boring-notch/boring-notch", trusted: true
      cask "stablyai/orca/orca", trusted: true
    '';

    taps = [
      "aws/tap"
      "TheBoredTeam/boring-notch" # Required tap for the fully qualified boring-notch cask
      "stablyai/orca" # Required tap for the fully qualified orca cask (Orca IDE, bundles orca-cli)
    ];

    # CLI tools not available or problematic in Nix
    brews = [
      "nx" # Nx CLI via Homebrew; prefer brew for global CLI convenience
      "docker-credential-helper" # Docker credential helper for secure storage of Docker credentials
      "argocd" # Declarative continuous delivery tool for Kubernetes
      "mysql-client" # MySQL client for interacting with MySQL databases
      "television" # Terminal-based TV streaming application
      "angular-cli" # Angular CLI for creating and building Angular projects (not available in nixpkgs)
      "codeburn" # Local AI coding token/cost dashboard; Homebrew formula exists, no nixpkgs package
    ];

    # GUI applications and system integrations
    casks = [
      "claude" # Claude desktop app; not packaged in nixpkgs, Homebrew cask tracks current releases
      "cursor" # AI-powered code editor; Nix package is broken/unmaintained (v0.47.8), Homebrew provides latest (v2.1.46+)
      "lm-studio" # Local LLM desktop app; Homebrew cask tracks current releases (v0.4.18) vs nixpkgs lmstudio (v0.4.10)
      "orbstack" # Container management tool with better performance than the Nix version
      "utm" # Virtual machine manager for macOS (not available in nixpkgs)
      "android-platform-tools" # Official Android SDK platform-tools; newer than nixpkgs android-tools
      "openmtp" # Android MTP file transfer on macOS; use for phone storage access over USB
      "hammerspoon" # Automation tool for macOS, requires system access
      "gitify" # GitHub notifications app for macOS
      "sourcetree" # Git GUI client, not available in nixpkgs
      "babeledit" # Localization editor for translating apps and websites
      "bitwarden" # Password manager desktop app; Homebrew cask tracks current macOS releases
      "steam" # Gaming platform, not properly available in nixpkgs for Darwin
      {
        name = "logi-options+";
        greedy = true; # Include in cask upgrades despite Logitech's auto-updater marker.
      }
      "tigervnc" # VNC client/server app; nixpkgs package is currently marked broken on Darwin
      "ddpm" # Dell Display and Peripheral Manager for Dell monitors and webcams
      "shottr" # Lightweight screenshot tool with URL scheme API support
      "corelocationcli" # CLI tool for accessing Core Location services (requires location permissions)
      "libreoffice" # Free office suite (not available in nixpkgs for Darwin)
      "phpstorm" # PHP IDE
      "discord" # Voice and text chat
      "zed" # Fast native code editor; Homebrew cask tracks current macOS app releases
      "warp" # Agent-enabled terminal trial; Homebrew cask tracks current macOS app releases
      "ghostty" # GPU-accelerated terminal emulator; nixpkgs ghostty has no darwin platform support
      "t3-code" # Minimal GUI control plane for AI coding agents (t3.codes)
    ];
  };
}
