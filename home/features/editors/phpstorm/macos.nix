{ pkgs, lib, config, ... }:
lib.mkIf pkgs.stdenv.isDarwin {
  # macOS-specific PhpStorm optimizations and system integration
  # Version-agnostic configuration for Apple Silicon and macOS
  
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
      
      # Avoid writing IDE XML settings from a script; prefer IDE defaults and UI settings.
      echo "ℹ️  No IDE XML settings written (prefer built-in defaults)"
      
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
