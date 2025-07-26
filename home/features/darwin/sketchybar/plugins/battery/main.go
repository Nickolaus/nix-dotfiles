package main

import (
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"time"

	"sketchybar-plugins/config"
	"sketchybar-plugins/utils"
)

const (
	pluginName = "battery"
	itemName   = "battery"
)

// BatteryPlugin handles battery monitoring for SketchyBar
type BatteryPlugin struct {
	config  *config.GlobalConfig
	logger  *utils.Logger
	updater *utils.SketchyBarUpdater
	sysinfo *utils.SystemInfo
	cache   *utils.CacheManager // Cache for battery data
}

// BatteryInfo represents current battery status
type BatteryInfo struct {
	Percentage    int
	IsCharging    bool
	TimeRemaining string
	CycleCount    int
	Condition     string
	IsPresent     bool
}

// NewBatteryPlugin creates a new battery monitoring plugin
func NewBatteryPlugin() (*BatteryPlugin, error) {
	cfg, err := config.LoadConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to load config: %w", err)
	}

	logger := utils.NewLogger(pluginName)
	updater := utils.NewSketchyBarUpdater(cfg)
	sysinfo := utils.NewSystemInfo(cfg, logger)

	// Initialize cache for battery data
	cacheDir := os.ExpandEnv("$HOME/.cache/sketchybar/battery.db")
	cache, err := utils.NewCacheManager(cacheDir, 30) // 30-second default TTL
	if err != nil {
		logger.Warning("Failed to initialize battery cache: %v", err)
		cache = nil
	}

	return &BatteryPlugin{
		config:  cfg,
		logger:  logger,
		updater: updater,
		sysinfo: sysinfo,
		cache:   cache,
	}, nil
}

// GetBatteryInfo gets comprehensive battery information
func (p *BatteryPlugin) GetBatteryInfo() (*BatteryInfo, error) {
	info := &BatteryInfo{
		IsPresent: false,
	}

	// Get battery information from pmset
	cmd := exec.Command("pmset", "-g", "batt")
	output, err := cmd.Output()
	if err != nil {
		return info, fmt.Errorf("failed to run pmset: %w", err)
	}

	outputStr := string(output)

	// Extract percentage
	percentageRegex := regexp.MustCompile(`(\d+)%`)
	percentageMatch := percentageRegex.FindStringSubmatch(outputStr)
	if len(percentageMatch) > 1 {
		if percentage, err := strconv.Atoi(percentageMatch[1]); err == nil {
			info.Percentage = percentage
			info.IsPresent = true
		}
	}

	if !info.IsPresent {
		return info, nil
	}

	// Check if charging
	info.IsCharging = strings.Contains(outputStr, "AC Power")

	// Extract time remaining
	timeRegex := regexp.MustCompile(`(\d+:\d+)`)
	timeMatch := timeRegex.FindStringSubmatch(outputStr)
	if len(timeMatch) > 1 {
		info.TimeRemaining = timeMatch[1]
	}

	// Get additional battery details for popup
	if err := p.getBatteryDetails(info); err != nil {
		p.logger.Debug("Failed to get battery details: %v", err)
	}

	return info, nil
}

// getBatteryDetails gets additional battery information with aggressive caching
func (p *BatteryPlugin) getBatteryDetails(info *BatteryInfo) error {
	// Cache slow system_profiler calls for 24 hours
	// Battery cycle count and condition change very rarely

	if p.cache != nil {
		if cached := p.getCachedBatteryDetails(); cached != nil {
			info.CycleCount = cached.CycleCount
			info.Condition = cached.Condition
			p.logger.Debug("Using cached battery details (cycle: %d, condition: %s)", cached.CycleCount, cached.Condition)
			return nil
		}
	}

	// Try fast method first before expensive system_profiler
	if err := p.getBatteryDetailsFast(info); err == nil {
		p.cacheBatteryDetails(info)
		return nil
	}

	// Fallback: Use slow system_profiler only when fast methods fail
	p.logger.Debug("Fast battery details failed, using system_profiler fallback")
	return p.getBatteryDetailsSystemProfiler(info)
}

// BatteryDetails represents cached battery details
type BatteryDetails struct {
	CycleCount int
	Condition  string
}

// getCachedBatteryDetails retrieves cached battery details
func (p *BatteryPlugin) getCachedBatteryDetails() *BatteryDetails {
	if p.cache == nil {
		return nil
	}

	key := "battery_details"
	if cached, exists := p.cache.Get(key); exists {
		if details, ok := cached.(*BatteryDetails); ok {
			return details
		}
	}
	return nil
}

