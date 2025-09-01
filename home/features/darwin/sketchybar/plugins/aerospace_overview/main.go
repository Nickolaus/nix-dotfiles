package main

import (
	"fmt"
	"os"
	"os/exec"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

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
	LastUpdate        time.Time
}

// Global state cache with mutex for thread safety
var (
	cachedOverview *WorkspaceOverview
	cacheMutex     sync.RWMutex
	lastEventTime  time.Time
	debounceTimer  *time.Timer
)

const (
	// Performance tuning constants
	CACHE_DURATION    = 2 * time.Second        // Cache aerospace data for 2 seconds
	DEBOUNCE_DURATION = 150 * time.Millisecond // Debounce rapid events
	MAX_RETRIES       = 2                      // Max retries for aerospace commands
)

func main() {
	sender := os.Getenv("SENDER")

	// Reduce debug noise - only log important events
	switch sender {
	case "aerospace_workspace_change":
		fmt.Printf("Workspace change detected\n")
	case "space_windows_change":
		// Skip logging for frequent window changes to reduce noise
		break
	default:
		fmt.Printf("Plugin called - SENDER: '%s'\n", sender)
	}

	// Handle different event types with appropriate optimizations
	switch sender {
	case "front_app_switched":
		// For front_app events, skip full update - this causes most of the flickering
		// The front_app plugin handles this separately
		fmt.Printf("Skipping aerospace update for front_app_switched (prevents flickering)\n")
		return

	case "space_windows_change":
		// Debounce rapid window changes (common when moving apps between displays)
		handleDebouncedUpdate()
		return

	case "aerospace_workspace_change":
		// Immediate update for workspace changes (user expects instant feedback)
		handleWorkspaceChange()
		return

	default:
		// Initial setup or manual trigger
		handleInitialSetup()
	}
}

// handleDebouncedUpdate implements debouncing for rapid events
func handleDebouncedUpdate() {
	now := time.Now()
	lastEventTime = now

	// Cancel existing timer if any
	if debounceTimer != nil {
		debounceTimer.Stop()
	}

	// Set new timer
	debounceTimer = time.AfterFunc(DEBOUNCE_DURATION, func() {
		// Check if this is still the latest event
		if time.Since(lastEventTime) >= DEBOUNCE_DURATION {
			updateWithCaching()
		}
	})
}

// handleWorkspaceChange handles immediate workspace changes
func handleWorkspaceChange() {
	// Clear cache for workspace changes to ensure accuracy
	cacheMutex.Lock()
	cachedOverview = nil
	cacheMutex.Unlock()

	updateWithCaching()
}

// handleInitialSetup handles initial plugin setup
func handleInitialSetup() {
	updateWithCaching()
}

// updateWithCaching updates using cached data when possible
func updateWithCaching() {
	var overview *WorkspaceOverview
	var err error

	// Try to use cached data first
	cacheMutex.RLock()
	if cachedOverview != nil && time.Since(cachedOverview.LastUpdate) < CACHE_DURATION {
		overview = cachedOverview
		cacheMutex.RUnlock()
		fmt.Printf("Using cached aerospace data (age: %v)\n", time.Since(overview.LastUpdate))
	} else {
		cacheMutex.RUnlock()

		// Fetch fresh data with focused workspace detection
		focusedWorkspace := getFocusedWorkspace()
		overview, err = getWorkspaceOverview(focusedWorkspace)
		if err != nil {
			fmt.Printf("Error getting workspace overview: %v\n", err)
			return
		}

		// Update cache
		cacheMutex.Lock()
		cachedOverview = overview
		cacheMutex.Unlock()

		fmt.Printf("Fetched fresh aerospace data - focused: %s\n", overview.FocusedWorkspace)
	}

	updateSketchyBar(overview)
}

// getFocusedWorkspace gets focused workspace with fallback
func getFocusedWorkspace() string {
	// Try environment variable first (fastest)
	if focused := os.Getenv("FOCUSED"); focused != "" {
		return focused
	}

	// Fallback to aerospace command
	if output, err := execWithRetry("/run/current-system/sw/bin/aerospace", "list-workspaces", "--focused"); err == nil {
		return strings.TrimSpace(string(output))
	}

	return ""
}

