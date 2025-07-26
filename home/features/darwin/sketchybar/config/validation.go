package config

import (
	"fmt"
	"regexp"
	"strings"
)

// ValidationError represents a config validation error
type ValidationError struct {
	Field   string
	Value   interface{}
	Message string
}

func (e ValidationError) Error() string {
	return fmt.Sprintf("validation error for field '%s': %s (value: %v)", e.Field, e.Message, e.Value)
}

// ValidationErrors represents multiple validation errors
type ValidationErrors []ValidationError

func (e ValidationErrors) Error() string {
	if len(e) == 0 {
		return "no validation errors"
	}

	var messages []string
	for _, err := range e {
		messages = append(messages, err.Error())
	}
	return fmt.Sprintf("config validation failed with %d errors:\n  - %s", len(e), strings.Join(messages, "\n  - "))
}

// Validate performs comprehensive validation of the entire config
func (g *GlobalConfig) Validate() error {
	var errors ValidationErrors

	// Validate Colors
	if err := g.Colors.Validate(); err != nil {
		if valErrs, ok := err.(ValidationErrors); ok {
			errors = append(errors, valErrs...)
		} else {
			errors = append(errors, ValidationError{Field: "colors", Message: err.Error()})
		}
	}

	// Validate System
	if err := g.System.Validate(); err != nil {
		if valErrs, ok := err.(ValidationErrors); ok {
			errors = append(errors, valErrs...)
		} else {
			errors = append(errors, ValidationError{Field: "system", Message: err.Error()})
		}
	}

	// Validate Settings
	if err := g.Settings.Validate(); err != nil {
		if valErrs, ok := err.(ValidationErrors); ok {
			errors = append(errors, valErrs...)
		} else {
			errors = append(errors, ValidationError{Field: "settings", Message: err.Error()})
		}
	}

	// Validate Cache
	if err := g.Cache.Validate(); err != nil {
		if valErrs, ok := err.(ValidationErrors); ok {
			errors = append(errors, valErrs...)
		} else {
			errors = append(errors, ValidationError{Field: "cache", Message: err.Error()})
		}
	}

	if len(errors) > 0 {
		return errors
	}

	return nil
}

// Validate checks all color values are valid hex colors
func (c *ColorScheme) Validate() error {
	var errors ValidationErrors

	colorFields := map[string]string{
		"rosewater": c.Rosewater, "flamingo": c.Flamingo, "pink": c.Pink, "mauve": c.Mauve,
		"red": c.Red, "maroon": c.Maroon, "peach": c.Peach, "yellow": c.Yellow,
		"green": c.Green, "teal": c.Teal, "sky": c.Sky, "sapphire": c.Sapphire,
		"blue": c.Blue, "lavender": c.Lavender, "text": c.Text, "subtext1": c.Subtext1,
		"subtext0": c.Subtext0, "overlay2": c.Overlay2, "overlay1": c.Overlay1, "overlay0": c.Overlay0,
		"surface2": c.Surface2, "surface1": c.Surface1, "surface0": c.Surface0,
		"base": c.Base, "mantle": c.Mantle, "crust": c.Crust,
	}

	for fieldName, colorValue := range colorFields {
		if !isValidHexColor(colorValue) {
			errors = append(errors, ValidationError{
				Field:   fmt.Sprintf("colors.%s", fieldName),
				Value:   colorValue,
				Message: "must be a valid hex color in format 0xFFRRGGBB or 0xAARRGGBB",
			})
		}
	}

	if len(errors) > 0 {
		return errors
	}

	return nil
}

// Validate checks system info values are reasonable
func (s *SystemInfo) Validate() error {
	var errors ValidationErrors

	// Validate PageSize
	if s.PageSize <= 0 {
		errors = append(errors, ValidationError{
			Field:   "system.page_size",
			Value:   s.PageSize,
			Message: "must be greater than 0",
		})
	}

	// Validate SystemTotalGB
	if s.SystemTotalGB <= 0 || s.SystemTotalGB > 1024 {
		errors = append(errors, ValidationError{
			Field:   "system.system_total_gb",
			Value:   s.SystemTotalGB,
			Message: "must be between 1 and 1024 GB",
		})
	}

	// Validate Architecture
	validArchs := []string{"arm64", "amd64", "x86_64"}
	if !contains(validArchs, s.Architecture) {
		errors = append(errors, ValidationError{
			Field:   "system.architecture",
			Value:   s.Architecture,
			Message: "must be one of: arm64, amd64, x86_64",
		})
	}

	if len(errors) > 0 {
		return errors
	}

	return nil
}