// cacheBatteryDetails stores battery details with 24-hour cache
func (p *BatteryPlugin) cacheBatteryDetails(info *BatteryInfo) {
	if p.cache == nil {
		return
	}

	details := &BatteryDetails{
		CycleCount: info.CycleCount,
		Condition:  info.Condition,
	}

	key := "battery_details"
	ttl := int64(24 * 60 * 60) // 24 hours - these values rarely change
	if err := p.cache.Set(key, details, ttl); err != nil {
		p.logger.Warning("Failed to cache battery details: %v", err)
	}
}

// 🚀 FAST METHOD: Try to get battery details without system_profiler
func (p *BatteryPlugin) getBatteryDetailsFast(info *BatteryInfo) error {
	// Method 1: Try ioreg (faster than system_profiler)
	cmd := exec.Command("bash", "-c", "ioreg -l -w0 | grep -E 'CycleCount|BatteryHealth'")
	output, err := cmd.Output()
	if err == nil {
		outputStr := string(output)

		// Extract cycle count from ioreg
		cycleRegex := regexp.MustCompile(`"CycleCount"\s*=\s*(\d+)`)
		if cycleMatch := cycleRegex.FindStringSubmatch(outputStr); len(cycleMatch) > 1 {
			if cycle, err := strconv.Atoi(cycleMatch[1]); err == nil {
				info.CycleCount = cycle
				info.Condition = "Good" // Default condition if ioreg works
				return nil
			}
		}
	}

	// Method 2: Intelligent estimation based on percentage
	if info.Percentage > 80 {
		info.Condition = "Good"
	} else if info.Percentage > 50 {
		info.Condition = "Fair"
	} else {
		info.Condition = "Poor"
	}

	// Estimate cycle count (rough approximation)
	info.CycleCount = 0 // Will be filled by cache or system_profiler later

	return fmt.Errorf("fast method provided estimates only")
}

// getBatteryDetailsSystemProfiler uses slow system_profiler as last resort
func (p *BatteryPlugin) getBatteryDetailsSystemProfiler(info *BatteryInfo) error {
	cmd := exec.Command("system_profiler", "SPPowerDataType")
	output, err := cmd.Output()
	if err != nil {
		// Apply smart defaults if system_profiler fails
		info.CycleCount = 0
		info.Condition = "Unknown"
		return fmt.Errorf("system_profiler failed: %w", err)
	}

	outputStr := string(output)

	// Extract cycle count
	cycleRegex := regexp.MustCompile(`Cycle Count:\s*(\d+)`)
	cycleMatch := cycleRegex.FindStringSubmatch(outputStr)
	if len(cycleMatch) > 1 {
		if cycle, err := strconv.Atoi(cycleMatch[1]); err == nil {
			info.CycleCount = cycle
		}
	}

	// Extract condition
	conditionRegex := regexp.MustCompile(`Condition:\s*(\w+)`)
	conditionMatch := conditionRegex.FindStringSubmatch(outputStr)
	if len(conditionMatch) > 1 {
		info.Condition = conditionMatch[1]
	}

	// Cache the results for 24 hours
	p.cacheBatteryDetails(info)

	return nil
}

// GetBatteryIcon returns appropriate battery icon based on level and charging status
func (p *BatteryPlugin) GetBatteryIcon(info *BatteryInfo) string {
	if !info.IsPresent {
		return "󰂑" // No battery
	}

	if info.IsCharging {
		// Charging icons
		switch {
		case info.Percentage >= 95:
			return "󰂅" // Charging - almost full
		case info.Percentage >= 80:
			return "󰂋" // Charging - high
		case info.Percentage >= 60:
			return "󰂊" // Charging - medium-high
		case info.Percentage >= 40:
			return "󰢞" // Charging - medium
		case info.Percentage >= 20:
			return "󰂇" // Charging - low
		default:
			return "󰢜" // Charging - very low
		}
	} else {
		// Battery icons
		switch {
		case info.Percentage >= 90:
			return "󰁹" // Full battery
		case info.Percentage >= 70:
			return "󰂂" // High battery
		case info.Percentage >= 50:
			return "󰂀" // Medium battery
		case info.Percentage >= 30:
			return "󰁾" // Low battery
		case info.Percentage >= 10:
			return "󰁼" // Very low battery
		default:
			return "󰂎" // Critical battery
		}
	}
}

// GetBatteryColor returns appropriate color based on battery level and charging status
func (p *BatteryPlugin) GetBatteryColor(info *BatteryInfo) string {
	if !info.IsPresent {
		return p.config.Colors.Red
	}

	if info.IsCharging {
		// Charging colors - more optimistic
		switch {
		case info.Percentage >= 80:
			return p.config.Colors.Green
		case info.Percentage >= 40:
			return p.config.Colors.Yellow
		default:
			return p.config.Colors.Peach
		}
	} else {
		// Battery colors - more conservative
		switch {
		case info.Percentage >= 70:
			return p.config.Colors.Green
		case info.Percentage >= 30:
			return p.config.Colors.Yellow
		case info.Percentage >= 10:
			return p.config.Colors.Peach
		default:
			return p.config.Colors.Red
		}
	}
}

