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
      
      # Ensure jq is available for JSON parsing
      if ! command -v jq >/dev/null 2>&1; then
        echo "Warning: jq not found, multi-monitor workspace filtering may not work properly"
      fi

      ##### Dynamic Configuration from Global Config #####
      # Load all configuration values dynamically from the global config system
      # This ensures single source of truth for colors, bar settings, and defaults
      
      # Check if config utility is available
      if command -v "$HOME/.local/bin/sketchybar/config" >/dev/null 2>&1; then
        # Load configuration dynamically
        eval "$($HOME/.local/bin/sketchybar/config all-shell)"
        
        # Fallback: extract individual settings if all-shell fails
        if [ -z "$BASE" ]; then
          BASE="$($HOME/.local/bin/sketchybar/config get colors.base 2>/dev/null || echo '0xff24273a')"
          TEXT="$($HOME/.local/bin/sketchybar/config get colors.text 2>/dev/null || echo '0xffffffff')"
          RED="$($HOME/.local/bin/sketchybar/config get colors.red 2>/dev/null || echo '0xffed8796')"
          GREEN="$($HOME/.local/bin/sketchybar/config get colors.green 2>/dev/null || echo '0xffa6da95')"
          BLUE="$($HOME/.local/bin/sketchybar/config get colors.blue 2>/dev/null || echo '0xff8aadf4')"
          YELLOW="$($HOME/.local/bin/sketchybar/config get colors.yellow 2>/dev/null || echo '0xfff9e2af')"
          SURFACE0="$($HOME/.local/bin/sketchybar/config get colors.surface0 2>/dev/null || echo '0xff363a4f')"
          BAR_HEIGHT="$($HOME/.local/bin/sketchybar/config get bar.height 2>/dev/null || echo '24')"
          BAR_NOTCH_HEIGHT="$($HOME/.local/bin/sketchybar/config get bar.notch_height 2>/dev/null || echo '42')"
          BAR_BLUR_RADIUS="$($HOME/.local/bin/sketchybar/config get bar.blur_radius 2>/dev/null || echo '30')"
          DEFAULT_PADDING="$($HOME/.local/bin/sketchybar/config get defaults.padding 2>/dev/null || echo '5')"
        fi
      else
        # Fallback to hardcoded values if config utility not available
        echo "Warning: Config utility not found, using fallback values"
        BASE="0xff24273a"
        TEXT="0xffffffff"
      RED="0xffed8796"
      GREEN="0xffa6da95"
      BLUE="0xff8aadf4"
        YELLOW="0xfff9e2af"
      SURFACE0="0xff363a4f"
        BAR_HEIGHT=24
        BAR_NOTCH_HEIGHT=42
        BAR_BLUR_RADIUS=30
        DEFAULT_PADDING=5
      fi

      ##### Bar Appearance with Dynamic Configuration #####
      # Using built-in notch_display_height property (available since Nov 2024)
      # See: https://github.com/FelixKratz/SketchyBar/pull/626
      # 
      # All values now loaded dynamically from global config
      # Falls back to reasonable defaults if config unavailable
      sketchybar --bar position=top topmost=off sticky=on display=all \
                       height="$BAR_HEIGHT" \
                       notch_display_height="$BAR_NOTCH_HEIGHT" \
                       blur_radius="$BAR_BLUR_RADIUS" \
                       color="''${BASE}ee"

      ##### Modern Unified Design System #####
      # 🎨 MODERN REDESIGN: Seamless, cohesive, minimalist approach
      # Creating grouped sections instead of fragmented individual boxes
      
      # Base item defaults - clean and minimal
      default=(
        # 🌊 SEAMLESS: Minimal spacing for flow
        padding_left=0
        padding_right=0
        
        # 🎨 MODERN: Refined typography
        icon.font="''${DEFAULT_ICON_FONT:-SF Pro Display:Semibold:15.0}"
        label.font="''${DEFAULT_LABEL_FONT:-SF Pro Display:Medium:13.0}"
        
        # 🎯 PERFECT ALIGNMENT: Precise positioning
        icon.y_offset=0
        label.y_offset=0
        
        # 🌈 CLEAN COLORS: Subtle, harmonious
        icon.color="''${TEXT}dd"
        label.color="''${TEXT}ee"
        
        # 🚀 OPTIMIZED SPACING: Enhanced visual balance
        icon.padding_left=8
        icon.padding_right=8       # Increased for better icon-to-label gap
        label.padding_left=0
        label.padding_right=8
        
        # 🎨 INVISIBLE BACKGROUNDS: Let groups handle styling
        background.drawing=off
        background.height=30
      )
      sketchybar --default "''${default[@]}"

      # Notifications will be configured as part of the system group

      ##### Modern Grouped Items Configuration #####
      # 🎨 Items organized into logical, visually cohesive groups
      
      # 🌊 LEFT GROUP: App Context & Media
      sketchybar --add item front_app left \
                 --set front_app icon.drawing=on \
                                 label.color="''${TEXT}ee" \
                                 label.padding_right=6 \
                                 script="$HOME/.local/bin/sketchybar/front_app" \
                 --subscribe front_app front_app_switched \
                 --add item spotify left \
                 --set spotify update_freq=1 \
                               icon.color="''${GREEN}dd" \
                               label.color="''${TEXT}dd" \
                               script="$HOME/.local/bin/sketchybar/spotify" \
                               click_script="$HOME/.local/bin/sketchybar/spotify toggle" \
                 --subscribe spotify media_change

      # ⏰ TIME & AMBIENT GROUP
      sketchybar --add item clock right \
                 --set clock update_freq=10 \
                             icon="󰥔" \
                             icon.color="''${LAVENDER}dd" \
                             label.color="''${TEXT}ee" \
                             script="$HOME/.local/bin/sketchybar/clock" \
                             click_script="$HOME/.local/bin/sketchybar/clock popup" \
                 --add item moon_phase right \
                 --set moon_phase update_freq=3600 \
                                  icon.color="''${YELLOW}dd" \
                                  label.color="''${TEXT}dd" \
                                  script="$HOME/.local/bin/sketchybar/moon_phase" \
                                  click_script="open -a 'Calendar'" \
                 --add item weather right \
                 --set weather update_freq=1800 \
                               icon.color="''${SKY}dd" \
                               label.color="''${TEXT}dd" \
                               script="$HOME/.local/bin/sketchybar/weather" \
                               click_script="$HOME/.local/bin/sketchybar/weather forecast"

      # 🌐 CONNECTIVITY GROUP
      sketchybar --add item network right \
                 --set network update_freq=5 \
                               icon.color="''${TEAL}dd" \
                               label.color="''${TEXT}dd" \
                               script="$HOME/.local/bin/sketchybar/network" \
                               click_script="$HOME/.local/bin/sketchybar/network popup" \
                 --subscribe network system_woke wifi_change \
                 --add item volume right \
                 --set volume icon.color="''${PEACH}dd" \
                             label.color="''${TEXT}dd" \
                             script="$HOME/.local/bin/sketchybar/volume" \
                             click_script="$HOME/.local/bin/sketchybar/volume toggle" \
                 --subscribe volume volume_change

      # ⚙️ SYSTEM RESOURCES GROUP  
      sketchybar --add item cpu right \
                 --set cpu update_freq=2 \
                           icon.color="''${RED}dd" \
                           label.color="''${TEXT}dd" \
                           script="$HOME/.local/bin/sketchybar/cpu" \
                           click_script="$HOME/.local/bin/sketchybar/cpu popup" \
                 --subscribe cpu system_woke \
                 --add item memory right \
                 --set memory update_freq=5 \
                             icon.color="''${MAUVE}dd" \
                             label.color="''${TEXT}dd" \
                             script="$HOME/.local/bin/sketchybar/memory" \
                             click_script="$HOME/.local/bin/sketchybar/memory popup" \
                 --subscribe memory system_woke \
                 --add item battery right \
                 --set battery update_freq=60 \
                              icon.color="''${GREEN}dd" \
                              label.color="''${TEXT}dd" \
                              script="$HOME/.local/bin/sketchybar/battery" \
                              click_script="$HOME/.local/bin/sketchybar/battery popup" \
                 --subscribe battery system_woke power_source_change

      # 🔔 ENHANCED NOTIFICATIONS with DND toggle and preview
      sketchybar --add item notifications right \
                 --set notifications update_freq=15 \
                                     icon.color="''${BLUE}dd" \
                                     label.color="''${TEXT}ee" \
                                     icon.padding_right=4 \
                                     label.padding_right=6 \
                                     script="$HOME/.local/bin/sketchybar/notifications" \
                                     click_script="~/.local/bin/sketchybar/notifications click" \
                 --subscribe notifications system_woke

      ##### Modern Group Separators #####
      # 🌊 Enhanced spacing between logical groups for optimal visual breathing room
      sketchybar --add item separator1 right \
                 --set separator1 padding_left=10 \
                                  padding_right=10 \
                                  background.drawing=off \
                                  icon.drawing=off \
                                  label.drawing=off \
                 --add item separator2 right \
                 --set separator2 padding_left=10 \
                                  padding_right=10 \
                                  background.drawing=off \
                                  icon.drawing=off \
                                  label.drawing=off \
                 --add item separator3 right \
                 --set separator3 padding_left=10 \
                                  padding_right=10 \
                                  background.drawing=off \
                                  icon.drawing=off \
                                  label.drawing=off

      ##### Modern Group System #####
      # 🎨 Create unified background groups for seamless design (after items are created)
      
      # Left Group: App Context & Media
      sketchybar --add bracket left_group front_app spotify \
                 --set left_group background.color="''${BASE}88" \
                                  background.corner_radius=12 \
                                  background.height=32 \
                                  background.border_width=0 \
                                  background.padding_left=10 \
                                  background.padding_right=14

      # Right Group: System Status (split into logical sections)
      # Time & Ambient Section (moderate density - standard padding)
      sketchybar --add bracket time_group clock moon_phase weather \
                 --set time_group background.color="''${BASE}88" \
                                  background.corner_radius=12 \
                                  background.height=32 \
                                  background.border_width=0 \
                                  background.padding_left=12 \
                                  background.padding_right=12
      
      # Connectivity Section (low density - tighter padding)
      sketchybar --add bracket connectivity_group network volume \
                 --set connectivity_group background.color="''${BASE}88" \
                                          background.corner_radius=12 \
                                          background.height=32 \
                                          background.border_width=0 \
                                          background.padding_left=10 \
                                          background.padding_right=10

      # System Resources Section (high density - generous padding)
      sketchybar --add bracket system_group cpu memory battery \
                 --set system_group background.color="''${BASE}88" \
                                    background.corner_radius=12 \
                                    background.height=32 \
                                    background.border_width=0 \
                                    background.padding_left=14 \
                                    background.padding_right=14

      ##### Dynamic AeroSpace Workspace Integration #####
      # Add AeroSpace workspace change event support  
      # See: https://nikitabobko.github.io/AeroSpace/goodies#show-aerospace-workspaces-in-sketchybar
      sketchybar --add event aerospace_workspace_change

      # Initialize dynamic workspace overview
      # This creates monitor groups and workspace indicators dynamically
      if command -v "$HOME/.local/bin/sketchybar/aerospace_overview" >/dev/null 2>&1; then
        "$HOME/.local/bin/sketchybar/aerospace_overview"
      else
        echo "Warning: aerospace_overview plugin not found, workspace indicators disabled"
      fi

      ##### Force all scripts to run the first time #####
      # Only run update if this is not a duplicate run
      if ! pgrep -f "sketchybar.*--update" > /dev/null 2>&1; then
        sketchybar --update
      fi
    '';
    executable = true;
  };

  # Plugin scripts based on official examples

    # Go-based configuration system (no longer using global.conf)

  # Go source files - explicitly copy needed directories (excluding bin/ which is managed by activation script)
  home.file.".config/sketchybar/plugins" = {
    source = ./plugins;
    recursive = true;
  };
  
  home.file.".config/sketchybar/tools" = {
    source = ./tools;
    recursive = true;
  };
  
  home.file.".config/sketchybar/config" = {
    source = ./config;
    recursive = true;
  };
  
  home.file.".config/sketchybar/utils" = {
    source = ./utils;
    recursive = true;
  };
  
  home.file.".config/sketchybar/go.mod".source = ./go.mod;
  home.file.".config/sketchybar/Makefile".source = ./Makefile;
  
  # Note: bin/ directory is dynamically managed by home.activation.buildGoPlugins

  # Plugins - All migrated to Go
  # All plugin functionality now handled by compiled Go binaries
  # Plugins (SketchyBar items): ~/.config/sketchybar/bin/
  # Tools (CLI utilities): ~/.config/sketchybar/bin/ (built from tools/ directory)



  # Titlebar Integration Helper - migrated to Go
  # All functionality now handled by the titlebar Go binary

  # Config templates now embedded in Go binary with Catppuccin theming

  # Quick setup script for common applications
  home.file.".local/bin/sketchybar-titlebar-setup" = {
    text = ''
      #!/bin/bash
      # Quick titlebar setup launcher - now uses Go binary
      ~/.config/sketchybar/bin/titlebar "$@"
    '';
    executable = true;
  };



  # Old aerospace_space.sh plugin removed - replaced with dynamic per-display system



  # SketchyBar startup is now handled by AeroSpace via after-startup-command
  # See: https://nikitabobko.github.io/AeroSpace/goodies#show-aerospace-workspaces-in-sketchybar
  # AeroSpace automatically starts SketchyBar and has built-in duplicate detection
  launchd.agents.sketchybar.enable = false;

  # Create log directory for any debugging needs
  home.file.".local/share/sketchybar/.keep".text = "";

  # Shell integration for SketchyBar events
  programs.fish = {
    interactiveShellInit = lib.mkAfter ''
      # SketchyBar integration - ready for dynamic per-display workspace system
      # Removed annoying echo message that printed on every shell startup
    '';
  };

    # Build Go plugins on activation
  home.activation.buildGoPlugins = lib.hm.dag.entryBefore ["writeBoundary"] ''
    echo "🔨 Building SketchyBar Go plugins..."

    # Clean up any existing conflicting files to prevent Home Manager conflicts
    echo "🧹 Cleaning up existing binaries to prevent conflicts..."
    if [ -d ~/.config/sketchybar/bin ]; then
      chmod -R u+w ~/.config/sketchybar/bin 2>/dev/null || true
      rm -rf ~/.config/sketchybar/bin 2>/dev/null || true
    fi
    if [ -d ~/.cache/sketchybar-go ]; then
      chmod -R u+w ~/.cache/sketchybar-go 2>/dev/null || true
      rm -rf ~/.cache/sketchybar-go 2>/dev/null || true
    fi

    # Try to find Go - first check if it's available, then try Nix store
    GO_BIN=""
    
    if command -v go >/dev/null 2>&1; then
      GO_BIN="go"
      echo "✅ Go found in PATH: $(go version)"
    else
      # Try to find Go in the Nix store from this generation
      GO_BIN="${pkgs.go}/bin/go"
      if [ -x "$GO_BIN" ]; then
        echo "✅ Go found in Nix store: $($GO_BIN version)"
      else
        echo "❌ Go not found in PATH or Nix store"
        echo "   Skipping plugin build - plugins will use bash fallbacks"
        echo "   Run 'cd ~/.config/nix-dotfiles/home/features/darwin/sketchybar && make build' manually later"
        exit 0
      fi
    fi

    # Ensure source directory exists
    if [ ! -d ~/.config/sketchybar ]; then
      echo "❌ SketchyBar source directory not found"
      exit 1
    fi

    # Create writable copy for building (Nix store is read-only)
    BUILD_DIR="$HOME/.cache/sketchybar-go-build"
    SOURCE_DIR="${./.}"
    echo "🧹 Cleaning build directory..."
    chmod -R u+w "$BUILD_DIR" 2>/dev/null || true
    rm -rf "$BUILD_DIR"

    echo "📋 Copying source files from Nix store..."
    # Copy source to writable location (follow symlinks to get real files)
    if ! cp -rL "$SOURCE_DIR" "$BUILD_DIR" 2>/dev/null; then
      echo "❌ Failed to copy source files"
      exit 1
    fi

    # Make files AND directories writable and change to build directory
    find "$BUILD_DIR" -type f -exec chmod u+w {} \;
    find "$BUILD_DIR" -type d -exec chmod u+w {} \;
    cd "$BUILD_DIR" || { echo "❌ Failed to enter build directory"; exit 1; }

    # Create/clean bin directory
    mkdir -p bin
    rm -f bin/* 2>/dev/null || true
    echo "📂 Building in: $BUILD_DIR"

    # Prepare Go environment for building
    echo "📦 Preparing Go environment..."
    # Dependencies will be fetched automatically during build
    echo "✅ Go environment ready"

    # Create bin directory
    mkdir -p bin

    # Build plugins with comprehensive error checking
    # True SketchyBar plugins (called by SketchyBar to update items)
    PLUGINS="cpu memory network battery volume front_app notifications clock moon_phase weather spotify aerospace_overview"
    # Utility tools (standalone CLI tools)
    TOOLS="titlebar config"
    
    BUILT_COUNT=0
    TOTAL_PLUGINS=12
    TOTAL_TOOLS=2
    TOTAL_TARGETS=$((TOTAL_PLUGINS + TOTAL_TOOLS))

    # Build SketchyBar plugins
    for plugin in $PLUGINS; do
      echo "🔌 Building $plugin plugin..."
      
      if [ -d "plugins/$plugin" ]; then
        if cd "plugins/$plugin" && $GO_BIN build -ldflags="-w -s -X main.version= -X main.commit= -X main.date=" -trimpath -a -gcflags=all=-l -tags=netgo -o "../../bin/$plugin" . 2>&1; then
          echo "✅ $plugin plugin built successfully"
          cd "$BUILD_DIR"
          BUILT_COUNT=$((BUILT_COUNT + 1))
        else
          echo "❌ $plugin plugin build failed"
          cd "$BUILD_DIR"
        fi
      else
        echo "⚠️  $plugin plugin source not found"
      fi
    done

    # Build utility tools
    for tool in $TOOLS; do
      echo "🛠️ Building $tool tool..."
      
      if [ -d "tools/$tool" ]; then
        if cd "tools/$tool" && $GO_BIN build -ldflags="-w -s -X main.version= -X main.commit= -X main.date=" -trimpath -a -gcflags=all=-l -tags=netgo -o "../../bin/$tool" . 2>&1; then
          echo "✅ $tool tool built successfully"
          cd "$BUILD_DIR"
          BUILT_COUNT=$((BUILT_COUNT + 1))
        else
          echo "❌ $tool tool build failed"
          cd "$BUILD_DIR"
        fi
      else
        echo "⚠️  $tool tool source not found"
      fi
    done

    # UPX compression now handled during individual builds

    # Deploy built binaries to user directory (bypassing Home Manager for binaries)
    if [ $BUILT_COUNT -gt 0 ]; then
      echo "🚀 Successfully built $BUILT_COUNT/$TOTAL_TARGETS items ($TOTAL_PLUGINS plugins + $TOTAL_TOOLS tools)!"
      echo "📂 Built binaries in: $BUILD_DIR/bin/"
      ls -la bin/
      
      # Create persistent cache directory for binaries
      CACHE_BIN_DIR="$HOME/.cache/sketchybar-go/bin"
      echo "📦 Installing binaries to cache: $CACHE_BIN_DIR"
      
      if mkdir -p "$CACHE_BIN_DIR" && cp bin/* "$CACHE_BIN_DIR/" 2>/dev/null; then
        chmod +x "$CACHE_BIN_DIR"/*
        echo "✅ Binaries installed to cache directory"
        ls -la "$CACHE_BIN_DIR/"
        
        # Deploy to dedicated binary location (avoids Home Manager conflicts)
        echo "🔗 Creating symlinks in ~/.local/bin/sketchybar/"
        FINAL_BIN_DIR="$HOME/.local/bin/sketchybar"
        mkdir -p "$FINAL_BIN_DIR"
        
        # Remove any existing files first to avoid conflicts
        rm -f "$FINAL_BIN_DIR"/* 2>/dev/null || true
        
        # Create fresh symlinks to cached binaries
        for binary in "$CACHE_BIN_DIR"/*; do
          if [ -f "$binary" ]; then
            target_name="$(basename "$binary")"
            ln -sf "$binary" "$FINAL_BIN_DIR/$target_name"
            echo "  ✅ Linked: $target_name"
          fi
        done

      else
        echo "❌ Failed to install binaries to cache directory"
      fi
    else
      echo "❌ No items were built successfully"
    fi

    # Cleanup temporary build directory (safely)
    echo "🧹 Cleaning up build directory..."
    if [ -d "$BUILD_DIR" ]; then
      cd / # Change to root directory before cleanup
      chmod -R u+w "$BUILD_DIR" 2>/dev/null || true
    rm -rf "$BUILD_DIR"
    fi
    
    if [ $BUILT_COUNT -eq $TOTAL_TARGETS ]; then
      echo "✨ All Go plugins and tools ready!"
    elif [ $BUILT_COUNT -gt 0 ]; then
      echo "⚠️  Some items built successfully ($BUILT_COUNT/$TOTAL_TARGETS)"
    else
      echo "❌ Build failed - using fallbacks"
    fi
  '';

  # Ensure SketchyBar and Go plugins are in PATH
  home.sessionPath = [
    "/opt/homebrew/bin"
    "$HOME/.local/bin/sketchybar"
  ];
} 