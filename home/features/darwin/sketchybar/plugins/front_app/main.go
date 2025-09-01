package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"sketchybar-plugins/config"
	"sketchybar-plugins/utils"
)

const (
	pluginName = "front_app"
	itemName   = "front_app"
)

// FrontAppPlugin handles front app tracking for SketchyBar
type FrontAppPlugin struct {
	config  *config.GlobalConfig
	logger  *utils.Logger
	updater *utils.SketchyBarUpdater
	sysinfo *utils.SystemInfo
}

// NewFrontAppPlugin creates a new front app tracking plugin
func NewFrontAppPlugin() (*FrontAppPlugin, error) {
	cfg, err := config.LoadConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to load config: %w", err)
	}

	logger := utils.NewLogger(pluginName)
	updater := utils.NewSketchyBarUpdater(cfg)
	sysinfo := utils.NewSystemInfo(cfg, logger)

	return &FrontAppPlugin{
		config:  cfg,
		logger:  logger,
		updater: updater,
		sysinfo: sysinfo,
	}, nil
}

// HandleFrontAppSwitched handles the front_app_switched event with professional app-font support
func (p *FrontAppPlugin) HandleFrontAppSwitched(appName string) error {
	p.logger.Debug("Front app switched to: %s", appName)

	// Get professional app-specific icon and smart-truncated name
	icon := p.GetAppIcon(appName)
	displayName := p.SmartTruncate(appName)

	// Update SketchyBar with app-font integration and emoji fallback
	if err := p.updateWithAppFont(icon, displayName); err != nil {
		return fmt.Errorf("failed to update SketchyBar: %w", err)
	}

	return nil
}

// updateWithAppFont updates SketchyBar with app font support and emoji fallback
func (p *FrontAppPlugin) updateWithAppFont(iconLigature, displayName string) error {
	// Try to use sketchybar-app-font if available
	cmd := exec.Command("sketchybar", "--set", itemName,
		"icon="+iconLigature,
		"label="+displayName,
		"icon.color="+p.config.Colors.Text,
		"label.color="+p.config.Colors.Text,
		"icon.font=sketchybar-app-font:Regular:16.0", // Use app font
		"label.font=SF Pro Display:Medium:13.0",
	)

	if output, err := cmd.CombinedOutput(); err != nil {
		// If app font fails, fall back to system font with emoji
		p.logger.Debug("App font failed, falling back to system font: %v", err)
		fallbackIcon := p.GetFallbackIcon(iconLigature)
		cmd = exec.Command("sketchybar", "--set", itemName,
			"icon="+fallbackIcon,
			"label="+displayName,
			"icon.color="+p.config.Colors.Text,
			"label.color="+p.config.Colors.Text,
			"icon.font=SF Pro Display:Semibold:15.0", // System font fallback
			"label.font=SF Pro Display:Medium:13.0",
		)
		if output2, err2 := cmd.CombinedOutput(); err2 != nil {
			return fmt.Errorf("both app font and fallback failed: %w (app font output: %s, fallback output: %s)",
				err2, output, output2)
		}
	}

	return nil
}

// GetAppIcon returns professional app icon with app-font integration
func (p *FrontAppPlugin) GetAppIcon(appName string) string {
	// Try to get professional app-specific icon from sketchybar-app-font
	if iconLigature := p.getAppFontIcon(appName); iconLigature != "" {
		return iconLigature
	}

	// Fall back to category-based app-font ligatures or emoji icons
	return p.getCategoryIcon(appName)
}

