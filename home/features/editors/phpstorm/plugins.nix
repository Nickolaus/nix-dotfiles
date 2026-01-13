{ pkgs, lib, config, ... }:
lib.mkIf pkgs.stdenv.isDarwin {
  # PhpStorm Plugin Management and Performance Configuration
  # Version-agnostic plugin optimization for PHP development on Apple Silicon
  
  # Create plugin management script that works with any PhpStorm version
  home.packages = with pkgs; [
    (writeShellScriptBin "phpstorm-plugins" ''
      #!/usr/bin/env bash
      
      echo "🔌 PhpStorm Plugin Manager (Version-Agnostic)"
      echo "============================================="
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
      
      case "''${1:-help}" in
        "list")
          echo "📋 Plugin status:"
          if [ -f "$PHPSTORM_CONFIG_DIR/options/disabled_plugins.xml" ]; then
            echo ""
            echo "❌ Disabled plugins (for performance):"
            grep -o 'value="[^"]*"' "$PHPSTORM_CONFIG_DIR/options/disabled_plugins.xml" | sed 's/value="//g' | sed 's/"//g' | head -10
            echo "   ... and more (see disabled_plugins.xml)"
          else
            echo "   No plugin restrictions applied"
          fi
          echo ""
          echo "✅ Essential plugins remain enabled for PHP development"
          ;;
          
        "optimize")
          echo "🚀 Optimizing plugin configuration..."
          
          # Create options directory if it doesn't exist
          mkdir -p "$PHPSTORM_CONFIG_DIR/options"
          
          # Backup current config
          if [ -f "$PHPSTORM_CONFIG_DIR/options/disabled_plugins.xml" ]; then
            cp "$PHPSTORM_CONFIG_DIR/options/disabled_plugins.xml" "$PHPSTORM_CONFIG_DIR/options/disabled_plugins.xml.backup"
            echo "   Backed up current plugin configuration"
          fi
          
          # Create a conservative disabled plugins configuration.
          cat > "$PHPSTORM_CONFIG_DIR/options/disabled_plugins.xml" << 'EOF'
<application>
  <component name="DisabledPlugins">
    <option name="disabledPlugins">
      <list>
        <!-- Disable AI Assistant and related resource-heavy features -->
        <option value="com.intellij.ml.llm" />
        <option value="com.jetbrains.plugins.ai.assistant" />
        <option value="com.intellij.grazie" />
      </list>
    </option>
  </component>
</application>
EOF
          
          echo "   Applied conservative plugin configuration"
          echo "   Disabled AI assistant plugins (add more if you want)"
          echo ""
          echo "✅ Plugin optimization complete!"
          echo "   Restart PhpStorm to apply changes"
          ;;
          
        "reset")
          echo "🔄 Resetting plugin configuration..."
          rm -f "$PHPSTORM_CONFIG_DIR/options/disabled_plugins.xml"
          echo "   Removed plugin restrictions"
          echo "   All plugins will be available after restart"
          ;;
          
        "help"|*)
          echo "Usage: phpstorm-plugins [command]"
          echo ""
          echo "Commands:"
          echo "  list      - Show plugin status"
          echo "  optimize  - Apply performance-optimized plugin config"
          echo "  reset     - Reset to default plugin configuration"
          echo "  help      - Show this help message"
          echo ""
          echo "💡 The optimize command only disables AI assistant plugins."
          echo "   Add more entries in disabled_plugins.xml if needed."
          echo ""
          echo "✅ Essential plugins that remain enabled:"
          echo "   • PHP Language Support"
          echo "   • Composer Integration"
          echo "   • Twig & Blade Templates"
          echo "   • Git Integration"
          echo "   • Code Quality Tools (PHPStan, PHPCS, etc.)"
          echo "   • Database Tools"
          echo "   • Basic Web Technologies (HTML, CSS, JS)"
          ;;
      esac
    '')
  ];
}
