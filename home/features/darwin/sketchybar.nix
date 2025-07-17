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
      # Based on official examples with our additions
      sketchybar --add item clock right \
                 --set clock update_freq=10 icon= script="$PLUGIN_DIR/clock.sh" \
                 --add item volume right \
                 --set volume script="$PLUGIN_DIR/volume.sh" \
                 --subscribe volume volume_change \
                 --add item battery right \
                 --set battery update_freq=120 script="$PLUGIN_DIR/battery.sh" \
                 --subscribe battery system_woke power_source_change

      ##### Force all scripts to run the first time #####
      sketchybar --update
    '';
    executable = true;
  };

  # Plugin scripts based on official examples

  # Battery plugin (official example)
  home.file.".config/sketchybar/plugins/battery.sh" = {
    text = ''
      #!/bin/sh

      PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"
      CHARGING="$(pmset -g batt | grep 'AC Power')"

      if [ "$PERCENTAGE" = "" ]; then
        exit 0
      fi

      case "''${PERCENTAGE}" in
        9[0-9]|100) ICON=""
        ;;
        [6-8][0-9]) ICON=""
        ;;
        [3-5][0-9]) ICON=""
        ;;
        [1-2][0-9]) ICON=""
        ;;
        *) ICON=""
      esac

      if [[ "$CHARGING" != "" ]]; then
        ICON=""
      fi

      # The item invoking this script (name $NAME) will get its icon and label
      # updated with the current battery status
      sketchybar --set "$NAME" icon="$ICON" label="''${PERCENTAGE}%"
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

      sketchybar --set "$NAME" label="$(date '+%d/%m %H:%M')"
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

  # Volume plugin (official example)
  home.file.".config/sketchybar/plugins/volume.sh" = {
    text = ''
      #!/bin/sh

      # The volume_change event supplies a $INFO variable in which the current volume
      # percentage is passed to the script.

      if [ "$SENDER" = "volume_change" ]; then
        VOLUME="$INFO"

        case $VOLUME in
          [6-9][0-9]|100) ICON=""
          ;;
          [3-5][0-9]) ICON=""
          ;;
          [1-9]|[1-2][0-9]) ICON=""
          ;;
          *) ICON=""
        esac

        sketchybar --set "$NAME" icon="$ICON" label="$VOLUME%"
      fi
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