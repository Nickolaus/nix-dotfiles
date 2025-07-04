{ pkgs, lib, ... }:
lib.mkIf pkgs.stdenv.isLinux {
  home.packages = with pkgs; [
    # ═══════════════════════════════════════════════════════════════════════════
    # 🌐 BROWSERS & WEB TOOLS
    # ═══════════════════════════════════════════════════════════════════════════
    firefox
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 💬 COMMUNICATION & COLLABORATION
    # ═══════════════════════════════════════════════════════════════════════════
    slack
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 💻 DEVELOPMENT ENVIRONMENTS & IDEs
    # ═══════════════════════════════════════════════════════════════════════════
    jetbrains.phpstorm
    code-cursor
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🖥️ DESKTOP ENVIRONMENT & WINDOW MANAGERS
    # ═══════════════════════════════════════════════════════════════════════════
    # gnome.gnome-terminal
    # ulauncher
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🛠️ SYSTEM UTILITIES (Linux)
    # ═══════════════════════════════════════════════════════════════════════════
    # Add Linux-specific utilities here
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🎨 DESIGN & CREATIVE TOOLS
    # ═══════════════════════════════════════════════════════════════════════════
    # Add design tools (GIMP, Inkscape, Blender, etc.)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 📊 PRODUCTIVITY & OFFICE
    # ═══════════════════════════════════════════════════════════════════════════
    # Add LibreOffice, note-taking apps, etc.
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🎵 MULTIMEDIA & ENTERTAINMENT
    # ═══════════════════════════════════════════════════════════════════════════
    # Add media players, audio/video tools, etc.
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🔧 DEVELOPMENT TOOLS (Linux-specific builds)
    # ═══════════════════════════════════════════════════════════════════════════
    # Add Linux-specific development utilities
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🎮 GAMES & ENTERTAINMENT
    # ═══════════════════════════════════════════════════════════════════════════
    # Add Steam, games, entertainment apps
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🔒 SECURITY TOOLS (Linux)
    # ═══════════════════════════════════════════════════════════════════════════
    # Add Linux-specific security utilities
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 📱 MOBILE DEVELOPMENT (Linux)
    # ═══════════════════════════════════════════════════════════════════════════
    # Add Android development tools, emulators, etc.
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🌐 LINUX DISTRIBUTION SPECIFIC
    # ═══════════════════════════════════════════════════════════════════════════
    # Add distribution-specific tools (apt alternatives, etc.)
  ];
} 