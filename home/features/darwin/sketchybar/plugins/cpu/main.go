package main

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"github.com/shirou/gopsutil/v3/cpu"

	"sketchybar-plugins/config"
	"sketchybar-plugins/utils"
)

const (
	pluginName = "cpu"
	itemName   = "cpu"
)

// CPUPlugin handles CPU monitoring for SketchyBar
type CPUPlugin struct {
	config  *config.GlobalConfig
	logger  *utils.Logger
	updater *utils.SketchyBarUpdater
	history *utils.HistoryManager
	trends  *utils.TrendGraph
	cache   *utils.CacheManager
}

// NewCPUPlugin creates a new CPU monitoring plugin
func NewCPUPlugin() (*CPUPlugin, error) {
	cfg, err := config.LoadConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to load config: %w", err)
	}

	logger := utils.NewLogger(pluginName)
	updater := utils.NewSketchyBarUpdater(cfg)
	history := utils.NewHistoryManager(cfg, logger)
	trends := utils.NewTrendGraph(cfg, logger)

	// Initialize cache for CPU plugin
	cacheDir := os.ExpandEnv("$HOME/.cache/sketchybar/cpu.db")
	cache, err := utils.NewCacheManager(cacheDir, 2) // 2 second cache for CPU samples
	if err != nil {
		logger.Warning("Failed to initialize CPU cache: %v", err)
		cache = nil
	}

	return &CPUPlugin{
		config:  cfg,
		logger:  logger,
		updater: updater,
		history: history,
		trends:  trends,
		cache:   cache,
	}, nil
}

// GetCPUUsage gets current CPU usage percentage with instant sampling (no sleep)
func (p *CPUPlugin) GetCPUUsage() (float64, error) {
	// Try instant CPU sampling first (fastest)
	if usage, err := p.getInstantCPUUsage(); err == nil {
		return usage, nil
	}

	// Fallback to optimized system command (fast)
	return p.getCPUUsageFromSystem()
}

// getInstantCPUUsage gets CPU usage without sleep using direct gopsutil (no complex caching)
func (p *CPUPlugin) getInstantCPUUsage() (float64, error) {
	// FIXED: Remove complex cache.GetOrSet that was causing deadlocks
	// Use simple direct call with basic caching

	// Check if we have a recent cached value first
	if p.cache != nil {
		if cached, exists := p.cache.Get("simple_cpu_cache"); exists {
			if usage, ok := cached.(float64); ok {
				return usage, nil
			}
		}
	}

	// Get fresh CPU measurement
	percentages, err := cpu.Percent(0, false)
	if err != nil {
		p.logger.Debug("gopsutil instant CPU failed: %v", err)
		return 0, err
	}

	if len(percentages) == 0 {
		return 0, fmt.Errorf("no CPU usage data available from gopsutil")
	}

	// Get overall CPU usage (instant snapshot)
	usage := percentages[0]

	// If instant measurement gives 0, use delta calculation
	if usage == 0 {
		if deltaUsage, err := p.calculateCPUDelta(); err == nil {
			usage = deltaUsage
		}
	}

	// Clamp to valid range
	if usage < 0 {
		usage = 0
	} else if usage > 100 {
		usage = 100
	}

	// Cache the result for 2 seconds (simple caching)
	if p.cache != nil {
		p.cache.Set("simple_cpu_cache", usage, 2)
	}

	return usage, nil
}

