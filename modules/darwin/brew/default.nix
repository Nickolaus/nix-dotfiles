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
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };

    taps = [
      "aws/tap"
      "TheBoredTeam/boring-notch"  # Required tap for boring-notch cask
    ];

    # CLI tools not available or problematic in Nix
    brews = [
      "nx"                      # Nx CLI via Homebrew; prefer brew for global CLI convenience
      "docker-credential-helper"  # Docker credential helper for secure storage of Docker credentials
      "argocd"                   # Declarative continuous delivery tool for Kubernetes
      "mysql-client"             # MySQL client for interacting with MySQL databases
      "television"               # Terminal-based TV streaming application
      "angular-cli"              # Angular CLI for creating and building Angular projects (not available in nixpkgs)
    ];

    # GUI applications and system integrations
    casks = [
      "orbstack"            # Container management tool with better performance than the Nix version
      "utm"                 # Virtual machine manager for macOS (not available in nixpkgs)
      "hammerspoon"         # Automation tool for macOS, requires system access
      "karabiner-elements"  # Keyboard customization tool requiring system-level permissions and integration
      "gitify"              # GitHub notifications app for macOS
      "sourcetree"          # Git GUI client, not available in nixpkgs
      "babeledit"           # Localization editor for translating apps and websites
      "steam"               # Gaming platform, not properly available in nixpkgs for Darwin
      "logi-options+"       # For hardware settings (DPI, etc.) - disable gesture features to avoid conflicts with Hammerspoon
      "ddpm"                # Dell Display and Peripheral Manager for Dell monitors and webcams
      "fathom"              # AI meeting notetaker and analytics app, not available in nixpkgs
      "shottr"              # Lightweight screenshot tool with URL scheme API support
      "corelocationcli"     # CLI tool for accessing Core Location services (requires location permissions)
      "boring-notch"        # Dynamic notch enhancement for MacBooks with notch display
    ];
  };
}