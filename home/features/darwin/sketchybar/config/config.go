package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

// GlobalConfig represents the shared configuration for all SketchyBar plugins
type GlobalConfig struct {
	// Catppuccin Macchiato Theme Colors
	Colors ColorScheme `json:"colors"`

	// System Information
	System SystemInfo `json:"system"`

	// Common Settings
	Settings CommonSettings `json:"settings"`

	// Cache Settings
	Cache CacheSettings `json:"cache"`
}

// ColorScheme contains the Catppuccin Macchiato color palette
type ColorScheme struct {
	// Core colors
	Rosewater string `json:"rosewater"`
	Flamingo  string `json:"flamingo"`
	Pink      string `json:"pink"`
	Mauve     string `json:"mauve"`
	Red       string `json:"red"`
	Maroon    string `json:"maroon"`
	Peach     string `json:"peach"`
	Yellow    string `json:"yellow"`
	Green     string `json:"green"`
	Teal      string `json:"teal"`
	Sky       string `json:"sky"`
	Sapphire  string `json:"sapphire"`
	Blue      string `json:"blue"`
	Lavender  string `json:"lavender"`

	// Neutral colors
	Text     string `json:"text"`
	Subtext1 string `json:"subtext1"`
	Subtext0 string `json:"subtext0"`
	Overlay2 string `json:"overlay2"`
	Overlay1 string `json:"overlay1"`
	Overlay0 string `json:"overlay0"`
	Surface2 string `json:"surface2"`
	Surface1 string `json:"surface1"`
	Surface0 string `json:"surface0"`
	Base     string `json:"base"`
	Mantle   string `json:"mantle"`
	Crust    string `json:"crust"`
}

// SystemInfo contains hardware-specific information
type SystemInfo struct {
	IsAppleSilicon bool   `json:"is_apple_silicon"`
	PageSize       int    `json:"page_size"`
	SystemTotalGB  int    `json:"system_total_gb"`
	Architecture   string `json:"architecture"`
}

// BarSettings contains SketchyBar appearance configuration
type BarSettings struct {
	Height             int    `json:"height"`
	NotchDisplayHeight int    `json:"notch_display_height"`
	BlurRadius         int    `json:"blur_radius"`
	Position           string `json:"position"`
	BackgroundColor    string `json:"background_color"`
}

// CommonSettings contains shared display and update settings
type CommonSettings struct {
	UpdateFreq UpdateFrequency `json:"update_freq"`
	Display    DisplaySettings `json:"display"`
	Bar        BarSettings     `json:"bar"`
}

// UpdateFrequency defines how often plugins should update (in seconds)
type UpdateFrequency struct {
	Fast     int `json:"fast"`      // For volume, spotify
	Normal   int `json:"normal"`    // For network, memory
	Slow     int `json:"slow"`      // For battery, weather
	VerySlow int `json:"very_slow"` // For moon phase
}

// DisplaySettings contains common display configuration
type DisplaySettings struct {
	IconFont         string `json:"icon_font"`
	LabelFont        string `json:"label_font"`
	BackgroundHeight int    `json:"background_height"`
	CornerRadius     int    `json:"corner_radius"`
	Padding          int    `json:"padding"`
	FontSize         int    `json:"font_size"`
}

// CacheSettings contains cache configuration
type CacheSettings struct {
	Dir           string `json:"dir"`
	HistoryLength int    `json:"history_length"`
	MaxAge        int    `json:"max_age_seconds"`
}

// Default configuration values
func DefaultConfig() *GlobalConfig {
	homeDir, _ := os.UserHomeDir()

	return &GlobalConfig{
		Colors: ColorScheme{
			// Core colors (Catppuccin Macchiato)
			Rosewater: "0xfff4dbd6",
			Flamingo:  "0xfff0c6c6",
			Pink:      "0xfff5bde6",
			Mauve:     "0xffc6a0f6",
			Red:       "0xffed8796",
			Maroon:    "0xffee99a0",
			Peach:     "0xfff5a97f",
			Yellow:    "0xfff9e2af",
			Green:     "0xffa6da95",
			Teal:      "0xff8bd5ca",
			Sky:       "0xff91d7e3",
			Sapphire:  "0xff7dc4e4",
			Blue:      "0xff8aadf4",
			Lavender:  "0xffb7bdf8",

			// Neutral colors
			Text:     "0xffffffff",
			Subtext1: "0xffb8c0e0",
			Subtext0: "0xffa5adcb",
			Overlay2: "0xff939ab7",
			Overlay1: "0xff8087a2",
			Overlay0: "0xff6e738d",
			Surface2: "0xff5b6078",
			Surface1: "0xff494d64",
			Surface0: "0xff363a4f",
			Base:     "0xff24273a",
			Mantle:   "0xff1e2030",
			Crust:    "0xff181926",
		},
		System: SystemInfo{
			IsAppleSilicon: true,  // Will be detected at runtime
			PageSize:       16384, // Apple Silicon default
			SystemTotalGB:  48,    // Will be detected at runtime
			Architecture:   "arm64",
		},
		Settings: CommonSettings{
			UpdateFreq: UpdateFrequency{
				Fast:     1,
				Normal:   5,
				Slow:     60,
				VerySlow: 3600,
			},
			Display: DisplaySettings{
				IconFont:         "Hack Nerd Font:Bold:17.0",
				LabelFont:        "Hack Nerd Font:Bold:14.0",
				BackgroundHeight: 24,
				CornerRadius:     8,
				Padding:          5,
				FontSize:         14,
			},
			Bar: BarSettings{
				Height:             24,
				NotchDisplayHeight: 42,
				BlurRadius:         30,
				Position:           "top",
				BackgroundColor:    "0xee24273a",
			},
		},
		Cache: CacheSettings{
			Dir:           filepath.Join(homeDir, ".cache", "sketchybar-go"),
			HistoryLength: 8,
			MaxAge:        300, // 5 minutes
		},
	}
}

