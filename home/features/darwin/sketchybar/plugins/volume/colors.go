package main

import (
	"sketchybar-plugins/utils"
)

// VolumeColorManager handles all color logic for the volume plugin
type VolumeColorManager struct {
	colors *utils.ColorPalette
}

// NewVolumeColorManager creates a new volume color manager
func NewVolumeColorManager() *VolumeColorManager {
	return &VolumeColorManager{
		colors: utils.NewCatppuccinMacchiato(),
	}
}

// GetVolumeColor returns appropriate color using standardized color logic
func (c *VolumeColorManager) GetVolumeColor(info *VolumeInfo) string {
	return c.colors.GetVolumeColor(info.Volume, info.IsMuted)
}

// GetMutedColor returns color for muted state
func (c *VolumeColorManager) GetMutedColor() string {
	return c.colors.Red
}

// GetNotificationColor returns color for volume change notifications
func (c *VolumeColorManager) GetNotificationColor() string {
	return c.colors.Blue
}
