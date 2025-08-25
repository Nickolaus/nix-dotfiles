package main

import (
	"sketchybar-plugins/utils"
)

// BatteryColorManager handles all color logic for the battery plugin
type BatteryColorManager struct {
	colors *utils.ColorPalette
}

// NewBatteryColorManager creates a new battery color manager
func NewBatteryColorManager() *BatteryColorManager {
	return &BatteryColorManager{
		colors: utils.NewCatppuccinMacchiato(),
	}
}

// GetBatteryColor returns appropriate color based on battery level and charging status
func (c *BatteryColorManager) GetBatteryColor(info *BatteryInfo) string {
	if !info.IsPresent {
		return c.colors.Red
	}

	if info.IsCharging {
		// Charging: use slightly more optimistic thresholds (shift by +10%)
		adjustedPercentage := float64(info.Percentage + 10)
		if adjustedPercentage > 100 {
			adjustedPercentage = 100
		}
		return c.colors.GetStatusColor(adjustedPercentage, false)
	} else {
		// Battery: use standard "high is good" logic
		return c.colors.GetStatusColor(float64(info.Percentage), false)
	}
}

// GetNoDeviceColor returns color for "no battery" state
func (c *BatteryColorManager) GetNoDeviceColor() string {
	return c.colors.Red
}
