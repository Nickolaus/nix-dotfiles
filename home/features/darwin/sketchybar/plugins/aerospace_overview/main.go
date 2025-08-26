package main

import (
	"fmt"
	"os"
	"os/exec"
	"sort"
	"strconv"
	"strings"
)

// Monitor represents an AeroSpace monitor
type Monitor struct {
	ID   int    `json:"monitor-id"`
	Name string `json:"monitor-name"`
}

// Workspace represents an AeroSpace workspace
type Workspace struct {
	Name      string `json:"workspace"`
	IsVisible bool   `json:"is-visible"`
	Monitor   string `json:"monitor"`
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
		if output, err := exec.Command("aerospace", "list-workspaces", "--focused").Output(); err == nil {
			focusedWorkspace = strings.TrimSpace(string(output))
		}
	}

	overview, err := getWorkspaceOverview(focusedWorkspace)
	if err != nil {
		fmt.Printf("Error getting workspace overview: %v\n", err)
		os.Exit(1)
	}

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
	cmd := exec.Command("aerospace", "list-monitors")
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
	cmd := exec.Command("aerospace", "list-workspaces", "--all")
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

		workspaces = append(workspaces, Workspace{
			Name:    line,
			Monitor: monitor,
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
	cmd := exec.Command("aerospace", "list-workspaces", "--monitor", "all", "--format", "%{workspace}:%{monitor-name}")
	output, err := cmd.Output()
	if err != nil {
		// Fallback: try to determine from visible workspaces
		return "main", nil
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	for _, line := range lines {
		parts := strings.Split(line, ":")
		if len(parts) == 2 && strings.TrimSpace(parts[0]) == workspace {
			return strings.TrimSpace(parts[1]), nil
		}
	}

	return "main", nil // default fallback
}

func getVisibleWorkspaces() ([]string, error) {
	// Get visible workspaces across all monitors
	cmd := exec.Command("aerospace", "list-workspaces", "--monitor", "all", "--visible")
	output, err := cmd.Output()
	if err != nil {
		// Fallback: try to get focused workspace only
		focusedCmd := exec.Command("aerospace", "list-workspaces", "--focused")
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

func updateSketchyBar(overview *WorkspaceOverview) {
	// Group workspaces by monitor
	workspacesByMonitor := make(map[string][]Workspace)
	for _, ws := range overview.Workspaces {
		monitor := ws.Monitor
		if monitor == "" {
			monitor = "unassigned"
		}
		workspacesByMonitor[monitor] = append(workspacesByMonitor[monitor], ws)
	}

	// Clear existing aerospace workspace items (plugin manages its own state)
	exec.Command("sketchybar", "--remove", "/aerospace.*/").Run()

	// Add monitor groups and workspace items
	for _, monitor := range overview.Monitors {
		monitorName := getShortMonitorName(monitor.Name)
		workspaces := workspacesByMonitor[monitor.Name]

		if len(workspaces) == 0 {
			continue // Skip monitors with no workspaces
		}

		// Add monitor label
		monitorItemName := fmt.Sprintf("aerospace.monitor.%d", monitor.ID)
		exec.Command("sketchybar",
			"--add", "item", monitorItemName, "left",
			"--set", monitorItemName,
			"label="+monitorName,
			"label.color=0xffadb3d1",
			"label.font=SF Pro Display:Bold:11.0",
			"label.padding_left=12",
			"label.padding_right=4",
			"background.drawing=off",
		).Run()

		// Add workspaces for this monitor
		for _, ws := range workspaces {
			itemName := fmt.Sprintf("aerospace.workspace.%s", ws.Name)

			// Determine visual state
			bgDrawing := "off"
			bgColor := "0x44ffffff"
			labelColor := "0xffcad3f5"

			if ws.Name == overview.FocusedWorkspace {
				bgDrawing = "on"
				bgColor = "0xffed8796"
				labelColor = "0xff24273a"
			} else if contains(overview.VisibleWorkspaces, ws.Name) {
				bgDrawing = "on"
				bgColor = "0x88363a4f"
				labelColor = "0xffffffff"
			}

			exec.Command("sketchybar",
				"--add", "item", itemName, "left",
				"--set", itemName,
				"label="+ws.Name,
				"label.color="+labelColor,
				"label.font=SF Pro Display:Semibold:13.0",
				"label.padding_left=8",
				"label.padding_right=8",
				"background.color="+bgColor,
				"background.corner_radius=6",
				"background.height=26",
				"background.drawing="+bgDrawing,
				"click_script=aerospace workspace "+ws.Name,
				"--subscribe", itemName, "aerospace_workspace_change",
			).Run()
		}

		// Add separator after monitor group (except for last monitor)
		if monitor.ID < len(overview.Monitors) {
			sepName := fmt.Sprintf("aerospace.separator.%d", monitor.ID)
			exec.Command("sketchybar",
				"--add", "item", sepName, "left",
				"--set", sepName,
				"label=│",
				"label.color=0x44ffffff",
				"label.font=SF Pro Display:Light:14.0",
				"label.padding_left=8",
				"label.padding_right=8",
				"background.drawing=off",
			).Run()
		}
	}

	// Handle unassigned workspaces if any
	if unassignedWorkspaces, exists := workspacesByMonitor["unassigned"]; exists && len(unassignedWorkspaces) > 0 {
		// Add separator
		exec.Command("sketchybar",
			"--add", "item", "aerospace.unassigned.separator", "left",
			"--set", "aerospace.unassigned.separator",
			"label=│",
			"label.color=0x44ffffff",
			"background.drawing=off",
		).Run()

		// Add unassigned label
		exec.Command("sketchybar",
			"--add", "item", "aerospace.unassigned.label", "left",
			"--set", "aerospace.unassigned.label",
			"label=Other",
			"label.color=0xfff5a97f",
			"label.font=SF Pro Display:Bold:11.0",
			"background.drawing=off",
		).Run()

		// Add unassigned workspaces
		for _, ws := range unassignedWorkspaces {
			itemName := fmt.Sprintf("aerospace.workspace.%s", ws.Name)

			bgDrawing := "off"
			bgColor := "0x44ffffff"
			labelColor := "0xffcad3f5"

			if ws.Name == overview.FocusedWorkspace {
				bgDrawing = "on"
				bgColor = "0xfff5a97f"
				labelColor = "0xff24273a"
			}

			exec.Command("sketchybar",
				"--add", "item", itemName, "left",
				"--set", itemName,
				"label="+ws.Name,
				"label.color="+labelColor,
				"background.color="+bgColor,
				"background.drawing="+bgDrawing,
				"click_script=aerospace workspace "+ws.Name,
				"--subscribe", itemName, "aerospace_workspace_change",
			).Run()
		}
	}
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