// LoadConfig loads configuration from file with validation or returns default if not found/invalid
func LoadConfig() (*GlobalConfig, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("could not get home directory: %w", err)
	}

	configPath := filepath.Join(homeDir, ".config", "sketchybar-go", "config.json")

	// Try to load existing config
	if data, err := os.ReadFile(configPath); err == nil {
		var config GlobalConfig
		if err := json.Unmarshal(data, &config); err != nil {
			// JSON parsing error - backup corrupted file and use defaults
			backupPath := configPath + ".backup." + fmt.Sprintf("%d", time.Now().Unix())
			if backupErr := os.WriteFile(backupPath, data, 0644); backupErr == nil {
				fmt.Printf("Warning: Config file has JSON errors, backed up to %s\n", backupPath)
			}
			fmt.Printf("Warning: Using default config due to JSON parsing error: %v\n", err)
		} else {
			// Validate the loaded config
			if validationErr := config.Validate(); validationErr != nil {
				// Validation error - backup invalid file and use defaults
				backupPath := configPath + ".invalid." + fmt.Sprintf("%d", time.Now().Unix())
				if backupErr := os.WriteFile(backupPath, data, 0644); backupErr == nil {
					fmt.Printf("Warning: Config file has validation errors, backed up to %s\n", backupPath)
				}
				fmt.Printf("Warning: Using default config due to validation errors:\n%v\n", validationErr)
			} else {
				// Config is valid!
				return &config, nil
			}
		}
	}

	// Return default config and save it
	config := DefaultConfig()

	// Validate default config (this should never fail, but safety first)
	if err := config.Validate(); err != nil {
		return nil, fmt.Errorf("default config validation failed (this is a bug): %w", err)
	}

	if err := SaveConfig(config); err != nil {
		// Non-fatal error, continue with default config
		fmt.Printf("Warning: Could not save default config: %v\n", err)
	} else {
		fmt.Printf("Created new default config at %s\n", configPath)
	}

	return config, nil
}

// SaveConfig saves configuration to file with validation
func SaveConfig(config *GlobalConfig) error {
	// Validate before saving
	if err := config.Validate(); err != nil {
		return fmt.Errorf("cannot save invalid config: %w", err)
	}

	homeDir, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("could not get home directory: %w", err)
	}

	configDir := filepath.Join(homeDir, ".config", "sketchybar-go")
	if err := os.MkdirAll(configDir, 0755); err != nil {
		return fmt.Errorf("could not create config directory: %w", err)
	}

	configPath := filepath.Join(configDir, "config.json")

	data, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return fmt.Errorf("could not marshal config: %w", err)
	}

	if err := os.WriteFile(configPath, data, 0644); err != nil {
		return fmt.Errorf("could not write config file: %w", err)
	}

	return nil
}

// GetStatusColor returns appropriate color based on percentage and context
func (c *ColorScheme) GetStatusColor(percentage float64, reverse bool) string {
	if reverse {
		// For cases where high = bad (like CPU usage)
		if percentage > 85 {
			return c.Red
		} else if percentage > 70 {
			return c.Peach
		} else if percentage > 50 {
			return c.Yellow
		} else {
			return c.Green
		}
	} else {
		// For cases where high = good (like battery)
		if percentage > 85 {
			return c.Green
		} else if percentage > 50 {
			return c.Yellow
		} else {
			return c.Red
		}
	}
}

// EnsureCacheDir creates the cache directory if it doesn't exist
func (c *CacheSettings) EnsureCacheDir() error {
	return os.MkdirAll(c.Dir, 0755)
}

// GetCacheFile returns the full path to a cache file
func (c *CacheSettings) GetCacheFile(filename string) string {
	return filepath.Join(c.Dir, filename)
}

// IsCacheValid checks if a cache file is still valid based on age
func (c *CacheSettings) IsCacheValid(filename string) bool {
	cachePath := c.GetCacheFile(filename)
	info, err := os.Stat(cachePath)
	if err != nil {
		return false
	}

	age := time.Since(info.ModTime())
	return age.Seconds() < float64(c.MaxAge)
}
