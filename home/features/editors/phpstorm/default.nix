{ pkgs, lib, config, ... }:
{
  imports = [
    ./plugins.nix
    ./macos.nix
  ];
  
  # PhpStorm configuration for macOS
  # Keep settings minimal and safe; prefer IDE defaults unless explicitly needed.
  
  config = lib.mkIf pkgs.stdenv.isDarwin {
    # Create dynamic PhpStorm optimization script that detects current version
    home.packages = with pkgs; [
    (writeShellScriptBin "phpstorm-setup-config" ''
      #!/usr/bin/env bash
      
      echo "🚀 PhpStorm Configuration Setup (Safe Defaults)"
      echo "========================================"
      echo ""
      
      # Detect PhpStorm installation and version
      PHPSTORM_APP=""
      JETBRAINS_CONFIG="$HOME/Library/Application Support/JetBrains"
      
      # Try to find PhpStorm in multiple locations
      if [ -d "/Applications/PhpStorm.app" ]; then
        PHPSTORM_APP="/Applications/PhpStorm.app"
        echo "📱 Found PhpStorm in /Applications/"
      elif command -v phpstorm >/dev/null 2>&1; then
        # PhpStorm installed via Nix - find the .app bundle
        PHPSTORM_BIN=$(which phpstorm)
        PHPSTORM_STORE_PATH=$(readlink -f "$PHPSTORM_BIN" | sed 's|/bin/phpstorm||')
        PHPSTORM_APP=$(find "$PHPSTORM_STORE_PATH" -name "PhpStorm.app" -type d | head -1)
        if [ -n "$PHPSTORM_APP" ]; then
          echo "📱 Found PhpStorm via Nix: $PHPSTORM_APP"
        fi
      fi
      
      if [ -z "$PHPSTORM_APP" ] || [ ! -d "$PHPSTORM_APP" ]; then
        echo "❌ PhpStorm not found in standard locations"
        echo "   Checked:"
        echo "   • /Applications/PhpStorm.app"
        echo "   • Nix installation (via 'which phpstorm')"
        echo "   Please install PhpStorm first"
        exit 1
      fi
      
      # Get PhpStorm version from Info.plist
      PHPSTORM_VERSION=$(defaults read "$PHPSTORM_APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "unknown")
      PHPSTORM_BUILD=$(defaults read "$PHPSTORM_APP/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo "unknown")
      
      echo "📱 Detected PhpStorm version: $PHPSTORM_VERSION (build $PHPSTORM_BUILD)"
      
      # Find the actual configuration directory
      PHPSTORM_CONFIG_DIR=""
      if [ -d "$JETBRAINS_CONFIG" ]; then
        # Pick the most recently modified PhpStorm config directory
        PHPSTORM_CONFIG_DIR=$(ls -1dt "$JETBRAINS_CONFIG"/PhpStorm* 2>/dev/null | head -1)
      fi
      
      if [ -z "$PHPSTORM_CONFIG_DIR" ]; then
        # Create config directory based on version
        MAJOR_VERSION=$(echo "$PHPSTORM_VERSION" | cut -d. -f1)
        MINOR_VERSION=$(echo "$PHPSTORM_VERSION" | cut -d. -f2)
        PHPSTORM_CONFIG_DIR="$JETBRAINS_CONFIG/PhpStorm$MAJOR_VERSION.$MINOR_VERSION"
        echo "📁 Creating configuration directory: $PHPSTORM_CONFIG_DIR"
        mkdir -p "$PHPSTORM_CONFIG_DIR/options"
      else
        echo "📁 Using existing configuration directory: $PHPSTORM_CONFIG_DIR"
      fi
      
      # Create options directory if it doesn't exist
      mkdir -p "$PHPSTORM_CONFIG_DIR/options"
      
      echo ""
      echo "🔧 Applying safe defaults..."
      
      # Create JVM options only if none exist, unless forced.
      if [ -f "$PHPSTORM_CONFIG_DIR/phpstorm64.vmoptions" ] && [ -z "''${PHPSTORM_FORCE_VMOPTIONS:-}" ]; then
        echo "ℹ️  Existing vmoptions found; leaving as-is."
      else
        if [ -f "$PHPSTORM_CONFIG_DIR/phpstorm64.vmoptions" ]; then
          cp "$PHPSTORM_CONFIG_DIR/phpstorm64.vmoptions" "$PHPSTORM_CONFIG_DIR/phpstorm64.vmoptions.bak"
          echo "   Backed up existing vmoptions to phpstorm64.vmoptions.bak"
        fi

        cat > "$PHPSTORM_CONFIG_DIR/phpstorm64.vmoptions" << 'EOF'
# Minimal, safe JVM options. Prefer IDE defaults unless you have a clear need.
-Xmx4096m
-XX:ReservedCodeCacheSize=512m
-XX:+UseG1GC
-XX:+HeapDumpOnOutOfMemoryError
-XX:-OmitStackTraceInFastThrow
-XX:+IgnoreUnrecognizedVMOptions
EOF
      fi
      
      echo "✅ Configuration files created successfully!"
      echo ""
      echo "📁 Configuration applied to: $PHPSTORM_CONFIG_DIR"
      echo ""
      echo "🔄 Please restart PhpStorm to apply changes"
      echo ""
      echo "💡 Additional maintenance commands:"
      echo "   phpstorm-optimize     - Clean caches and optimize"
      echo "   phpstorm-health       - Check performance status"
      echo "   phpstorm-plugins list - Manage plugins for performance"
    '')
    
    # Additional performance monitoring scripts
    (writeShellScriptBin "phpstorm-optimize" ''
      #!/usr/bin/env bash
      
      echo "🚀 PhpStorm Performance Optimizer for Apple Silicon M4 Pro"
      echo "============================================================"
      echo ""
      
      # Check if PhpStorm is running
      if pgrep -f "PhpStorm" > /dev/null; then
        echo "⚠️  PhpStorm is currently running. Please close it first."
        echo "   Run: phpstorm-kill"
        exit 1
      fi
      
      echo "🧹 Cleaning temporary files..."
      rm -rf ~/Library/Caches/JetBrains/PhpStorm*
      rm -rf ~/Library/Logs/JetBrains/PhpStorm*
      # Leave user data (scratches/eval) intact.
      
      echo "📊 System memory status:"
      vm_stat | head -5
      echo ""
      
      echo "🔧 JVM configuration:"
      echo "   Use IDE defaults unless you've set vmoptions"
      echo "   Check active flags with: phpstorm-health"
      echo ""
      
      echo "✅ PhpStorm optimization complete!"
      echo ""
      echo "💡 Tips for best performance:"
      echo "   • Close unused projects"
      echo "   • Disable unnecessary plugins"
      echo "   • Use 'Power Save Mode' for large projects"
      echo "   • Monitor memory usage with: phpstorm-memory"
      echo ""
      echo "🚀 Start PhpStorm now for optimal performance!"
    '')
    
    (writeShellScriptBin "phpstorm-health" ''
      #!/usr/bin/env bash
      
      echo "🏥 PhpStorm Health Check"
      echo "========================"
      echo ""
      
      # Check if PhpStorm is running
      if ! pgrep -f "PhpStorm" > /dev/null; then
        echo "❌ PhpStorm is not running"
        exit 1
      fi
      
      echo "✅ PhpStorm is running"
      echo ""
      
      # Memory usage
      echo "📊 Memory Usage:"
      ps aux | grep -i phpstorm | grep -v grep | awk '{printf "   CPU: %s%%, Memory: %s%%, RSS: %sMB\n", $3, $4, int($6/1024)}'
      echo ""
      
      # JVM info
      echo "☕ JVM Information:"
      jps -v | grep -i phpstorm | head -1 | sed 's/.*-X/-X/g' | tr ' ' '\n' | grep -E '^-X(ms|mx|XX)' | head -5 | sed 's/^/   /'
      echo ""
      
      # System resources
      echo "🖥️  System Resources:"
      echo "   CPU Cores: $(sysctl -n hw.ncpu)"
      echo "   Memory: $(echo "$(sysctl -n hw.memsize) / 1024 / 1024 / 1024" | bc)GB"
      echo "   Load Average: $(uptime | awk -F'load averages:' '{print $2}')"
      echo ""
      
      # Cache sizes
      echo "💾 Cache Status:"
      if [ -d ~/Library/Caches/JetBrains ]; then
        cache_size=$(du -sh ~/Library/Caches/JetBrains 2>/dev/null | awk '{print $1}')
        echo "   Cache Size: $cache_size"
      else
        echo "   Cache: Clean"
      fi
      
      echo ""
      echo "💡 Use 'phpstorm-optimize' to clean up and optimize"
    '')
  ];
  
  # Shell aliases for PhpStorm management
  home.shellAliases = {
    # PhpStorm performance monitoring
    "phpstorm-memory" = "ps aux | grep -i phpstorm | grep -v grep | awk '{print $2, $3, $4, $6, $11}' | column -t";
    "phpstorm-kill" = "pkill -f PhpStorm";
    "phpstorm-restart" = "pkill -f PhpStorm && sleep 2 && open -a PhpStorm";
    
    # PhpStorm cache management
    "phpstorm-clear-cache" = "rm -rf ~/Library/Caches/JetBrains/PhpStorm* && echo 'PhpStorm cache cleared'";
    "phpstorm-clear-logs" = "rm -rf ~/Library/Logs/JetBrains/PhpStorm* && echo 'PhpStorm logs cleared'";
    "phpstorm-clear-all" = "phpstorm-clear-cache && phpstorm-clear-logs && echo 'All PhpStorm temporary files cleared'";
    
    # Performance diagnostics
    "phpstorm-perf" = "echo 'PhpStorm Performance Check:' && phpstorm-memory && echo '' && echo 'Java processes:' && jps -v | grep -i phpstorm";
  };
  
  # Environment variables for optimal PhpStorm performance
  home.sessionVariables = {    
    # Disable JetBrains data sharing for performance
    "JETBRAINS_DATA_SHARING" = "false";
  };

  # Apply minimal, safe vmoptions via Home Manager (no manual script run needed).
  home.activation.phpstormVmOptions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    config_root="$HOME/Library/Application Support/JetBrains"
    target="$(ls -1dt "$config_root"/PhpStorm* 2>/dev/null | head -1)"
    if [ -n "$target" ]; then
      mkdir -p "$target"
      vmopts="$target/phpstorm64.vmoptions"
      marker="Managed by Home Manager"
      if [ -f "$vmopts" ] && ! grep -q "$marker" "$vmopts"; then
        exit 0
      fi
      cat > "$vmopts" << 'EOF'
# Managed by Home Manager: minimal, safe JVM options for PhpStorm
-Xmx4096m
-XX:ReservedCodeCacheSize=512m
-XX:+UseG1GC
-XX:+HeapDumpOnOutOfMemoryError
-XX:-OmitStackTraceInFastThrow
-XX:+IgnoreUnrecognizedVMOptions
EOF
    fi
  '';
  };
}
