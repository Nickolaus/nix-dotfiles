package main

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"sketchybar-plugins/config"
	"sketchybar-plugins/utils"
)

const (
	pluginName = "memory"
	itemName   = "memory"
)

// MemoryPlugin handles memory monitoring for SketchyBar with Apple Silicon support
type MemoryPlugin struct {
	config  *config.GlobalConfig
	logger  *utils.Logger
	updater *utils.SketchyBarUpdater
	history *utils.HistoryManager
	trends  *utils.TrendGraph
	cache   *utils.CacheManager // Isolated cache for memory plugin
}

// NewMemoryPlugin creates a new memory monitoring plugin
func NewMemoryPlugin() (*MemoryPlugin, error) {
	cfg, err := config.LoadConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to load config: %w", err)
	}

	logger := utils.NewLogger(pluginName)
	updater := utils.NewSketchyBarUpdater(cfg)
	history := utils.NewHistoryManager(cfg, logger)
	trends := utils.NewTrendGraph(cfg, logger)

	// ISOLATED CACHE: Each plugin gets its own dedicated cache
	cacheDir := os.ExpandEnv("$HOME/.cache/sketchybar/memory.db")
	cache, err := utils.NewCacheManager(cacheDir, 300) // 5 minute default TTL
	if err != nil {
		logger.Warning("Failed to initialize memory cache: %v", err)
		cache = nil
	}

	return &MemoryPlugin{
		config:  cfg,
		logger:  logger,
		updater: updater,
		history: history,
		trends:  trends,
		cache:   cache,
	}, nil
}

// MemoryInfo represents detailed memory information
type MemoryInfo struct {
	UsedGB        float64
	TotalGB       float64
	UsagePercent  float64
	SystemTotalGB int
}

// VMStatOutput represents parsed vm_stat output
type VMStatOutput struct {
	PageSize    int
	TotalPages  int
	UsedPages   int
	FreePages   int
	ActivePages int
	WiredPages  int
}

// GetMemoryInfo gets detailed memory information optimized for Apple Silicon
func (p *MemoryPlugin) GetMemoryInfo() (*MemoryInfo, error) {
	// Use vm_stat for Apple Silicon optimized memory info
	vmStatOutput, err := p.getVMStat()
	if err != nil {
		return nil, fmt.Errorf("failed to get vm_stat info: %w", err)
	}

	// Get system total memory from hardware profiler (includes GPU/Neural Engine reserved memory)
	systemTotalGB := p.getSystemTotalMemoryGB()
	if systemTotalGB == 0 {
		p.logger.Debug("Could not get system memory from hardware profiler, using vm_stat calculation")
		systemTotalGB = int(vmStatOutput.TotalPages * vmStatOutput.PageSize / 1024 / 1024 / 1024)
	}

	// Calculate usable memory statistics
	totalUsableBytes := vmStatOutput.TotalPages * vmStatOutput.PageSize
	usedBytes := vmStatOutput.UsedPages * vmStatOutput.PageSize

	// Convert to GB with precision
	usedGB := float64(usedBytes) / 1024 / 1024 / 1024
	totalUsableGB := float64(totalUsableBytes) / 1024 / 1024 / 1024

	// Calculate percentage based on usable memory pool (not including GPU/Neural Engine reserved)
	usagePercent := float64(usedBytes) / float64(totalUsableBytes) * 100

	// Clamp percentage to valid range
	if usagePercent < 0 {
		usagePercent = 0
	} else if usagePercent > 100 {
		usagePercent = 100
	}

	return &MemoryInfo{
		UsedGB:        usedGB,
		TotalGB:       totalUsableGB,
		UsagePercent:  usagePercent,
		SystemTotalGB: systemTotalGB,
	}, nil
}

// getSystemTotalMemoryGB gets total system memory using isolated cache (24 hour TTL)
func (p *MemoryPlugin) getSystemTotalMemoryGB() int {
	if p.cache == nil {
		return p.detectTotalMemoryFromSystem()
	}

	key := "system_total_memory_gb"

	// ISOLATED CACHE: Use memory plugin's own cache instead of shared singleton
	if cached, exists := p.cache.Get(key); exists {
		if memory, ok := cached.(int); ok {
			p.logger.Debug("Retrieved system memory from isolated cache: %dGB", memory)
			return memory
		}
	}

	// Cache miss - detect total memory directly
	totalMemory := p.detectTotalMemoryFromSystem()

	// Store result with 24-hour TTL (hardware specs don't change)
	if setErr := p.cache.Set(key, totalMemory, 86400); setErr != nil {
		p.logger.Warning("Failed to cache total memory: %v", setErr)
	}

	p.logger.Debug("Detected and cached system memory: %dGB", totalMemory)
	return totalMemory
}

