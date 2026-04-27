{ pkgs, lib, flake, ... }:
lib.mkIf pkgs.stdenv.isDarwin {
  home.packages = with pkgs; [
    # ═══════════════════════════════════════════════════════════════════════════
    # 📦 DEVELOPMENT TOOLS (Darwin-specific)
    # ═══════════════════════════════════════════════════════════════════════════
    devenv # Development environment (from nixpkgs)

    # ═══════════════════════════════════════════════════════════════════════════
    # 💬 COMMUNICATION & COLLABORATION
    # ═══════════════════════════════════════════════════════════════════════════
    # slack # Managed by Microsoft Company Portal

    # ═══════════════════════════════════════════════════════════════════════════
    # 🤖 AI & PRODUCTIVITY TOOLS
    # ═══════════════════════════════════════════════════════════════════════════
    # chatgpt # DMG source URL unreliable, install via Homebrew
    raycast
    # ═══════════════════════════════════════════════════════════════════════════
    # 💻 DEVELOPMENT ENVIRONMENTS & IDEs
    # ═══════════════════════════════════════════════════════════════════════════
    hoppscotch
    bruno # Open-source IDE for exploring and testing APIs
    insomnia # API client for REST, GraphQL, and gRPC

    # ═══════════════════════════════════════════════════════════════════════════
    # 🎨 DESIGN & CREATIVE TOOLS
    # ═══════════════════════════════════════════════════════════════════════════
    # Add macOS design tools here (Figma, Sketch alternatives, etc.)

    # ═══════════════════════════════════════════════════════════════════════════
    # 📱 MOBILE DEVELOPMENT (macOS)
    # ═══════════════════════════════════════════════════════════════════════════
    # Add iOS development tools here (if available in nixpkgs)

    # ═══════════════════════════════════════════════════════════════════════════
    # 🛠️ SYSTEM UTILITIES (macOS)
    # ═══════════════════════════════════════════════════════════════════════════
    betterdisplay # Display management tool for macOS
    # Screenshot functionality: Shottr is installed via Homebrew and triggered by Hammerspoon shortcuts.
    # Add macOS-specific utilities here

    # ═══════════════════════════════════════════════════════════════════════════
    # 📊 PRODUCTIVITY & OFFICE
    # ═══════════════════════════════════════════════════════════════════════════
    obsidian

    # ═══════════════════════════════════════════════════════════════════════════
    # 🎵 MULTIMEDIA & ENTERTAINMENT
    # ═══════════════════════════════════════════════════════════════════════════
    spotify

    # ═══════════════════════════════════════════════════════════════════════════
    # 🌐 BROWSERS & WEB TOOLS
    # ═══════════════════════════════════════════════════════════════════════════
    # Add macOS-specific browsers or web development tools

    # ═══════════════════════════════════════════════════════════════════════════
    # 🔧 DEVELOPMENT TOOLS (macOS-specific builds)
    # ═══════════════════════════════════════════════════════════════════════════
    # Add macOS-specific development utilities

    # ═══════════════════════════════════════════════════════════════════════════
    # 🎮 GAMES & ENTERTAINMENT
    # ═══════════════════════════════════════════════════════════════════════════
    # Add games or entertainment apps
  ];
}