// Validate checks bar settings are reasonable
func (b *BarSettings) Validate() error {
	var errors ValidationErrors

	// Validate Height
	if b.Height < 10 || b.Height > 100 {
		errors = append(errors, ValidationError{
			Field:   "settings.bar.height",
			Value:   b.Height,
			Message: "must be between 10 and 100 pixels",
		})
	}

	// Validate NotchDisplayHeight
	if b.NotchDisplayHeight < 20 || b.NotchDisplayHeight > 200 {
		errors = append(errors, ValidationError{
			Field:   "settings.bar.notch_display_height",
			Value:   b.NotchDisplayHeight,
			Message: "must be between 20 and 200 pixels",
		})
	}

	// Validate BlurRadius
	if b.BlurRadius < 0 || b.BlurRadius > 100 {
		errors = append(errors, ValidationError{
			Field:   "settings.bar.blur_radius",
			Value:   b.BlurRadius,
			Message: "must be between 0 and 100",
		})
	}

	// Validate Position
	validPositions := []string{"top", "bottom"}
	if !contains(validPositions, b.Position) {
		errors = append(errors, ValidationError{
			Field:   "settings.bar.position",
			Value:   b.Position,
			Message: "must be either 'top' or 'bottom'",
		})
	}

	// Validate BackgroundColor
	if !isValidHexColor(b.BackgroundColor) {
		errors = append(errors, ValidationError{
			Field:   "settings.bar.background_color",
			Value:   b.BackgroundColor,
			Message: "must be a valid hex color in format 0xFFRRGGBB or 0xAARRGGBB",
		})
	}

	if len(errors) > 0 {
		return errors
	}

	return nil
}

// Validate checks all common settings
func (c *CommonSettings) Validate() error {
	var errors ValidationErrors

	// Validate UpdateFreq
	if err := c.UpdateFreq.Validate(); err != nil {
		if valErrs, ok := err.(ValidationErrors); ok {
			errors = append(errors, valErrs...)
		} else {
			errors = append(errors, ValidationError{Field: "settings.update_freq", Message: err.Error()})
		}
	}

	// Validate Display
	if err := c.Display.Validate(); err != nil {
		if valErrs, ok := err.(ValidationErrors); ok {
			errors = append(errors, valErrs...)
		} else {
			errors = append(errors, ValidationError{Field: "settings.display", Message: err.Error()})
		}
	}

	// Validate Bar
	if err := c.Bar.Validate(); err != nil {
		if valErrs, ok := err.(ValidationErrors); ok {
			errors = append(errors, valErrs...)
		} else {
			errors = append(errors, ValidationError{Field: "settings.bar", Message: err.Error()})
		}
	}

	if len(errors) > 0 {
		return errors
	}

	return nil
}

// Validate checks update frequencies are reasonable
func (u *UpdateFrequency) Validate() error {
	var errors ValidationErrors

	// Validate Fast
	if u.Fast < 1 || u.Fast > 60 {
		errors = append(errors, ValidationError{
			Field:   "settings.update_freq.fast",
			Value:   u.Fast,
			Message: "must be between 1 and 60 seconds",
		})
	}

	// Validate Normal
	if u.Normal < 1 || u.Normal > 300 {
		errors = append(errors, ValidationError{
			Field:   "settings.update_freq.normal",
			Value:   u.Normal,
			Message: "must be between 1 and 300 seconds",
		})
	}

	// Validate Slow
	if u.Slow < 10 || u.Slow > 3600 {
		errors = append(errors, ValidationError{
			Field:   "settings.update_freq.slow",
			Value:   u.Slow,
			Message: "must be between 10 and 3600 seconds",
		})
	}

	// Validate VerySlow
	if u.VerySlow < 60 || u.VerySlow > 86400 {
		errors = append(errors, ValidationError{
			Field:   "settings.update_freq.very_slow",
			Value:   u.VerySlow,
			Message: "must be between 60 and 86400 seconds (1 day)",
		})
	}

	// Logical validation: fast <= normal <= slow <= very_slow
	if u.Fast > u.Normal {
		errors = append(errors, ValidationError{
			Field:   "settings.update_freq.fast",
			Value:   u.Fast,
			Message: "fast frequency must be <= normal frequency",
		})
	}

	if u.Normal > u.Slow {
		errors = append(errors, ValidationError{
			Field:   "settings.update_freq.normal",
			Value:   u.Normal,
			Message: "normal frequency must be <= slow frequency",
		})
	}

	if u.Slow > u.VerySlow {
		errors = append(errors, ValidationError{
			Field:   "settings.update_freq.slow",
			Value:   u.Slow,
			Message: "slow frequency must be <= very_slow frequency",
		})
	}

	if len(errors) > 0 {
		return errors
	}

	return nil
}

