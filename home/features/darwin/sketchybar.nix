{ pkgs, lib, config, ... }:
lib.mkIf pkgs.stdenv.isDarwin {
  # SketchyBar Home Manager Configuration
  # Sets up SketchyBar as a user service for macOS
  # 
  # NOTE: SketchyBar binary is installed via Homebrew (see modules/darwin/brew/default.nix)
  # This ensures proper macOS system integration and TCC privacy permissions.
  # Font support (sketchybar-app-font) remains available through Nix.
  # 
  # Based on official SketchyBar examples, adapted for AeroSpace integration.

  # Stable wrapper script for SketchyBar to handle macOS privacy permissions
  # This creates a fixed path that can be granted permissions once
  home.file.".local/bin/sketchybar-wrapper" = {
    text = ''
      #!/bin/bash
      # SketchyBar Wrapper Script
      # This wrapper exists at a stable path to handle macOS privacy permissions
      # The actual SketchyBar binary is installed via Homebrew
      
      exec /opt/homebrew/bin/sketchybar "$@"
    '';
    executable = true;
  };

  # Configuration file based on official examples
  home.file.".config/sketchybar/sketchybarrc" = {
    text = ''
      #!/bin/bash
      # SketchyBar Configuration
      # Based on official SketchyBar examples, adapted for AeroSpace workspace management
      # See: https://felixkratz.github.io/SketchyBar/setup

      PLUGIN_DIR="$CONFIG_DIR/plugins"

      ##### Bar Appearance with Notch Support #####
      # Using built-in notch_display_height property (available since Nov 2024)
      # See: https://github.com/FelixKratz/SketchyBar/pull/626
      # 
      # height=24         External displays (DELL U3421WE, non-Retina)
      # notch_display_height=42   Notched displays (MacBook Pro/Air with notch)
      #
      # SketchyBar automatically uses the appropriate height per display
      sketchybar --bar position=top height=24 notch_display_height=42 blur_radius=30 color=0xaa000000 topmost=on

      ##### Changing Defaults #####
      # Default values applied to all items (from official examples)
      default=(
        padding_left=5
        padding_right=5
        icon.font="Hack Nerd Font:Bold:17.0"
        label.font="Hack Nerd Font:Bold:14.0"
        icon.color=0xffffffff
        label.color=0xffffffff
        icon.padding_left=4
        icon.padding_right=4
        label.padding_left=4
        label.padding_right=4
      )
      sketchybar --default "''${default[@]}"

      ##### Adding AeroSpace Workspace Indicators #####
      # Adapted from official Mission Control spaces for AeroSpace integration
      SPACE_ICONS=("1" "2" "3" "4" "5" "6" "7" "8" "9")
      for i in "''${!SPACE_ICONS[@]}"
      do
        sid="$(($i+1))"
        space=(
          space="$sid"
          icon="''${SPACE_ICONS[i]}"
          icon.padding_left=7
          icon.padding_right=7
          background.color=0x40ffffff
          background.corner_radius=5
          background.height=25
          label.drawing=off
          script="$PLUGIN_DIR/aerospace_space.sh"
          click_script="aerospace workspace $sid"
        )
        sketchybar --add space space."$sid" left --set space."$sid" "''${space[@]}"
      done

      ##### Adding Left Items #####
      # Based on official examples
      sketchybar --add item chevron left \
                 --set chevron icon= label.drawing=off \
                 --add item front_app left \
                 --set front_app icon.drawing=off script="$PLUGIN_DIR/front_app.sh" \
                 --subscribe front_app front_app_switched

      ##### Adding Right Items #####
      # Enhanced system monitoring with interactivity
      sketchybar --add item clock right \
                 --set clock update_freq=10 icon= script="$PLUGIN_DIR/clock.sh" \
                           click_script="open 'msteams://teams.microsoft.com/l/entity/ef56c0de-d29a-4bbf-a32c-043b63007997/calendar'" \
                 --add item network right \
                 --set network update_freq=5 script="$PLUGIN_DIR/network.sh" \
                           click_script="open /System/Library/PreferencePanes/Network.prefPane" \
                 --add item cpu right \
                 --set cpu update_freq=2 script="$PLUGIN_DIR/cpu.sh" \
                       click_script="open -a 'Activity Monitor'" \
                 --add item memory right \
                 --set memory update_freq=5 script="$PLUGIN_DIR/memory.sh" \
                         click_script="open -a 'Activity Monitor'" \
                 --add item volume right \
                 --set volume script="$PLUGIN_DIR/volume.sh" \
                         click_script="open /System/Library/PreferencePanes/Sound.prefPane" \
                 --subscribe volume volume_change \
                 --add item battery right \
                 --set battery update_freq=60 script="$PLUGIN_DIR/battery.sh" \
                         click_script="open /System/Library/PreferencePanes/Battery.prefPane" \
                 --subscribe battery system_woke power_source_change

      ##### Force all scripts to run the first time #####
      sketchybar --update
    '';
    executable = true;
  };

  # Plugin scripts based on official examples

  # CPU plugin - monitors CPU usage with color indicators
  home.file.".config/sketchybar/plugins/cpu.sh" = {
    text = ''
      #!/bin/bash

      # CPU usage plugin for SketchyBar with enhanced colors and interactivity

      # Get CPU usage using iostat for more accurate results
      CPU_USAGE=$(iostat -c 1 | tail -1 | awk '{print 100-$6}' | cut -d. -f1)
      
      # Fallback to top if iostat fails
      if [ -z "$CPU_USAGE" ] || [ "$CPU_USAGE" = "100" ]; then
        CPU_USAGE=$(top -l 1 | grep -E "^CPU" | grep -Eo '[0-9]*\.[0-9]*%' | head -1 | sed 's/%//')
        CPU_USAGE=''${CPU_USAGE%.*}
      fi

      # Ensure we have a valid number
      if [ -z "$CPU_USAGE" ]; then
        CPU_USAGE=0
      fi

      # Set color and icon based on usage with Catppuccin colors
      if [ "$CPU_USAGE" -gt 80 ]; then
          COLOR="0xffed8796"  # Catppuccin Red
          ICON="󰻠"           # CPU icon - high usage
      elif [ "$CPU_USAGE" -gt 50 ]; then
          COLOR="0xfff5a97f"  # Catppuccin Peach
          ICON="󰻟"           # CPU icon - medium usage
      elif [ "$CPU_USAGE" -gt 20 ]; then
          COLOR="0xfff9e2af"  # Catppuccin Yellow
          ICON="󰻟"           # CPU icon - normal usage
      else
          COLOR="0xffa6da95"  # Catppuccin Green
          ICON="󰻞"           # CPU icon - low usage
      fi

      # Update the display with colors
      sketchybar --set "$NAME" \
                 icon="$ICON" \
                 icon.color="$COLOR" \
                 label="''${CPU_USAGE}%" \
                 label.color="0xffffffff"
    '';
    executable = true;
  };

  # Network plugin - monitors network connectivity and speed
  home.file.".config/sketchybar/plugins/network.sh" = {
    text = ''
      #!/bin/bash

      # Enhanced network status plugin for SketchyBar with proper interface detection

      # Check internet connectivity
      if ping -c 1 -W 1000 8.8.8.8 &>/dev/null; then
          CONNECTED=true
      else
          CONNECTED=false
      fi

      # Get active network interface
      INTERFACE=$(route get default 2>/dev/null | grep interface | awk '{print $2}')
      
      # Get interface details from networksetup
      INTERFACE_TYPE=""
      if [ -n "$INTERFACE" ]; then
          INTERFACE_INFO=$(networksetup -listallhardwareports | grep -A1 "Device: $INTERFACE" | head -2)
          INTERFACE_TYPE=$(echo "$INTERFACE_INFO" | grep "Hardware Port:" | cut -d: -f2 | sed 's/^ *//')
      fi

      # Check WiFi status specifically
      WIFI_SSID=$(networksetup -getairportnetwork en0 2>/dev/null | cut -d: -f2 | sed 's/^ *//')
      WIFI_CONNECTED=false
      if [ -n "$WIFI_SSID" ] && [ "$WIFI_SSID" != "You are not associated with an AirPort network." ]; then
          WIFI_CONNECTED=true
      fi

      # Determine connection type and set appropriate icon/color
      if [ "$CONNECTED" = false ]; then
          COLOR="0xffed8796"        # Red - No connection
          ICON="󰈂"                # Network disconnected
          LABEL="No Network"
      elif [ "$WIFI_CONNECTED" = true ]; then
          # Connected via WiFi
          # Try to get signal strength for color coding
          if command -v airport >/dev/null 2>&1; then
              SIGNAL=$(airport -I | awk '/agrCtlRSSI/ {print $2}')
              if [ -n "$SIGNAL" ] && [ "$SIGNAL" -gt -50 ]; then
                  COLOR="0xffa6da95"  # Green - Strong WiFi
                  ICON="󰤨"          # WiFi strong
              elif [ -n "$SIGNAL" ] && [ "$SIGNAL" -gt -70 ]; then
                  COLOR="0xfff9e2af"  # Yellow - Medium WiFi
                  ICON="󰤥"          # WiFi medium
              else
                  COLOR="0xfff5a97f"  # Orange - Weak WiFi
                  ICON="󰤢"          # WiFi weak
              fi
          else
              COLOR="0xffa6da95"      # Green - WiFi connected
              ICON="󰤨"              # WiFi strong
          fi
          LABEL="$WIFI_SSID"
      else
          # Connected via wired connection
          case "$INTERFACE_TYPE" in
              *"USB"*|*"LAN"*)
                  COLOR="0xffa6da95"  # Green - USB Ethernet
                  ICON="󰌗"          # USB icon
                  LABEL="USB Ethernet"
                  ;;
              *"Thunderbolt"*)
                  COLOR="0xffa6da95"  # Green - Thunderbolt
                  ICON="󱎔"          # Thunderbolt icon
                  LABEL="Thunderbolt"
                  ;;
              *"Ethernet"*)
                  COLOR="0xffa6da95"  # Green - Ethernet
                  ICON="󰈀"          # Ethernet icon
                  LABEL="Ethernet"
                  ;;
              *)
                  COLOR="0xffa6da95"  # Green - Unknown wired
                  ICON="󰈀"          # Generic ethernet
                  LABEL="Wired"
                  ;;
          esac
      fi

      # Update the display
      sketchybar --set "$NAME" \
                 icon="$ICON" \
                 icon.color="$COLOR" \
                 label="$LABEL" \
                 label.color="0xffffffff"
    '';
    executable = true;
  };

  # Memory plugin - monitors memory usage with color indicators
  home.file.".config/sketchybar/plugins/memory.sh" = {
    text = ''
      #!/bin/bash

      # Memory usage plugin for SketchyBar with enhanced display

      # Get memory info using vm_stat and memory_pressure
      VM_STAT=$(vm_stat)
      MEMORY_PRESSURE=$(memory_pressure 2>/dev/null | grep "System-wide memory free percentage" | awk '{print $5}' | sed 's/%//')

      # Extract memory statistics
      PAGES_FREE=$(echo "$VM_STAT" | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
      PAGES_ACTIVE=$(echo "$VM_STAT" | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
      PAGES_INACTIVE=$(echo "$VM_STAT" | grep "Pages inactive" | awk '{print $3}' | sed 's/\.//')
      PAGES_SPECULATIVE=$(echo "$VM_STAT" | grep "Pages speculative" | awk '{print $3}' | sed 's/\.//')
      PAGES_WIRED=$(echo "$VM_STAT" | grep "Pages wired down" | awk '{print $4}' | sed 's/\.//')

      # Calculate memory usage (4KB per page)
      PAGE_SIZE=4096
      TOTAL_PAGES=$((PAGES_FREE + PAGES_ACTIVE + PAGES_INACTIVE + PAGES_SPECULATIVE + PAGES_WIRED))
      USED_PAGES=$((PAGES_ACTIVE + PAGES_INACTIVE + PAGES_SPECULATIVE + PAGES_WIRED))

      # Convert to GB
      TOTAL_GB=$((TOTAL_PAGES * PAGE_SIZE / 1024 / 1024 / 1024))
      USED_GB=$((USED_PAGES * PAGE_SIZE / 1024 / 1024 / 1024))

      # Calculate percentage
      if [ "$TOTAL_GB" -gt 0 ]; then
          PERCENTAGE=$((USED_GB * 100 / TOTAL_GB))
      else
          PERCENTAGE=0
      fi

      # Set color and icon based on usage with proper Catppuccin colors
      if [ "$PERCENTAGE" -gt 85 ]; then
          COLOR="0xffed8796"  # Catppuccin Red - Critical
          ICON="󰍛"           # Memory icon - critical
      elif [ "$PERCENTAGE" -gt 70 ]; then
          COLOR="0xfff5a97f"  # Catppuccin Peach - High
          ICON="󰍛"           # Memory icon - high
      elif [ "$PERCENTAGE" -gt 50 ]; then
          COLOR="0xfff9e2af"  # Catppuccin Yellow - Medium
          ICON="󰍛"           # Memory icon - medium
      else
          COLOR="0xffa6da95"  # Catppuccin Green - Good
          ICON="󰍛"           # Memory icon - good
      fi

      # Update the display with colors and percentage
      sketchybar --set "$NAME" \
                 icon="$ICON" \
                 icon.color="$COLOR" \
                 label="''${USED_GB}G (''${PERCENTAGE}%)" \
                 label.color="0xffffffff"
    '';
    executable = true;
  };

  # Battery plugin - enhanced with colors, charging status, and time remaining
  home.file.".config/sketchybar/plugins/battery.sh" = {
    text = ''
      #!/bin/bash

      # Enhanced battery plugin for SketchyBar with charging status and colors

      BATTERY_INFO="$(pmset -g batt)"
      PERCENTAGE="$(echo "$BATTERY_INFO" | grep -Eo "\d+%" | cut -d% -f1)"
      CHARGING="$(echo "$BATTERY_INFO" | grep 'AC Power')"
      
      # Get time remaining if available
      TIME_REMAINING="$(echo "$BATTERY_INFO" | grep -o '[0-9]*:[0-9]*' | head -1)"

      if [ "$PERCENTAGE" = "" ]; then
        exit 0
      fi

      # Determine charging status
      IS_CHARGING=false
      if [[ "$CHARGING" != "" ]]; then
        IS_CHARGING=true
      fi

      # Set icon and color based on battery level and charging status
      if [ "$IS_CHARGING" = true ]; then
          # Charging icons and colors
          case "''${PERCENTAGE}" in
            9[5-9]|100) 
                ICON="󰂅"          # Charging - almost full
                COLOR="0xffa6da95" # Green
                ;;
            [8-9][0-4]) 
                ICON="󰂋"          # Charging - high
                COLOR="0xffa6da95" # Green  
                ;;
            [6-7][0-9]) 
                ICON="󰂊"          # Charging - medium-high
                COLOR="0xfff9e2af" # Yellow
                ;;
            [4-5][0-9]) 
                ICON="󰢞"          # Charging - medium
                COLOR="0xfff9e2af" # Yellow
                ;;
            [2-3][0-9]) 
                ICON="󰂇"          # Charging - low
                COLOR="0xfff5a97f" # Orange
                ;;
            *) 
                ICON="󰢜"          # Charging - very low
                COLOR="0xfff5a97f" # Orange
                ;;
          esac
          STATUS="⚡"
      else
          # Battery icons and colors  
          case "''${PERCENTAGE}" in
            9[0-9]|100) 
                ICON="󰁹"          # Full battery
                COLOR="0xffa6da95" # Green
                ;;
            [7-8][0-9]) 
                ICON="󰂂"          # High battery
                COLOR="0xffa6da95" # Green
                ;;
            [5-6][0-9]) 
                ICON="󰂀"          # Medium battery
                COLOR="0xfff9e2af" # Yellow
                ;;
            [3-4][0-9]) 
                ICON="󰁾"          # Low battery
                COLOR="0xfff5a97f" # Orange
                ;;
            [1-2][0-9]) 
                ICON="󰁼"          # Very low battery
                COLOR="0xffed8796" # Red
                ;;
            *) 
                ICON="󰂎"          # Critical battery
                COLOR="0xffed8796" # Red
                ;;
          esac
          STATUS=""
      fi

      # Build label with time remaining if available
      if [ -n "$TIME_REMAINING" ] && [ "$IS_CHARGING" = false ]; then
          LABEL="''${PERCENTAGE}% (''${TIME_REMAINING})"
      else
          LABEL="''${PERCENTAGE}%''${STATUS}"
      fi

      # Update the display with colors and enhanced info
      sketchybar --set "$NAME" \
                 icon="$ICON" \
                 icon.color="$COLOR" \
                 label="$LABEL" \
                 label.color="0xffffffff"
    '';
    executable = true;
  };

  # Clock plugin (official example)
  home.file.".config/sketchybar/plugins/clock.sh" = {
    text = ''
      #!/bin/sh

      # The $NAME variable is passed from sketchybar and holds the name of
      # the item invoking this script:
      # https://felixkratz.github.io/SketchyBar/config/events#events-and-scripting

      sketchybar --set "$NAME" label="$(date '+%d.%m %H:%M')"
    '';
    executable = true;
  };

  # Front app plugin (official example)
  home.file.".config/sketchybar/plugins/front_app.sh" = {
    text = ''
      #!/bin/sh

      # Some events send additional information specific to the event in the $INFO
      # variable. E.g. the front_app_switched event sends the name of the newly
      # focused application in the $INFO variable:
      # https://felixkratz.github.io/SketchyBar/config/events#events-and-scripting

      if [ "$SENDER" = "front_app_switched" ]; then
        sketchybar --set "$NAME" label="$INFO"
      fi
    '';
    executable = true;
  };

  # AeroSpace space plugin (adapted from official space.sh for AeroSpace)
  home.file.".config/sketchybar/plugins/aerospace_space.sh" = {
    text = ''
      #!/bin/sh

      # Adapted from official space.sh for AeroSpace integration
      # The $SELECTED variable indicates if the space is currently selected
      # We also check AeroSpace's focused workspace to ensure sync

      if command -v aerospace >/dev/null 2>&1; then
        # Get current focused workspace from AeroSpace
        FOCUSED_WORKSPACE=$(aerospace list-workspaces --focused)
        # Extract workspace number from space name (e.g., "space.1" -> "1")
        SPACE_NUM=$(echo "$NAME" | sed 's/space\.//')
        
        # Check if this space matches the focused workspace
        if [ "$SPACE_NUM" = "$FOCUSED_WORKSPACE" ]; then
          SELECTED="on"
        else
          SELECTED="off"
        fi
      else
        # Fallback to $SELECTED variable if AeroSpace is not available
        SELECTED="${SELECTED:-off}"
      fi

      sketchybar --set "$NAME" background.drawing="$SELECTED"
    '';
    executable = true;
  };

  # Volume plugin - enhanced with better icons and colors
  home.file.".config/sketchybar/plugins/volume.sh" = {
    text = ''
      #!/bin/bash

      # Enhanced volume plugin for SketchyBar with colors and mute detection

      # Get volume level and mute status  
      if [ "$SENDER" = "volume_change" ]; then
        VOLUME="$INFO"
      else
        VOLUME=$(osascript -e "output volume of (get volume settings)")
      fi
      
      MUTED=$(osascript -e "output muted of (get volume settings)")

      # Set icon and color based on volume level and mute status
      if [ "$MUTED" = "true" ]; then
          ICON="󰸈"              # Muted icon
          COLOR="0xffed8796"     # Red for muted
          LABEL="Muted"
      else
          case $VOLUME in
              [8-9][0-9]|100)
                  ICON="󰕾"        # High volume
                  COLOR="0xffa6da95" # Green
                  ;;
              [6-7][0-9])
                  ICON="󰖀"        # Medium-high volume  
                  COLOR="0xfff9e2af" # Yellow
                  ;;
              [3-5][0-9])
                  ICON="󰕿"        # Medium volume
                  COLOR="0xfff9e2af" # Yellow
                  ;;
              [1-2][0-9])
                  ICON="󰖁"        # Low volume
                  COLOR="0xfff5a97f" # Orange
                  ;;
              [1-9])
                  ICON="󰕿"        # Very low volume
                  COLOR="0xfff5a97f" # Orange
                  ;;
              *)
                  ICON="󰖁"        # Zero/muted volume
                  COLOR="0xffed8796" # Red
                  ;;
          esac
          LABEL="''${VOLUME}%"
      fi

      # Update the display with colors
      sketchybar --set "$NAME" \
                 icon="$ICON" \
                 icon.color="$COLOR" \
                 label="$LABEL" \
                 label.color="0xffffffff"
    '';
    executable = true;
  };

  # Use Homebrew's service management as per official setup
  # We disable our custom launchd service in favor of Homebrew's approach
  launchd.agents.sketchybar.enable = false;

  # Create log directory for any debugging needs
  home.file.".local/share/sketchybar/.keep".text = "";

  # Shell integration for SketchyBar events
  programs.fish = {
    interactiveShellInit = lib.mkAfter ''
      # SketchyBar integration
      # Trigger workspace updates when switching with AeroSpace
      if command -v sketchybar >/dev/null 2>&1
        # AeroSpace integration happens through the plugin scripts
        # The aerospace_space.sh plugin monitors workspace changes automatically
        echo "SketchyBar available for AeroSpace integration"
      end
    '';
  };

  # Ensure SketchyBar is in PATH (via Homebrew)
  home.sessionPath = [
    "/opt/homebrew/bin"
  ];
} 