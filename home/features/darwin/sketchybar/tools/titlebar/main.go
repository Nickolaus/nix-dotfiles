package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"sketchybar-plugins/config"
	"sketchybar-plugins/utils"

	"github.com/fatih/color"
)

// AppInfo represents information about an application
type AppInfo struct {
	Name         string
	Path         string
	Description  string
	Instructions []string
	ConfigFiles  []ConfigTemplate
}

// ConfigTemplate represents a configuration file template
type ConfigTemplate struct {
	Name     string
	Path     string
	Content  string
	Required bool
}

func main() {
	if len(os.Args) > 1 && (os.Args[1] == "--help" || os.Args[1] == "-h") {
		showHelp()
		return
	}

	// Load global configuration
	cfg, err := config.LoadConfig()
	if err != nil {
		fmt.Printf("Warning: Could not load global config: %v\n", err)
		cfg = config.DefaultConfig()
	}

	// Setup colors using global config
	setupColors(cfg)

	fmt.Printf("%s🎨 SketchyBar Titlebar Integration Setup%s\n",
		color.New(color.FgBlue).SprintFunc()(""),
		color.New(color.Reset).SprintFunc()(""))
	fmt.Printf("%sSetting up seamless app integration...%s\n\n",
		color.New(color.FgYellow).SprintFunc()(""),
		color.New(color.Reset).SprintFunc()(""))

	// Define supported applications
	apps := getSupportedApps()

	// Check command line arguments for specific app
	if len(os.Args) > 1 {
		appName := strings.ToLower(os.Args[1])
		if app, exists := apps[appName]; exists {
			configureApp(app, cfg)
			return
		} else {
			fmt.Printf("%s❌ Unknown application: %s%s\n",
				color.New(color.FgRed).SprintFunc()(""),
				appName,
				color.New(color.Reset).SprintFunc()(""))
			fmt.Println("Use --help to see supported applications")
			os.Exit(1)
		}
	}

	// Interactive mode - show all applications
	showApplicationMenu(apps, cfg)
}

func setupColors(cfg *config.GlobalConfig) {
	// Set up color output based on global config
	color.NoColor = false
}

func getSupportedApps() map[string]AppInfo {
	return map[string]AppInfo{
		"vscode": {
			Name:        "Visual Studio Code",
			Path:        "/Applications/Visual Studio Code.app",
			Description: "Microsoft Visual Studio Code editor",
			Instructions: []string{
				"Install 'Apc Customize UI++' extension",
				"Add configuration to settings.json",
				"Run Command Palette > 'Enable Apc extension'",
				"Restart application",
			},
			ConfigFiles: []ConfigTemplate{
				{
					Name:     "settings.json",
					Path:     "~/Library/Application Support/Code/User/settings.json",
					Content:  getVSCodeConfig(),
					Required: true,
				},
			},
		},
		"vscodium": {
			Name:        "VSCodium",
			Path:        "/Applications/VSCodium.app",
			Description: "Open source VS Code alternative",
			Instructions: []string{
				"Install 'Apc Customize UI++' extension",
				"Add configuration to settings.json",
				"Run Command Palette > 'Enable Apc extension'",
				"Restart application",
			},
			ConfigFiles: []ConfigTemplate{
				{
					Name:     "settings.json",
					Path:     "~/Library/Application Support/VSCodium/User/settings.json",
					Content:  getVSCodeConfig(),
					Required: true,
				},
			},
		},
		"cursor": {
			Name:        "Cursor",
			Path:        "/Applications/Cursor.app",
			Description: "AI-powered code editor",
			Instructions: []string{
				"Install 'Apc Customize UI++' extension",
				"Add configuration to settings.json",
				"Run Command Palette > 'Enable Apc extension'",
				"Restart application",
			},
			ConfigFiles: []ConfigTemplate{
				{
					Name:     "settings.json",
					Path:     "~/Library/Application Support/Cursor/User/settings.json",
					Content:  getVSCodeConfig(),
					Required: true,
				},
			},
		},
		"firefox": {
			Name:        "Firefox",
			Path:        "/Applications/Firefox.app",
			Description: "Mozilla Firefox browser",
			Instructions: []string{
				"Enable userChrome.css in about:config",
				"Set toolkit.legacyUserProfileCustomizations.stylesheets = true",
				"Create userChrome.css in profile chrome folder",
				"Restart Firefox",
			},
			ConfigFiles: []ConfigTemplate{
				{
					Name:     "userChrome.css",
					Path:     "~/Library/Application Support/Firefox/Profiles/*/chrome/userChrome.css",
					Content:  getFirefoxConfig(),
					Required: true,
				},
			},
		},
		"iterm2": {
			Name:        "iTerm2",
			Path:        "/Applications/iTerm.app",
			Description: "Advanced terminal emulator",
			Instructions: []string{
				"Open Preferences (⌘+,)",
				"Go to Profiles > Window",
				"Set Style to 'No Title Bar'",
				"Optionally adjust 'Screen' settings",
			},
		},
		"terminal": {
			Name:        "Terminal",
			Path:        "/System/Applications/Utilities/Terminal.app",
			Description: "macOS built-in terminal",
			Instructions: []string{
				"Open Preferences (⌘+,)",
				"Go to Profiles > Window",
				"Uncheck 'Title Bar'",
				"Adjust window settings as needed",
			},
		},
	}
}

