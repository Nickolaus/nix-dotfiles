package main

import (
	"fmt"
	"os"
	"strings"

	"sketchybar-plugins/config"
)

func main() {
	// Load global configuration with enhanced error handling
	cfg, err := config.LoadConfig()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Fatal: Failed to load configuration: %v\n", err)
		os.Exit(1)
	}

	// Validate configuration (additional safety check)
	if validationErr := cfg.Validate(); validationErr != nil {
		fmt.Fprintf(os.Stderr, "Warning: Configuration has validation issues:\n%v\n", validationErr)
		fmt.Fprintf(os.Stderr, "Using possibly invalid configuration - results may be unreliable.\n\n")
	}

	// Check command line arguments
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	command := os.Args[1]

	switch command {
	case "validate":
		validateConfig(cfg)
	case "colors":
		printColors(cfg)
	case "colors-shell":
		printColorsShell(cfg)
	case "bar":
		printBarSettings(cfg)
	case "bar-shell":
		printBarSettingsShell(cfg)
	case "defaults":
		printDefaults(cfg)
	case "defaults-shell":
		printDefaultsShell(cfg)
	case "all-shell":
		printAllShell(cfg)
	case "get":
		if len(os.Args) < 3 {
			fmt.Fprintf(os.Stderr, "Error: 'get' command requires a key\n")
			printUsage()
			os.Exit(1)
		}
		getValue(cfg, os.Args[2])
	case "help", "--help", "-h":
		printUsage()
		os.Exit(0)
	default:
		fmt.Fprintf(os.Stderr, "Error: Unknown command '%s'\n", command)
		printUsage()
		os.Exit(1)
	}
}

// validateConfig validates the current configuration and reports detailed results
func validateConfig(cfg *config.GlobalConfig) {
	fmt.Printf("🔍 Validating SketchyBar configuration...\n\n")

	if err := cfg.Validate(); err != nil {
		if valErrs, ok := err.(config.ValidationErrors); ok {
			fmt.Printf("❌ Configuration validation failed with %d error(s):\n\n", len(valErrs))
			for i, valErr := range valErrs {
				fmt.Printf("  %d. Field: %s\n", i+1, valErr.Field)
				fmt.Printf("     Value: %v\n", valErr.Value)
				fmt.Printf("     Error: %s\n\n", valErr.Message)
			}
			fmt.Printf("💡 Fix these errors to ensure reliable plugin operation.\n")
			fmt.Printf("   Run 'rm ~/.config/sketchybar-go/config.json' to reset to defaults.\n")
			os.Exit(1)
		} else {
			fmt.Printf("❌ Configuration validation failed: %v\n", err)
			os.Exit(1)
		}
	} else {
		fmt.Printf("✅ Configuration is valid!\n\n")

		// Print summary of key settings
		fmt.Printf("📊 Configuration Summary:\n")
		fmt.Printf("  • Bar Position: %s\n", cfg.Settings.Bar.Position)
		fmt.Printf("  • Bar Height: %d px\n", cfg.Settings.Bar.Height)
		fmt.Printf("  • Font Size: %d pt\n", cfg.Settings.Display.FontSize)
		fmt.Printf("  • Update Frequencies: Fast=%ds, Normal=%ds, Slow=%ds, VerySlow=%ds\n",
			cfg.Settings.UpdateFreq.Fast,
			cfg.Settings.UpdateFreq.Normal,
			cfg.Settings.UpdateFreq.Slow,
			cfg.Settings.UpdateFreq.VerySlow)
		fmt.Printf("  • Cache History: %d entries\n", cfg.Cache.HistoryLength)
		fmt.Printf("  • Architecture: %s\n", cfg.System.Architecture)
		fmt.Printf("  • Memory: %d GB\n", cfg.System.SystemTotalGB)
		fmt.Printf("\n🎨 Theme: Catppuccin Macchiato (%d colors defined)\n", 22) // 22 total colors
	}
}

func printUsage() {
	fmt.Println("SketchyBar Config Utility")
	fmt.Println("")
	fmt.Println("Usage:")
	fmt.Println("  config validate      Validate current configuration")
	fmt.Println("  config colors        Print all Catppuccin colors (JSON)")
	fmt.Println("  config colors-shell  Print colors as shell variables")
	fmt.Println("  config bar           Print bar settings (JSON)")
	fmt.Println("  config bar-shell     Print bar settings as shell variables")
	fmt.Println("  config defaults      Print default widget settings (JSON)")
	fmt.Println("  config defaults-shell Print defaults as shell variables")
	fmt.Println("  config all-shell     Print all settings as shell variables")
	fmt.Println("  config get <key>     Get specific value")
	fmt.Println("  config help          Show this help message")
	fmt.Println("")
	fmt.Println("Examples:")
	fmt.Println("  config validate")
	fmt.Println("  config get colors.red")
	fmt.Println("  config get bar.height")
	fmt.Println("  config get defaults.padding")
}