// calculateCPUDelta calculates CPU usage from stats delta (for when instant measurement returns 0)
// Uses a separate cache key to avoid conflicts with instant measurements
func (p *CPUPlugin) calculateCPUDelta() (float64, error) {
	// Get current CPU times
	stats, err := cpu.Times(false)
	if err != nil || len(stats) == 0 {
		return 0, err
	}

	currentStats := stats[0]
	currentTotal := currentStats.Total()
	currentIdle := currentStats.Idle

	// Get previous stats from cache (FIXED: use delta-specific cache key)
	prevData, exists := p.cache.Get("cpu_delta_stats")
	if !exists {
		// First run - store current stats and return reasonable default
		p.cache.Set("cpu_delta_stats", map[string]float64{
			"total": currentTotal,
			"idle":  currentIdle,
		}, 10)
		return 15.0, nil // Reasonable default for first measurement
	}

	prevMap, ok := prevData.(map[string]float64)
	if !ok {
		return 0, fmt.Errorf("invalid previous CPU stats")
	}

	prevTotal := prevMap["total"]
	prevIdle := prevMap["idle"]

	// Calculate usage percentage
	totalDelta := currentTotal - prevTotal
	idleDelta := currentIdle - prevIdle

	if totalDelta <= 0 {
		return 0, fmt.Errorf("invalid CPU delta")
	}

	usage := 100.0 * (1.0 - idleDelta/totalDelta)

	// Store current stats for next measurement (FIXED: use delta-specific cache key)
	p.cache.Set("cpu_delta_stats", map[string]float64{
		"total": currentTotal,
		"idle":  currentIdle,
	}, 10)

	return usage, nil
}

// getCPUUsageFromSystem gets CPU usage using real-time macOS system commands
func (p *CPUPlugin) getCPUUsageFromSystem() (float64, error) {
	// Use top for real-time CPU measurement (iostat gives averages since boot!)
	cmd := exec.Command("bash", "-c", `
		# Parse real-time CPU usage from top (not cumulative averages)
		top -l 1 | grep "CPU usage" | awk '{gsub(/%/, "", $3); gsub(/%/, "", $5); print $3 + $5}'
	`)

	output, err := cmd.Output()
	if err != nil {
		// Fallback to top if iostat fails
		return p.getFallbackCPUUsage()
	}

	// Parse the output
	usageStr := strings.TrimSpace(string(output))
	usage, err := strconv.ParseFloat(usageStr, 64)
	if err != nil {
		p.logger.Debug("Failed to parse iostat CPU usage: %s", usageStr)
		return p.getFallbackCPUUsage()
	}

	// Clamp to valid range
	if usage < 0 {
		usage = 0
	} else if usage > 100 {
		usage = 100
	}

	return usage, nil
}

// getFallbackCPUUsage provides the fastest possible fallback CPU measurement
func (p *CPUPlugin) getFallbackCPUUsage() (float64, error) {
	// Super fast fallback using vm_stat and sysctl
	cmd := exec.Command("bash", "-c", `
		# Quick CPU load approximation using load average
		uptime | awk -F'load averages: ' '{print $2}' | awk '{print $1 * 100 / 14}' | cut -d. -f1
	`)

	output, err := cmd.Output()
	if err != nil {
		// Ultimate fallback - return cached value or reasonable default
		if p.cache != nil {
			if cached, exists := p.cache.Get("last_known_cpu_fallback"); exists {
				if usage, ok := cached.(float64); ok {
					return usage, nil
				}
			}
		}
		return 20.0, nil // Reasonable default
	}

	usageStr := strings.TrimSpace(string(output))
	usage, err := strconv.ParseFloat(usageStr, 64)
	if err != nil {
		return 20.0, nil
	}

	// Clamp and store as backup
	if usage < 0 {
		usage = 0
	} else if usage > 100 {
		usage = 100
	}

	// Cache the value as backup
	if p.cache != nil {
		p.cache.Set("last_known_cpu_fallback", usage, 30)
	}

	return usage, nil
}

