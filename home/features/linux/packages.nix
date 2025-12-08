{ pkgs, lib, ... }:

lib.mkIf pkgs.stdenv.isLinux {
  home.packages = with pkgs; [
    # ═══════════════════════════════════════════════════════════════════════════
    # 📦 DEVELOPMENT TOOLS (Linux-specific)
    # ═══════════════════════════════════════════════════════════════════════════
    devenv  # Development environment (from nixpkgs)
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🌐 BROWSERS & WEB TOOLS
    # ═══════════════════════════════════════════════════════════════════════════
    firefox
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 💬 COMMUNICATION & COLLABORATION
    # ═══════════════════════════════════════════════════════════════════════════
  ] 
  ++ lib.optionals pkgs.stdenv.isx86_64 [ slack ]  # x86_64-only (no ARM build)
  ++ [
    
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
  ]
  ++ lib.optionals pkgs.stdenv.isx86_64 [ hoppscotch ]  # x86_64-only (no ARM build)
  ++ [
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
  ]
  ++ lib.optionals pkgs.stdenv.isx86_64 [ spotify ]  # x86_64-only (no ARM build)
  ++ [
    
    # ═══════════════════════════════════════════════════════════════════════════
    # 🔧 DEVELOPMENT TOOLS (Linux-specific builds)
    # ═══════════════════════════════════════════════════════════════════════════
    mysql80  # Database client
  ];
} 