func printColors(cfg *config.GlobalConfig) {
	fmt.Printf(`{
  "rosewater": "%s",
  "flamingo": "%s",
  "pink": "%s",
  "mauve": "%s",
  "red": "%s",
  "maroon": "%s",
  "peach": "%s",
  "yellow": "%s",
  "green": "%s",
  "teal": "%s",
  "sky": "%s",
  "sapphire": "%s",
  "blue": "%s",
  "lavender": "%s",
  "text": "%s",
  "subtext1": "%s",
  "subtext0": "%s",
  "overlay2": "%s",
  "overlay1": "%s",
  "overlay0": "%s",
  "surface2": "%s",
  "surface1": "%s",
  "surface0": "%s",
  "base": "%s",
  "mantle": "%s",
  "crust": "%s"
}`,
		cfg.Colors.Rosewater, cfg.Colors.Flamingo, cfg.Colors.Pink, cfg.Colors.Mauve,
		cfg.Colors.Red, cfg.Colors.Maroon, cfg.Colors.Peach, cfg.Colors.Yellow,
		cfg.Colors.Green, cfg.Colors.Teal, cfg.Colors.Sky, cfg.Colors.Sapphire,
		cfg.Colors.Blue, cfg.Colors.Lavender, cfg.Colors.Text, cfg.Colors.Subtext1,
		cfg.Colors.Subtext0, cfg.Colors.Overlay2, cfg.Colors.Overlay1, cfg.Colors.Overlay0,
		cfg.Colors.Surface2, cfg.Colors.Surface1, cfg.Colors.Surface0, cfg.Colors.Base,
		cfg.Colors.Mantle, cfg.Colors.Crust)
}

func printColorsShell(cfg *config.GlobalConfig) {
	fmt.Printf(`# Catppuccin Macchiato Color Palette (from global config)
ROSEWATER="%s"
FLAMINGO="%s"
PINK="%s"
MAUVE="%s"
RED="%s"
MAROON="%s"
PEACH="%s"
YELLOW="%s"
GREEN="%s"
TEAL="%s"
SKY="%s"
SAPPHIRE="%s"
BLUE="%s"
LAVENDER="%s"
TEXT="%s"
SUBTEXT1="%s"
SUBTEXT0="%s"
OVERLAY2="%s"
OVERLAY1="%s"
OVERLAY0="%s"
SURFACE2="%s"
SURFACE1="%s"
SURFACE0="%s"
BASE="%s"
MANTLE="%s"
CRUST="%s"`,
		cfg.Colors.Rosewater, cfg.Colors.Flamingo, cfg.Colors.Pink, cfg.Colors.Mauve,
		cfg.Colors.Red, cfg.Colors.Maroon, cfg.Colors.Peach, cfg.Colors.Yellow,
		cfg.Colors.Green, cfg.Colors.Teal, cfg.Colors.Sky, cfg.Colors.Sapphire,
		cfg.Colors.Blue, cfg.Colors.Lavender, cfg.Colors.Text, cfg.Colors.Subtext1,
		cfg.Colors.Subtext0, cfg.Colors.Overlay2, cfg.Colors.Overlay1, cfg.Colors.Overlay0,
		cfg.Colors.Surface2, cfg.Colors.Surface1, cfg.Colors.Surface0, cfg.Colors.Base,
		cfg.Colors.Mantle, cfg.Colors.Crust)
}

func printBarSettings(cfg *config.GlobalConfig) {
	fmt.Printf(`{
  "height": %d,
  "notch_display_height": %d,
  "blur_radius": %d,
  "position": "%s",
  "background_color": "%s"
}`,
		cfg.Settings.Bar.Height,
		cfg.Settings.Bar.NotchDisplayHeight,
		cfg.Settings.Bar.BlurRadius,
		cfg.Settings.Bar.Position,
		cfg.Settings.Bar.BackgroundColor)
}

func printBarSettingsShell(cfg *config.GlobalConfig) {
	fmt.Printf(`# Bar Settings (from global config)
BAR_HEIGHT=%d
BAR_NOTCH_HEIGHT=%d
BAR_BLUR_RADIUS=%d
BAR_POSITION="%s"
BAR_BACKGROUND="%s"`,
		cfg.Settings.Bar.Height,
		cfg.Settings.Bar.NotchDisplayHeight,
		cfg.Settings.Bar.BlurRadius,
		cfg.Settings.Bar.Position,
		cfg.Settings.Bar.BackgroundColor)
}

func printDefaults(cfg *config.GlobalConfig) {
	fmt.Printf(`{
  "padding": %d,
  "corner_radius": %d,
  "icon_font": "%s",
  "label_font": "%s",
  "font_size": %d
}`,
		cfg.Settings.Display.Padding,
		cfg.Settings.Display.CornerRadius,
		cfg.Settings.Display.IconFont,
		cfg.Settings.Display.LabelFont,
		cfg.Settings.Display.FontSize)
}

