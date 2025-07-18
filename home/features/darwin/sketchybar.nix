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

      ##### Adding AeroSpace Workspace Indicators #####
      # Official AeroSpace + SketchyBar integration
      # Based on: https://nikitabobko.github.io/AeroSpace/goodies#show-aerospace-workspaces-in-sketchybar
      
      # Add AeroSpace workspace change event
      sketchybar --add event aerospace_workspace_change
      
      # Application-specific workspace icons with Catppuccin theming
      # Icons represent typical application categories for each workspace
      SPACE_ICONS=(
        "󰈹"   # 1: Web browser (Safari/Chrome)
        "💻"   # 2: Development (Code/Terminal)
        "🗂️"   # 3: Files & Organization  
        "💬"   # 4: Communication (Slack/Discord)
        "🎵"   # 5: Media & Entertainment
        "📧"   # 6: Email & Calendar
        "🔧"   # 7: Utilities & Tools
        "📚"   # 8: Documentation & Reading
        "🎮"   # 9: Games & Recreation
      )
      
      for i in "''${!SPACE_ICONS[@]}"
      do
        sid="$(($i+1))"
        space=(
          space="$sid"
          icon="''${SPACE_ICONS[i]}"
          icon.padding_left=8
          icon.padding_right=8
          icon.color="$SUBTEXT1"
          icon.font="SF Pro Display:Bold:16.0"
          background.color="$SURFACE0"
          background.corner_radius=8
          background.height=24
          background.border_width=1
          background.border_color="$SURFACE1"
          background.drawing=off
          label.drawing=off
          script="$PLUGIN_DIR/aerospace_space.sh"
          click_script="aerospace workspace $sid"
        )
        sketchybar --add space space."$sid" left \
                   --subscribe space."$sid" aerospace_workspace_change \
                   --set space."$sid" "''${space[@]}"
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
                           click_script="$PLUGIN_DIR/clock.sh popup" \
                 --add item moon_phase right \
                 --set moon_phase update_freq=3600 script="$PLUGIN_DIR/moon_phase.sh" \
                           click_script="open -a 'Calendar'" \
                 --add item weather right \
                 --set weather update_freq=1800 script="$PLUGIN_DIR/weather.sh" \
                           click_script="open -a 'Weather'" \
                 --add item spotify left \
                 --set spotify update_freq=1 script="$PLUGIN_DIR/spotify.sh" \
                           click_script="$PLUGIN_DIR/spotify.sh toggle" \
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
                         click_script="$PLUGIN_DIR/volume.sh toggle" \
                 --subscribe volume volume_change \
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

  # CPU plugin - monitors CPU usage with color indicators
  home.file.".config/sketchybar/plugins/cpu.sh" = {
    text = ''
      #!/bin/bash

      # Set up PATH for system commands
      export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:$PATH"

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

      # Catppuccin Macchiato themed CPU indicators
      if [ "$CPU_USAGE" -gt 80 ]; then
          COLOR="0xffed8796"  # Catppuccin Red - Critical
          ICON="󰻠"           # CPU icon - high usage
          BG_COLOR="0xff363a4f"  # Surface0 background
      elif [ "$CPU_USAGE" -gt 50 ]; then
          COLOR="0xfff5a97f"  # Catppuccin Peach - High
          ICON="󰻟"           # CPU icon - medium usage  
          BG_COLOR="0xff363a4f"  # Surface0 background
      elif [ "$CPU_USAGE" -gt 20 ]; then
          COLOR="0xfff9e2af"  # Catppuccin Yellow - Medium
          ICON="󰻟"           # CPU icon - normal usage
          BG_COLOR="0xff363a4f"  # Surface0 background
      else
          COLOR="0xffa6da95"  # Catppuccin Green - Good
          ICON="󰻞"           # CPU icon - low usage
          BG_COLOR="0xff363a4f"  # Surface0 background
      fi

      # Update display with Catppuccin theming
      sketchybar --set "$NAME" \
                 icon="$ICON" \
                 icon.color="$COLOR" \
                 label="''${CPU_USAGE}%" \
                 label.color="0xffffffff" \
                 background.color="$BG_COLOR" \
                 background.corner_radius=8 \
                 background.padding_left=5 \
                 background.padding_right=5
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

      # Set up PATH for system commands
      export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:$PATH"

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

      # Catppuccin Macchiato themed memory indicators
      if [ "$PERCENTAGE" -gt 85 ]; then
          COLOR="0xffed8796"  # Catppuccin Red - Critical
          ICON="󰍛"           # Memory icon - critical
          BG_COLOR="0xff363a4f"  # Surface0 background
      elif [ "$PERCENTAGE" -gt 70 ]; then
          COLOR="0xfff5a97f"  # Catppuccin Peach - High
          ICON="󰍛"           # Memory icon - high
          BG_COLOR="0xff363a4f"  # Surface0 background
      elif [ "$PERCENTAGE" -gt 50 ]; then
          COLOR="0xfff9e2af"  # Catppuccin Yellow - Medium
          ICON="󰍛"           # Memory icon - medium
          BG_COLOR="0xff363a4f"  # Surface0 background
      else
          COLOR="0xffa6da95"  # Catppuccin Green - Good
          ICON="󰍛"           # Memory icon - good
          BG_COLOR="0xff363a4f"  # Surface0 background
      fi

      # Update display with Catppuccin theming
      sketchybar --set "$NAME" \
                 icon="$ICON" \
                 icon.color="$COLOR" \
                 label="''${USED_GB}G (''${PERCENTAGE}%)" \
                 label.color="0xffffffff" \
                 background.color="$BG_COLOR" \
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

  # Weather plugin - displays current weather conditions
  home.file.".config/sketchybar/plugins/weather.sh" = {
    text = ''
      #!/bin/bash

      # Weather plugin for SketchyBar with Catppuccin theming
      # Uses wttr.in API for weather data (no API key required)
      # Location is automatically detected by IP or can be customized

      # Configuration
      LOCATION=""  # Empty = auto-detect, or set to "Amsterdam" or other city
      
      # Cache file to avoid too frequent API calls
      CACHE_FILE="$HOME/.cache/sketchybar_weather"
      CACHE_DURATION=1800  # 30 minutes in seconds

      # Create cache directory if it doesn't exist
      mkdir -p "$(dirname "$CACHE_FILE")"

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
                       label.color="0xffffffff" \
                       background.color="0xff363a4f" \
                       background.corner_radius=8 \
                       background.padding_left=5 \
                       background.padding_right=5
            exit 0
          fi
        fi
      fi

      # Fetch new weather data
      if [ -n "$LOCATION" ]; then
        WEATHER_URL="wttr.in/$LOCATION?format=%C+%t"
      else
        WEATHER_URL="wttr.in/?format=%C+%t"
      fi

      # Get weather data with timeout
      WEATHER_DATA=$(curl -s --max-time 10 "$WEATHER_URL" 2>/dev/null)

      if [ $? -eq 0 ] && [ -n "$WEATHER_DATA" ]; then
        # Parse weather data
        CONDITION=$(echo "$WEATHER_DATA" | sed 's/+[0-9-]*°[CF]$//' | xargs)
        TEMP=$(echo "$WEATHER_DATA" | grep -o '+[0-9-]*°[CF]' | head -1)
        
        # Map conditions to icons and colors (Catppuccin themed)
        case "$CONDITION" in
          *"Clear"*|*"Sunny"*)
            WEATHER_ICON="☀️"
            WEATHER_COLOR="0xfff9e2af"  # Yellow
            ;;
          *"Partly cloudy"*|*"Partly Cloudy"*)
            WEATHER_ICON="⛅"
            WEATHER_COLOR="0xff8aadf4"  # Blue
            ;;
          *"Cloudy"*|*"Overcast"*)
            WEATHER_ICON="☁️"
            WEATHER_COLOR="0xff939ab7"  # Overlay2
            ;;
          *"Rain"*|*"Drizzle"*)
            WEATHER_ICON="🌧️"
            WEATHER_COLOR="0xff7dc4e4"  # Sapphire
            ;;
          *"Snow"*)
            WEATHER_ICON="❄️"
            WEATHER_COLOR="0xfff4dbd6"  # Rosewater
            ;;
          *"Thunderstorm"*|*"Thunder"*)
            WEATHER_ICON="⛈️"
            WEATHER_COLOR="0xffc6a0f6"  # Mauve
            ;;
          *"Fog"*|*"Mist"*)
            WEATHER_ICON="🌫️"
            WEATHER_COLOR="0xffa5adcb"  # Subtext0
            ;;
          *)
            WEATHER_ICON="🌤️"
            WEATHER_COLOR="0xff8aadf4"  # Blue (default)
            ;;
        esac

        WEATHER_TEMP="$TEMP"
        
        # Cache the results
        cat > "$CACHE_FILE" << EOF
