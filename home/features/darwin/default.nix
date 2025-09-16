{ ... }: {
  imports = [
    ./packages.nix
    ./shell.nix
    ./keybindings
    # ./sketchybar  # Disabled - using system built-in menu bar with boring-notch instead
  ];
} 