// Validate checks display settings are reasonable
func (d *DisplaySettings) Validate() error {
	var errors ValidationErrors

	// Validate fonts are not empty
	if strings.TrimSpace(d.IconFont) == "" {
		errors = append(errors, ValidationError{
			Field:   "settings.display.icon_font",
			Value:   d.IconFont,
			Message: "cannot be empty",
		})
	}

	if strings.TrimSpace(d.LabelFont) == "" {
		errors = append(errors, ValidationError{
			Field:   "settings.display.label_font",
			Value:   d.LabelFont,
			Message: "cannot be empty",
		})
	}

	// Validate BackgroundHeight
	if d.BackgroundHeight < 10 || d.BackgroundHeight > 100 {
		errors = append(errors, ValidationError{
			Field:   "settings.display.background_height",
			Value:   d.BackgroundHeight,
			Message: "must be between 10 and 100 pixels",
		})
	}

	// Validate CornerRadius
	if d.CornerRadius < 0 || d.CornerRadius > 20 {
		errors = append(errors, ValidationError{
			Field:   "settings.display.corner_radius",
			Value:   d.CornerRadius,
			Message: "must be between 0 and 20 pixels",
		})
	}

	// Validate Padding
	if d.Padding < 0 || d.Padding > 20 {
		errors = append(errors, ValidationError{
			Field:   "settings.display.padding",
			Value:   d.Padding,
			Message: "must be between 0 and 20 pixels",
		})
	}

	// Validate FontSize
	if d.FontSize < 8 || d.FontSize > 48 {
		errors = append(errors, ValidationError{
			Field:   "settings.display.font_size",
			Value:   d.FontSize,
			Message: "must be between 8 and 48 points",
		})
	}

	if len(errors) > 0 {
		return errors
	}

	return nil
}

// Validate checks cache settings are reasonable
func (c *CacheSettings) Validate() error {
	var errors ValidationErrors

	// Validate Dir is not empty
	if strings.TrimSpace(c.Dir) == "" {
		errors = append(errors, ValidationError{
			Field:   "cache.dir",
			Value:   c.Dir,
			Message: "cannot be empty",
		})
	}

	// Validate HistoryLength
	if c.HistoryLength < 1 || c.HistoryLength > 1000 {
		errors = append(errors, ValidationError{
			Field:   "cache.history_length",
			Value:   c.HistoryLength,
			Message: "must be between 1 and 1000",
		})
	}

	// Validate MaxAge
	if c.MaxAge < 10 || c.MaxAge > 86400 {
		errors = append(errors, ValidationError{
			Field:   "cache.max_age_seconds",
			Value:   c.MaxAge,
			Message: "must be between 10 and 86400 seconds (1 day)",
		})
	}

	if len(errors) > 0 {
		return errors
	}

	return nil
}

// Helper functions for validation

// isValidHexColor checks if a string is a valid hex color
func isValidHexColor(color string) bool {
	// Support 0xRRGGBB (6 hex digits) and 0xAARRGGBB (8 hex digits) formats
	hexColorRegex := regexp.MustCompile(`^0x[0-9a-fA-F]{6}$|^0x[0-9a-fA-F]{8}$`)
	return hexColorRegex.MatchString(color)
}

// contains checks if a slice contains a string
func contains(slice []string, item string) bool {
	for _, s := range slice {
		if s == item {
			return true
		}
	}
	return false
}
 