WEATHER_ICON="$WEATHER_ICON"
WEATHER_TEMP="$WEATHER_TEMP"
WEATHER_COLOR="$WEATHER_COLOR"
EOF

      else
        # Fallback when API is unavailable
        WEATHER_ICON="❌"
        WEATHER_TEMP="N/A"
        WEATHER_COLOR="0xffed8796"  # Red
        
        # Don't cache errors
        rm -f "$CACHE_FILE"
      fi

      # Update display
      sketchybar --set "$NAME" \
                 icon="$WEATHER_ICON" \
                 label="$WEATHER_TEMP" \
                 icon.color="$WEATHER_COLOR" \
                 label.color="0xffffffff" \
                 background.color="0xff363a4f" \
                 background.corner_radius=8 \
                 background.padding_left=5 \
                 background.padding_right=5
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

  # AeroSpace space plugin with Catppuccin theming
  home.file.".config/sketchybar/plugins/aerospace_space.sh" = {
    text = ''
      #!/bin/bash

      # AeroSpace + SketchyBar integration with Catppuccin Macchiato theming
      # Based on: https://nikitabobko.github.io/AeroSpace/goodies#show-aerospace-workspaces-in-sketchybar
      
      # Catppuccin Macchiato colors
      MAUVE="0xffc6a0f6"
      SURFACE0="0xff363a4f"
      SURFACE1="0xff494d64"
      TEXT="0xffffffff"
      SUBTEXT1="0xffb8c0e0"
      
      # Extract workspace number from space name (e.g., "space.1" -> "1")
      SPACE_NUM=$(echo "$NAME" | sed 's/space\.//')
      
      # Check if this space matches the focused workspace from AeroSpace
      if [ "$SPACE_NUM" = "$FOCUSED_WORKSPACE" ]; then
        # Active workspace: Mauve background with white text
        sketchybar --set "$NAME" \
                   background.drawing=on \
                   background.color="$MAUVE" \
                   background.border_color="$MAUVE" \
                   icon.color="$TEXT"
      else
        # Inactive workspace: Subtle background with muted text
        sketchybar --set "$NAME" \
                   background.drawing=on \
                   background.color="$SURFACE0" \
                   background.border_color="$SURFACE1" \
                   icon.color="$SUBTEXT1"
      fi
    '';
    executable = true;
  };

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