// detectTotalMemoryFromSystem detects total system memory using system_profiler
func (p *MemoryPlugin) detectTotalMemoryFromSystem() int {
	// Try to get memory info from system_profiler
	cmd := exec.Command("system_profiler", "SPHardwareDataType")
	output, err := cmd.Output()
	if err != nil {
		p.logger.Debug("system_profiler failed: %v", err)
		return 48 // Default fallback for Apple Silicon
	}

	// Parse memory from output
	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		if strings.Contains(line, "Memory:") {
			// Extract memory size (e.g., "32 GB", "64 GB")
			parts := strings.Fields(strings.TrimSpace(line))
			for i, part := range parts {
				if part == "GB" && i > 0 {
					if memory, err := strconv.Atoi(parts[i-1]); err == nil {
						p.logger.Debug("Detected system memory: %dGB", memory)
						return memory
					}
				}
			}
		}
	}

	p.logger.Debug("Could not parse system memory, using fallback")
	return 48 // Apple Silicon fallback
}

// getVMStat parses vm_stat output for Apple Silicon optimized memory monitoring
func (p *MemoryPlugin) getVMStat() (*VMStatOutput, error) {
	cmd := exec.Command("vm_stat")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to run vm_stat: %w", err)
	}

	lines := strings.Split(string(output), "\n")
	result := &VMStatOutput{}

	// Parse page size from first line: "Mach Virtual Memory Statistics: (page size of 16384 bytes)"
	for _, line := range lines {
		if strings.Contains(line, "page size of") {
			parts := strings.Fields(line)
			for i, part := range parts {
				if strings.Contains(part, "bytes)") && i > 0 {
					sizeStr := strings.TrimSuffix(parts[i-1], " bytes)")
					if size, err := strconv.Atoi(sizeStr); err == nil {
						result.PageSize = size
						break
					}
				}
			}
		}
	}

	// Default to Apple Silicon page size if not found
	if result.PageSize == 0 {
		result.PageSize = 16384
	}

	// Parse memory statistics
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.Contains(line, "Pages free:") {
			if count := p.parseVMStatLine(line); count >= 0 {
				result.FreePages = count
			}
		} else if strings.Contains(line, "Pages active:") {
			if count := p.parseVMStatLine(line); count >= 0 {
				result.ActivePages = count
			}
		} else if strings.Contains(line, "Pages wired down:") {
			if count := p.parseVMStatLine(line); count >= 0 {
				result.WiredPages = count
			}
		}
	}

	// Calculate totals
	result.TotalPages = result.FreePages + result.ActivePages + result.WiredPages
	result.UsedPages = result.ActivePages + result.WiredPages

	// Add other memory types we might have missed
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.Contains(line, "Pages inactive:") {
			if count := p.parseVMStatLine(line); count >= 0 {
				result.TotalPages += count
			}
		} else if strings.Contains(line, "Pages speculative:") {
			if count := p.parseVMStatLine(line); count >= 0 {
				result.TotalPages += count
			}
		} else if strings.Contains(line, "Pages purgeable:") {
			if count := p.parseVMStatLine(line); count >= 0 {
				result.TotalPages += count
			}
		}
	}

	return result, nil
}

// parseVMStatLine extracts the numeric value from a vm_stat line
func (p *MemoryPlugin) parseVMStatLine(line string) int {
	parts := strings.Fields(line)
	if len(parts) >= 3 {
		// Remove trailing period and parse
		countStr := strings.TrimSuffix(parts[len(parts)-1], ".")
		if count, err := strconv.Atoi(countStr); err == nil {
			return count
		}
	}
	return -1
}

// GetMemoryIcon returns appropriate memory icon based on usage
func (p *MemoryPlugin) GetMemoryIcon(usage float64) string {
	switch {
	case usage > 85:
		return "󰍛" // Memory icon - critical usage
	case usage > 70:
		return "󰍛" // Memory icon - high usage
	case usage > 50:
		return "󰍛" // Memory icon - medium usage
	default:
		return "󰍛" // Memory icon - good usage
	}
}

