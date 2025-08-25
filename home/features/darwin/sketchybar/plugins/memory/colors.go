package main

import (
	"sketchybar-plugins/utils"
)

// MemoryColorManager handles all color logic for the memory plugin
type MemoryColorManager struct {
	colors *utils.ColorPalette
}

// NewMemoryColorManager creates a new memory color manager
func NewMemoryColorManager() *MemoryColorManager {
	return &MemoryColorManager{
		colors: utils.NewCatppuccinMacchiato(),
	}
}

// GetMemoryColor returns appropriate color based on memory usage
func (c *MemoryColorManager) GetMemoryColor(usagePercent float64) string {
	// Memory usage: high values are bad, so use reverse logic
	return c.colors.GetStatusColor(usagePercent, true)
}