// getAppFontIcon attempts to get professional icon from sketchybar-app-font icon_map.sh
func (p *FrontAppPlugin) getAppFontIcon(appName string) string {
	// Call the icon_map.sh script if available (official installer puts it in helpers/)
	iconMapScript := os.ExpandEnv("$HOME/.config/sketchybar/helpers/icon_map.sh")
	if _, err := os.Stat(iconMapScript); os.IsNotExist(err) {
		return ""
	}

	// Execute the icon mapping function
	cmd := exec.Command("bash", "-c", fmt.Sprintf(`
		source %s 2>/dev/null || exit 1
		__icon_map "%s"
		echo "$icon_result"
	`, iconMapScript, appName))

	output, err := cmd.Output()
	if err != nil {
		p.logger.Debug("Icon mapping failed for %s: %v", appName, err)
		return ""
	}

	result := strings.TrimSpace(string(output))
	if result != "" && result != appName {
		p.logger.Debug("App font icon for %s: %s", appName, result)
		return result
	}

	return ""
}

// getCategoryIcon provides fallback icons with app-font ligatures where possible
func (p *FrontAppPlugin) getCategoryIcon(appName string) string {
	lowerName := strings.ToLower(appName)

	// Category-based fallbacks using app-font ligatures where possible
	switch {
	case strings.Contains(lowerName, "cursor"):
		return ":cursor:" // App-font ligature for Cursor
	case strings.Contains(lowerName, "chrome"):
		return ":google-chrome:" // App-font ligature for Chrome
	case strings.Contains(lowerName, "safari"):
		return ":safari:" // App-font ligature for Safari
	case strings.Contains(lowerName, "firefox"):
		return ":firefox:" // App-font ligature for Firefox
	case strings.Contains(lowerName, "code") || strings.Contains(lowerName, "vscode"):
		return ":visual-studio-code:" // App-font ligature for VS Code
	case strings.Contains(lowerName, "phpstorm"):
		return ":phpstorm:" // App-font ligature for PhpStorm
	case strings.Contains(lowerName, "slack"):
		return ":slack:" // App-font ligature for Slack
	case strings.Contains(lowerName, "discord"):
		return ":discord:" // App-font ligature for Discord
	case strings.Contains(lowerName, "spotify"):
		return ":spotify:" // App-font ligature for Spotify
	case strings.Contains(lowerName, "finder"):
		return ":finder:" // App-font ligature for Finder
	case strings.Contains(lowerName, "terminal") || strings.Contains(lowerName, "iterm") || strings.Contains(lowerName, "wezterm"):
		return ":terminal:" // Generic terminal ligature
	case strings.Contains(lowerName, "sourcetree"):
		return ":sourcetree:" // App-font ligature for SourceTree
	case strings.Contains(lowerName, "photoshop"):
		return ":adobe-photoshop:" // App-font ligature for Photoshop
	case strings.Contains(lowerName, "figma"):
		return ":figma:" // App-font ligature for Figma

	// Emoji fallbacks for unmapped apps
	case strings.Contains(lowerName, "webstorm") || strings.Contains(lowerName, "intellij") ||
		strings.Contains(lowerName, "vim") || strings.Contains(lowerName, "emacs"):
		return "" // Modern code editor icon
	case strings.Contains(lowerName, "edge") || strings.Contains(lowerName, "brave") || strings.Contains(lowerName, "arc"):
		return "🌐" // Browser fallback
	case strings.Contains(lowerName, "music") || strings.Contains(lowerName, "vlc") ||
		strings.Contains(lowerName, "quicktime") || strings.Contains(lowerName, "plex"):
		return "🎵" // Media fallback
	case strings.Contains(lowerName, "teams") || strings.Contains(lowerName, "zoom") ||
		strings.Contains(lowerName, "messages") || strings.Contains(lowerName, "mail"):
		return "💬" // Communication fallback
	case strings.Contains(lowerName, "files") || strings.Contains(lowerName, "forklift"):
		return "📁" // File manager fallback
	case strings.Contains(lowerName, "steam") || strings.Contains(lowerName, "game") || strings.Contains(lowerName, "epic"):
		return "🎮" // Games fallback
	case strings.Contains(lowerName, "sketch") || strings.Contains(lowerName, "illustrator") || strings.Contains(lowerName, "canva"):
		return "🎨" // Design fallback
	default:
		return "📱" // Generic app fallback
	}
}

