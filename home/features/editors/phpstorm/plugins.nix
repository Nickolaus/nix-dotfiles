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
          
          # Create optimized disabled plugins configuration
          cat > "$PHPSTORM_CONFIG_DIR/options/disabled_plugins.xml" << 'EOF'
<application>
  <component name="DisabledPlugins">
    <option name="disabledPlugins">
      <list>
        <!-- Disable resource-intensive plugins that aren't essential for PHP development -->
        <option value="com.intellij.copyright" />
        <option value="hg4idea" />
        <option value="CVS" />
        <option value="com.intellij.tasks" />
        <option value="com.intellij.uiDesigner" />
        <option value="DevKit" />
        <option value="CFML Support" />
        <option value="CloudFormation" />
        <option value="Docker" />
        <option value="Kubernetes" />
        <option value="org.jetbrains.plugins.vagrant" />
        <option value="com.intellij.diagram" />
        <option value="com.intellij.persistence" />
        <option value="com.intellij.spring.boot" />
        <option value="com.intellij.spring" />
        <option value="com.intellij.javaee" />
        <option value="com.intellij.jsp" />
        <option value="com.intellij.struts2" />
        <option value="com.intellij.gwt" />
        <option value="com.intellij.flex" />
        <option value="org.jetbrains.plugins.less" />
        <option value="org.jetbrains.plugins.sass" />
        <option value="org.jetbrains.plugins.stylus" />
        <option value="Remote Hosts Access" />
        <option value="FTP/SFTP Connectivity" />
        <option value="org.jetbrains.plugins.terminal" />
        <option value="com.intellij.plugins.html.instantEditing" />
        <option value="LiveEdit" />
        <option value="org.jetbrains.plugins.emmet" />
        <option value="W3C Validators" />
        <option value="XPathView + XSLT Support" />
        <option value="XSLT-Debugger" />
        <option value="com.intellij.properties" />
        <option value="com.intellij.java-i18n" />
        <option value="com.intellij.plugins.rest" />
        <option value="AsciiDoc" />
        <option value="org.asciidoctor.intellij.asciidoc" />
        <option value="Markdown" />
        <option value="org.intellij.plugins.markdown" />
        <option value="YAML" />
        <option value="org.jetbrains.plugins.yaml" />
        
        <!-- Disable AI Assistant and other resource-heavy features -->
        <option value="com.intellij.ml.llm" />
        <option value="com.jetbrains.plugins.ai.assistant" />
        <option value="com.intellij.grazie" />
        <option value="tanvd.grazi" />
        
        <!-- Disable unused language support -->
        <option value="Pythonid" />
        <option value="com.jetbrains.python" />
        <option value="org.jetbrains.plugins.ruby" />
        <option value="com.intellij.plugins.ruby" />
        <option value="org.jetbrains.plugins.go" />
        <option value="com.goide" />
        <option value="Scala" />
        <option value="org.intellij.scala" />
        <option value="Kotlin" />
        <option value="org.jetbrains.kotlin" />
        <option value="com.intellij.plugins.rust" />
        <option value="org.rust.lang" />
      </list>
    </option>
  </component>
</application>
EOF
          
          echo "   Applied performance-optimized plugin configuration"
          echo "   Disabled non-essential plugins for better performance"
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
          echo "💡 The optimize command disables resource-intensive plugins"
          echo "   while keeping essential PHP development tools enabled."
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
