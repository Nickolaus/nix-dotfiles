package main

import (
	"fmt"
	"os"
	"os/exec"
	"sort"
	"strconv"
	"strings"

	"sketchybar-plugins/utils"
)

// Monitor represents an AeroSpace monitor
type Monitor struct {
	ID   int    `json:"monitor-id"`
	Name string `json:"monitor-name"`
}

// Workspace represents an AeroSpace workspace
type Workspace struct {
	Name        string   `json:"workspace"`
	IsVisible   bool     `json:"is-visible"`
	Monitor     string   `json:"monitor"`
	MonitorID   int      `json:"monitor-id"`
	AppNames    []string `json:"apps"`
	WindowCount int      `json:"window-count"`
}

// WorkspaceOverview holds the complete state
type WorkspaceOverview struct {
	Monitors          []Monitor
	Workspaces        []Workspace
	VisibleWorkspaces []string
	FocusedWorkspace  string
}

func main() {
	// Get the focused workspace from environment (set by AeroSpace)
	focusedWorkspace := os.Getenv("FOCUSED")
	if focusedWorkspace == "" {
		// Fallback: get current workspace directly
		if output, err := exec.Command("/run/current-system/sw/bin/aerospace", "list-workspaces", "--focused").Output(); err == nil {
			focusedWorkspace = strings.TrimSpace(string(output))
		}
	}

	// Simple approach like front_app: just update what's needed
	sender := os.Getenv("SENDER")

	// Debug logging (show all calls to debug the issue)
	fmt.Printf("Plugin called - SENDER: '%s', FOCUSED env: '%s', detected focused: '%s'\n", sender, os.Getenv("FOCUSED"), focusedWorkspace)

	overview, err := getWorkspaceOverview(focusedWorkspace)
	if err != nil {
		fmt.Printf("Error getting workspace overview: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Updating SketchyBar - focused: %s, visible: %v\n", overview.FocusedWorkspace, overview.VisibleWorkspaces)
	updateSketchyBar(overview)
}

func getWorkspaceOverview(focusedWorkspace string) (*WorkspaceOverview, error) {
	overview := &WorkspaceOverview{
		FocusedWorkspace: focusedWorkspace,
	}

	// Get monitors
	monitors, err := getMonitors()
	if err != nil {
		return nil, fmt.Errorf("failed to get monitors: %w", err)
	}
	overview.Monitors = monitors

	// Get all workspaces with their monitor assignments
	workspaces, err := getWorkspaces()
	if err != nil {
		return nil, fmt.Errorf("failed to get workspaces: %w", err)
	}
	overview.Workspaces = workspaces

	// Get visible workspaces
	visibleWorkspaces, err := getVisibleWorkspaces()
	if err != nil {
		return nil, fmt.Errorf("failed to get visible workspaces: %w", err)
	}
	overview.VisibleWorkspaces = visibleWorkspaces

	return overview, nil
}

func getMonitors() ([]Monitor, error) {
	cmd := exec.Command("/run/current-system/sw/bin/aerospace", "list-monitors")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("aerospace list-monitors failed: %w", err)
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	var monitors []Monitor

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}

		// Parse format: "1 | Built-in Retina Display"
		parts := strings.Split(line, " | ")
		if len(parts) != 2 {
			continue
		}

		id, err := strconv.Atoi(strings.TrimSpace(parts[0]))
		if err != nil {
			continue
		}

		monitors = append(monitors, Monitor{
			ID:   id,
			Name: strings.TrimSpace(parts[1]),
		})
	}

	// Sort monitors by ID for consistent ordering
	sort.Slice(monitors, func(i, j int) bool {
		return monitors[i].ID < monitors[j].ID
	})

	return monitors, nil
}

