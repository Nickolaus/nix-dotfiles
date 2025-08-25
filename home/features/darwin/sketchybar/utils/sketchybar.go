package utils

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"sketchybar-plugins/config"
)

// SketchyBarUpdater handles communication with SketchyBar
type SketchyBarUpdater struct {
	config *config.GlobalConfig
}

// NewSketchyBarUpdater creates a new SketchyBar updater
func NewSketchyBarUpdater(cfg *config.GlobalConfig) *SketchyBarUpdater {
	return &SketchyBarUpdater{config: cfg}
}

// UpdateItem updates a SketchyBar item with consistent styling
func (sb *SketchyBarUpdater) UpdateItem(name, icon, label, iconColor string) error {
	return sb.UpdateItemDetailed(name, icon, label, iconColor, sb.config.Colors.Text, sb.config.Colors.Surface0)
}

// UpdateItemDetailed updates a SketchyBar item with modern group-based design
func (sb *SketchyBarUpdater) UpdateItemDetailed(name, icon, label, iconColor, labelColor, bgColor string) error {
	cmd := exec.Command("sketchybar", "--set", name,
		"icon="+icon,
		"label="+label,
		"icon.color="+iconColor,
		"label.color="+labelColor,
		// 🎨 MODERN: Individual backgrounds disabled - groups handle styling
		"background.drawing=off",
		// 🎯 PERFECT ALIGNMENT: Precise positioning for modern typography
		"icon.y_offset=0",
		"label.y_offset=0",
		// 🌊 SEAMLESS SPACING: Let group containers provide the structure
		"icon.padding_left=8",
		"icon.padding_right=6",
		"label.padding_left=0",
		"label.padding_right=8",
		// 🎨 NO ITEM PADDING: Groups provide consistent spacing
		"padding_left=0",
		"padding_right=0",
	)

	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("failed to update SketchyBar item %s: %w (output: %s)", name, err, output)
	}

	return nil
}

// UpdatePopup updates a SketchyBar popup
func (sb *SketchyBarUpdater) UpdatePopup(name, content string) error {
	cmd := exec.Command("sketchybar", "--set", name, "popup.background.color="+sb.config.Colors.Surface0)
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("failed to update popup %s: %w (output: %s)", name, err, output)
	}

	return nil
}

// Round rounds a float64 to the specified number of decimal places
func Round(val float64, precision int) float64 {
	if precision == 0 {
		return float64(int(val + 0.5))
	}

	multiplier := 1.0
	for i := 0; i < precision; i++ {
		multiplier *= 10
	}

	return float64(int(val*multiplier+0.5)) / multiplier
}

// GetCPUIcon returns appropriate CPU icon based purely on usage level
func GetCPUIcon(usage float64) string {
	switch {
	case usage > 85:
		return "󰘚" // High usage - CPU
	case usage > 65:
		return "󰻠" // Medium-high usage - CPU
	case usage > 35:
		return "󰻟" // Medium usage - CPU
	case usage > 15:
		return "󰻞" // Low-medium usage - CPU
	default:
		return "󰻝" // Low usage - CPU
	}
}

// OpenApplication opens a macOS application
func OpenApplication(appName string) error {
	cmd := exec.Command("open", "-a", appName)
	return cmd.Run()
}

// ShowNotification shows a macOS notification
func ShowNotification(title, message string) error {
	script := fmt.Sprintf(`display notification "%s" with title "%s"`, message, title)
	cmd := exec.Command("osascript", "-e", script)
	return cmd.Run()
}

// ExpandPath expands tilde (~) in file paths to the home directory
func ExpandPath(path string) string {
	if strings.HasPrefix(path, "~/") {
		homeDir, err := os.UserHomeDir()
		if err != nil {
			return path // Return original path if we can't get home dir
		}
		return filepath.Join(homeDir, path[2:])
	}
	return path
}