// HandlePopupAction shows detailed memory information with trend graph
func (p *MemoryPlugin) HandlePopupAction() error {
	p.logger.Info("Showing memory popup")

	// Get current memory info
	memInfo, err := p.GetMemoryInfo()
	if err != nil {
		return fmt.Errorf("failed to get memory info for popup: %w", err)
	}

	// Get historical data
	history, err := p.history.GetHistory("memory_history")
	if err != nil {
		p.logger.Debug("No history available for popup: %v", err)
		history = []float64{memInfo.UsagePercent} // Use current value as fallback
	}

	// Generate trend graph
	trendGraph := p.trends.GenerateTrendGraph(history)

	// Show detailed popup with trend and system info
	popupLabel := fmt.Sprintf("Memory Trend: %s (%.0f%%) | %s",
		trendGraph,
		memInfo.UsagePercent,
		p.formatMemoryDetails(memInfo))

	icon := p.GetMemoryIcon(memInfo.UsagePercent)
	color := p.config.Colors.GetStatusColor(memInfo.UsagePercent, true) // true = reverse (high usage is bad)

	if err := p.updater.UpdateItem(itemName, icon, popupLabel, color); err != nil {
		return fmt.Errorf("failed to update popup: %w", err)
	}

	// Schedule reset after 8 seconds and open Activity Monitor
	go func() {
		time.Sleep(8 * time.Second)

		// Open Activity Monitor
		if err := utils.OpenApplication("Activity Monitor"); err != nil {
			p.logger.Error("Failed to open Activity Monitor: %v", err)
		}

		// Reset to normal display
		if err := p.UpdateDisplay(); err != nil {
			p.logger.Error("Failed to reset display after popup: %v", err)
		}
	}()

	return nil
}

// formatMemoryDetails creates a detailed memory description
func (p *MemoryPlugin) formatMemoryDetails(memInfo *MemoryInfo) string {
	if memInfo.SystemTotalGB >= 32 {
		// For systems with 32GB+ RAM, show decimal precision
		return fmt.Sprintf("%.1fG/%.0fG (System: %dG)",
			memInfo.UsedGB, memInfo.TotalGB, memInfo.SystemTotalGB)
	} else {
		// For smaller RAM configurations, use integer GB
		return fmt.Sprintf("%.0fG/%.0fG (System: %dG)",
			memInfo.UsedGB, memInfo.TotalGB, memInfo.SystemTotalGB)
	}
}

// UpdateDisplay updates the SketchyBar display with current memory usage
func (p *MemoryPlugin) UpdateDisplay() error {
	// Get current memory info
	memInfo, err := p.GetMemoryInfo()
	if err != nil {
		return fmt.Errorf("failed to get memory info: %w", err)
	}

	p.logger.Debug("Memory usage: %.1f%% (%.1fG/%.0fG, System: %dG)",
		memInfo.UsagePercent, memInfo.UsedGB, memInfo.TotalGB, memInfo.SystemTotalGB)

	// Update history
	if err := p.history.AppendValue("memory_history", memInfo.UsagePercent); err != nil {
		p.logger.Error("Failed to update history: %v", err)
		// Non-fatal, continue
	}

	// Get appropriate icon and color
	icon := p.GetMemoryIcon(memInfo.UsagePercent)
	color := p.config.Colors.GetStatusColor(memInfo.UsagePercent, true) // true = reverse (high usage is bad)

	// Format label with appropriate precision
	var label string
	if memInfo.SystemTotalGB >= 32 {
		// High-precision for large RAM systems
		label = fmt.Sprintf("%.1fG/%dG (%.0f%%)",
			memInfo.UsedGB, memInfo.SystemTotalGB, memInfo.UsagePercent)
	} else {
		// Standard precision for smaller systems
		label = fmt.Sprintf("%.0fG/%dG (%.0f%%)",
			memInfo.UsedGB, memInfo.SystemTotalGB, memInfo.UsagePercent)
	}

	// Update SketchyBar
	if err := p.updater.UpdateItem(itemName, icon, label, color); err != nil {
		return fmt.Errorf("failed to update SketchyBar: %w", err)
	}

	return nil
}

// Run starts the memory monitoring plugin
func (p *MemoryPlugin) Run() error {
	p.logger.Info("Starting memory plugin")

	// 🛠️ SLEEP/WAKE FIX: Check if triggered by system events
	sender := os.Getenv("SENDER")
	if sender == "system_woke" {
		p.logger.Info("System woke from sleep - memory state may have changed")
		// Note: Hardware detection cache (24h TTL) stays valid, but current usage should refresh
		// The next GetMemoryInfo call will get fresh usage data while keeping hardware cache
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

	// Regular memory monitoring update
	return p.UpdateDisplay()
}

func main() {
	plugin, err := NewMemoryPlugin()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create memory plugin: %v\n", err)
		os.Exit(1)
	}

	if err := plugin.Run(); err != nil {
		plugin.logger.Error("Plugin execution failed: %v", err)
		fmt.Fprintf(os.Stderr, "Memory plugin failed: %v\n", err)
		os.Exit(1)
	}
}