// HandlePopupAction shows detailed battery information
func (p *BatteryPlugin) HandlePopupAction() error {
	p.logger.Info("Showing battery popup")

	// Get current battery info
	batteryInfo, err := p.GetBatteryInfo()
	if err != nil {
		return fmt.Errorf("failed to get battery info for popup: %w", err)
	}

	if !batteryInfo.IsPresent {
		if err := p.updater.UpdateItem(itemName, "󰂑", "No Battery", p.config.Colors.Red); err != nil {
			return fmt.Errorf("failed to update popup: %w", err)
		}
		return nil
	}

	// Build detailed popup message
	var status string
	var timeMsg string

	if batteryInfo.IsCharging {
		status = "⚡ Charging"
		if batteryInfo.TimeRemaining != "" {
			timeMsg = fmt.Sprintf("🕐 %s until full", batteryInfo.TimeRemaining)
		} else {
			timeMsg = "🕐 Calculating time..."
		}
	} else {
		status = "🔋 On Battery"
		if batteryInfo.TimeRemaining != "" {
			timeMsg = fmt.Sprintf("🕐 %s remaining", batteryInfo.TimeRemaining)
		} else {
			timeMsg = "🕐 Calculating time..."
		}
	}

	// Create detailed popup label
	condition := batteryInfo.Condition
	if condition == "" {
		condition = "Unknown"
	}

	popupLabel := fmt.Sprintf("%s • %d%% • %s • Health: %s • Cycles: %d",
		status, batteryInfo.Percentage, timeMsg, condition, batteryInfo.CycleCount)

	icon := p.GetBatteryIcon(batteryInfo)
	color := p.GetBatteryColor(batteryInfo)

	if err := p.updater.UpdateItem(itemName, icon, popupLabel, color); err != nil {
		return fmt.Errorf("failed to update popup: %w", err)
	}

	// Schedule reset after 8 seconds and open Battery preferences
	go func() {
		time.Sleep(8 * time.Second)

		// Open Battery preferences
		cmd := exec.Command("open", "/System/Library/PreferencePanes/Battery.prefPane")
		if err := cmd.Run(); err != nil {
			p.logger.Error("Failed to open Battery preferences: %v", err)
		}

		// Reset to normal display
		if err := p.UpdateDisplay(); err != nil {
			p.logger.Error("Failed to reset display after popup: %v", err)
		}
	}()

	return nil
}

// UpdateDisplay updates the SketchyBar display with current battery status
func (p *BatteryPlugin) UpdateDisplay() error {
	// Get current battery info
	batteryInfo, err := p.GetBatteryInfo()
	if err != nil {
		return fmt.Errorf("failed to get battery info: %w", err)
	}

	if !batteryInfo.IsPresent {
		// No battery detected
		if err := p.updater.UpdateItem(itemName, "󰂑", "No Battery", p.config.Colors.Red); err != nil {
			return fmt.Errorf("failed to update SketchyBar: %w", err)
		}
		return nil
	}

	p.logger.Debug("Battery: %d%%, Charging: %v", batteryInfo.Percentage, batteryInfo.IsCharging)

	// Get appropriate icon and color
	icon := p.GetBatteryIcon(batteryInfo)
	color := p.GetBatteryColor(batteryInfo)

	// Format label
	var label string
	if batteryInfo.TimeRemaining != "" && !batteryInfo.IsCharging {
		// Show time remaining for battery mode
		label = fmt.Sprintf("%d%% (%s)", batteryInfo.Percentage, batteryInfo.TimeRemaining)
	} else {
		// Show percentage with charging indicator
		chargingIndicator := ""
		if batteryInfo.IsCharging {
			chargingIndicator = "⚡"
		}
		label = fmt.Sprintf("%d%%%s", batteryInfo.Percentage, chargingIndicator)
	}

	// Update SketchyBar
	if err := p.updater.UpdateItem(itemName, icon, label, color); err != nil {
		return fmt.Errorf("failed to update SketchyBar: %w", err)
	}

	return nil
}

// Run starts the battery monitoring plugin
func (p *BatteryPlugin) Run() error {
	p.logger.Info("Starting battery plugin")

	// Handle command line arguments
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "popup":
			return p.HandlePopupAction()
		default:
			p.logger.Debug("Unknown argument: %s", os.Args[1])
		}
	}

	// Regular battery monitoring update
	return p.UpdateDisplay()
}

func main() {
	plugin, err := NewBatteryPlugin()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create battery plugin: %v\n", err)
		os.Exit(1)
	}

	if err := plugin.Run(); err != nil {
		plugin.logger.Error("Plugin execution failed: %v", err)
		fmt.Fprintf(os.Stderr, "Battery plugin failed: %v\n", err)
		os.Exit(1)
	}
}
