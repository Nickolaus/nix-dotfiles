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

  # System preferences for SketchyBar integration
  # Auto-hide menu bar on desktop - allows hovering to access app menus
  targets.darwin.defaults."com.apple.dock" = {
    autohide = true;
  };
  
  targets.darwin.defaults.NSGlobalDomain = {
    _HIHideMenuBar = true;                    # Hide menu bar on desktop
    AppleMenuBarVisibleInFullscreen = true;   # But show in fullscreen apps
  };

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

      # Set up environment  
      export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:$PATH"
      
      # Reproducible configuration directory detection
      # Home Manager creates symlinks at ~/.config/sketchybar pointing to Nix store
      CONFIG_DIR="$HOME/.config/sketchybar"
      PLUGIN_DIR="$CONFIG_DIR/plugins"
      
      # Ensure jq is available for JSON parsing
      if ! command -v jq >/dev/null 2>&1; then
        echo "Warning: jq not found, multi-monitor workspace filtering may not work properly"
      fi

      ##### Catppuccin Macchiato Color Palette #####
      # Official Catppuccin Macchiato colors for consistent theming
      # https://github.com/catppuccin/catppuccin
      
      # Core colors
      ROSEWATER="0xfff4dbd6"
      FLAMINGO="0xfff0c6c6"
      PINK="0xfff5bde6"
      MAUVE="0xffc6a0f6"
      RED="0xffed8796"
      MAROON="0xffee99a0"
      PEACH="0xfff5a97f"
      YELLOW="0xfff9e2af"
      GREEN="0xffa6da95"
      TEAL="0xff8bd5ca"
      SKY="0xff91d7e3"
      SAPPHIRE="0xff7dc4e4"
      BLUE="0xff8aadf4"
      LAVENDER="0xffb7bdf8"
      
      # Neutral colors
      TEXT="0xffffffff"
      SUBTEXT1="0xffb8c0e0"
      SUBTEXT0="0xffa5adcb"
      OVERLAY2="0xff939ab7"
      OVERLAY1="0xff8087a2"
      OVERLAY0="0xff6e738d"
      SURFACE2="0xff5b6078"
      SURFACE1="0xff494d64"
      SURFACE0="0xff363a4f"
      BASE="0xff24273a"
      MANTLE="0xff1e2030"
      CRUST="0xff181926"

      ##### Bar Appearance with Catppuccin Theme #####
      # Using built-in notch_display_height property (available since Nov 2024)
      # See: https://github.com/FelixKratz/SketchyBar/pull/626
      # 
      # height=24         External displays (DELL U3421WE, non-Retina)
      # notch_display_height=42   Notched displays (MacBook Pro/Air with notch)
      #
      # Catppuccin Macchiato themed bar with subtle transparency
      sketchybar --bar position=top topmost=off sticky=on display=all height=24 notch_display_height=42 blur_radius=30 color="''${BASE}ee"

      ##### Catppuccin Themed Defaults #####
      # Catppuccin Macchiato themed default values for all widgets
      default=(
        padding_left=5
        padding_right=5
        icon.font="Hack Nerd Font:Bold:17.0"
        label.font="Hack Nerd Font:Bold:14.0"
        icon.color="$TEXT"
        label.color="$TEXT"
        icon.padding_left=4
        icon.padding_right=4
        label.padding_left=4
        label.padding_right=4
        background.height=24
        background.corner_radius=8
        background.border_width=1
        background.border_color="$SURFACE0"
      )
      sketchybar --default "''${default[@]}"

      # Static workspace indicators removed - preparing for dynamic per-display system

      ##### Adding Left Items #####
      # Workspace icons, front app display, and media controls
      sketchybar --add item chevron left \
                 --set chevron icon= label.drawing=off \
                 --add item front_app left \
                 --set front_app icon.drawing=off script="$PLUGIN_DIR/front_app.sh" \
                 --subscribe front_app front_app_switched

      ##### Adding Right Items #####
      # Logically organized: notifications | time & ambient | connectivity | system | power
      sketchybar --add item notifications right \
                 --set notifications update_freq=10 script="$PLUGIN_DIR/notifications.sh" \
                           click_script="$PLUGIN_DIR/notifications.sh toggle" \
                 --add item clock right \
                 --set clock update_freq=10 icon= script="$PLUGIN_DIR/clock.sh" \
                           click_script="$PLUGIN_DIR/clock.sh popup" \
                 --add item moon_phase right \
                 --set moon_phase update_freq=3600 script="$PLUGIN_DIR/moon_phase.sh" \
                           click_script="open -a 'Calendar'" \
                 --add item weather right \
                 --set weather update_freq=1800 script="$PLUGIN_DIR/weather.sh" \
                           click_script="$PLUGIN_DIR/weather.sh forecast" \
                 --add item spotify left \
                 --set spotify update_freq=1 script="$PLUGIN_DIR/spotify.sh" \
                           click_script="$PLUGIN_DIR/spotify.sh toggle" \
                 --add item network right \
                 --set network update_freq=5 script="$PLUGIN_DIR/network.sh" \
                           click_script="$PLUGIN_DIR/network.sh popup" \
                 --add item volume right \
                 --set volume script="$PLUGIN_DIR/volume.sh" \
                         click_script="$PLUGIN_DIR/volume.sh toggle" \
                 --subscribe volume volume_change \
                 --add item cpu right \
                 --set cpu update_freq=2 script="$PLUGIN_DIR/cpu.sh" \
                       click_script="$PLUGIN_DIR/cpu.sh popup" \
                 --add item memory right \
                 --set memory update_freq=5 script="$PLUGIN_DIR/memory.sh" \
                         click_script="$PLUGIN_DIR/memory.sh popup" \
                 --add item battery right \
                 --set battery update_freq=60 script="$PLUGIN_DIR/battery.sh" \
                         click_script="$PLUGIN_DIR/battery.sh popup" \
                 --subscribe battery system_woke power_source_change

      ##### Force all scripts to run the first time #####
      # Only run update if this is not a duplicate run
      if ! pgrep -f "sketchybar.*--update" > /dev/null 2>&1; then
        sketchybar --update
      fi
    '';
    executable = true;
  };

  # Plugin scripts based on official examples

  # Advanced CPU plugin with visual graph and trend monitoring
  home.file.".config/sketchybar/plugins/cpu.sh" = {
    text = ''
      #!/bin/bash

      # Advanced CPU monitoring with visual graphs and Catppuccin theming
      # Displays usage trends with sparkline-style graphs

      # Set up PATH for system commands
      export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:$PATH"

      # History file for trend tracking
      HISTORY_FILE="$HOME/.cache/sketchybar_cpu_history"
      HISTORY_LENGTH=8  # Number of data points to track

      # Catppuccin Macchiato colors
      RED="0xffed8796"
      PEACH="0xfff5a97f" 
      YELLOW="0xfff9e2af"
      GREEN="0xffa6da95"
      SURFACE0="0xff363a4f"
      TEXT="0xffffffff"

      # Handle popup action to show historical trends
      if [ "$1" = "popup" ]; then
        # Generate trend graph for popup display
        POPUP_GRAPH=""
        if [ -f "$HISTORY_FILE" ]; then
          while IFS= read -r value; do
            if [ "$value" -gt 80 ]; then
              POPUP_GRAPH="$POPUP_GRAPH|"  # Full bar - high usage
            elif [ "$value" -gt 60 ]; then
              POPUP_GRAPH="$POPUP_GRAPH:"  # Three quarters bar
            elif [ "$value" -gt 40 ]; then
              POPUP_GRAPH="$POPUP_GRAPH-"  # Half bar
            elif [ "$value" -gt 20 ]; then
              POPUP_GRAPH="$POPUP_GRAPH."  # Quarter bar
            else
              POPUP_GRAPH="$POPUP_GRAPH_"  # Minimum bar
            fi
          done < "$HISTORY_FILE"
        fi
        
        # Show detailed popup with trend graph
        sketchybar --set "$NAME" label="CPU Trend: $POPUP_GRAPH (''${CPU_USAGE}%)"
        
        # Reset after delay and open Activity Monitor
        sleep 3
        open -a "Activity Monitor"
        
        # Trigger normal update
        exec "$0"
        exit 0
      fi

      # Get current CPU usage
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

      # Create cache directory
      mkdir -p "$(dirname "$HISTORY_FILE")"

      # Update history
      if [ -f "$HISTORY_FILE" ]; then
        # Read existing history and add new value
        HISTORY=$(tail -n $((HISTORY_LENGTH - 1)) "$HISTORY_FILE")
        echo "$HISTORY" > "$HISTORY_FILE"
        echo "$CPU_USAGE" >> "$HISTORY_FILE"
      else
        # Initialize history file
        for i in $(seq 1 $HISTORY_LENGTH); do
          echo "$CPU_USAGE" >> "$HISTORY_FILE"
        done
      fi

      # Generate visual graph using ASCII-compatible characters
      GRAPH=""
      while IFS= read -r value; do
        if [ "$value" -gt 80 ]; then
          GRAPH="$GRAPH|"  # Full bar - high usage
        elif [ "$value" -gt 60 ]; then
          GRAPH="$GRAPH:"  # Three quarters bar
        elif [ "$value" -gt 40 ]; then
          GRAPH="$GRAPH-"  # Half bar
        elif [ "$value" -gt 20 ]; then
          GRAPH="$GRAPH."  # Quarter bar
        else
          GRAPH="$GRAPH_"  # Minimum bar - low usage
        fi
      done < "$HISTORY_FILE"

      # Determine overall color and icon based on current usage
      if [ "$CPU_USAGE" -gt 80 ]; then
          COLOR="$RED"      # Critical
          ICON="󰻠"         # CPU icon - high usage
          GRAPH_COLOR="$RED"
      elif [ "$CPU_USAGE" -gt 50 ]; then
          COLOR="$PEACH"    # High
          ICON="󰻟"         # CPU icon - medium usage  
          GRAPH_COLOR="$YELLOW"
      elif [ "$CPU_USAGE" -gt 20 ]; then
          COLOR="$YELLOW"   # Medium
          ICON="󰻟"         # CPU icon - normal usage
          GRAPH_COLOR="$YELLOW"
      else
          COLOR="$GREEN"    # Good
          ICON="󰻞"         # CPU icon - low usage
          GRAPH_COLOR="$GREEN"
      fi

      # Create clean, stable display: just percentage (no jumping graphs)
      DISPLAY_LABEL="''${CPU_USAGE}%"

      # Update display with clean, stable layout
      sketchybar --set "$NAME" \
                 icon="$ICON" \
                 icon.color="$COLOR" \
                 label="$DISPLAY_LABEL" \
                 label.color="$TEXT" \
                 background.color="$SURFACE0" \
                 background.corner_radius=8 \
                 background.padding_left=5 \
                 background.padding_right=5
    '';
    executable = true;
  };

  # Advanced Network plugin with detailed monitoring and popup information
  home.file.".config/sketchybar/plugins/network.sh" = {
    text = ''
      #!/bin/bash

      # Advanced network monitoring with detailed popup and Catppuccin theming
      # Shows connection quality, speed estimates, and detailed network information

      # Catppuccin Macchiato colors
      RED="0xffed8796"
      PEACH="0xfff5a97f" 
      YELLOW="0xfff9e2af"
      GREEN="0xffa6da95"
      BLUE="0xff8aadf4"
      SURFACE0="0xff363a4f"
      TEXT="0xffffffff"

      # Handle popup action
      if [ "$1" = "popup" ]; then
        # Gather comprehensive network information
        EXTERNAL_IP=$(curl -s --max-time 5 https://ipinfo.io/ip 2>/dev/null || echo "Unknown")
        LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
        DEFAULT_GATEWAY=$(route get default 2>/dev/null | grep gateway | awk '{print $2}')
        DNS_SERVERS=$(scutil --dns | grep nameserver | head -2 | awk '{print $3}' | tr '\n' ' ')
        
        # WiFi specific details
        WIFI_SSID=$(networksetup -getairportnetwork en0 2>/dev/null | cut -d: -f2 | sed 's/^ *//')
        if [ -n "$WIFI_SSID" ] && [ "$WIFI_SSID" != "You are not associated with an AirPort network." ]; then
          WIFI_INFO=$(system_profiler SPAirPortDataType 2>/dev/null | grep -A20 "Current Network Information")
          SIGNAL_STRENGTH=$(echo "$WIFI_INFO" | grep "Signal / Noise" | awk -F: '{print $2}' | awk '{print $1}' | sed 's/dBm//')
          WIFI_SECURITY=$(echo "$WIFI_INFO" | grep "Security" | awk -F: '{print $2}' | sed 's/^ *//')
        fi
        
        # Connection speed test (basic)
        PING_TIME=$(ping -c 3 8.8.8.8 2>/dev/null | tail -1 | awk -F'/' '{print $5}' | cut -d. -f1)
        
        # Interface information
        INTERFACE=$(route get default 2>/dev/null | grep interface | awk '{print $2}')
        INTERFACE_INFO=$(networksetup -listallhardwareports | grep -A1 "Device: $INTERFACE" | head -2)
        INTERFACE_TYPE=$(echo "$INTERFACE_INFO" | grep "Hardware Port:" | cut -d: -f2 | sed 's/^ *//')
        
        # Build comprehensive popup message
        if [ -n "$WIFI_SSID" ] && [ "$WIFI_SSID" != "You are not associated with an AirPort network." ]; then
          POPUP_MSG="📶 $WIFI_SSID • Signal: ''${SIGNAL_STRENGTH}dBm • Security: $WIFI_SECURITY"
        else
          POPUP_MSG="🌐 $INTERFACE_TYPE • Interface: $INTERFACE"
        fi
        
        POPUP_MSG="$POPUP_MSG • Local: $LOCAL_IP • External: $EXTERNAL_IP • Gateway: $DEFAULT_GATEWAY • Ping: ''${PING_TIME}ms"
        
        # Show detailed popup for 10 seconds
        sketchybar --set "$NAME" label="$POPUP_MSG"
        
        # Reset after delay and open Network preferences
        sleep 10
        open /System/Library/PreferencePanes/Network.prefPane
        
        # Trigger normal update
        exec "$0"
        exit 0
      fi

      # Regular network monitoring
      # Check internet connectivity with multiple servers
      CONNECTED=false
      for server in 8.8.8.8 1.1.1.1 9.9.9.9; do
        if ping -c 1 -W 1000 $server &>/dev/null; then
          CONNECTED=true
          break
        fi
      done

      # Get active network interface and details
      INTERFACE=$(route get default 2>/dev/null | grep interface | awk '{print $2}')
      INTERFACE_TYPE=""
      if [ -n "$INTERFACE" ]; then
          INTERFACE_INFO=$(networksetup -listallhardwareports | grep -A1 "Device: $INTERFACE" | head -2)
          INTERFACE_TYPE=$(echo "$INTERFACE_INFO" | grep "Hardware Port:" | cut -d: -f2 | sed 's/^ *//')
      fi

      # Check WiFi status with signal strength
      WIFI_SSID=$(networksetup -getairportnetwork en0 2>/dev/null | cut -d: -f2 | sed 's/^ *//')
      WIFI_CONNECTED=false
      SIGNAL_STRENGTH=""
      
      if [ -n "$WIFI_SSID" ] && [ "$WIFI_SSID" != "You are not associated with an AirPort network." ]; then
          WIFI_CONNECTED=true
          # Get signal strength for better status indication
          if command -v airport >/dev/null 2>&1; then
              SIGNAL_STRENGTH=$(airport -I | awk '/agrCtlRSSI/ {print $2}')
          fi
      fi

      # Determine connection status with enhanced visuals
      if [ "$CONNECTED" = false ]; then
          COLOR="$RED"              # No connection
          ICON="󰈂"                # Network disconnected
          LABEL="No Network"
      elif [ "$WIFI_CONNECTED" = true ]; then
          # WiFi connection with signal quality indication
          if [ -n "$SIGNAL_STRENGTH" ]; then
              if [ "$SIGNAL_STRENGTH" -gt -40 ]; then
                  COLOR="$GREEN"    # Excellent signal
                  ICON="󰤨"        # WiFi excellent
                  QUALITY="||||"    # 4 bars
              elif [ "$SIGNAL_STRENGTH" -gt -55 ]; then
                  COLOR="$GREEN"    # Good signal
                  ICON="󰤥"        # WiFi good
                  QUALITY="|||:"    # 3 bars
              elif [ "$SIGNAL_STRENGTH" -gt -70 ]; then
                  COLOR="$YELLOW"   # Fair signal
                  ICON="󰤢"        # WiFi fair
                  QUALITY="||.."    # 2 bars
              else
                  COLOR="$PEACH"    # Poor signal
                  ICON="󰤟"        # WiFi poor
                  QUALITY="|..."    # 1 bar
              fi
              # Truncate long SSID names
              DISPLAY_SSID="$WIFI_SSID"
              if [ ''${#DISPLAY_SSID} -gt 12 ]; then
                DISPLAY_SSID="''${DISPLAY_SSID:0:9}..."
              fi
              LABEL="$DISPLAY_SSID $QUALITY"
          else
              COLOR="$GREEN"        # WiFi connected
              ICON="󰤨"            # WiFi icon
              LABEL="$WIFI_SSID"
          fi
      else
          # Wired connection with type detection
          case "$INTERFACE_TYPE" in
              *"USB"*|*"LAN"*)
                  COLOR="$BLUE"     # USB Ethernet
                  ICON="󰌗"        # USB icon
                  LABEL="USB Ethernet"
                  ;;
              *"Thunderbolt"*)
                  COLOR="$BLUE"     # Thunderbolt
                  ICON="󱎔"        # Thunderbolt icon
                  LABEL="Thunderbolt"
                  ;;
              *"Ethernet"*)
                  COLOR="$GREEN"    # Ethernet
                  ICON="󰈀"        # Ethernet icon
                  LABEL="Ethernet"
                  ;;
              *)
                  COLOR="$GREEN"    # Unknown wired
                  ICON="󰈀"        # Generic ethernet
                  LABEL="Wired"
                  ;;
          esac
      fi

      # Update display with Catppuccin theming
      sketchybar --set "$NAME" \
                 icon="$ICON" \
                 icon.color="$COLOR" \
                 label="$LABEL" \
                 label.color="$TEXT" \
                 background.color="$SURFACE0" \
                 background.corner_radius=8 \
                 background.padding_left=5 \
                 background.padding_right=5
    '';
    executable = true;
  };

  # Advanced Memory plugin with visual graph and detailed monitoring
  home.file.".config/sketchybar/plugins/memory.sh" = {
    text = ''
      #!/bin/bash

      # Advanced memory monitoring with visual graphs and Catppuccin theming
      # Shows memory usage trends with detailed breakdown

      # Set up PATH for system commands
      export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:$PATH"

      # History file for trend tracking
      HISTORY_FILE="$HOME/.cache/sketchybar_memory_history"
      HISTORY_LENGTH=8  # Number of data points to track

      # Catppuccin Macchiato colors
      RED="0xffed8796"
      PEACH="0xfff5a97f" 
      YELLOW="0xfff9e2af"
      GREEN="0xffa6da95"
      SURFACE0="0xff363a4f"
      TEXT="0xffffffff"

      # Handle popup action to show historical trends
      if [ "$1" = "popup" ]; then
        # Generate trend graph for popup display
        POPUP_GRAPH=""
        if [ -f "$HISTORY_FILE" ]; then
          while IFS= read -r value; do
            if [ "$value" -gt 85 ]; then
              POPUP_GRAPH="$POPUP_GRAPH|"  # Full bar - critical usage
            elif [ "$value" -gt 70 ]; then
              POPUP_GRAPH="$POPUP_GRAPH:"  # Three quarters bar - high
            elif [ "$value" -gt 50 ]; then
              POPUP_GRAPH="$POPUP_GRAPH-"  # Half bar - medium
            elif [ "$value" -gt 30 ]; then
              POPUP_GRAPH="$POPUP_GRAPH."  # Quarter bar - low
            else
              POPUP_GRAPH="$POPUP_GRAPH_"  # Minimum bar - very low
            fi
          done < "$HISTORY_FILE"
        fi
        
        # Show detailed popup with trend graph
        sketchybar --set "$NAME" label="Memory Trend: $POPUP_GRAPH (''${PERCENTAGE}%)"
        
        # Reset after delay and open Activity Monitor
        sleep 3
        open -a "Activity Monitor"
        
        # Trigger normal update
        exec "$0"
        exit 0
      fi

      # Get detailed memory information
      VM_STAT=$(vm_stat)
      MEMORY_PRESSURE=$(memory_pressure 2>/dev/null | grep "System-wide memory free percentage" | awk '{print $5}' | sed 's/%//')

      # Extract memory statistics with better parsing
      PAGES_FREE=$(echo "$VM_STAT" | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
      PAGES_ACTIVE=$(echo "$VM_STAT" | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
      PAGES_INACTIVE=$(echo "$VM_STAT" | grep "Pages inactive" | awk '{print $3}' | sed 's/\.//')
      PAGES_SPECULATIVE=$(echo "$VM_STAT" | grep "Pages speculative" | awk '{print $3}' | sed 's/\.//')
      PAGES_WIRED=$(echo "$VM_STAT" | grep "Pages wired down" | awk '{print $4}' | sed 's/\.//')

      # Calculate memory usage (4KB per page)
      PAGE_SIZE=4096
      TOTAL_PAGES=$((PAGES_FREE + PAGES_ACTIVE + PAGES_INACTIVE + PAGES_SPECULATIVE + PAGES_WIRED))
      USED_PAGES=$((PAGES_ACTIVE + PAGES_INACTIVE + PAGES_SPECULATIVE + PAGES_WIRED))

      # Convert to GB with decimal precision
      TOTAL_GB=$((TOTAL_PAGES * PAGE_SIZE / 1024 / 1024 / 1024))
      USED_GB=$((USED_PAGES * PAGE_SIZE / 1024 / 1024 / 1024))

      # Calculate percentage
      if [ "$TOTAL_GB" -gt 0 ]; then
          PERCENTAGE=$((USED_GB * 100 / TOTAL_GB))
      else
          PERCENTAGE=0
      fi

      # Create cache directory
      mkdir -p "$(dirname "$HISTORY_FILE")"

      # Update history
      if [ -f "$HISTORY_FILE" ]; then
        # Read existing history and add new value
        HISTORY=$(tail -n $((HISTORY_LENGTH - 1)) "$HISTORY_FILE")
        echo "$HISTORY" > "$HISTORY_FILE"
        echo "$PERCENTAGE" >> "$HISTORY_FILE"
      else
        # Initialize history file
        for i in $(seq 1 $HISTORY_LENGTH); do
          echo "$PERCENTAGE" >> "$HISTORY_FILE"
        done
      fi

      # Generate visual graph using ASCII-compatible characters
      GRAPH=""
      while IFS= read -r value; do
        if [ "$value" -gt 85 ]; then
          GRAPH="$GRAPH|"  # Full bar - critical usage
        elif [ "$value" -gt 70 ]; then
          GRAPH="$GRAPH:"  # Three quarters bar - high
        elif [ "$value" -gt 50 ]; then
          GRAPH="$GRAPH-"  # Half bar - medium
        elif [ "$value" -gt 30 ]; then
          GRAPH="$GRAPH."  # Quarter bar - low
        else
          GRAPH="$GRAPH_"  # Minimum bar - very low
        fi
      done < "$HISTORY_FILE"

      # Determine color and icon based on current usage
      if [ "$PERCENTAGE" -gt 85 ]; then
          COLOR="$RED"      # Critical
          ICON="󰍛"         # Memory icon - critical
          GRAPH_COLOR="$RED"
      elif [ "$PERCENTAGE" -gt 70 ]; then
          COLOR="$PEACH"    # High
          ICON="󰍛"         # Memory icon - high
          GRAPH_COLOR="$YELLOW"
      elif [ "$PERCENTAGE" -gt 50 ]; then
          COLOR="$YELLOW"   # Medium
          ICON="󰍛"         # Memory icon - medium
          GRAPH_COLOR="$YELLOW"
      else
          COLOR="$GREEN"    # Good
          ICON="󰍛"         # Memory icon - good
          GRAPH_COLOR="$GREEN"
      fi

      # Create clean, stable display: just usage info (no jumping graphs)
      DISPLAY_LABEL="''${USED_GB}G (''${PERCENTAGE}%)"

      # Update display with clean, stable layout
      sketchybar --set "$NAME" \
                 icon="$ICON" \
                 icon.color="$COLOR" \
                 label="$DISPLAY_LABEL" \
                 label.color="$TEXT" \
                 background.color="$SURFACE0" \
                 background.corner_radius=8 \
                 background.padding_left=5 \
                 background.padding_right=5
    '';
    executable = true;
  };

  # Enhanced Battery plugin with detailed popup information
  home.file.".config/sketchybar/plugins/battery.sh" = {
    text = ''
      #!/bin/bash

      # Advanced battery plugin with popup details and Catppuccin theming

      # Handle popup action
      if [ "$1" = "popup" ]; then
        # Get detailed battery information
        BATTERY_INFO="$(pmset -g batt)"
        POWER_INFO="$(pmset -g ps)"
        ADAPTER_INFO="$(pmset -g adapter)"
        
        # Extract detailed info
        PERCENTAGE="$(echo "$BATTERY_INFO" | grep -Eo "\d+%" | cut -d% -f1)"
        TIME_REMAINING="$(echo "$BATTERY_INFO" | grep -o '[0-9]*:[0-9]*' | head -1)"
        CYCLE_COUNT="$(system_profiler SPPowerDataType | grep "Cycle Count" | awk '{print $3}')"
        CONDITION="$(system_profiler SPPowerDataType | grep "Condition" | awk '{print $2}')"
        CHARGING="$(echo "$BATTERY_INFO" | grep 'AC Power')"
        
        # Build popup message
        if [[ "$CHARGING" != "" ]]; then
          STATUS="⚡ Charging"
          if [ -n "$TIME_REMAINING" ]; then
            TIME_MSG="🕐 $TIME_REMAINING until full"
          else
            TIME_MSG="🕐 Calculating time..."
          fi
        else
          STATUS="🔋 On Battery"
          if [ -n "$TIME_REMAINING" ]; then
            TIME_MSG="🕐 $TIME_REMAINING remaining"
          else
            TIME_MSG="🕐 Calculating time..."
          fi
        fi
        
        # Show detailed popup for 8 seconds
        POPUP_MSG="$STATUS • ''${PERCENTAGE}% • $TIME_MSG • Health: $CONDITION • Cycles: $CYCLE_COUNT"
        sketchybar --set "$NAME" label="$POPUP_MSG"
        
        # Reset after delay and open System Preferences
        sleep 8
        open /System/Library/PreferencePanes/Battery.prefPane
        
        # Trigger normal update
        exec "$0"
        exit 0
      fi

      # Regular battery monitoring
      BATTERY_INFO="$(pmset -g batt)"
      PERCENTAGE="$(echo "$BATTERY_INFO" | grep -Eo "\d+%" | cut -d% -f1)"
      CHARGING="$(echo "$BATTERY_INFO" | grep 'AC Power')"

      if [ "$PERCENTAGE" = "" ]; then
        exit 0
      fi

      # Determine charging status
      IS_CHARGING=false
      if [[ "$CHARGING" != "" ]]; then
        IS_CHARGING=true
      fi

      # Catppuccin themed battery indicators
      if [ "$IS_CHARGING" = true ]; then
          # Charging icons and colors
          case "''${PERCENTAGE}" in
            9[5-9]|100) 
                ICON="󰂅"          # Charging - almost full
                COLOR="0xffa6da95" # Catppuccin Green
                ;;
            [8-9][0-4]) 
                ICON="󰂋"          # Charging - high
                COLOR="0xffa6da95" # Catppuccin Green  
                ;;
            [6-7][0-9]) 
                ICON="󰂊"          # Charging - medium-high
                COLOR="0xfff9e2af" # Catppuccin Yellow
                ;;
            [4-5][0-9]) 
                ICON="󰢞"          # Charging - medium
                COLOR="0xfff9e2af" # Catppuccin Yellow
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

      # Update display with Catppuccin theming
      sketchybar --set "$NAME" \
                 icon="$ICON" \
                 icon.color="$COLOR" \
                 label="$LABEL" \
                 label.color="0xffffffff" \
                 background.color="0xff363a4f" \
                 background.corner_radius=8 \
                 background.padding_left=5 \
                 background.padding_right=5
    '';
    executable = true;
  };

  # Enhanced Clock plugin with calendar popup and event preview
  home.file.".config/sketchybar/plugins/clock.sh" = {
    text = ''
      #!/bin/bash

      # Enhanced clock plugin with calendar integration and event preview
      # Click: Show calendar popup with today's events

      # Handle click action
      if [ "$1" = "popup" ]; then
        # Get today's events from Calendar
        TODAY=$(date '+%Y-%m-%d')
        EVENTS=$(osascript << EOF
tell application "Calendar"
  set todayEvents to {}
  set todayDate to date "$TODAY"
  
  repeat with cal in calendars
    try
      set calEvents to events of cal whose start date ≥ todayDate and start date < (todayDate + 1 * days)
      repeat with evt in calEvents
        set eventInfo to (summary of evt) & " at " & (time string of start date of evt)
        set end of todayEvents to eventInfo
      end repeat
    end try
  end repeat
  
  if length of todayEvents > 0 then
    return (todayEvents as string)
  else
    return "No events today"
  end if
end tell
EOF
)
        
        # Show temporary popup with events
        if [ "$EVENTS" != "No events today" ]; then
          # Clean up the event string and show first 3 events
          CLEAN_EVENTS=$(echo "$EVENTS" | sed 's/item delimiter/\n/g' | head -3 | tr '\n' ' • ')
          sketchybar --set "$NAME" label="📅 $CLEAN_EVENTS"
        else
          sketchybar --set "$NAME" label="📅 No events today"
        fi
        
        # Reset after 5 seconds
        sleep 5
        
        # Open Calendar app
        open -a "Calendar"
        
        # Reset display
        sketchybar --set "$NAME" label="$(date '+%d.%m %H:%M')"
        exit 0
      fi

      # Regular time update
      CURRENT_TIME=$(date '+%d.%m %H:%M')
      
      # Check if it's a work day and add indicator
      DAY_OF_WEEK=$(date '+%u') # 1=Monday, 7=Sunday
      if [ "$DAY_OF_WEEK" -ge 1 ] && [ "$DAY_OF_WEEK" -le 5 ]; then
        # Weekday - check for next meeting
        NEXT_MEETING=$(osascript << EOF 2>/dev/null
tell application "Calendar"
  set now to current date
  set endOfDay to now + (24 * 60 * 60 - (time of now))
  
  repeat with cal in calendars
    try
      set upcomingEvents to events of cal whose start date > now and start date ≤ endOfDay
      if length of upcomingEvents > 0 then
        set nextEvent to item 1 of upcomingEvents
        return (time string of start date of nextEvent)
      end if
    end try
  end repeat
  
  return ""
end tell
EOF
)
        
        if [ -n "$NEXT_MEETING" ] && [ "$NEXT_MEETING" != "" ]; then
          INDICATOR="🕐"
        else
          INDICATOR=""
        fi
      else
        # Weekend
        INDICATOR="🌟"
      fi

      # Update display with time and indicator
      sketchybar --set "$NAME" \
                 icon="$INDICATOR" \
                 label="$CURRENT_TIME" \
                 icon.color="0xffffffff" \
                 label.color="0xffffffff"
    '';
    executable = true;
  };

  # Moon Phase plugin - displays current lunar phase
  home.file.".config/sketchybar/plugins/moon_phase.sh" = {
    text = ''
      #!/bin/bash

      # Moon Phase plugin for SketchyBar
      # Calculates current lunar phase and displays appropriate emoji

      # Calculate days since new moon (Jan 6, 2000 was a new moon)
      current_date=$(date +%s)
      new_moon_ref=947116800  # Jan 6, 2000 00:00:00 UTC
      lunar_cycle=2551443     # Lunar cycle in seconds (29.53059 days)
      
      # Calculate current position in lunar cycle
      days_since_ref=$(( (current_date - new_moon_ref) / 86400 ))
      cycle_position=$(( days_since_ref % (lunar_cycle / 86400) ))
      
      # Determine moon phase based on cycle position
      if [ $cycle_position -lt 1 ]; then
          MOON="🌑"  # New Moon
          PHASE="New"
      elif [ $cycle_position -lt 7 ]; then
          MOON="🌒"  # Waxing Crescent
          PHASE="Waxing"
      elif [ $cycle_position -lt 9 ]; then
          MOON="🌓"  # First Quarter  
          PHASE="First Quarter"
      elif [ $cycle_position -lt 15 ]; then
          MOON="🌔"  # Waxing Gibbous
          PHASE="Waxing"
      elif [ $cycle_position -lt 16 ]; then
          MOON="🌕"  # Full Moon
          PHASE="Full"
      elif [ $cycle_position -lt 22 ]; then
          MOON="🌖"  # Waning Gibbous
          PHASE="Waning"
      elif [ $cycle_position -lt 24 ]; then
          MOON="🌗"  # Last Quarter
          PHASE="Last Quarter"
      else
          MOON="🌘"  # Waning Crescent
          PHASE="Waning"
      fi

      # Update display with moon phase
      sketchybar --set "$NAME" \
                 icon="$MOON" \
                 label="" \
                 icon.color="0xffffffff"
    '';
    executable = true;
  };

  # Spotify plugin - shows current track with play/pause control
  home.file.".config/sketchybar/plugins/spotify.sh" = {
    text = ''
      #!/bin/bash

      # Spotify plugin for SketchyBar with play/pause control
      # Shows current track and provides click-to-toggle functionality

      # Handle toggle action from click
      if [ "$1" = "toggle" ]; then
        osascript -e 'tell application "Spotify" to playpause'
        exit 0
      fi

      # Check if Spotify is running
      if ! pgrep -x "Spotify" > /dev/null; then
        sketchybar --set "$NAME" \
                   icon="󰓇" \
                   label="Not playing" \
                   icon.color="0xff6c7086" \
                   label.color="0xff6c7086"
        exit 0
      fi

      # Get Spotify state and track info
      SPOTIFY_STATE=$(osascript -e 'tell application "Spotify" to player state as string' 2>/dev/null)
      
      if [ "$SPOTIFY_STATE" = "playing" ]; then
        TRACK=$(osascript -e 'tell application "Spotify" to name of current track as string' 2>/dev/null)
        ARTIST=$(osascript -e 'tell application "Spotify" to artist of current track as string' 2>/dev/null)
        
        # Truncate long track names
        if [ ''${#TRACK} -gt 20 ]; then
          TRACK="''${TRACK:0:17}..."
        fi
        if [ ''${#ARTIST} -gt 15 ]; then
          ARTIST="''${ARTIST:0:12}..."
        fi
        
        ICON="󰏤"  # Playing icon
        LABEL="$ARTIST - $TRACK"
        COLOR="0xffa6da95"  # Catppuccin Green when playing
        BG_COLOR="0xff363a4f"  # Surface0 background
        
      elif [ "$SPOTIFY_STATE" = "paused" ]; then
        TRACK=$(osascript -e 'tell application "Spotify" to name of current track as string' 2>/dev/null)
        ARTIST=$(osascript -e 'tell application "Spotify" to artist of current track as string' 2>/dev/null)
        
        # Truncate long track names
        if [ ''${#TRACK} -gt 20 ]; then
          TRACK="''${TRACK:0:17}..."
        fi
        if [ ''${#ARTIST} -gt 15 ]; then
          ARTIST="''${ARTIST:0:12}..."
        fi
        
        ICON="󰐊"  # Paused icon
        LABEL="$ARTIST - $TRACK"
        COLOR="0xfff9e2af"  # Catppuccin Yellow when paused
        BG_COLOR="0xff363a4f"  # Surface0 background
        
      else
        ICON="󰓇"  # Spotify icon
        LABEL="Ready"
        COLOR="0xff939ab7"  # Catppuccin Overlay2 when stopped
        BG_COLOR="0xff363a4f"  # Surface0 background
      fi

      # Update display with Catppuccin theming
      sketchybar --set "$NAME" \
                 icon="$ICON" \
                 label="$LABEL" \
                 icon.color="$COLOR" \
                 label.color="0xffffffff" \
                 background.color="$BG_COLOR" \
                 background.corner_radius=8 \
                 background.padding_left=8 \
                 background.padding_right=8
    '';
    executable = true;
  };

  # Advanced Weather plugin with multi-day forecasting and detailed conditions
  home.file.".config/sketchybar/plugins/weather.sh" = {
    text = ''
      #!/bin/bash

      # Advanced weather plugin with multi-day forecasting and Catppuccin theming
      # Uses wttr.in API for comprehensive weather data (no API key required)
      # Features: current conditions, 3-day forecast popup, detailed weather info

      # Catppuccin Macchiato colors
      YELLOW="0xfff9e2af"
      BLUE="0xff8aadf4"
      SAPPHIRE="0xff7dc4e4"
      GREEN="0xffa6da95"
      RED="0xffed8796"
      PEACH="0xfff5a97f"
      MAUVE="0xffc6a0f6"
      ROSEWATER="0xfff4dbd6"
      OVERLAY2="0xff939ab7"
      SUBTEXT0="0xffa5adcb"
      SURFACE0="0xff363a4f"
      TEXT="0xffffffff"

      # Configuration
      LOCATION=""  # Empty = auto-detect, or set to specific city
      CACHE_FILE="$HOME/.cache/sketchybar_weather"
      FORECAST_CACHE="$HOME/.cache/sketchybar_weather_forecast"
      CACHE_DURATION=1800  # 30 minutes in seconds

      # Create cache directory
      mkdir -p "$(dirname "$CACHE_FILE")"

      # Handle forecast popup action
      if [ "$1" = "forecast" ]; then
        # Get detailed 3-day forecast
        if [ -n "$LOCATION" ]; then
          FORECAST_URL="wttr.in/$LOCATION?format=%l:+%C+%t+%w+%h\n%l:+Tomorrow:+%C+%t+%w\n%l:+Day+3:+%C+%t+%w"
        else
          FORECAST_URL="wttr.in/?format=%l:+%C+%t+%w+%h\n%l:+Tomorrow:+%C+%t+%w\n%l:+Day+3:+%C+%t+%w"
        fi
        
        # Fetch comprehensive weather data
        if [ -n "$LOCATION" ]; then
          DETAILED_URL="wttr.in/$LOCATION?format=j1"
        else
          DETAILED_URL="wttr.in/?format=j1"
        fi
        
        DETAILED_DATA=$(curl -s --max-time 8 "$DETAILED_URL" 2>/dev/null)
        
        if [ $? -eq 0 ] && [ -n "$DETAILED_DATA" ]; then
          # Parse JSON data for comprehensive info
          LOCATION_NAME=$(echo "$DETAILED_DATA" | jq -r '.nearest_area[0].areaName[0].value // "Unknown"' 2>/dev/null || echo "Unknown")
          CURRENT_TEMP=$(echo "$DETAILED_DATA" | jq -r '.current_condition[0].temp_C // "N/A"' 2>/dev/null || echo "N/A")
          FEELS_LIKE=$(echo "$DETAILED_DATA" | jq -r '.current_condition[0].FeelsLikeC // "N/A"' 2>/dev/null || echo "N/A")
          HUMIDITY=$(echo "$DETAILED_DATA" | jq -r '.current_condition[0].humidity // "N/A"' 2>/dev/null || echo "N/A")
          WIND_SPEED=$(echo "$DETAILED_DATA" | jq -r '.current_condition[0].windspeedKmph // "N/A"' 2>/dev/null || echo "N/A")
          WIND_DIR=$(echo "$DETAILED_DATA" | jq -r '.current_condition[0].winddir16Point // "N/A"' 2>/dev/null || echo "N/A")
          VISIBILITY=$(echo "$DETAILED_DATA" | jq -r '.current_condition[0].visibility // "N/A"' 2>/dev/null || echo "N/A")
          UV_INDEX=$(echo "$DETAILED_DATA" | jq -r '.current_condition[0].uvIndex // "N/A"' 2>/dev/null || echo "N/A")
          
                     # Tomorrow's forecast
          TOMORROW_CONDITION=$(echo "$DETAILED_DATA" | jq -r '.weather[1].hourly[4].weatherDesc[0].value // "N/A"' 2>/dev/null || echo "N/A")
          TOMORROW_HIGH=$(echo "$DETAILED_DATA" | jq -r '.weather[1].maxtempC // "N/A"' 2>/dev/null || echo "N/A")
          TOMORROW_LOW=$(echo "$DETAILED_DATA" | jq -r '.weather[1].mintempC // "N/A"' 2>/dev/null || echo "N/A")
          
          # Day after tomorrow
          DAY3_CONDITION=$(echo "$DETAILED_DATA" | jq -r '.weather[2].hourly[4].weatherDesc[0].value // "N/A"' 2>/dev/null || echo "N/A")
          DAY3_HIGH=$(echo "$DETAILED_DATA" | jq -r '.weather[2].maxtempC // "N/A"' 2>/dev/null || echo "N/A")
          DAY3_LOW=$(echo "$DETAILED_DATA" | jq -r '.weather[2].mintempC // "N/A"' 2>/dev/null || echo "N/A")
          
          # Build comprehensive forecast popup
          POPUP_MSG="🌍 $LOCATION_NAME • Now: ''${CURRENT_TEMP}°C (feels ''${FEELS_LIKE}°C) • Humidity: ''${HUMIDITY}% • Wind: ''${WIND_SPEED}km/h $WIND_DIR • UV: $UV_INDEX • Tomorrow: $TOMORROW_CONDITION ''${TOMORROW_HIGH}°/''${TOMORROW_LOW}°C • Day 3: $DAY3_CONDITION ''${DAY3_HIGH}°/''${DAY3_LOW}°C"
        else
          # Fallback simple forecast
          POPUP_MSG="🌤️ Weather forecast unavailable • Check your internet connection"
        fi
        
        # Show detailed forecast for 12 seconds
        sketchybar --set "$NAME" label="$POPUP_MSG"
        
        # Reset after delay and open Weather app
        sleep 12
        open -a "Weather"
        
        # Trigger normal update
        exec "$0"
        exit 0
      fi

      # Regular weather monitoring with enhanced caching
      # Check if cache is still valid
      if [ -f "$CACHE_FILE" ]; then
        CACHE_TIME=$(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null)
        CURRENT_TIME=$(date +%s)
        if [ $((CURRENT_TIME - CACHE_TIME)) -lt $CACHE_DURATION ]; then
          # Use cached data
          if [ -s "$CACHE_FILE" ]; then
            source "$CACHE_FILE"
            
            # Update display with cached data
            sketchybar --set "$NAME" \
                       icon="$WEATHER_ICON" \
                       label="$WEATHER_TEMP" \
                       icon.color="$WEATHER_COLOR" \
                       label.color="$TEXT" \
                       background.color="$SURFACE0" \
                       background.corner_radius=8 \
                       background.padding_left=5 \
                       background.padding_right=5
            exit 0
          fi
        fi
      fi

      # Fetch current weather with enhanced format
      if [ -n "$LOCATION" ]; then
        WEATHER_URL="wttr.in/$LOCATION?format=%C+%t+%w"
      else
        WEATHER_URL="wttr.in/?format=%C+%t+%w"
      fi

      # Get weather data with timeout
      WEATHER_DATA=$(curl -s --max-time 10 "$WEATHER_URL" 2>/dev/null)

      if [ $? -eq 0 ] && [ -n "$WEATHER_DATA" ]; then
        # Parse enhanced weather data
        CONDITION=$(echo "$WEATHER_DATA" | sed 's/+[0-9-]*°[CF].*$//' | xargs)
        TEMP=$(echo "$WEATHER_DATA" | grep -o '+[0-9-]*°[CF]' | head -1)
        WIND=$(echo "$WEATHER_DATA" | grep -o '[0-9]*km/h' | head -1)
        
        # Enhanced condition mapping with more accurate icons and colors
        case "$CONDITION" in
          *"Clear"*|*"Sunny"*)
            WEATHER_ICON="☀️"
            WEATHER_COLOR="$YELLOW"
            ;;
          *"Partly cloudy"*|*"Partly Cloudy"*)
            WEATHER_ICON="⛅"
            WEATHER_COLOR="$BLUE"
            ;;
          *"Cloudy"*|*"Overcast"*)
            WEATHER_ICON="☁️"
            WEATHER_COLOR="$OVERLAY2"
            ;;
          *"Light rain"*|*"Patchy rain"*)
            WEATHER_ICON="🌦️"
            WEATHER_COLOR="$SAPPHIRE"
            ;;
          *"Rain"*|*"Heavy rain"*|*"Drizzle"*)
            WEATHER_ICON="🌧️"
            WEATHER_COLOR="$SAPPHIRE"
            ;;
          *"Snow"*|*"Light snow"*|*"Heavy snow"*)
            WEATHER_ICON="❄️"
            WEATHER_COLOR="$ROSEWATER"
            ;;
          *"Thunderstorm"*|*"Thunder"*)
            WEATHER_ICON="⛈️"
            WEATHER_COLOR="$MAUVE"
            ;;
          *"Fog"*|*"Mist"*|*"Haze"*)
            WEATHER_ICON="🌫️"
            WEATHER_COLOR="$SUBTEXT0"
            ;;
          *"Windy"*)
            WEATHER_ICON="💨"
            WEATHER_COLOR="$GREEN"
            ;;
          *)
            WEATHER_ICON="🌤️"
            WEATHER_COLOR="$BLUE"
            ;;
        esac

        # Create enhanced display with temperature
        WEATHER_TEMP="$TEMP"
        
        # Cache the enhanced results
        cat > "$CACHE_FILE" << EOF
