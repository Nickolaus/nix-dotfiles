package main

import (
	"sketchybar-plugins/utils"
)

// SpotifyColorManager handles all color logic for the Spotify plugin
type SpotifyColorManager struct {
	colors *utils.ColorPalette
}

// NewSpotifyColorManager creates a new Spotify color manager
func NewSpotifyColorManager() *SpotifyColorManager {
	return &SpotifyColorManager{
		colors: utils.NewCatppuccinMacchiato(),
	}
}

// GetPlayingColor returns color for actively playing state
func (c *SpotifyColorManager) GetPlayingColor() string {
	return c.colors.Green
}

// GetPausedColor returns color for paused state
func (c *SpotifyColorManager) GetPausedColor() string {
	return c.colors.Yellow
}

// GetStoppedColor returns color for stopped/ready state
func (c *SpotifyColorManager) GetStoppedColor() string {
	return c.colors.Overlay2
}

// GetNotPlayingColor returns color for not playing state
func (c *SpotifyColorManager) GetNotPlayingColor() string {
	return c.colors.Overlay2
}

// GetTextColor returns color for text elements
func (c *SpotifyColorManager) GetTextColor() string {
	return c.colors.Text
}

// GetSurfaceColor returns color for surface elements
func (c *SpotifyColorManager) GetSurfaceColor() string {
	return c.colors.Surface0
}
