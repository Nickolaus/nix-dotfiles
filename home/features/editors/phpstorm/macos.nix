{ pkgs, lib, config, ... }:
lib.mkIf pkgs.stdenv.isDarwin {
  # macOS-specific PhpStorm optimizations and system integration
  # Version-agnostic configuration for Apple Silicon and macOS
  
  # macOS-specific environment variables
  home.sessionVariables = {    
    # PhpStorm-specific optimizations (won't affect system input)
    "IDEA_CASE_SENSITIVE_FS" = "true";
    "IDEA_DISABLE_SYSTEM_CRASH_REPORTS" = "true";
    "IDEA_RETINA" = "true";
    "IDEA_LOG_PERF_STATS" = "false";
    "IDEA_LOG_SLOW_OPERATIONS" = "false";
  };
  
  # macOS-specific shell aliases
  home.shellAliases = {
    # System integration
    "phpstorm-spotlight" = "mdimport -r /Applications/PhpStorm.app";
    "phpstorm-permissions" = "tccutil reset All com.jetbrains.PhpStorm && echo 'PhpStorm permissions reset. Restart PhpStorm to re-grant permissions.'";
    
    # Performance monitoring
    "phpstorm-activity" = "sudo fs_usage -w -f filesys PhpStorm | head -20";
    "phpstorm-network" = "lsof -i -P | grep -i phpstorm";
    "phpstorm-files" = "lsof -p $(pgrep PhpStorm) | wc -l";
    
    # System resource monitoring
    "phpstorm-cpu" = "top -pid $(pgrep PhpStorm) -l 1";
    "phpstorm-memory-detailed" = "vmmap $(pgrep PhpStorm) | grep -E '(TOTAL|Physical|Virtual)'";
    
    # Keychain management
    "phpstorm-keychain" = "security find-generic-password -s PhpStorm -g";
    "phpstorm-keychain-clean" = "security delete-generic-password -s PhpStorm";
  };
  
  # Create macOS-specific management scripts
  home.packages = with pkgs; [
    (writeShellScriptBin "phpstorm-macos-setup" ''
      #!/usr/bin/env bash
      
      echo "🍎 PhpStorm macOS Integration Setup (Version-Agnostic)"
      echo "======================================================"
      echo ""
      
      # Find PhpStorm configuration directory
      JETBRAINS_CONFIG="$HOME/Library/Application Support/JetBrains"
      PHPSTORM_CONFIG_DIR=""
      
      if [ -d "$JETBRAINS_CONFIG" ]; then
        PHPSTORM_CONFIG_DIR=$(find "$JETBRAINS_CONFIG" -maxdepth 1 -type d -name "PhpStorm*" | head -1)
      fi
      
      if [ -z "$PHPSTORM_CONFIG_DIR" ]; then
        echo "❌ PhpStorm configuration directory not found"
        echo "   Please run PhpStorm at least once to create configuration"
        exit 1
      fi
      
      echo "📁 Using configuration: $PHPSTORM_CONFIG_DIR"
      echo ""
      
      # Check macOS version
      macos_version=$(sw_vers -productVersion)
      echo "📱 macOS Version: $macos_version"
      
      # Check Apple Silicon
      if [[ $(uname -m) == "arm64" ]]; then
        echo "🚀 Apple Silicon detected: $(sysctl -n machdep.cpu.brand_string)"
      else
        echo "⚠️  Intel processor detected"
      fi
      
      echo ""
      echo "🔧 Configuring macOS integration..."
      
      # Create necessary directories
      mkdir -p "$PHPSTORM_CONFIG_DIR/options"
      
      # Create macOS-specific configuration files
      cat > "$PHPSTORM_CONFIG_DIR/options/macos.xml" << 'EOF'
<application>
  <component name="MacOSSettings">
    <!-- Native macOS integration -->
    <option name="useNativeMenuBar" value="true" />
    <option name="useNativeFileChooser" value="true" />
    <option name="useNativeClipboard" value="true" />
    <option name="useNativeNotifications" value="true" />
    
    <!-- Retina display optimizations -->
    <option name="enableRetinaSupport" value="true" />
    <option name="useRetinaGlyphs" value="true" />
    <option name="retinaScaleFactor" value="2.0" />
    
    <!-- Touch Bar support (if available) -->
    <option name="touchBarEnabled" value="false" />
    <option name="touchBarShowFnKeys" value="true" />
    
    <!-- Mission Control integration -->
    <option name="fullScreenMode" value="false" />
    <option name="nativeFullScreen" value="false" />
    
    <!-- Dock integration -->
    <option name="showInDock" value="true" />
    <option name="dockBadgeEnabled" value="false" />
    
    <!-- Window management -->
    <option name="windowTitleBarStyle" value="system" />
    <option name="transparentTitleBar" value="false" />
    <option name="unifiedTitleAndToolbar" value="true" />
  </component>
  
  <component name="AppleScriptSettings">
    <!-- Disable AppleScript for security and performance -->
    <option name="enableAppleScript" value="false" />
    <option name="allowAppleScriptExecution" value="false" />
  </component>
  
  <component name="SecuritySettings">
    <!-- macOS security optimizations -->
    <option name="allowFileSystemAccess" value="true" />
    <option name="requestPermissions" value="true" />
    <option name="sandboxMode" value="false" />
  </component>
</application>
EOF
      
      # Create keychain settings
      cat > "$PHPSTORM_CONFIG_DIR/options/keychain.xml" << 'EOF'
<application>
  <component name="KeychainSettings">
    <!-- Use macOS Keychain for secure credential storage -->
    <option name="useSystemKeychain" value="true" />
    <option name="storePasswordsInKeychain" value="true" />
    <option name="keychainService" value="PhpStorm" />
    
    <!-- Git credential integration -->
    <option name="useKeychainForGit" value="true" />
    <option name="useKeychainForSvn" value="false" />
    
    <!-- Database credential storage -->
    <option name="useKeychainForDatabase" value="true" />
    
    <!-- SSH key management -->
    <option name="useKeychainForSsh" value="true" />
    <option name="sshAgentIntegration" value="true" />
  </component>
</application>
EOF
      
      # Create file system settings
      cat > "$PHPSTORM_CONFIG_DIR/options/filesystem.xml" << 'EOF'
<application>
  <component name="FileSystemSettings">
    <!-- APFS optimizations -->
    <option name="useNativeFileWatcher" value="true" />
    <option name="fileWatcherScanDepth" value="3" />
    <option name="enableFileWatcher" value="true" />
    
    <!-- Exclude system directories for performance -->
    <option name="excludeSystemDirectories" value="true" />
    <option name="excludeHiddenFiles" value="true" />
    <option name="excludeNodeModules" value="true" />
    <option name="excludeVendor" value="false" />
    
    <!-- File indexing optimizations -->
    <option name="maxFileSizeForIndexing" value="20480" />
    <option name="indexOnlyProjectFiles" value="true" />
    <option name="skipIndexingForLargeFiles" value="true" />
    
    <!-- Case sensitivity (APFS is case-sensitive) -->
    <option name="caseSensitiveFileSystem" value="true" />
    
    <!-- Symlink handling -->
    <option name="followSymlinks" value="true" />
    <option name="resolveSymlinksInIncludes" value="true" />
    
    <!-- Temporary file handling -->
    <option name="deleteTempFilesOnExit" value="true" />
    <option name="tempFileLifetime" value="7" />
  </component>
</application>
EOF
      
      # Set up Spotlight indexing
      echo "🔍 Configuring Spotlight indexing..."
      mdimport -r /Applications/PhpStorm.app 2>/dev/null || echo "   PhpStorm not found in Applications"
      
      # Check file system
      fs_type=$(diskutil info / | grep "File System" | awk '{print $3}')
      echo "💾 File System: $fs_type"
      
      if [[ "$fs_type" == "APFS" ]]; then
        echo "✅ APFS detected - optimizations enabled"
      else
        echo "⚠️  Non-APFS file system detected"
      fi
      
      # Check available memory
      total_memory=$(sysctl -n hw.memsize)
      memory_gb=$((total_memory / 1024 / 1024 / 1024))
      echo "🧠 Total Memory: ''${memory_gb}GB"
      
      if [[ $memory_gb -ge 32 ]]; then
        echo "✅ Sufficient memory for high-performance settings"
      elif [[ $memory_gb -ge 16 ]]; then
        echo "⚠️  Consider reducing JVM heap size for systems with less memory"
      else
        echo "❌ Low memory detected - performance may be limited"
      fi
      
      echo ""
      echo "✅ macOS integration setup complete!"
      echo "   Configuration applied to: $PHPSTORM_CONFIG_DIR"
      echo ""
      echo "🔐 Security and Permissions:"
      echo "   • Full Disk Access may be required for indexing"
      echo "   • Accessibility permissions may be needed for some features"
      echo "   • Network permissions required for updates and plugins"
      echo ""
      echo "💡 To grant permissions:"
      echo "   System Preferences → Security & Privacy → Privacy"
      echo "   Add PhpStorm to required categories"
      echo ""
      echo "🔄 Restart PhpStorm to apply all changes"
    '')
  ];
}