func showApplicationMenu(apps map[string]AppInfo, cfg *config.GlobalConfig) {
	fmt.Printf("%s📋 Supported Applications:%s\n\n",
		color.New(color.FgYellow).SprintFunc()(""),
		color.New(color.Reset).SprintFunc()(""))

	installedApps := []string{}
	notInstalledApps := []string{}

	for key, app := range apps {
		if checkAppInstalled(app.Path) {
			installedApps = append(installedApps, key)
			fmt.Printf("%s✅ %s%s - %s\n",
				color.New(color.FgGreen).SprintFunc()(""),
				app.Name,
				color.New(color.Reset).SprintFunc()(""),
				app.Description)
		} else {
			notInstalledApps = append(notInstalledApps, key)
			fmt.Printf("%s❌ %s%s - %s (not installed)\n",
				color.New(color.FgRed).SprintFunc()(""),
				app.Name,
				color.New(color.Reset).SprintFunc()(""),
				app.Description)
		}
	}

	if len(installedApps) > 0 {
		fmt.Printf("\n%s🔧 To configure a specific app, run:%s\n",
			color.New(color.FgBlue).SprintFunc()(""),
			color.New(color.Reset).SprintFunc()(""))
		fmt.Printf("   titlebar <app_name>\n\n")

		fmt.Printf("%sAvailable apps:%s %s\n",
			color.New(color.FgYellow).SprintFunc()(""),
			color.New(color.Reset).SprintFunc()(""),
			strings.Join(installedApps, ", "))
	}

	// Show general tips
	showGeneralTips()
}

func configureApp(app AppInfo, cfg *config.GlobalConfig) {
	fmt.Printf("%s🔧 Configuring %s...%s\n\n",
		color.New(color.FgBlue).SprintFunc()(""),
		app.Name,
		color.New(color.Reset).SprintFunc()(""))

	if !checkAppInstalled(app.Path) {
		fmt.Printf("%s❌ %s not found at %s%s\n",
			color.New(color.FgRed).SprintFunc()(""),
			app.Name, app.Path,
			color.New(color.Reset).SprintFunc()(""))
		return
	}

	// Show instructions
	fmt.Printf("%s📋 Configuration Instructions:%s\n",
		color.New(color.FgYellow).SprintFunc()(""),
		color.New(color.Reset).SprintFunc()(""))

	for i, instruction := range app.Instructions {
		fmt.Printf("   %d. %s\n", i+1, instruction)
	}

	// Handle config files
	if len(app.ConfigFiles) > 0 {
		fmt.Printf("\n%s📝 Configuration Files:%s\n",
			color.New(color.FgBlue).SprintFunc()(""),
			color.New(color.Reset).SprintFunc()(""))

		for _, configFile := range app.ConfigFiles {
			handleConfigFile(configFile, cfg)
		}
	}

	// Attempt automatic configuration for supported apps
	attemptAutomaticConfig(app)

	fmt.Printf("\n%s✅ %s configuration complete!%s\n",
		color.New(color.FgGreen).SprintFunc()(""),
		app.Name,
		color.New(color.Reset).SprintFunc()(""))
}

