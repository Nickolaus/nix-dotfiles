package utils

// ColorPalette defines the Catppuccin Macchiato color scheme used across all plugins
//
// ⚠️  CRITICAL: SketchyBar requires RGBA color format with alpha channel!
// Format: "0xffRRGGBB" where:
//   - "0x" = hex prefix
//   - "ff" = alpha channel (fully opaque, required!)
//   - "RRGGBB" = RGB color values
//
// Example: "0xffed8796" NOT "0xed8796"
// Missing alpha channel will make colors invisible/broken!
type ColorPalette struct {
	// Base colors
	Base   string
	Mantle string
	Crust  string

	// Surface colors
	Surface0 string
	Surface1 string
	Surface2 string

	// Text colors
	Text     string
	Subtext0 string
	Subtext1 string

	// Overlay colors
	Overlay0 string
	Overlay1 string
	Overlay2 string

	// Status colors (semantic)
	Red    string
	Green  string
	Yellow string
	Blue   string
	Peach  string

	// Accent colors
	Lavender  string
	Mauve     string
	Sky       string
	Sapphire  string
	Rosewater string
}

// NewCatppuccinMacchiato returns the standard Catppuccin Macchiato color palette
// All colors include the required "ff" alpha channel for SketchyBar compatibility
func NewCatppuccinMacchiato() *ColorPalette {
	return &ColorPalette{
		// Base colors
		Base:   "0xff24273a",
		Mantle: "0xff1e2030",
		Crust:  "0xff181926",

		// Surface colors
		Surface0: "0xff363a4f",
		Surface1: "0xff494d64",
		Surface2: "0xff5b6078",

		// Text colors
		Text:     "0xffcad3f5",
		Subtext0: "0xffa5adcb",
		Subtext1: "0xffb8c0e0",

		// Overlay colors
		Overlay0: "0xff6e738d",
		Overlay1: "0xff8087a2",
		Overlay2: "0xff939ab7",

		// Status colors (semantic)
		Red:    "0xffed8796",
		Green:  "0xffa6da95",
		Yellow: "0xffeed49f",
		Blue:   "0xff8aadf4",
		Peach:  "0xfff5a97f",

		// Accent colors
		Lavender:  "0xffb7bdf8",
		Mauve:     "0xffc6a0f6",
		Sky:       "0xff91d7e3",
		Sapphire:  "0xff7dc4e4",
		Rosewater: "0xfff4dbd6",
	}
}

// StatusLevel represents different status severity levels
type StatusLevel int

const (
	StatusGood StatusLevel = iota
	StatusMedium
	StatusPoor
	StatusCritical
)

// GetStatusColor returns appropriate color based on percentage and context with consistent thresholds
func (c *ColorPalette) GetStatusColor(percentage float64, reverse bool) string {
	level := c.getStatusLevel(percentage, reverse)
	return c.getColorForLevel(level)
}

// GetSignalColor returns color for signal strength/quality (specialized for network)
func (c *ColorPalette) GetSignalColor(quality int) string {
	var level StatusLevel
	switch {
	case quality >= 75:
		level = StatusGood // Excellent signal
	case quality >= 60:
		level = StatusGood // Good signal
	case quality >= 40:
		level = StatusMedium // Fair signal
	case quality >= 20:
		level = StatusPoor // Poor signal
	default:
		level = StatusCritical // Very poor signal
	}
	return c.getColorForLevel(level)
}

// GetVolumeColor returns color for volume levels with mute handling
func (c *ColorPalette) GetVolumeColor(volume int, isMuted bool) string {
	if isMuted {
		return c.Red // Muted
	}
	// Use standard "high is good" logic for volume
	return c.GetStatusColor(float64(volume), false)
}

// getStatusLevel determines the status level based on percentage and context
func (c *ColorPalette) getStatusLevel(percentage float64, reverse bool) StatusLevel {
	if reverse {
		// For cases where high = bad (like CPU/Memory usage)
		if percentage > 85 {
			return StatusCritical // Critical (>85%)
		} else if percentage > 70 {
			return StatusPoor // High (70-85%)
		} else if percentage > 50 {
			return StatusMedium // Medium (50-70%)
		} else {
			return StatusGood // Good (<50%)
		}
	} else {
		// For cases where high = good (like battery/signal)
		if percentage > 70 {
			return StatusGood // Good (>70%)
		} else if percentage > 50 {
			return StatusMedium // Medium (50-70%)
		} else if percentage > 20 {
			return StatusPoor // Low (20-50%)
		} else {
			return StatusCritical // Critical (<20%)
		}
	}
}

// getColorForLevel maps status levels to actual colors
func (c *ColorPalette) getColorForLevel(level StatusLevel) string {
	switch level {
	case StatusGood:
		return c.Green
	case StatusMedium:
		return c.Yellow
	case StatusPoor:
		return c.Peach
	case StatusCritical:
		return c.Red
	default:
		return c.Text // Fallback
	}
}
