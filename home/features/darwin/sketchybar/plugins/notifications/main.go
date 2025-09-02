package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"sketchybar-plugins/config"
	"sketchybar-plugins/utils"
)

const (
	pluginName = "notifications"
	itemName   = "notifications"
)

// NotificationsPlugin provides a simple DND toggle and notification center access
type NotificationsPlugin struct {
	config           *config.GlobalConfig
	logger           *utils.Logger
	updater          *utils.SketchyBarUpdater
	doNotDisturbFile string
}

// NotificationInfo holds the current notification state
type NotificationInfo struct {
	IsDNDActive bool
	Icon        string
	Label       string
	Color       string
}

// NewNotificationsPlugin creates a new notifications plugin instance
func NewNotificationsPlugin() (*NotificationsPlugin, error) {
	cfg, err := config.LoadConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to load config: %w", err)
	}

	logger := utils.NewLogger(pluginName)
	updater := utils.NewSketchyBarUpdater(cfg)

	// DND file path
	homeDir := os.Getenv("HOME")
	dndFile := filepath.Join(homeDir, ".local", "state", "sketchybar_dnd")

	return &NotificationsPlugin{
		config:           cfg,
		logger:           logger,
		updater:          updater,
		doNotDisturbFile: dndFile,
	}, nil
}

// UpdateDisplay refreshes the notification display
func (p *NotificationsPlugin) UpdateDisplay() error {
	info := &NotificationInfo{}

	// Check DND status
	if _, err := os.Stat(p.doNotDisturbFile); err == nil {
		info.IsDNDActive = true
		info.Icon = "🔕"
		info.Label = "DND"
		info.Color = p.config.Colors.Yellow
		p.logger.Debug("DND is active")
	} else {
		info.IsDNDActive = false
		info.Icon = "🔔"
		info.Label = ""
		info.Color = p.config.Colors.Text
		p.logger.Debug("DND is inactive")
	}

	// Update SketchyBar
	return p.updater.UpdateItem(itemName, info.Icon, info.Label, info.Color)
}

// HandleToggleAction toggles DND mode
func (p *NotificationsPlugin) HandleToggleAction() error {
	p.logger.Info("Toggling DND mode")

	// Ensure state directory exists
	stateDir := filepath.Dir(p.doNotDisturbFile)
	if err := os.MkdirAll(stateDir, 0755); err != nil {
		return fmt.Errorf("failed to create state directory: %w", err)
	}

	// Check current DND state
	dndActive := false
	if _, err := os.Stat(p.doNotDisturbFile); err == nil {
		dndActive = true
	}

	if dndActive {
		// Turn off DND
		if err := os.Remove(p.doNotDisturbFile); err != nil {
			return fmt.Errorf("failed to turn off DND: %w", err)
		}
		p.logger.Info("DND turned OFF")

		// Show confirmation
		if err := p.updater.UpdateItem(itemName, "🔔", "DND OFF", p.config.Colors.Green); err != nil {
			return fmt.Errorf("failed to show confirmation: %w", err)
		}
	} else {
		// Turn on DND
		file, err := os.Create(p.doNotDisturbFile)
		if err != nil {
			return fmt.Errorf("failed to turn on DND: %w", err)
		}
		file.Close()
		p.logger.Info("DND turned ON")

		// Show confirmation
		if err := p.updater.UpdateItem(itemName, "🔕", "DND ON", p.config.Colors.Yellow); err != nil {
			return fmt.Errorf("failed to show confirmation: %w", err)
		}
	}

	// Reset to normal display after 2 seconds
	go func() {
		time.Sleep(2 * time.Second)
		if err := p.UpdateDisplay(); err != nil {
			p.logger.Error("Failed to reset display: %v", err)
		}
	}()

	return nil
}

// HandleClickAction handles mouse clicks
func (p *NotificationsPlugin) HandleClickAction() error {
	button := os.Getenv("BUTTON")
	p.logger.Debug("Click detected - Button: %s", button)

	switch button {
	case "right":
		// Right click -> Toggle DND
		p.logger.Info("Right-click: toggling DND")
		return p.HandleToggleAction()
	case "left":
		fallthrough
	default:
		// Left click -> Open Notification Center
		p.logger.Info("Left-click: opening Notification Center")
		return p.openNotificationCenter()
	}
}

// openNotificationCenter opens macOS Notification Center
func (p *NotificationsPlugin) openNotificationCenter() error {
	// Try keyboard shortcut first
	cmd := exec.Command("osascript", "-e", `tell application "System Events" to key code 99 using {command down}`)
	if err := cmd.Run(); err != nil {
		p.logger.Debug("Keyboard shortcut failed, opening System Preferences")
		// Fallback: open Notifications in System Preferences
		cmd = exec.Command("open", "x-apple.systempreferences:com.apple.preference.notifications")
		return cmd.Run()
	}
	return nil
}

// Run starts the notifications plugin
func (p *NotificationsPlugin) Run() error {
	p.logger.Info("Starting notifications plugin")

	// Handle command line arguments
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "toggle", "dnd":
			return p.HandleToggleAction()
		case "click":
			return p.HandleClickAction()
		case "open":
			return p.openNotificationCenter()
		default:
			p.logger.Debug("Unknown argument: %s", os.Args[1])
		}
	}

	// Regular display update
	return p.UpdateDisplay()
}

func main() {
	plugin, err := NewNotificationsPlugin()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create notifications plugin: %v\n", err)
		os.Exit(1)
	}

	if err := plugin.Run(); err != nil {
		plugin.logger.Error("Plugin execution failed: %v", err)
		fmt.Fprintf(os.Stderr, "Notifications plugin failed: %v\n", err)
		os.Exit(1)
	}
}
