{ config, pkgs, lib, ... }:

# Hyprland user configuration
# Keybindings, colors, animations, workspace management

lib.mkIf pkgs.stdenv.isLinux {
  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;

    settings = {
      # Monitor configuration - adjust per hardware
      monitor = [
        ",preferred,auto,1" # Auto-detect monitors
      ];

      # Autostart applications
      exec-once = [
        "waybar" # Status bar
        "mako" # Notification daemon
        "nm-applet --indicator" # Network manager tray
        "blueman-applet" # Bluetooth tray
        "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.wl-clipboard}/bin/cliphist store" # Clipboard manager
      ];

      # Environment variables
      env = [
        "XCURSOR_SIZE,24"
        "QT_QPA_PLATFORMTHEME,qt5ct"
      ];

      # Input configuration
      input = {
        kb_layout = "de";
        kb_variant = "";
        kb_model = "";
        kb_options = "";
        kb_rules = "";

        follow_mouse = 1;

        touchpad = {
          natural_scroll = true;
          disable_while_typing = true;
          tap-to-click = true;
        };

        sensitivity = 0; # -1.0 - 1.0, 0 means no modification
      };

      # General window and gap settings
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";

        layout = "dwindle"; # or "master"

        allow_tearing = false;
      };

      # Decoration settings
      decoration = {
        rounding = 10;

        blur = {
          enabled = true;
          size = 3;
          passes = 1;
          vibrancy = 0.1696;
        };

        drop_shadow = true;
        shadow_range = 4;
        shadow_render_power = 3;
        "col.shadow" = "rgba(1a1a1aee)";
      };

      # Animation settings (smooth and modern)
      animations = {
        enabled = true;

        bezier = [
          "myBezier, 0.05, 0.9, 0.1, 1.05"
        ];

        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };

      # Layout settings
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      master = {
        new_is_master = true;
      };

      # Window rules
      windowrulev2 = [
        # Float specific windows
        "float,class:(pavucontrol)"
        "float,class:(nm-connection-editor)"
        "float,class:(blueman-manager)"
        "float,title:(Picture-in-Picture)"

        # Opacity rules
        "opacity 0.9 0.9,class:^(thunar)$"
        "opacity 0.95 0.95,class:^(wezterm)$"
        "opacity 0.95 0.95,class:^(dev.warp.Warp|Warp)$"

        # Workspace assignments
        "workspace 2,class:^(firefox)$"
        "workspace 3,class:^(Slack)$"
        "workspace 7,class:^(dev.warp.Warp|Warp)$"
      ];

      # Gestures
      gestures = {
        workspace_swipe = true;
        workspace_swipe_fingers = 3;
      };

      # Miscellaneous settings
      misc = {
        force_default_wallpaper = 0; # Disable anime mascot
        disable_hyprland_logo = true;
      };

      # Keybindings (similar to AeroSpace style)
      "$mod" = "SUPER";

      bind = [
        # Application launchers
        "$mod, RETURN, exec, wezterm"
        "$mod SHIFT, RETURN, exec, warp-terminal"
        "$mod, D, exec, rofi -show drun"
        "$mod, E, exec, thunar"

        # Window management
        "$mod, Q, killactive,"
        "$mod SHIFT, Q, exit,"
        "$mod, V, togglefloating,"
        "$mod, F, fullscreen,"
        "$mod, P, pseudo," # dwindle
        "$mod, J, togglesplit," # dwindle

        # Focus movement (vim-style)
        "$mod, H, movefocus, l"
        "$mod, L, movefocus, r"
        "$mod, K, movefocus, u"
        "$mod, J, movefocus, d"

        # Window movement
        "$mod SHIFT, H, movewindow, l"
        "$mod SHIFT, L, movewindow, r"
        "$mod SHIFT, K, movewindow, u"
        "$mod SHIFT, J, movewindow, d"

        # Workspace switching
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"

        # Move window to workspace
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"

        # Special workspace (scratchpad)
        "$mod, S, togglespecialworkspace, magic"
        "$mod SHIFT, S, movetoworkspace, special:magic"

        # Scroll through workspaces
        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"

        # Screenshots
        ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
        "SHIFT, Print, exec, grim -g \"$(slurp)\" - | swappy -f -"
        "$mod, Print, exec, grim -g \"$(slurp)\" ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"

        # Lock screen
        "$mod, Escape, exec, swaylock"

        # Media keys
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];

      # Mouse bindings
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };

  # Additional packages for Hyprland
  home.packages = with pkgs; [
    # Screenshot tools
    grim
    slurp
    swappy

    # Clipboard manager
    cliphist

    # Brightness control
    brightnessctl

    # Color picker
    hyprpicker

    # Wallpaper
    awww
  ];

  # Swaylock configuration
  programs.swaylock = {
    enable = true;
    settings = {
      color = "1e1e2e";
      font-size = 24;
      indicator-idle-visible = false;
      indicator-radius = 100;
      show-failed-attempts = true;
    };
  };

  # Swayidle configuration (auto-lock)
  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 300; # 5 minutes
        command = "${pkgs.swaylock}/bin/swaylock -f";
      }
      {
        timeout = 600; # 10 minutes
        command = "${pkgs.systemd}/bin/systemctl suspend";
      }
    ];
  };
}