// GetFallbackIcon converts app-font ligature to emoji for system font fallback
func (p *FrontAppPlugin) GetFallbackIcon(ligature string) string {
	// Convert common app-font ligatures to emoji equivalents
	switch ligature {
	case ":cursor:", ":visual-studio-code:", ":phpstorm:":
		return ""
	case ":google-chrome:", ":safari:", ":firefox:":
		return "🌐"
	case ":slack:", ":discord:":
		return "💬"
	case ":spotify:":
		return "🎵"
	case ":finder:":
		return "📁"
	case ":terminal:":
		return "⚡"
	case ":sourcetree:":
		return "📝"
	case ":adobe-photoshop:", ":figma:":
		return "🎨"
	default:
		// If it's already an emoji or unknown ligature, return as-is
		if strings.HasPrefix(ligature, ":") && strings.HasSuffix(ligature, ":") {
			return "📱" // Generic app fallback for unknown ligatures
		}
		return ligature // Return emoji as-is
	}
}

// SmartTruncate implements fixed-width truncation for app names
func (p *FrontAppPlugin) SmartTruncate(appName string) string {
	const maxLength = 15  // Fixed maximum length
	const truncateAt = 12 // Truncate with ellipsis if longer than 15

	// Clean up common app name patterns first
	cleaned := p.cleanAppName(appName)

	if len(cleaned) <= maxLength {
		return cleaned
	}

	// Truncate with ellipsis for consistent width
	return cleaned[:truncateAt] + "…"
}

// cleanAppName cleans up common app name patterns
func (p *FrontAppPlugin) cleanAppName(appName string) string {
	cleaned := strings.TrimSpace(appName)

	// Handle common app name patterns for better readability
	switch {
	case strings.HasSuffix(cleaned, " - Google Chrome"):
		cleaned = strings.Replace(cleaned, " - Google Chrome", "", 1)
	case strings.HasSuffix(cleaned, " — WezTerm"):
		cleaned = strings.Replace(cleaned, " — WezTerm", "", 1)
	case strings.HasPrefix(cleaned, "PhpStorm - "):
		cleaned = strings.Replace(cleaned, "PhpStorm - ", "", 1)
	case strings.Contains(cleaned, " - ") && !strings.Contains(cleaned, "▶"):
		// Generic "App - Document" pattern: show just the app name for space efficiency
		parts := strings.Split(cleaned, " - ")
		if len(parts) > 0 {
			cleaned = parts[0] // Take first part (app name)
		}
	case strings.Contains(cleaned, " ▶ "):
		// Media format: "App ▶ Artist - Song" -> keep app part
		parts := strings.Split(cleaned, " ▶ ")
		if len(parts) > 0 {
			cleaned = parts[0] // Keep just the app name for consistent width
		}
	}

	return cleaned
}

// UpdateDisplay updates the SketchyBar display (not typically used for front_app)
func (p *FrontAppPlugin) UpdateDisplay() error {
	// Front app plugin is event-driven, so regular updates aren't needed
	// But we can provide a fallback to show current app if needed
	p.logger.Debug("Front app plugin - no regular update needed (event-driven)")
	return nil
}

// Run starts the front app tracking plugin
func (p *FrontAppPlugin) Run() error {
	p.logger.Info("Starting front app plugin")

	// Check if this is triggered by the front_app_switched event
	sender := os.Getenv("SENDER")
	info := os.Getenv("INFO")

	if sender == "front_app_switched" {
		if info != "" {
			return p.HandleFrontAppSwitched(info)
		} else {
			p.logger.Debug("Front app switched but no app name provided")
			return nil
		}
	}

	// For regular execution, just log that it's running
	p.logger.Debug("Front app plugin ready (event-driven)")
	return nil
}

func main() {
	plugin, err := NewFrontAppPlugin()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create front app plugin: %v\n", err)
		os.Exit(1)
	}

	if err := plugin.Run(); err != nil {
		plugin.logger.Error("Plugin execution failed: %v", err)
		fmt.Fprintf(os.Stderr, "Front app plugin failed: %v\n", err)
		os.Exit(1)
	}
}