// execWithRetry executes command with retry logic
func execWithRetry(name string, args ...string) ([]byte, error) {
	var lastErr error

	for i := 0; i < MAX_RETRIES; i++ {
		output, err := exec.Command(name, args...).Output()
		if err == nil {
			return output, nil
		}
		lastErr = err

		// Short delay between retries
		if i < MAX_RETRIES-1 {
			time.Sleep(50 * time.Millisecond)
		}
	}

	return nil, fmt.Errorf("command failed after %d retries: %w", MAX_RETRIES, lastErr)
}

func getWorkspaceOverview(focusedWorkspace string) (*WorkspaceOverview, error) {
	overview := &WorkspaceOverview{
		FocusedWorkspace: focusedWorkspace,
		LastUpdate:       time.Now(),
	}

	// Get all data in parallel to reduce total latency
	type result struct {
		monitors   []Monitor
		workspaces []Workspace
		visible    []string
		err        error
	}

	resultChan := make(chan result, 1)

	go func() {
		var r result

		// Get monitors
		r.monitors, r.err = getMonitors()
		if r.err != nil {
			resultChan <- r
			return
		}

		// Get workspaces and visible workspaces in parallel
		workspaceChan := make(chan []Workspace, 1)
		visibleChan := make(chan []string, 1)
		errorChan := make(chan error, 2)

		go func() {
			if ws, err := getWorkspaces(); err != nil {
				errorChan <- err
			} else {
				workspaceChan <- ws
			}
		}()

		go func() {
			if vis, err := getVisibleWorkspaces(); err != nil {
				errorChan <- err
			} else {
				visibleChan <- vis
			}
		}()

		// Collect results
		workspacesReceived := false
		visibleReceived := false

		for !workspacesReceived || !visibleReceived {
			select {
			case r.workspaces = <-workspaceChan:
				workspacesReceived = true
			case r.visible = <-visibleChan:
				visibleReceived = true
			case err := <-errorChan:
				r.err = err
				resultChan <- r
				return
			}
		}

		resultChan <- r
	}()

	// Wait for results with timeout
	select {
	case r := <-resultChan:
		if r.err != nil {
			return nil, r.err
		}
		overview.Monitors = r.monitors
		overview.Workspaces = r.workspaces
		overview.VisibleWorkspaces = r.visible
	case <-time.After(3 * time.Second):
		return nil, fmt.Errorf("aerospace commands timed out")
	}

	return overview, nil
}

func getMonitors() ([]Monitor, error) {
	output, err := execWithRetry("/run/current-system/sw/bin/aerospace", "list-monitors")
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
	output, err := execWithRetry("/run/current-system/sw/bin/aerospace", "list-workspaces", "--all")
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

		// Get monitor assignment and apps for this workspace efficiently
		monitor := getWorkspaceMonitorFast(line)
		appNames, windowCount := getWorkspaceAppsFast(line)

		workspaces = append(workspaces, Workspace{
			Name:        line,
			Monitor:     monitor,
			AppNames:    appNames,
			WindowCount: windowCount,
		})
	}

	// Sort workspaces numerically where possible, then alphabetically
	sort.Slice(workspaces, func(i, j int) bool {
		if numI, errI := strconv.Atoi(workspaces[i].Name); errI == nil {
			if numJ, errJ := strconv.Atoi(workspaces[j].Name); errJ == nil {
				return numI < numJ
			}
		}
		return workspaces[i].Name < workspaces[j].Name
	})

	return workspaces, nil
}