func getWorkspaces() ([]Workspace, error) {
	// Get all workspaces
	cmd := exec.Command("/run/current-system/sw/bin/aerospace", "list-workspaces", "--all")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("aerospace list-workspaces failed: %w", err)
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	var workspaces []Workspace

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}

		// Get monitor for this workspace
		monitor, err := getWorkspaceMonitor(line)
		if err != nil {
			monitor = "unassigned" // fallback
		}

		// Get applications in this workspace (like native AeroSpace interface)
		appNames, windowCount := getWorkspaceApps(line)

		workspaces = append(workspaces, Workspace{
			Name:        line,
			Monitor:     monitor,
			AppNames:    appNames,
			WindowCount: windowCount,
		})
	}

	// Sort workspaces numerically where possible, then alphabetically
	sort.Slice(workspaces, func(i, j int) bool {
		// Try to parse as numbers first
		if numI, errI := strconv.Atoi(workspaces[i].Name); errI == nil {
			if numJ, errJ := strconv.Atoi(workspaces[j].Name); errJ == nil {
				return numI < numJ
			}
		}
		// Fall back to string comparison
		return workspaces[i].Name < workspaces[j].Name
	})

	return workspaces, nil
}

func getWorkspaceMonitor(workspace string) (string, error) {
	// Get workspace assignments exactly like AeroSpace native interface
	cmd := exec.Command("/run/current-system/sw/bin/aerospace", "list-workspaces", "--monitor", "all", "--format", "%{workspace}|%{monitor-name}|%{monitor-id}")
	output, err := cmd.Output()
	if err != nil {
		// Fallback: check if workspace is visible on any monitor
		for _, monitor := range []string{"1", "2", "3"} {
			visCmd := exec.Command("/run/current-system/sw/bin/aerospace", "list-workspaces", "--monitor", monitor, "--visible")
			if visOutput, visErr := visCmd.Output(); visErr == nil {
				visibleWorkspaces := strings.Split(strings.TrimSpace(string(visOutput)), "\n")
				for _, ws := range visibleWorkspaces {
					if strings.TrimSpace(ws) == workspace {
						// Get monitor name for this ID
						monCmd := exec.Command("/run/current-system/sw/bin/aerospace", "list-monitors")
						if monOutput, monErr := monCmd.Output(); monErr == nil {
							monLines := strings.Split(strings.TrimSpace(string(monOutput)), "\n")
							for _, monLine := range monLines {
								if strings.HasPrefix(monLine, monitor+" | ") {
									return strings.TrimSpace(strings.Split(monLine, " | ")[1]), nil
								}
							}
						}
					}
				}
			}
		}
		return "", fmt.Errorf("could not determine monitor for workspace %s", workspace)
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	for _, line := range lines {
		parts := strings.Split(line, "|")
		if len(parts) >= 2 && strings.TrimSpace(parts[0]) == workspace {
			return strings.TrimSpace(parts[1]), nil
		}
	}

	return "", fmt.Errorf("workspace %s not found in monitor assignments", workspace)
}

func getVisibleWorkspaces() ([]string, error) {
	// Get visible workspaces across all monitors
	cmd := exec.Command("/run/current-system/sw/bin/aerospace", "list-workspaces", "--monitor", "all", "--visible")
	output, err := cmd.Output()
	if err != nil {
		// Fallback: try to get focused workspace only
		focusedCmd := exec.Command("/run/current-system/sw/bin/aerospace", "list-workspaces", "--focused")
		if focusedOutput, focusedErr := focusedCmd.Output(); focusedErr == nil {
			focused := strings.TrimSpace(string(focusedOutput))
			if focused != "" {
				return []string{focused}, nil
			}
		}
		return []string{}, nil // Return empty if all fails, don't error
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	var visible []string
	for _, line := range lines {
		if trimmed := strings.TrimSpace(line); trimmed != "" {
			visible = append(visible, trimmed)
		}
	}

	return visible, nil
}

func getWorkspaceApps(workspace string) ([]string, int) {
	// Get windows in this workspace like native AeroSpace interface
	cmd := exec.Command("/run/current-system/sw/bin/aerospace", "list-windows", "--workspace", workspace, "--format", "%{app-name}")
	output, err := cmd.Output()
	if err != nil {
		return []string{}, 0
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	appMap := make(map[string]bool)
	windowCount := 0

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line != "" {
			appMap[line] = true
			windowCount++
		}
	}

	// Convert map to slice for consistent ordering
	var appNames []string
	for app := range appMap {
		appNames = append(appNames, app)
	}
	sort.Strings(appNames)

	return appNames, windowCount
}

func updateSketchyBar(overview *WorkspaceOverview) {
	// Get color palette - consistent with all other plugins
	colors := utils.NewCatppuccinMacchiato()

	// Update existing items instead of rebuilding everything (prevents flickering)
	updateExistingItems(overview, colors)
}

func getShortMonitorName(fullName string) string {
	// Common monitor name mappings for cleaner display
	switch {
	case strings.Contains(fullName, "Built-in"):
		return "💻"
	case strings.Contains(fullName, "LG HDR 4K"):
		return "🖥️"
	case strings.Contains(fullName, "Studio Display"):
		return "🖥️"
	case strings.Contains(fullName, "Pro Display"):
		return "⚡"
	case strings.Contains(fullName, "Thunderbolt"):
		return "⚡"
	default:
		// Extract model name or use first word
		parts := strings.Fields(fullName)
		if len(parts) > 0 {
			return parts[0]
		}
		return "Monitor"
	}
}

func contains(slice []string, item string) bool {
	for _, s := range slice {
		if s == item {
			return true
		}
	}
	return false
}

// updateExistingLabelsOnly updates only the labels of existing items (no structure changes)
// This is much faster and prevents flickering for front_app_switched events
func updateExistingLabelsOnly(focusedWorkspace string) {
	overview, err := getWorkspaceOverview(focusedWorkspace)
	if err != nil {
		fmt.Printf("Error getting workspace overview for label update: %v\n", err)
		return
	}

	// Update labels for each monitor without rebuilding structure
	for _, monitor := range overview.Monitors {
		// Find the active workspace for this monitor (same logic as updateSketchyBar)
		var activeWorkspace *Workspace
		for _, ws := range overview.Workspaces {
			if ws.Monitor == monitor.Name && contains(overview.VisibleWorkspaces, ws.Name) {
				activeWorkspace = &ws
				break
			}
		}

		// If no visible workspace found, find any workspace assigned to this monitor
		if activeWorkspace == nil {
			for _, ws := range overview.Workspaces {
				if ws.Monitor == monitor.Name {
					activeWorkspace = &ws
					break
				}
			}
		}

		// Skip monitors with no workspaces
		if activeWorkspace == nil {
			continue
		}

		itemName := fmt.Sprintf("aerospace.display.%d", monitor.ID)
		monitorIcon := getShortMonitorName(monitor.Name)

		// Use same label formatting logic as updateSketchyBar
		var displayLabel string
		if len(activeWorkspace.AppNames) > 0 {
			// Show active workspace with apps: "💻 2 - Chrome, Slack"
			apps := activeWorkspace.AppNames
			if len(apps) > 2 {
				displayLabel = fmt.Sprintf("%s %s - %s, %s (+%d)",
					monitorIcon, activeWorkspace.Name, apps[0], apps[1], len(apps)-2)
			} else {
				displayLabel = fmt.Sprintf("%s %s - %s",
					monitorIcon, activeWorkspace.Name, strings.Join(apps, ", "))
			}
		} else {
			// Show workspace with monitor name: "🖥️ 6 - Empty"
			displayLabel = fmt.Sprintf("%s %s - Empty", monitorIcon, activeWorkspace.Name)
		}

		// Update only the label, not the entire item structure
		exec.Command("sketchybar",
			"--set", itemName,
			"label="+displayLabel,
		).Run()
	}

	fmt.Printf("Lightweight label update completed\n")
}

// updateExistingItems updates labels and colors of existing items (no structure rebuild)
func updateExistingItems(overview *WorkspaceOverview, colors *utils.ColorPalette) {
	// Track which items we're updating
	for _, monitor := range overview.Monitors {
		// Find the active workspace for this monitor
		var activeWorkspace *Workspace
		for _, ws := range overview.Workspaces {
			if ws.Monitor == monitor.Name && contains(overview.VisibleWorkspaces, ws.Name) {
				activeWorkspace = &ws
				break
			}
		}

		// If no visible workspace found, find any workspace assigned to this monitor
		if activeWorkspace == nil {
			for _, ws := range overview.Workspaces {
				if ws.Monitor == monitor.Name {
					activeWorkspace = &ws
					break
				}
			}
		}

		// Skip monitors with no workspaces
		if activeWorkspace == nil {
			continue
		}

		itemName := fmt.Sprintf("aerospace.display.%d", monitor.ID)
		monitorIcon := getShortMonitorName(monitor.Name)

		// Create the display label (same as before)
		var displayLabel string
		if len(activeWorkspace.AppNames) > 0 {
			apps := activeWorkspace.AppNames
			if len(apps) > 2 {
				displayLabel = fmt.Sprintf("%s %s - %s, %s (+%d)",
					monitorIcon, activeWorkspace.Name, apps[0], apps[1], len(apps)-2)
			} else {
				displayLabel = fmt.Sprintf("%s %s - %s",
					monitorIcon, activeWorkspace.Name, strings.Join(apps, ", "))
			}
		} else {
			displayLabel = fmt.Sprintf("%s %s - Empty", monitorIcon, activeWorkspace.Name)
		}

		// Determine styling (same logic as before)
		isFocused := activeWorkspace.Name == overview.FocusedWorkspace
		bgDrawing := "off"
		bgColor := colors.Surface0
		labelColor := colors.Subtext0 // Muted text for inactive

		if isFocused {
			bgDrawing = "on"
			bgColor = colors.Red     // Focused workspace
			labelColor = colors.Text // Bright text for focused
		}

		// Check if item exists, if not create it
		checkResult := exec.Command("sketchybar", "--query", itemName).Run()
		if checkResult != nil {
			// Item doesn't exist, create it (first time setup)
			createNewItem(itemName, displayLabel, bgDrawing, bgColor, labelColor, colors, monitor.ID)
		} else {
			// Item exists, just update it (prevents flickering)
			fmt.Printf("Updating item %s with label: %s\n", itemName, displayLabel)
			exec.Command("sketchybar",
				"--set", itemName,
				"label="+displayLabel,
				"background.drawing="+bgDrawing,
				"background.color="+bgColor,
				"label.color="+labelColor,
				"update_freq=1",
			).Run()
		}
	}
}

// createNewItem creates a new SketchyBar item (only called when item doesn't exist)
func createNewItem(itemName, displayLabel, bgDrawing, bgColor, labelColor string, colors *utils.ColorPalette, monitorID int) {
	monitorPattern := fmt.Sprintf("%d", monitorID)

	exec.Command("sketchybar",
		"--add", "item", itemName, "left",
		"--set", itemName,
		"label="+displayLabel,
		"label.color="+labelColor,
		"label.font=SF Pro Display:Medium:13.0",
		"label.padding_left=8",
		"label.padding_right=8",
		"icon.drawing=off",
		"background.color="+bgColor,
		"background.corner_radius=8",
		"background.height=30",
		"background.drawing="+bgDrawing,
		"update_freq=5",
		"click_script=aerospace focus-monitor "+monitorPattern,
		"script=$HOME/.local/bin/sketchybar/aerospace_overview",
		"--subscribe", itemName, "aerospace_workspace_change", "space_windows_change", "front_app_switched",
	).Run()
}
