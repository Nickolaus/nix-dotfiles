{
  pkgs,
  lib,
  config,
  ...
}: {
  # SketchyBar System Configuration
  # A highly customizable status bar for macOS
  # The actual configuration is managed by Home Manager

  # SketchyBar is now managed via Homebrew for proper system integration
  # See modules/darwin/brew/default.nix

  # Menu bar configuration for SketchyBar compatibility
  system.defaults.NSGlobalDomain._HIHideMenuBar = true;  # Hide system menu bar for SketchyBar
} 