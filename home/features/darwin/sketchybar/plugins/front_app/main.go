package main

import (
	"fmt"
	"os"

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

// HandleFrontAppSwitched handles the front_app_switched event
func (p *FrontAppPlugin) HandleFrontAppSwitched(appName string) error {
	p.logger.Debug("Front app switched to: %s", appName)

	// Update SketchyBar with the new application name
	// Icon is not drawn (icon.drawing=off in config), so we just use empty icon
	if err := p.updater.UpdateItem(itemName, "", appName, p.config.Colors.Text); err != nil {
		return fmt.Errorf("failed to update SketchyBar: %w", err)
	}

	return nil
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
