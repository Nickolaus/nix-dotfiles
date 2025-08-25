package main

import (
	"sketchybar-plugins/utils"
)

// NetworkColorManager handles all color logic for the network plugin
type NetworkColorManager struct {
	colors *utils.ColorPalette
}

// NewNetworkColorManager creates a new network color manager
func NewNetworkColorManager() *NetworkColorManager {
	return &NetworkColorManager{
		colors: utils.NewCatppuccinMacchiato(),
	}
}

// GetNetworkColor returns appropriate color based on network connection status
func (c *NetworkColorManager) GetNetworkColor(info *NetworkInfo) string {
	if !info.IsConnected {
		return c.colors.Red // No connection
	}

	// VPN connections get special lavender coloring for security indication
	if info.IsVPNActive {
		return c.colors.Lavender // VPN connections (secure)
	}

	// Hotspot connections get orange coloring for mobile data indication
	if info.IsHotspot {
		return c.colors.Peach // Mobile hotspot (limited data)
	}

	switch info.InterfaceType {
	case "wifi":
		return c.colors.GetSignalColor(info.SignalQuality) // Standardized signal quality colors
	case "ethernet":
		return c.colors.Green // Ethernet is always reliable
	case "usb":
		return c.colors.Blue // USB tethering
	case "bluetooth":
		return c.colors.Sky // Bluetooth PAN
	default:
		return c.colors.Subtext1 // Unknown connection
	}
}

// GetDisconnectedColor returns color for disconnected state
func (c *NetworkColorManager) GetDisconnectedColor() string {
	return c.colors.Red
}

// GetVPNColor returns color for VPN connections
func (c *NetworkColorManager) GetVPNColor() string {
	return c.colors.Lavender
}

// GetHotspotColor returns color for mobile hotspot connections
func (c *NetworkColorManager) GetHotspotColor() string {
	return c.colors.Peach
}