func checkAppInstalled(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func handleConfigFile(template ConfigTemplate, cfg *config.GlobalConfig) {
	fmt.Printf("\n%s📄 %s:%s\n",
		color.New(color.FgCyan).SprintFunc()(""),
		template.Name,
		color.New(color.Reset).SprintFunc()(""))

	// Expand tilde in path
	expandedPath := utils.ExpandPath(template.Path)

	// Handle wildcard paths (like Firefox profiles)
	if strings.Contains(expandedPath, "*") {
		matches, err := filepath.Glob(expandedPath)
		if err != nil || len(matches) == 0 {
			fmt.Printf("   %sPath: %s (create this path manually)%s\n",
				color.New(color.FgYellow).SprintFunc()(""),
				template.Path,
				color.New(color.Reset).SprintFunc()(""))
		} else {
			fmt.Printf("   %sPath: %s%s\n",
				color.New(color.FgGreen).SprintFunc()(""),
				matches[0],
				color.New(color.Reset).SprintFunc()(""))
		}
	} else {
		fmt.Printf("   %sPath: %s%s\n",
			color.New(color.FgGreen).SprintFunc()(""),
			expandedPath,
			color.New(color.Reset).SprintFunc()(""))
	}

	if template.Content != "" {
		fmt.Printf("   %sContent preview:%s\n",
			color.New(color.FgBlue).SprintFunc()(""),
			color.New(color.Reset).SprintFunc()(""))
		lines := strings.Split(template.Content, "\n")
		for _, line := range lines[:min(5, len(lines))] {
			fmt.Printf("     %s\n", line)
		}
		if len(lines) > 5 {
			fmt.Printf("     ... (%d more lines)\n", len(lines)-5)
		}
	}
}

func attemptAutomaticConfig(app AppInfo) {
	// Only attempt automatic configuration for apps that support it
	switch strings.ToLower(app.Name) {
	case "cursor", "vscodium":
		if err := ensureAppOwnership(app.Path); err != nil {
			fmt.Printf("%s⚠️  Could not ensure app ownership: %v%s\n",
				color.New(color.FgYellow).SprintFunc()(""),
				err,
				color.New(color.Reset).SprintFunc()(""))
		} else {
			fmt.Printf("%s✅ App ownership configured%s\n",
				color.New(color.FgGreen).SprintFunc()(""),
				color.New(color.Reset).SprintFunc()(""))
		}
	}
}

func ensureAppOwnership(appPath string) error {
	currentUser := os.Getenv("USER")
	if currentUser == "" {
		return fmt.Errorf("could not determine current user")
	}

	cmd := exec.Command("sudo", "chown", "-R", currentUser, appPath)
	return cmd.Run()
}

func showGeneralTips() {
	fmt.Printf("\n%s💡 General Tips:%s\n",
		color.New(color.FgYellow).SprintFunc()(""),
		color.New(color.Reset).SprintFunc()(""))

	tips := []string{
		"Use ⌘+H to hide apps instead of minimize for cleaner workspace",
		"Consider using AeroSpace workspaces to organize apps",
		"Some apps may require restart after titlebar changes",
		"Test changes gradually - you can always revert",
		"Check SketchyBar community discussions for more tips",
	}

	for _, tip := range tips {
		fmt.Printf("• %s\n", tip)
	}
}

func showHelp() {
	fmt.Printf("%s🎨 SketchyBar Titlebar Integration Setup%s\n\n",
		color.New(color.FgBlue).SprintFunc()(""),
		color.New(color.Reset).SprintFunc()(""))

	fmt.Printf("Usage:\n")
	fmt.Printf("  titlebar [app_name]  Configure specific application\n")
	fmt.Printf("  titlebar --help      Show this help message\n\n")

	fmt.Printf("Supported applications:\n")
	fmt.Printf("  vscode     Visual Studio Code\n")
	fmt.Printf("  vscodium   VSCodium (open source VS Code)\n")
	fmt.Printf("  cursor     Cursor AI editor\n")
	fmt.Printf("  firefox    Mozilla Firefox\n")
	fmt.Printf("  iterm2     iTerm2 terminal\n")
	fmt.Printf("  terminal   macOS Terminal\n\n")

	fmt.Printf("Examples:\n")
	fmt.Printf("  titlebar vscode    Configure VS Code\n")
	fmt.Printf("  titlebar firefox   Configure Firefox\n")
	fmt.Printf("  titlebar           Interactive mode (show all apps)\n")
}

func getVSCodeConfig() string {
	return `{
  // SketchyBar Integration Settings
  "window.titleBarStyle": "native",
  "window.menuBarVisibility": "toggle",
  "apc.electron": {
    "frame": false,
    "titleBarStyle": "hiddenInset"
  },
  "apc.header": {
    "height": 36
  },
  "apc.sidebar.titlebar": {
    "height": 36
  },
  // Integration with Catppuccin theme
  "workbench.colorTheme": "Catppuccin Macchiato",
  "editor.fontFamily": "JetBrainsMono Nerd Font, Menlo, Monaco, 'Courier New', monospace",
  "terminal.integrated.fontFamily": "JetBrainsMono Nerd Font"
}`
}

func getFirefoxConfig() string {
	return `/* SketchyBar Integration CSS for Firefox */
/* Place this file in: ~/Library/Application Support/Firefox/Profiles/[profile]/chrome/userChrome.css */

/* Hide titlebar buttons */
.titlebar-buttonbox-container {
  display: none !important;
}

/* Optional: Reduce titlebar height */
#titlebar {
  height: 32px !important;
}

/* Optional: Hide menu bar (use Alt to show temporarily) */
#toolbar-menubar {
  height: 0 !important;
  margin-bottom: 0 !important;
}

/* Catppuccin Macchiato theme integration */
:root {
  --catppuccin-base: #24273a;
  --catppuccin-surface0: #363a4f;
  --catppuccin-text: #cad3f5;
}

/* Apply theme to browser chrome */
#nav-bar {
  background-color: var(--catppuccin-surface0) !important;
}`
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