func printDefaultsShell(cfg *config.GlobalConfig) {
	fmt.Printf(`# Default Widget Settings (from global config)
DEFAULT_PADDING=%d
DEFAULT_CORNER_RADIUS=%d
DEFAULT_ICON_FONT="%s"
DEFAULT_LABEL_FONT="%s"
DEFAULT_FONT_SIZE=%d`,
		cfg.Settings.Display.Padding,
		cfg.Settings.Display.CornerRadius,
		cfg.Settings.Display.IconFont,
		cfg.Settings.Display.LabelFont,
		cfg.Settings.Display.FontSize)
}

func printAllShell(cfg *config.GlobalConfig) {
	printColorsShell(cfg)
	fmt.Println("")
	printBarSettingsShell(cfg)
	fmt.Println("")
	printDefaultsShell(cfg)
}

func getValue(cfg *config.GlobalConfig, key string) {
	parts := strings.Split(key, ".")
	if len(parts) != 2 {
		fmt.Fprintf(os.Stderr, "Error: Key must be in format 'section.property'\n")
		os.Exit(1)
	}

	section := parts[0]
	property := parts[1]

	switch section {
	case "colors":
		getColorValue(cfg, property)
	case "bar":
		getBarValue(cfg, property)
	case "defaults":
		getDefaultValue(cfg, property)
	default:
		fmt.Fprintf(os.Stderr, "Error: Unknown section '%s'\n", section)
		os.Exit(1)
	}
}

func getColorValue(cfg *config.GlobalConfig, property string) {
	switch property {
	case "rosewater":
		fmt.Print(cfg.Colors.Rosewater)
	case "flamingo":
		fmt.Print(cfg.Colors.Flamingo)
	case "pink":
		fmt.Print(cfg.Colors.Pink)
	case "mauve":
		fmt.Print(cfg.Colors.Mauve)
	case "red":
		fmt.Print(cfg.Colors.Red)
	case "maroon":
		fmt.Print(cfg.Colors.Maroon)
	case "peach":
		fmt.Print(cfg.Colors.Peach)
	case "yellow":
		fmt.Print(cfg.Colors.Yellow)
	case "green":
		fmt.Print(cfg.Colors.Green)
	case "teal":
		fmt.Print(cfg.Colors.Teal)
	case "sky":
		fmt.Print(cfg.Colors.Sky)
	case "sapphire":
		fmt.Print(cfg.Colors.Sapphire)
	case "blue":
		fmt.Print(cfg.Colors.Blue)
	case "lavender":
		fmt.Print(cfg.Colors.Lavender)
	case "text":
		fmt.Print(cfg.Colors.Text)
	case "subtext1":
		fmt.Print(cfg.Colors.Subtext1)
	case "subtext0":
		fmt.Print(cfg.Colors.Subtext0)
	case "overlay2":
		fmt.Print(cfg.Colors.Overlay2)
	case "overlay1":
		fmt.Print(cfg.Colors.Overlay1)
	case "overlay0":
		fmt.Print(cfg.Colors.Overlay0)
	case "surface2":
		fmt.Print(cfg.Colors.Surface2)
	case "surface1":
		fmt.Print(cfg.Colors.Surface1)
	case "surface0":
		fmt.Print(cfg.Colors.Surface0)
	case "base":
		fmt.Print(cfg.Colors.Base)
	case "mantle":
		fmt.Print(cfg.Colors.Mantle)
	case "crust":
		fmt.Print(cfg.Colors.Crust)
	default:
		fmt.Fprintf(os.Stderr, "Error: Unknown color '%s'\n", property)
		os.Exit(1)
	}
}

func getBarValue(cfg *config.GlobalConfig, property string) {
	switch property {
	case "height":
		fmt.Print(cfg.Settings.Bar.Height)
	case "notch_height":
		fmt.Print(cfg.Settings.Bar.NotchDisplayHeight)
	case "blur_radius":
		fmt.Print(cfg.Settings.Bar.BlurRadius)
	case "position":
		fmt.Print(cfg.Settings.Bar.Position)
	case "background":
		fmt.Print(cfg.Settings.Bar.BackgroundColor)
	default:
		fmt.Fprintf(os.Stderr, "Error: Unknown bar setting '%s'\n", property)
		os.Exit(1)
	}
}

func getDefaultValue(cfg *config.GlobalConfig, property string) {
	switch property {
	case "padding":
		fmt.Print(cfg.Settings.Display.Padding)
	case "corner_radius":
		fmt.Print(cfg.Settings.Display.CornerRadius)
	case "icon_font":
		fmt.Print(cfg.Settings.Display.IconFont)
	case "label_font":
		fmt.Print(cfg.Settings.Display.LabelFont)
	case "font_size":
		fmt.Print(cfg.Settings.Display.FontSize)
	default:
		fmt.Fprintf(os.Stderr, "Error: Unknown default setting '%s'\n", property)
		os.Exit(1)
	}
}
