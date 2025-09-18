{ pkgs, lib, config, ... }:
{
  imports = [
    ./plugins.nix
    ./macos.nix
  ];
  
  # PhpStorm Performance Optimization for macOS
  # Optimized for Apple Silicon M4 Pro with 48GB RAM
  # Version-agnostic configuration that works with any PhpStorm version
  
  config = lib.mkIf pkgs.stdenv.isDarwin {
    # Create dynamic PhpStorm optimization script that detects current version
    home.packages = with pkgs; [
    (writeShellScriptBin "phpstorm-setup-config" ''
      #!/usr/bin/env bash
      
      echo "🚀 PhpStorm Dynamic Configuration Setup"
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
        # Look for PhpStorm configuration directories
        PHPSTORM_CONFIG_DIR=$(find "$JETBRAINS_CONFIG" -maxdepth 1 -type d -name "PhpStorm*" | head -1)
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
      echo "🔧 Applying performance optimizations..."
      
      # Create JVM options file
      cat > "$PHPSTORM_CONFIG_DIR/phpstorm64.vmoptions" << 'EOF'
# ═══════════════════════════════════════════════════════════════════════════
# 🚀 PhpStorm JVM Performance Optimization for Apple Silicon M4 Pro (48GB RAM)
# ═══════════════════════════════════════════════════════════════════════════

# Memory allocation (optimized for 48GB system)
-Xms4g
-Xmx8g
-XX:ReservedCodeCacheSize=1g
-XX:InitialCodeCacheSize=64m

# Garbage Collection (G1GC optimized for Apple Silicon)
-XX:+UseG1GC
-XX:SoftRefLRUPolicyMSPerMB=50
-XX:CICompilerCount=4
-XX:+HeapDumpOnOutOfMemoryError
-XX:-OmitStackTraceInFastThrow
-XX:+IgnoreUnrecognizedVMOptions

# Apple Silicon specific optimizations
-XX:+UnlockExperimentalVMOptions
-XX:+UseTransparentHugePages
-XX:+UseLargePages
-XX:LargePageSizeInBytes=2m

# Performance tuning
-XX:MaxInlineLevel=20
-XX:MaxTrivialSize=12
-XX:CompileThreshold=1500
-XX:OnStackReplacePercentage=933
-XX:NetProcessors=14

# macOS specific optimizations
-Djava.system.class.loader=com.intellij.util.lang.PathClassLoader
-Dsun.io.useCanonPrefixCache=false
-Dsun.awt.disablegrab=true
-Dsun.swing.enableImprovedDragGesture=true

# File system performance
-Dide.mac.file.chooser.native=false
-Dapple.laf.useScreenMenuBar=true
-Dcom.apple.mrj.application.apple.menu.about.name=PhpStorm
-Dapple.awt.application.name=PhpStorm

# Rendering optimizations for Retina displays
-Dsun.java2d.renderer=sun.java2d.marlin.MarlinRenderingEngine
-Dsun.java2d.renderer.useThreadLocal=true
-Dswing.aatext=true
-Dawt.useSystemAAFontSettings=lcd

# Network and I/O optimizations
-Dhttp.keepAlive=false
-Dide.slow.operations.assertion=false
-Djdk.http.auth.tunneling.disabledSchemes=""

# Plugin and indexing performance
-Dide.plugins.snapshot.on.unload.fail=false
-Dide.show.tips.on.startup.default.value=false
-Didea.ProcessCanceledException=disabled
-Didea.cycle.buffer.size=disabled

# Disable problematic features for performance
-Didea.ui.tree.deferred.icon.invalidates=false
-Dide.tree.ui.experimental=false
-Didea.editor.tab.selection.animation=false
-Dide.experimental.ui=false
EOF
      
      # Create IDE general settings
      cat > "$PHPSTORM_CONFIG_DIR/options/ide.general.xml" << 'EOF'
<application>
  <component name="GeneralSettings">
    <option name="autoSaveIfInactive" value="true" />
    <option name="autoSaveIntervalInSeconds" value="300" />
    <option name="confirmExit" value="false" />
    <option name="confirmOpenNewProject2" value="0" />
    <option name="processCloseConfirmation" value="TERMINATE" />
    <option name="reopenLastProject" value="false" />
    <option name="showTipsOnStartup" value="false" />
    <option name="supportScreenReaders" value="false" />
    <option name="useSafeWrite" value="false" />
  </component>
  <component name="Registry">
    <!-- Performance optimizations -->
    <entry key="actionSystem.update.actions.async" value="true" />
    <entry key="ide.editor.tab.selection.animation" value="false" />
    <entry key="ide.tree.ui.experimental" value="false" />
    <entry key="editor.zero.latency.typing" value="true" />
    <entry key="ide.slow.operations.assertion" value="false" />
    
    <!-- macOS specific optimizations -->
    <entry key="ide.mac.allowDarkWindowDecorations" value="true" />
    <entry key="ide.mac.bigsur.window.with.tabs.enabled" value="true" />
    <entry key="apple.laf.useScreenMenuBar" value="true" />
    
    <!-- Memory and caching -->
    <entry key="ide.max.intellisense.filesize" value="5000" />
    <entry key="idea.max.content.load.filesize" value="20000" />
    <entry key="psi.incremental.reparse.depth.limit" value="1000" />
    
    <!-- Disable resource-intensive features -->
    <entry key="ide.tooltip.initialDelay.highlighter" value="1500" />
    <entry key="ide.completion.delay" value="0" />
    <entry key="editor.distraction.free.mode" value="false" />
  </component>
</application>
EOF
      
      # Create editor performance settings
      cat > "$PHPSTORM_CONFIG_DIR/options/editor.xml" << 'EOF'
<application>
  <component name="EditorSettings">
    <option name="IS_ANIMATED_SCROLLING" value="false" />
    <option name="IS_CAMEL_WORDS" value="true" />
    <option name="IS_DND_ENABLED" value="true" />
    <option name="IS_FOLDING_OUTLINE_SHOWN" value="false" />
    <option name="IS_INDENT_GUIDES_SHOWN" value="true" />
    <option name="IS_RIGHT_MARGIN_SHOWN" value="true" />
    <option name="IS_WHITESPACES_SHOWN" value="false" />
    <option name="STRIP_TRAILING_SPACES" value="Modified" />
    <option name="IS_ENSURE_NEWLINE_AT_EOF" value="true" />
    <option name="SHOW_BREADCRUMBS" value="false" />
    <option name="SHOW_INTENTION_BULB" value="true" />
    <option name="SHOW_QUICK_DOC_ON_MOUSE_OVER_ELEMENT" value="false" />
  </component>
  <component name="CodeInsightSettings">
    <option name="AUTO_POPUP_PARAMETER_INFO" value="false" />
    <option name="AUTO_POPUP_JAVADOC_INFO" value="false" />
    <option name="SHOW_FULL_SIGNATURES_IN_PARAMETER_INFO" value="false" />
    <option name="PARAMETER_INFO_DELAY" value="1000" />
    <option name="JAVADOC_INFO_DELAY" value="1000" />
  </component>
</application>
EOF
      
      # Create UI settings for performance
      cat > "$PHPSTORM_CONFIG_DIR/options/ui.lnf.xml" << 'EOF'
<application>
  <component name="UISettings">
    <option name="ANIMATE_WINDOWS" value="false" />
    <option name="SHOW_TOOL_WINDOW_NUMBERS" value="true" />
    <option name="HIDE_TOOL_STRIPES" value="false" />
    <option name="SHOW_MEMORY_INDICATOR" value="true" />
    <option name="SHOW_MAIN_TOOLBAR" value="false" />
    <option name="SHOW_STATUS_BAR" value="true" />
    <option name="SHOW_NAVIGATION_BAR" value="false" />
    <option name="ALWAYS_SHOW_WINDOW_BUTTONS" value="false" />
    <option name="CYCLE_SCROLLING" value="true" />
    <option name="SCROLL_TAB_LAYOUT_IN_EDITOR" value="true" />
    <option name="HIDE_TABS_IF_NEED" value="true" />
    <option name="SHOW_CLOSE_BUTTON" value="true" />
    <option name="EDITOR_TAB_LIMIT" value="20" />
    <option name="REUSE_NOT_MODIFIED_TABS" value="true" />
    <option name="ANIMATE_WINDOWS" value="false" />
    <option name="SHOW_WINDOW_ICON" value="false" />
    <option name="ANTI_ALIASING_IN_EDITOR" value="true" />
    <option name="MOVE_MOUSE_ON_DEFAULT_BUTTON" value="false" />
    <option name="ENABLE_ALPHA_MODE" value="false" />
    <option name="SHOW_MEMORY_INDICATOR" value="true" />
    <option name="CLOSE_NON_MODIFIED_FILES_FIRST" value="true" />
    <option name="ACTIVATE_RIGHT_EDITOR_ON_CLOSE" value="true" />
    <option name="EDITOR_TAB_PLACEMENT" value="1" />
    <option name="SHOW_DIRECTORY_FOR_NON_UNIQUE_FILENAMES" value="true" />
  </component>
</application>
EOF
      
      echo "✅ Configuration files created successfully!"
      echo ""
      echo "📁 Configuration applied to: $PHPSTORM_CONFIG_DIR"
      echo ""
      echo "🔄 Please restart PhpStorm to apply the performance optimizations"
      echo ""
      echo "💡 Additional optimization commands:"
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
      rm -rf ~/Library/Application\ Support/JetBrains/PhpStorm*/eval
      rm -rf ~/Library/Application\ Support/JetBrains/PhpStorm*/scratches
      
      echo "📊 System memory status:"
      vm_stat | head -5
      echo ""
      
      echo "🔧 JVM configuration:"
      echo "   Heap: 4GB initial, 8GB maximum"
      echo "   Code Cache: 1GB reserved"
      echo "   GC: G1 (optimized for Apple Silicon)"
      echo "   CPU Cores: 14 (M4 Pro)"
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
    # Java performance for JetBrains IDEs
    "_JAVA_OPTIONS" = "-XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1HeapRegionSize=16m -XX:+UseStringDeduplication";
    
    # Disable JetBrains data sharing for performance
    "JETBRAINS_DATA_SHARING" = "false";
  };
  };
}