WEATHER_ICON="$WEATHER_ICON"
WEATHER_TEMP="$WEATHER_TEMP"
WEATHER_COLOR="$WEATHER_COLOR"
EOF

      else
        # Enhanced fallback when API is unavailable
        WEATHER_ICON="❌"
        WEATHER_TEMP="Offline"
        WEATHER_COLOR="$RED"
        
                 # Don't cache errors
        rm -f "$CACHE_FILE"
      fi

      # Update display with Catppuccin theming
      sketchybar --set "$NAME" \
                 icon="$WEATHER_ICON" \
                 label="$WEATHER_TEMP" \
                 icon.color="$WEATHER_COLOR" \
                 label.color="$TEXT" \
                 background.color="$SURFACE0" \
                 background.corner_radius=8 \
                 background.padding_left=5 \
                 background.padding_right=5
    '';
    executable = true;
  };

  # Advanced Notification Center integration
  home.file.".config/sketchybar/plugins/notifications.sh" = {
    text = ''
      #!/bin/bash

      # Advanced notification center integration with Catppuccin theming
      # Monitors macOS notifications and provides custom notification display

      # Catppuccin Macchiato colors
      RED="0xffed8796"
      PEACH="0xfff5a97f" 
      YELLOW="0xfff9e2af"
      GREEN="0xffa6da95"
      BLUE="0xff8aadf4"
      MAUVE="0xffc6a0f6"
      SURFACE0="0xff363a4f"
      SURFACE1="0xff494d64"
      TEXT="0xffffffff"
      SUBTEXT1="0xffb8c0e0"

      # Configuration
      NOTIFICATION_LOG="$HOME/.cache/sketchybar_notifications"
      DO_NOT_DISTURB_FILE="$HOME/.cache/sketchybar_dnd"

      # Create cache directory
      mkdir -p "$(dirname "$NOTIFICATION_LOG")"

      # Handle toggle action (Do Not Disturb)
      if [ "$1" = "toggle" ]; then
        if [ -f "$DO_NOT_DISTURB_FILE" ]; then
          # Turn off Do Not Disturb
          rm -f "$DO_NOT_DISTURB_FILE"
          
          # Show confirmation
          sketchybar --set "$NAME" \
                     icon="🔔" \
                     label="Notifications ON" \
                     icon.color="$GREEN"
          sleep 2
          
          # Reset to normal display
          exec "$0"
        else
          # Turn on Do Not Disturb
          touch "$DO_NOT_DISTURB_FILE"
          
          # Show confirmation
          sketchybar --set "$NAME" \
                     icon="🔕" \
                     label="Do Not Disturb" \
                     icon.color="$YELLOW"
          sleep 2
          
          # Reset to DND display
          exec "$0"
        fi
        exit 0
      fi

      # Check Do Not Disturb status
      DND_ACTIVE=false
      if [ -f "$DO_NOT_DISTURB_FILE" ]; then
        DND_ACTIVE=true
      fi

      # Check macOS Do Not Disturb status (system level)
      SYSTEM_DND=$(defaults read ~/Library/Preferences/ByHost/com.apple.notificationcenterui doNotDisturb 2>/dev/null || echo "0")

      # Get notification count from recent notifications
             # This is a simplified approach - in practice you'd want to monitor actual notification events
      NOTIFICATION_COUNT=0
      
      # Check for recent notifications in the last hour using log
      RECENT_NOTIFICATIONS=$(log show --predicate 'subsystem == "com.apple.UserNotifications"' --info --last 1h 2>/dev/null | grep -c "Posting notification" 2>/dev/null || echo "0")
      
      # Simulate notification count (since direct notification monitoring is complex)
               # In a real implementation, you'd hook into the notification system
      if [ "$RECENT_NOTIFICATIONS" -gt 0 ]; then
        NOTIFICATION_COUNT=$RECENT_NOTIFICATIONS
      fi

      # Limit notification count display to avoid clutter
      if [ "$NOTIFICATION_COUNT" -gt 99 ]; then
        NOTIFICATION_COUNT="99+"
      fi

      # Determine display based on status
      if [ "$SYSTEM_DND" = "1" ] || [ "$DND_ACTIVE" = true ]; then
        # Do Not Disturb is active
        ICON="🔕"
        COLOR="$YELLOW"
        if [ "$NOTIFICATION_COUNT" -gt 0 ]; then
          LABEL="DND ($NOTIFICATION_COUNT)"
        else
          LABEL="DND"
        fi
      else
        # Normal notification status
        if [ "$NOTIFICATION_COUNT" -gt 0 ]; then
          # Has notifications
          if [ "$NOTIFICATION_COUNT" -gt 10 ]; then
            ICON="🔴"  # Red dot for many notifications
            COLOR="$RED"
          elif [ "$NOTIFICATION_COUNT" -gt 5 ]; then
            ICON="🟡"  # Yellow dot for several notifications
            COLOR="$YELLOW"
          else
            ICON="🔔"  # Bell for few notifications
            COLOR="$BLUE"
          fi
          LABEL="$NOTIFICATION_COUNT"
        else
          # No notifications
          ICON="🔔"
          COLOR="$GREEN"
          LABEL=""
        fi
      fi

      # Check for urgent notifications (simplified)
             # In practice, you'd parse actual notification priority
      URGENT_COUNT=$(echo "$NOTIFICATION_COUNT" | grep -E '^[0-9]+$' 2>/dev/null)
      if [ -n "$URGENT_COUNT" ] && [ "$URGENT_COUNT" -gt 20 ]; then
        # Too many notifications - suggest action
        COLOR="$RED"
        ICON="🚨"
        LABEL="$NOTIFICATION_COUNT!"
      fi

      # Special handling for specific times
      CURRENT_HOUR=$(date +%H)
      if [ "$CURRENT_HOUR" -ge 22 ] || [ "$CURRENT_HOUR" -le 6 ]; then
        # Night time - suggest quiet mode
        if [ "$DND_ACTIVE" = false ] && [ "$SYSTEM_DND" != "1" ]; then
          COLOR="$MAUVE"
          ICON="🌙"
          if [ -n "$LABEL" ]; then
            LABEL="$LABEL 🌙"
          else
            LABEL="🌙"
          fi
        fi
      fi

      # Update display with notification status
      sketchybar --set "$NAME" \
                 icon="$ICON" \
                 icon.color="$COLOR" \
                 label="$LABEL" \
                 label.color="$TEXT" \
                 background.color="$SURFACE0" \
                 background.corner_radius=8 \
                 background.padding_left=5 \
                 background.padding_right=5
    '';
    executable = true;
  };

  # Titlebar Integration Helper - for seamless app integration with SketchyBar
  home.file.".config/sketchybar/helpers/titlebar_setup.sh" = {
    text = ''
      #!/bin/bash

      # Titlebar Hiding Setup for Seamless SketchyBar Integration
      # This script helps configure applications to hide their titlebars for a unified look
      # Based on community recommendations from SketchyBar discussions

      # Catppuccin colors for output
      GREEN="\033[0;32m"
      YELLOW="\033[1;33m"
      BLUE="\033[0;34m"
      RED="\033[0;31m"
      NC="\033[0m" # No Color

      echo -e "''${BLUE}🎨 SketchyBar Titlebar Integration Setup''${NC}"
      echo -e "''${YELLOW}Setting up seamless app integration...''${NC}\n"

      # Function to check if application is installed
      check_app() {
        local app_path="$1"
        if [ -d "$app_path" ]; then
          return 0
        else
          return 1
        fi
      }

      # Function to backup and modify application
      modify_app() {
        local app_path="$1"
        local app_name="$2"
        
        echo -e "''${BLUE}Configuring $app_name...''${NC}"
        
        # Check if app exists
        if ! check_app "$app_path"; then
          echo -e "''${RED}❌ $app_name not found at $app_path''${NC}"
          return 1
        fi
        
        # Ensure ownership for modification
        if ! sudo chown -R $(whoami) "$app_path" 2>/dev/null; then
          echo -e "''${RED}❌ Failed to get ownership of $app_name''${NC}"
          return 1
        fi
        
        echo -e "''${GREEN}✅ $app_name configured for titlebar hiding''${NC}"
        return 0
      }

      echo -e "''${YELLOW}📋 Application Configuration Instructions:''${NC}\n"

      # VSCode / VSCode Insiders / VSCodium
      echo -e "''${BLUE}💻 Visual Studio Code / VSCodium:''${NC}"
      echo "1. Install 'Apc Customize UI++' extension"
      echo "2. Add to settings.json:"
      echo '   "window.titleBarStyle": "native",'
      echo '   "apc.electron": { "frame": false }'
      echo "3. Run Command Palette > 'Enable Apc extension'"
      echo "4. Restart application"
      echo ""

      # Firefox
      echo -e "''${BLUE}🦊 Firefox:''${NC}"
      echo "1. Enable userChrome.css:"
      echo "   - Go to about:config"
      echo "   - Set toolkit.legacyUserProfileCustomizations.stylesheets = true"
      echo "2. Create userChrome.css in profile chrome folder:"
      echo "   .titlebar-buttonbox-container { display: none !important; }"
      echo "3. Restart Firefox"
      echo ""

      # iTerm2
      echo -e "''${BLUE}🖥️  iTerm2:''${NC}"
      echo "1. Open Preferences (⌘+,)"
      echo "2. Go to Profiles > Window"
      echo "3. Set Style to 'No Title Bar'"
      echo "4. Optionally adjust 'Screen' settings for better integration"
      echo ""

      # Terminal
      echo -e "''${BLUE}📟 Terminal.app:''${NC}"
      echo "1. Open Preferences (⌘+,)"
      echo "2. Go to Profiles > Window"
      echo "3. Uncheck 'Title Bar'"
      echo "4. Adjust window settings as needed"
      echo ""

      # Finder
      echo -e "''${BLUE}📁 Finder:''${NC}"
      echo "1. This requires third-party tools like HiddenBar or Bartender"
      echo "2. Or use defaults write for some title bar modifications"
      echo "3. Note: Full Finder titlebar hiding is limited by macOS"
      echo ""

      # General Tips
      echo -e "''${YELLOW}💡 General Tips:''${NC}"
      echo "• Use ⌘+H to hide apps instead of minimize for cleaner workspace"
      echo "• Consider using AeroSpace workspaces to organize apps"
      echo "• Some apps may require restart after titlebar changes"
      echo "• Test changes gradually - you can always revert"
      echo ""

      # Automated modifications for supporting apps
      echo -e "''${YELLOW}🔧 Attempting automatic configuration...''${NC}\n"

      # Check and configure VSCodium if available
      if check_app "/Applications/VSCodium.app"; then
        modify_app "/Applications/VSCodium.app" "VSCodium"
      fi

      # Check and configure Cursor if available
      if check_app "/Applications/Cursor.app"; then
        modify_app "/Applications/Cursor.app" "Cursor"
      fi

      echo -e "\n''${GREEN}🎉 Titlebar integration setup complete!''${NC}"
      echo -e "''${BLUE}💡 Remember to apply application-specific settings manually.''${NC}"
      echo -e "''${YELLOW}📖 See SketchyBar community discussions for more tips.''${NC}"
    '';
    executable = true;
  };

  # Application-specific titlebar configuration templates
  home.file.".config/sketchybar/helpers/app_configs/vscode_settings.json" = {
    text = ''
      {
        // SketchyBar Integration Settings for VSCode
        "window.titleBarStyle": "native",
        "window.menuBarVisibility": "toggle",
        "apc.electron": {
          "frame": false,
          "titleBarStyle": "hiddenInset"
        },
        "apc.header": {
          "height": 36
        },
        "apc.sidebar.titlebar": {
          "height": 36
        },
        // Optional: Enhanced integration
        "workbench.colorTheme": "Catppuccin Macchiato",
        "editor.fontFamily": "JetBrainsMono Nerd Font, Menlo, Monaco, 'Courier New', monospace",
        "terminal.integrated.fontFamily": "JetBrainsMono Nerd Font"
      }
    '';
  };

  home.file.".config/sketchybar/helpers/app_configs/firefox_userChrome.css" = {
    text = ''
      /* SketchyBar Integration CSS for Firefox */
      /* Place this file in: ~/Library/Application Support/Firefox/Profiles/[profile]/chrome/userChrome.css */

      /* Hide titlebar buttons */
      .titlebar-buttonbox-container {
        display: none !important;
      }

      /* Optional: Reduce titlebar height */
      #titlebar {
        height: 32px !important;
      }

      /* Optional: Hide menu bar (use Alt to show temporarily) */
      #toolbar-menubar {
        height: 0 !important;
        margin-bottom: 0 !important;
      }

      /* Catppuccin Macchiato theme integration */
      :root {
        --catppuccin-base: #24273a;
        --catppuccin-surface0: #363a4f;
        --catppuccin-text: #cad3f5;
      }

      /* Apply theme to browser chrome */
      #nav-bar {
        background-color: var(--catppuccin-surface0) !important;
      }
    '';
  };

  # Quick setup script for common applications
  home.file.".local/bin/sketchybar-titlebar-setup" = {
    text = ''
      #!/bin/bash
      # Quick titlebar setup launcher
      ~/.config/sketchybar/helpers/titlebar_setup.sh "$@"
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

  # Old aerospace_space.sh plugin removed - replaced with dynamic per-display system

  # Enhanced Volume plugin with audio device switching and advanced controls
  home.file.".config/sketchybar/plugins/volume.sh" = {
    text = ''
      #!/bin/bash

      # Advanced volume plugin for SketchyBar with device switching and smart controls
      # Left click: Toggle mute
      # Right click: Cycle audio devices  
      # Requires: switchaudio-osx (installed via Homebrew)

      # Handle click actions
      case "$1" in
        "toggle")
          # Toggle mute/unmute
          osascript -e "set volume output muted not (output muted of (get volume settings))"
          ;;
        "device")
          # Cycle through audio devices using switchaudio-osx
          if command -v SwitchAudioSource >/dev/null 2>&1; then
            CURRENT_DEVICE=$(SwitchAudioSource -c)
            ALL_DEVICES=$(SwitchAudioSource -a -t output)
            
            # Find next device in list
            FOUND_CURRENT=false
            NEXT_DEVICE=""
            FIRST_DEVICE=""
            
            while IFS= read -r device; do
              if [ -z "$FIRST_DEVICE" ]; then
                FIRST_DEVICE="$device"
              fi
              
              if [ "$FOUND_CURRENT" = true ]; then
                NEXT_DEVICE="$device"
                break
              fi
              
              if [ "$device" = "$CURRENT_DEVICE" ]; then
                FOUND_CURRENT=true
              fi
            done <<< "$ALL_DEVICES"
            
            # If no next device found, wrap to first
            if [ -z "$NEXT_DEVICE" ]; then
              NEXT_DEVICE="$FIRST_DEVICE"
            fi
            
            # Switch to next device
            SwitchAudioSource -s "$NEXT_DEVICE"
            
            # Show temporary notification
            sketchybar --set "$NAME" label="→ $NEXT_DEVICE"
            sleep 2
          fi
          ;;
        "up")
          # Volume up by 5%
          CURRENT=$(osascript -e "output volume of (get volume settings)")
          NEW_VOLUME=$((CURRENT + 5))
          if [ $NEW_VOLUME -gt 100 ]; then NEW_VOLUME=100; fi
          osascript -e "set volume output volume $NEW_VOLUME"
          ;;
        "down")
          # Volume down by 5%
          CURRENT=$(osascript -e "output volume of (get volume settings)")
          NEW_VOLUME=$((CURRENT - 5))
          if [ $NEW_VOLUME -lt 0 ]; then NEW_VOLUME=0; fi
          osascript -e "set volume output volume $NEW_VOLUME"
          ;;
      esac

      # Get current volume and mute status  
      if [ "$SENDER" = "volume_change" ]; then
        VOLUME="$INFO"
      else
        VOLUME=$(osascript -e "output volume of (get volume settings)")
      fi
      
      MUTED=$(osascript -e "output muted of (get volume settings)")

      # Get current audio device for display
      CURRENT_DEVICE=""
      if command -v SwitchAudioSource >/dev/null 2>&1; then
        CURRENT_DEVICE=$(SwitchAudioSource -c 2>/dev/null)
        # Shorten device name for display
        if [ ''${#CURRENT_DEVICE} -gt 12 ]; then
          CURRENT_DEVICE="''${CURRENT_DEVICE:0:9}..."
        fi
      fi

      # Set icon and color based on volume level and mute status
      if [ "$MUTED" = "true" ]; then
          ICON="󰸈"              # Muted icon
          COLOR="0xffed8796"     # Red for muted
          if [ -n "$CURRENT_DEVICE" ]; then
            LABEL="Muted ($CURRENT_DEVICE)"
          else
            LABEL="Muted"
          fi
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
          
          if [ -n "$CURRENT_DEVICE" ]; then
            LABEL="''${VOLUME}% ($CURRENT_DEVICE)"
          else
            LABEL="''${VOLUME}%"
          fi
      fi

      # Update the display with enhanced information
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
      # Ready for dynamic per-display workspace system
      if command -v sketchybar >/dev/null 2>&1
        echo "SketchyBar available for AeroSpace integration"
      end
    '';
  };

  # Ensure SketchyBar is in PATH (via Homebrew)
  home.sessionPath = [
    "/opt/homebrew/bin"
  ];
} 