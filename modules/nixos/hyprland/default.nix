{ config, pkgs, lib, ... }:

# Hyprland Wayland compositor configuration for NixOS
# Modern tiling window manager with animations and effects

{
  # Enable Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true; # X11 app compatibility
  };

  # Display manager - greetd with tuigreet
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  # Required packages for Hyprland
  environment.systemPackages = with pkgs; [
    # Wayland utilities
    wl-clipboard    # Clipboard manager
    wlr-randr       # Display configuration
    grim            # Screenshot utility
    slurp           # Region selector
    swappy          # Screenshot editor
    
    # Notification daemon
    mako            # Lightweight notification daemon
    libnotify       # Send notifications
    
    # Application launcher
    rofi-wayland    # App launcher
    
    # File manager
    xfce.thunar     # GUI file manager
    
    # Terminal
    wezterm         # Configured via Home Manager
    
    # Screen locker
    swaylock-effects
    
    # Idle management
    swayidle
    
    # Network management GUI (for NetworkManager)
    networkmanagerapplet
    
    # Bluetooth GUI (already enabled in main config)
    # blueman is enabled system-wide
    
    # Qt Wayland support
    qt5.qtwayland
    qt6.qtwayland
    
    # GTK portal for file chooser dialogs
    xdg-desktop-portal-gtk
  ];

  # XDG Desktop Portal for Hyprland
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config.common.default = "*";
  };

  # Environment variables for Wayland
  environment.sessionVariables = {
    # Wayland-specific
    NIXOS_OZONE_WL = "1"; # Electron apps use Wayland
    MOZ_ENABLE_WAYLAND = "1"; # Firefox use Wayland
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
    _JAVA_AWT_WM_NONREPARENTING = "1"; # Java GUI compatibility
    
    # XDG compliance
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
  };

  # Security - allow Hyprland to use realtime priority
  security.pam.services.swaylock = {};

  # Enable polkit for privilege escalation
  security.polkit.enable = true;

  # Polkit authentication agent
  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    description = "polkit-gnome-authentication-agent-1";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  # Font configuration for Hyprland
  fonts = {
    packages = with pkgs; [
      # Fonts are managed in ../shared/fonts.nix
      # Additional Hyprland-specific fonts here if needed
    ];
  };

  # Note: User-specific Hyprland configuration is in home/features/linux/hyprland/
  # This includes keybindings, colors, animations, etc.
}

