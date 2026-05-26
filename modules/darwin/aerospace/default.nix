{ pkgs
, ...
}: {
  services.aerospace = {
    enable = true;
    package = pkgs.aerospace;

    settings = {
      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;

      on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];
      on-focus-changed = [
        "move-mouse window-lazy-center"
      ];

      automatically-unhide-macos-hidden-apps = false;

      accordion-padding = 30;
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";

      gaps = {
        outer.bottom = 0;
        outer.top = 0;
        outer.left = 1;
        outer.right = 1;
        inner.horizontal = 3;
        inner.vertical = 3;
      };

      # WORKSPACE TO MONITOR ASSIGNMENT
      # Layout Logic (managed by MonitorManager.lua):
      # - Office setup (no LG monitor): All workspaces use side-by-side tiling
      # - Home-Office setup (with LG HDR 4K):
      #   * Workspaces 1-5: side-by-side on main monitor
      #   * Workspaces 6-7: stacking layout on LG portrait monitor  
      #   * Workspaces 8-9: side-by-side on built-in monitor
      workspace-to-monitor-force-assignment = {
        "1" = "main";
        "2" = "main";
        "3" = "main";
        "4" = "main";
        "5" = "main";
        "6" = [ "LG HDR 4K" "main" ];
        "7" = [ "LG HDR 4K" "main" ];
        "8" = [ "built-in" "main" ];
        "9" = [ "built-in" "main" ];
      };

      key-mapping.preset = "qwerty";
      mode.main.binding = {
        ctrl-1 = "workspace 1";
        ctrl-2 = "workspace 2";
        ctrl-3 = "workspace 3";
        ctrl-4 = "workspace 4";
        ctrl-5 = "workspace 5";
        ctrl-f1 = "workspace 6";
        ctrl-f2 = "workspace 7";
        ctrl-f3 = "workspace 8";
        ctrl-f4 = "workspace 9";

        ctrl-shift-p = "workspace --wrap-around prev";
        ctrl-shift-n = "workspace --wrap-around next";

        # Move windows to workspaces and follow
        ctrl-shift-1 = [ "move-node-to-workspace 1" "workspace 1" ];
        ctrl-shift-2 = [ "move-node-to-workspace 2" "workspace 2" ];
        ctrl-shift-3 = [ "move-node-to-workspace 3" "workspace 3" ];
        ctrl-shift-4 = [ "move-node-to-workspace 4" "workspace 4" ];
        ctrl-shift-5 = [ "move-node-to-workspace 5" "workspace 5" ];
        ctrl-shift-f1 = [ "move-node-to-workspace 6" "workspace 6" ];
        ctrl-shift-f2 = [ "move-node-to-workspace 7" "workspace 7" ];
        ctrl-shift-f3 = [ "move-node-to-workspace 8" "workspace 8" ];
        ctrl-shift-f4 = [ "move-node-to-workspace 9" "workspace 9" ];

        # Window focus navigation
        ctrl-left = "focus --boundaries-action wrap-around-the-workspace left";
        ctrl-right = "focus --boundaries-action wrap-around-the-workspace right";
        ctrl-up = "focus --boundaries-action wrap-around-the-workspace up";
        ctrl-down = "focus --boundaries-action wrap-around-the-workspace down";

        # Move windows within workspace
        ctrl-shift-left = "move left";
        ctrl-shift-right = "move right";
        ctrl-shift-up = "move up";
        ctrl-shift-down = "move down";

        # Horizontal monitor management (left/right for multi-monitor setup)
        ctrl-shift-alt-right = "move-node-to-monitor right";
        ctrl-shift-alt-left = "move-node-to-monitor left";

        # Monitor focus switching (horizontal only)
        ctrl-alt-left = "focus-monitor left";
        ctrl-alt-right = "focus-monitor right";

        # Layout management
        ctrl-shift-space = "layout floating tiling";
        ctrl-f = "layout floating tiling";

        # Manual layout switching shortcuts
        ctrl-t = "exec-and-forget /run/current-system/sw/bin/aerospace layout tiles horizontal vertical"; # Force layout switch

        # MonitorManager integration - applies all workspace layouts based on monitor setup
        ctrl-m = "exec-and-forget /opt/homebrew/bin/hs -c 'MonitorManager.fix()'";

        # Development-focused app launches
        ctrl-enter = "exec-and-forget open -na WezTerm";
        ctrl-shift-enter = "exec-and-forget open -na Warp";
        ctrl-b = "exec-and-forget open -na \"Google Chrome\" --args --new-window";

        # System utilities
        ctrl-l = "exec-and-forget pmset displaysleepnow";
        ctrl-shift-q = "close --quit-if-last-window";

        # Disable unwanted cmd+letter bindings that conflict with apps
        # cmd-b = []; # Disable default workspace B binding
        # cmd-l = []; # Disable default workspace L binding

        # Mode switching
        ctrl-r = "mode resize";
        ctrl-shift-comma = "mode layout";
        ctrl-shift-period = "mode monitor";
      };

      mode.resize.binding = {
        left = "resize width +50";
        right = "resize width -50";
        up = "resize height +50";
        down = "resize height -50";
        # Fine-grained resizing
        shift-left = "resize width +10";
        shift-right = "resize width -10";
        shift-up = "resize height +10";
        shift-down = "resize height -10";
        enter = "mode main";
        esc = "mode main";
      };

      mode.layout.binding = {
        esc = "mode main";
        enter = "mode main";
        r = "flatten-workspace-tree";
        # Window joining
        ctrl-left = "join-with left";
        ctrl-right = "join-with right";
        ctrl-up = "join-with up";
        ctrl-down = "join-with down";
        # Layout presets
        ctrl-s = "layout v_accordion";
        ctrl-w = "layout h_accordion";
        ctrl-e = "layout tiles horizontal vertical";
      };

      # Monitor management mode
      mode.monitor.binding = {
        esc = "mode main";
        enter = "mode main";
        # Quick workspace assignments per monitor
        "1" = "move-node-to-monitor 1"; # Ultra-wide
        "2" = "move-node-to-monitor 2"; # Laptop
        "3" = "move-node-to-monitor 3"; # QHD
        # Focus monitor directly (horizontal only)
        left = "focus-monitor left";
        right = "focus-monitor right";
      };

      # App placement rules (simplified - just workspace assignment)
      on-window-detected = [
        # PRIMARY CODING APPS
        {
          "if" = {
            "app-id" = "com.todesktop.230313mzl4w4u92"; # Cursor
          };
          "run" = "move-node-to-workspace 1";
        }
        {
          "if" = {
            "app-id" = "com.apple.dt.Xcode";
          };
          "run" = "move-node-to-workspace 1";
        }
        {
          "if" = {
            "app-id" = "com.jetbrains.PhpStorm";
          };
          "run" = "move-node-to-workspace 1";
        }

        # TERMINAL - Goes to coding workspace
        {
          "if" = {
            "app-id" = "com.github.wez.wezterm";
          };
          "run" = "move-node-to-workspace 7";
        }
        {
          "if" = {
            "app-id" = "dev.warp.Warp-Stable";
          };
          "run" = "move-node-to-workspace 7";
        }

        # BROWSERS
        {
          "if".app-name-regex-substring = "Google.Chrome";
          "run" = "move-node-to-workspace 1";
        }
        {
          "if" = {
            "app-id" = "org.mozilla.firefox";
          };
          "run" = "move-node-to-workspace 6";
        }
        {
          "if" = {
            "app-id" = "com.apple.Safari";
          };
          "run" = "move-node-to-workspace 6";
        }

        # COMMUNICATION
        {
          "if" = {
            "app-id" = "com.tinyspeck.slackmacgap";
          };
          "run" = "move-node-to-workspace 9";
        }
        {
          "if" = {
            "app-id" = "com.microsoft.teams2";
          };
          "run" = "move-node-to-workspace 9";
        }
        {
          "if" = {
            "app-id" = "com.microsoft.Teams";
          };
          "run" = "move-node-to-workspace 9";
        }

        # UTILITIES
        {
          "if" = {
            "app-id" = "md.obsidian";
          };
          "run" = "move-node-to-workspace 7";
        }
        {
          "if" = {
            "app-id" = "com.apple.ActivityMonitor";
          };
          "run" = "move-node-to-workspace 8";
        }
      ];
    };
  };
}
