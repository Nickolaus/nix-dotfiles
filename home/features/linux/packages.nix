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
    # 🤖 AI & PRODUCTIVITY TOOLS (mirrored from macOS where available)
    # ═══════════════════════════════════════════════════════════════════════════
    # chatgpt - not available on Linux
    # raycast - macOS only, use rofi/ulauncher as alternative
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 💻 DEVELOPMENT ENVIRONMENTS & IDEs
    # ═══════════════════════════════════════════════════════════════════════════
    jetbrains.phpstorm
    code-cursor
    hoppscotch
    bruno  # Open-source IDE for exploring and testing APIs
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🖥️ DESKTOP ENVIRONMENT & WINDOW MANAGERS
    # ═══════════════════════════════════════════════════════════════════════════
    # Hyprland and Waybar configured via modules
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🛠️ SYSTEM UTILITIES (Linux)
    # ═══════════════════════════════════════════════════════════════════════════
    ksnip  # Screenshot tool (Linux alternative to Lightshot)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🎨 DESIGN & CREATIVE TOOLS
    # ═══════════════════════════════════════════════════════════════════════════
    # Add design tools as needed (GIMP, Inkscape, Blender, etc.)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 📊 PRODUCTIVITY & OFFICE
    # ═══════════════════════════════════════════════════════════════════════════
    obsidian  # Note-taking (mirrored from macOS)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🎵 MULTIMEDIA & ENTERTAINMENT
    # ═══════════════════════════════════════════════════════════════════════════
    spotify  # Music streaming (mirrored from macOS)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🔧 DEVELOPMENT TOOLS (Linux-specific builds)
    # ═══════════════════════════════════════════════════════════════════════════
    mysql80  # Database client
  ];
} 