// getWorkspaceMonitorFast gets workspace monitor with single command
func getWorkspaceMonitorFast(workspace string) string {
	// Single efficient command to get monitor assignment
	output, err := execWithRetry("/run/current-system/sw/bin/aerospace", "list-workspaces", "--monitor", "all", "--format", "%{workspace}|%{monitor-name}")
	if err != nil {
		return "unknown"
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	for _, line := range lines {
		parts := strings.Split(line, "|")
		if len(parts) >= 2 && strings.TrimSpace(parts[0]) == workspace {
			return strings.TrimSpace(parts[1])
		}
	}

	return "unassigned"
}

func getVisibleWorkspaces() ([]string, error) {
	output, err := execWithRetry("/run/current-system/sw/bin/aerospace", "list-workspaces", "--monitor", "all", "--visible")
	if err != nil {
		// Fallback: try to get focused workspace only
		if focusedOutput, focusedErr := execWithRetry("/run/current-system/sw/bin/aerospace", "list-workspaces", "--focused"); focusedErr == nil {
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

// getWorkspaceAppsFast gets workspace apps with better error handling
func getWorkspaceAppsFast(workspace string) ([]string, int) {
	output, err := execWithRetry("/run/current-system/sw/bin/aerospace", "list-windows", "--workspace", workspace, "--format", "%{app-name}")
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
	colors := utils.NewCatppuccinMacchiato()

	// Batch updates to prevent flickering
	activeMonitors := getActiveMonitors(overview.Monitors, overview.Workspaces, overview.VisibleWorkspaces)

	// Clean up inactive monitors first (in batch)
	cleanupInactiveMonitors(overview.Monitors, activeMonitors)

	// Prepare all updates in memory first, then apply in batch
	var updates [][]string

	for _, monitor := range activeMonitors {
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

		if activeWorkspace == nil {
			continue
		}

		itemName := fmt.Sprintf("aerospace.display.%d", monitor.ID)
		monitorIcon := getShortMonitorName(monitor.Name)

		// Create display label
		var displayLabel string
		var workspaceIndicator string

		isFocused := activeWorkspace.Name == overview.FocusedWorkspace
		isVisible := contains(overview.VisibleWorkspaces, activeWorkspace.Name)

		if isFocused {
			workspaceIndicator = "●" // Focused
		} else if isVisible {
			workspaceIndicator = "◉" // Visible
		} else {
			workspaceIndicator = "○" // Inactive
		}

		if len(activeWorkspace.AppNames) > 0 {
			formattedApps := formatAppNames(activeWorkspace.AppNames)
			displayLabel = fmt.Sprintf("%s %s %s  •  %s",
				monitorIcon, workspaceIndicator, activeWorkspace.Name, formattedApps)
		} else {
			displayLabel = fmt.Sprintf("%s %s %s  •  Empty",
				monitorIcon, workspaceIndicator, activeWorkspace.Name)
		}

		// Determine styling
		var bgDrawing, bgColor, labelColor string
		if isFocused {
			bgDrawing, bgColor, labelColor = "on", colors.Blue, colors.Text
		} else if isVisible {
			bgDrawing, bgColor, labelColor = "on", colors.Surface1, colors.Subtext1
		} else {
			bgDrawing, bgColor, labelColor = "off", colors.Surface0, colors.Subtext0
		}

		// Check if item exists, create or update
		if exec.Command("sketchybar", "--query", itemName).Run() != nil {
			// Create new item
			updates = append(updates, []string{
				"sketchybar", "--add", "item", itemName, "left",
				"--set", itemName,
				"icon=", "label=" + displayLabel,
				"label.color=" + labelColor,
				"label.font=SF Pro Display:Semibold:12.5",
				"label.padding_left=8", "label.padding_right=8",
				"icon.drawing=off",
				"background.color=" + bgColor,
				"background.corner_radius=6",
				"background.height=30",
				"background.drawing=" + bgDrawing,
				"background.padding_left=0", "background.padding_right=0",
				"padding_left=0", "padding_right=0",
				"background.border_width=0",
				"update_freq=10", // Reduced frequency for better performance
				"click_script=aerospace focus-monitor " + fmt.Sprintf("%d", monitor.ID),
				"script=$HOME/.local/bin/sketchybar/aerospace_overview",
				"--subscribe", itemName, "aerospace_workspace_change", "space_windows_change",
			})
		} else {
			// Update existing item (batched update)
			updates = append(updates, []string{
				"sketchybar", "--set", itemName,
				"label=" + displayLabel,
				"background.drawing=" + bgDrawing,
				"background.color=" + bgColor,
				"label.color=" + labelColor,
				"update_freq=10", // Consistent update frequency
			})
		}
	}

	// Execute all updates
	for _, update := range updates {
		exec.Command(update[0], update[1:]...).Run()
	}

	fmt.Printf("Batch update completed - %d monitors processed\n", len(activeMonitors))
}

// formatAppNames provides smart app name formatting with proper truncation
func formatAppNames(apps []string) string {
	if len(apps) == 0 {
		return "Empty"
	}

	// Clean up app names for better readability
	cleanedApps := make([]string, 0, len(apps))
	for _, app := range apps {
		cleaned := cleanAppName(app)
		if cleaned != "" {
			cleanedApps = append(cleanedApps, cleaned)
		}
	}

	if len(cleanedApps) == 0 {
		return "Empty"
	}

	// Smart display logic with improved readability
	switch len(cleanedApps) {
	case 1:
		return cleanedApps[0]
	case 2:
		return fmt.Sprintf("%s, %s", cleanedApps[0], cleanedApps[1])
	case 3:
		return fmt.Sprintf("%s, %s, %s", cleanedApps[0], cleanedApps[1], cleanedApps[2])
	default:
		// Show first 2 apps with elegant count indicator
		return fmt.Sprintf("%s, %s  +%d more", cleanedApps[0], cleanedApps[1], len(cleanedApps)-2)
	}
}

// cleanAppName cleans up app names for better display
func cleanAppName(appName string) string {
	cleaned := strings.TrimSpace(appName)

	switch {
	case strings.HasSuffix(cleaned, " - Google Chrome"):
		cleaned = strings.Replace(cleaned, " - Google Chrome", "", 1)
	case strings.HasSuffix(cleaned, " — WezTerm"):
		cleaned = strings.Replace(cleaned, " — WezTerm", "", 1)
	case strings.HasPrefix(cleaned, "PhpStorm - "):
		cleaned = strings.Replace(cleaned, "PhpStorm - ", "", 1)
	case strings.Contains(cleaned, " - "):
		parts := strings.Split(cleaned, " - ")
		if len(parts) > 1 {
			cleaned = parts[len(parts)-1]
		}
	}

	// Truncate very long names
	if len(cleaned) > 18 {
		cleaned = cleaned[:15] + "…"
	}

	return cleaned
}

func getShortMonitorName(fullName string) string {
	switch {
	case strings.Contains(fullName, "Built-in"):
		return "󰌢" // Laptop icon
	case strings.Contains(fullName, "LG HDR 4K"):
		return "󰍹" // 4K monitor
	case strings.Contains(fullName, "LG HDR WQHD"):
		return "󰍺" // Ultrawide
	case strings.Contains(fullName, "Studio Display"):
		return "󰨇" // Apple display
	case strings.Contains(fullName, "Pro Display"):
		return "󰨇" // Apple display
	case strings.Contains(fullName, "Thunderbolt"):
		return "󱈟" // Thunderbolt
	case strings.Contains(fullName, "LG"):
		return "󰍹" // Generic LG
	default:
		return "󰍹" // Generic monitor
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

func cleanupInactiveMonitors(allMonitors []Monitor, activeMonitors []Monitor) {
	activeIDs := make(map[int]bool)
	for _, monitor := range activeMonitors {
		activeIDs[monitor.ID] = true
	}

	// Clean up efficiently - check common monitor IDs
	for monitorID := 1; monitorID <= 10; monitorID++ {
		if !activeIDs[monitorID] {
			itemName := fmt.Sprintf("aerospace.display.%d", monitorID)
			if exec.Command("sketchybar", "--query", itemName).Run() == nil {
				exec.Command("sketchybar", "--remove", itemName).Run()
			}
		}
	}
}

func getActiveMonitors(aerospaceMonitors []Monitor, workspaces []Workspace, visibleWorkspaces []string) []Monitor {
	var activeMonitors []Monitor

	for _, monitor := range aerospaceMonitors {
		hasActiveContent := false

		for _, ws := range workspaces {
			if ws.Monitor == monitor.Name {
				if len(ws.AppNames) > 0 ||
					(strings.Contains(monitor.Name, "Built-in") && contains(visibleWorkspaces, ws.Name)) {
					hasActiveContent = true
					break
				}
			}
		}

		if hasActiveContent {
			activeMonitors = append(activeMonitors, monitor)
		}
	}

	return activeMonitors
}
