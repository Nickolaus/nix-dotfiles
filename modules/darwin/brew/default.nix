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
      "FelixKratz/formulae"  # SketchyBar - macOS status bar replacement
    ];

    # CLI tools not available or problematic in Nix
    brews = [
      "docker-credential-helper"  # Docker credential helper for secure storage of Docker credentials
      "argocd"                   # Declarative continuous delivery tool for Kubernetes
      "mysql-client"             # MySQL client for interacting with MySQL databases
      "television"               # Terminal-based TV streaming application
      "sketchybar"               # Highly customizable macOS status bar (requires system permissions)
    ];

    # GUI applications and system integrations
    casks = [
      "orbstack"            # Container management tool with better performance than the Nix version
      "hammerspoon"         # Automation tool for macOS, requires system access
      "gitify"              # GitHub notifications app for macOS
      "sourcetree"          # Git GUI client, not available in nixpkgs
      "babeledit"           # Localization editor for translating apps and websites
    ];
  };
}
