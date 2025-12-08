{ config, pkgs, lib, ... }:

# Waybar status bar configuration
# Toggleable via waybar.enable option

let
  cfg = config.programs.waybar;
in
lib.mkIf pkgs.stdenv.isLinux {
  programs.waybar = {
    enable = lib.mkDefault true; # Toggle: set to false to disable
    
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 34;
        spacing = 4;
        
        # Module order
        modules-left = [ "hyprland/workspaces" "hyprland/window" ];
        modules-center = [ "clock" ];
        modules-right = [
          "idle_inhibitor"
          "pulseaudio"
          "network"
          "bluetooth"
          "cpu"
          "memory"
          "temperature"
          "backlight"
          "battery"
          "tray"
        ];
        
        # Module configurations
        "hyprland/workspaces" = {
          format = "{icon}";
          format-icons = {
            "1" = "1";
            "2" = "2";
            "3" = "3";
            "4" = "4";
            "5" = "5";
            "6" = "6";
            "7" = "7";
            "8" = "8";
            "9" = "9";
            "10" = "10";
            urgent = "";
            focused = "";
            default = "";
          };
          on-click = "activate";
          sort-by-number = true;
        };
        
        "hyprland/window" = {
          max-length = 50;
          separate-outputs = true;
        };
        
        idle_inhibitor = {
          format = "{icon}";
          format-icons = {
            activated = "";
            deactivated = "";
          };
        };
        
        tray = {
          spacing = 10;
        };
        
        clock = {
          format = "{:%H:%M}";
          format-alt = "{:%A, %B %d, %Y (%R)}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "month";
            mode-mon-col = 3;
            weeks-pos = "right";
            on-scroll = 1;
            on-click-right = "mode";
            format = {
              months = "<span color='#ffead3'><b>{}</b></span>";
              days = "<span color='#ecc6d9'><b>{}</b></span>";
              weeks = "<span color='#99ffdd'><b>W{}</b></span>";
              weekdays = "<span color='#ffcc66'><b>{}</b></span>";
              today = "<span color='#ff6699'><b><u>{}</u></b></span>";
            };
          };
        };
        
        cpu = {
          format = " {usage}%";
          tooltip = false;
          on-click = "wezterm -e htop";
        };
        
        memory = {
          format = " {}%";
          on-click = "wezterm -e htop";
        };
        
        temperature = {
          critical-threshold = 80;
          format = "{icon} {temperatureC}°C";
          format-icons = [ "" "" "" ];
        };
        
        backlight = {
          format = "{icon} {percent}%";
          format-icons = [ "" "" "" "" "" "" "" "" "" ];
          on-scroll-up = "${pkgs.brightnessctl}/bin/brightnessctl set 5%+";
          on-scroll-down = "${pkgs.brightnessctl}/bin/brightnessctl set 5%-";
        };
        
        battery = {
          states = {
            good = 95;
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-charging = " {capacity}%";
          format-plugged = " {capacity}%";
          format-alt = "{icon} {time}";
          format-icons = [ "" "" "" "" "" ];
        };
        
        network = {
          format-wifi = " {essid} ({signalStrength}%)";
          format-ethernet = " {ipaddr}";
          format-linked = " {ifname} (No IP)";
          format-disconnected = "⚠ Disconnected";
          format-alt = "{ifname}: {ipaddr}/{cidr}";
          tooltip-format = "{ifname} via {gwaddr}";
          on-click-right = "nm-connection-editor";
        };
        
        bluetooth = {
          format = " {status}";
          format-connected = " {device_alias}";
          format-connected-battery = " {device_alias} {device_battery_percentage}%";
          tooltip-format = "{controller_alias}\t{controller_address}\n\n{num_connections} connected";
          tooltip-format-connected = "{controller_alias}\t{controller_address}\n\n{num_connections} connected\n\n{device_enumerate}";
          tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
          tooltip-format-enumerate-connected-battery = "{device_alias}\t{device_address}\t{device_battery_percentage}%";
          on-click = "blueman-manager";
        };
        
        pulseaudio = {
          scroll-step = 5;
          format = "{icon} {volume}%";
          format-bluetooth = "{icon} {volume}%";
          format-bluetooth-muted = " {icon}";
          format-muted = " {volume}%";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [ "" "" "" ];
          };
          on-click = "pavucontrol";
        };
      };
    };
    
    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free";
        font-size: 14px;
        min-height: 0;
      }
      
      window#waybar {
        background-color: rgba(30, 30, 46, 0.8);
        color: #cdd6f4;
        transition-property: background-color;
        transition-duration: .5s;
      }
      
      window#waybar.hidden {
        opacity: 0.2;
      }
      
      #workspaces button {
        padding: 0 5px;
        background-color: transparent;
        color: #cdd6f4;
        border-bottom: 3px solid transparent;
      }
      
      #workspaces button:hover {
        background: rgba(0, 0, 0, 0.2);
        box-shadow: inset 0 -3px #cdd6f4;
      }
      
      #workspaces button.focused,
      #workspaces button.active {
        background-color: rgba(89, 176, 228, 0.3);
        border-bottom: 3px solid #89b4fa;
      }
      
      #workspaces button.urgent {
        background-color: #f38ba8;
      }
      
      #clock,
      #battery,
      #cpu,
      #memory,
      #temperature,
      #backlight,
      #network,
      #pulseaudio,
      #bluetooth,
      #idle_inhibitor,
      #tray,
      #window {
        padding: 0 10px;
        margin: 0 2px;
      }
      
      #window {
        font-weight: bold;
      }
      
      #clock {
        color: #89b4fa;
      }
      
      #battery {
        color: #a6e3a1;
      }
      
      #battery.charging {
        color: #a6e3a1;
      }
      
      #battery.warning:not(.charging) {
        color: #fab387;
      }
      
      #battery.critical:not(.charging) {
        color: #f38ba8;
        animation-name: blink;
        animation-duration: 0.5s;
        animation-timing-function: linear;
        animation-iteration-count: infinite;
        animation-direction: alternate;
      }
      
      @keyframes blink {
        to {
          background-color: #f38ba8;
          color: #1e1e2e;
        }
      }
      
      #cpu {
        color: #89dceb;
      }
      
      #memory {
        color: #cba6f7;
      }
      
      #temperature {
        color: #fab387;
      }
      
      #temperature.critical {
        color: #f38ba8;
      }
      
      #backlight {
        color: #f9e2af;
      }
      
      #network {
        color: #a6e3a1;
      }
      
      #network.disconnected {
        color: #f38ba8;
      }
      
      #pulseaudio {
        color: #f5c2e7;
      }
      
      #pulseaudio.muted {
        color: #6c7086;
      }
      
      #bluetooth {
        color: #89b4fa;
      }
      
      #idle_inhibitor {
        color: #f9e2af;
      }
      
      #idle_inhibitor.activated {
        color: #eba0ac;
      }
      
      #tray > .passive {
        -gtk-icon-effect: dim;
      }
      
      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
        background-color: #f38ba8;
      }
    '';
  };

  # Additional packages for Waybar
  home.packages = with pkgs; [
    # Required for system tray
    networkmanagerapplet
    blueman
    pavucontrol
    
    # Icon themes
    papirus-icon-theme
  ];
}