// HandlePopupAction shows detailed CPU information with enhanced trend graphs
func (p *CPUPlugin) HandlePopupAction() error {
	p.logger.Info("Showing CPU popup with enhanced trend graphs")

	// Get current usage (now instant)
	usage, err := p.GetCPUUsage()
	if err != nil {
		return fmt.Errorf("failed to get CPU usage for popup: %w", err)
	}

	// Get historical data
	history, err := p.history.GetHistory("cpu_history")
	if err != nil || len(history) == 0 {
		p.logger.Debug("No history available for popup: %v", err)
		return utils.ShowNotification("CPU Monitor", "No historical data available yet")
	}

	// Create different trend graph configurations
	sparkConfig := utils.TrendGraphConfig{
		Style:     utils.StyleSpark,
		Width:     20,
		ShowPeak:  true,
		ShowAvg:   true,
		ShowTrend: true,
	}

	blockConfig := utils.TrendGraphConfig{
		Style:     utils.StyleBlocks,
		Width:     15,
		ShowPeak:  false,
		ShowAvg:   false,
		ShowTrend: false,
	}

	// Generate enhanced trend graphs
	sparkGraph := p.trends.GenerateEnhancedTrendGraph(history, sparkConfig)
	blockGraph := p.trends.GenerateEnhancedTrendGraph(history, blockConfig)

	// Create detailed notification message
	message := fmt.Sprintf("Current: %.1f%%\n", usage)
	message += fmt.Sprintf("Sparkline: %s\n", sparkGraph)
	message += fmt.Sprintf("Blocks: %s\n", blockGraph)
	message += fmt.Sprintf("Data points: %d", len(history))

	// Show enhanced popup and open Activity Monitor
	if err := utils.ShowNotification("CPU Usage Trends", message); err != nil {
		return fmt.Errorf("failed to show notification: %w", err)
	}

	// Schedule opening Activity Monitor after notification
	go func() {
		time.Sleep(1 * time.Second)
		if err := utils.OpenApplication("Activity Monitor"); err != nil {
			p.logger.Error("Failed to open Activity Monitor: %v", err)
		}
	}()

	return nil
}

// UpdateDisplay updates the SketchyBar display with current CPU usage
func (p *CPUPlugin) UpdateDisplay() error {
	// Get current CPU usage (now instant - no more 1 second delay!)
	usage, err := p.GetCPUUsage()
	if err != nil {
		return fmt.Errorf("failed to get CPU usage: %w", err)
	}

	p.logger.Debug("CPU usage: %.1f%% (instant measurement)", usage)

	// Update history
	if err := p.history.AppendValue("cpu_history", usage); err != nil {
		p.logger.Error("Failed to update history: %v", err)
		// Non-fatal, continue
	}

	// Get appropriate icon and color
	icon := utils.GetCPUIcon(usage)
	color := p.config.Colors.GetStatusColor(usage, true) // true = reverse (high usage is bad)

	// Get trend indicator
	trendIcon := p.history.GetTrendDirection("cpu_history")

	// Format label with trend
	label := fmt.Sprintf("%.0f%% %s", usage, trendIcon)

	// Update SketchyBar
	if err := p.updater.UpdateItem(itemName, icon, label, color); err != nil {
		return fmt.Errorf("failed to update SketchyBar: %w", err)
	}

	return nil
}

// Run starts the CPU monitoring plugin
func (p *CPUPlugin) Run() error {
	p.logger.Info("Starting CPU plugin")

	// 🛠️ SLEEP/WAKE FIX: Check if triggered by system events
	sender := os.Getenv("SENDER")
	if sender == "system_woke" {
		p.logger.Info("System woke from sleep - invalidating CPU cache")
		if p.cache != nil {
			// Invalidate CPU-related cache on wake (system state has changed)
			p.cache.InvalidatePattern("simple_cpu_cache")
			p.cache.InvalidatePattern("cpu_delta_stats")
			p.cache.InvalidatePattern("last_known_cpu_fallback")
		}
	}

	// Handle command line arguments
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "popup":
			return p.HandlePopupAction()
		default:
			p.logger.Debug("Unknown argument: %s", os.Args[1])
		}
	}

	// Regular CPU monitoring update (now much faster!)
	return p.UpdateDisplay()
}

func main() {
	plugin, err := NewCPUPlugin()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create CPU plugin: %v\n", err)
		os.Exit(1)
	}

	if err := plugin.Run(); err != nil {
		plugin.logger.Error("Plugin execution failed: %v", err)
		fmt.Fprintf(os.Stderr, "CPU plugin failed: %v\n", err)
		os.Exit(1)
	}
}
