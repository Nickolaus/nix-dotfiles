package main

import (
	"fmt"
	"os"
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

// HandleFrontAppSwitched handles the front_app_switched event with smart formatting
func (p *FrontAppPlugin) HandleFrontAppSwitched(appName string) error {
	p.logger.Debug("Front app switched to: %s", appName)

	// Get contextual icon and smart-truncated name
	icon := p.GetAppIcon(appName)
	displayName := p.SmartTruncate(appName)

	// Update SketchyBar with enhanced display
	if err := p.updater.UpdateItem(itemName, icon, displayName, p.config.Colors.Text); err != nil {
		return fmt.Errorf("failed to update SketchyBar: %w", err)
	}

	return nil
}

// GetAppIcon returns contextual icon based on app type
func (p *FrontAppPlugin) GetAppIcon(appName string) string {
	lowerName := strings.ToLower(appName)

	// 💻 Development & Code Editors
	if strings.Contains(lowerName, "cursor") || strings.Contains(lowerName, "code") ||
		strings.Contains(lowerName, "phpstorm") || strings.Contains(lowerName, "webstorm") ||
		strings.Contains(lowerName, "intellij") || strings.Contains(lowerName, "vim") ||
		strings.Contains(lowerName, "emacs") || strings.Contains(lowerName, "atom") {
		return "󰅩" // Code editor icon (alternative)
	}

	// 🌐 Web Browsers
	if strings.Contains(lowerName, "safari") || strings.Contains(lowerName, "chrome") ||
		strings.Contains(lowerName, "firefox") || strings.Contains(lowerName, "edge") ||
		strings.Contains(lowerName, "brave") || strings.Contains(lowerName, "arc") {
		return "󰖟" // Browser icon
	}

	// 🎵 Media & Music
	if strings.Contains(lowerName, "spotify") || strings.Contains(lowerName, "music") ||
		strings.Contains(lowerName, "vlc") || strings.Contains(lowerName, "quicktime") ||
		strings.Contains(lowerName, "itunes") || strings.Contains(lowerName, "plex") {
		return "󰝚" // Music/media icon
	}

	// 💬 Communication
	if strings.Contains(lowerName, "slack") || strings.Contains(lowerName, "discord") ||
		strings.Contains(lowerName, "teams") || strings.Contains(lowerName, "zoom") ||
		strings.Contains(lowerName, "messages") || strings.Contains(lowerName, "mail") {
		return "󰭹" // Communication icon
	}

	// 🗂️ File Management
	if strings.Contains(lowerName, "finder") || strings.Contains(lowerName, "files") ||
		strings.Contains(lowerName, "forklift") || strings.Contains(lowerName, "path finder") {
		return "󰉋" // File manager icon
	}

	// 🎮 Games & Entertainment
	if strings.Contains(lowerName, "steam") || strings.Contains(lowerName, "game") ||
		strings.Contains(lowerName, "epic") || strings.Contains(lowerName, "unity") {
		return "󰊖" // Game controller icon
	}

	// ⚙️ System & Utilities
	if strings.Contains(lowerName, "terminal") || strings.Contains(lowerName, "iTerm") ||
		strings.Contains(lowerName, "wezterm") || strings.Contains(lowerName, "console") {
		return "󰆍" // Terminal icon
	}

	// 🎨 Design & Creative
	if strings.Contains(lowerName, "photoshop") || strings.Contains(lowerName, "figma") ||
		strings.Contains(lowerName, "sketch") || strings.Contains(lowerName, "illustrator") ||
		strings.Contains(lowerName, "canva") || strings.Contains(lowerName, "pixelmator") {
		return "󰏘" // Design icon
	}

	// 📝 Default for unknown apps
	return "󰣖" // Generic application icon
}

// SmartTruncate implements intelligent truncation for app names
func (p *FrontAppPlugin) SmartTruncate(appName string) string {
	const maxLength = 50 // Reasonable limit for SketchyBar display

	if len(appName) <= maxLength {
		return appName
	}

	// Handle music/media format: "Artist - Song Title"
	if strings.Contains(appName, " - ") && strings.Contains(appName, "▶") {
		parts := strings.Split(appName, " - ")
		if len(parts) >= 2 {
			// For media: show "App ▶ Artist - Song..." (prioritize song info)
			app := parts[0]  // "Cursor ▶ Rage Against..."
			song := parts[1] // "Killing In The Name"

			// Extract app name from the first part
			if strings.Contains(app, "▶") {
				appParts := strings.Split(app, "▶")
				if len(appParts) >= 2 {
					appOnly := strings.TrimSpace(appParts[0]) // "Cursor"
					artist := strings.TrimSpace(appParts[1])  // "Rage Against..."

					// Smart format: "Cursor ▶ Artist - Song"
					combined := fmt.Sprintf("%s ▶ %s - %s", appOnly, artist, song)
					if len(combined) <= maxLength {
						return combined
					}

					// If still too long, prioritize song over artist
					songTruncated := p.truncateMiddle(song, 20)
					return fmt.Sprintf("%s ▶ %s", appOnly, songTruncated)
				}
			}
		}
	}

	// Handle app with document: "App - Document"
	if strings.Contains(appName, " - ") {
		parts := strings.Split(appName, " - ")
		if len(parts) == 2 {
			app := strings.TrimSpace(parts[0])
			doc := strings.TrimSpace(parts[1])

			// Keep app name, truncate document
			if len(app)+3+15 <= maxLength { // "App - DocumentTrunc..."
				docTruncated := p.truncateMiddle(doc, maxLength-len(app)-3)
				return fmt.Sprintf("%s - %s", app, docTruncated)
			}
		}
	}

	// Default: truncate from middle to preserve beginning and end
	return p.truncateMiddle(appName, maxLength)
}

// truncateMiddle truncates from the middle, preserving start and end
func (p *FrontAppPlugin) truncateMiddle(text string, maxLen int) string {
	if len(text) <= maxLen {
		return text
	}

	if maxLen <= 3 {
		return text[:maxLen]
	}

	// Reserve 3 characters for "..."
	availableLen := maxLen - 3
	startLen := availableLen / 2
	endLen := availableLen - startLen

	return text[:startLen] + "..." + text[len(text)-endLen:]
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
