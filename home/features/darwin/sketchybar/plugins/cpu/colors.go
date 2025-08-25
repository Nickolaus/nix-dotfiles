package main

import (
	"sketchybar-plugins/utils"
)

// CPUColorManager handles all color logic for the CPU plugin
type CPUColorManager struct {
	colors *utils.ColorPalette
}

// NewCPUColorManager creates a new CPU color manager
func NewCPUColorManager() *CPUColorManager {
	return &CPUColorManager{
		colors: utils.NewCatppuccinMacchiato(),
	}
}

// GetCPUColor returns appropriate color based on CPU usage
func (c *CPUColorManager) GetCPUColor(usage float64) string {
	// CPU usage: high values are bad, so use reverse logic
	return c.colors.GetStatusColor(usage, true)
}
