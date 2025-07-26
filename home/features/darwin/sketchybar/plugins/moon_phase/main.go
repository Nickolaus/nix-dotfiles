package main

import (
	"fmt"
	"os"
	"time"

	"sketchybar-plugins/config"
	"sketchybar-plugins/utils"
)

const (
	pluginName = "moon_phase"
	itemName   = "moon_phase"
)

// MoonPhasePlugin handles moon phase calculation for SketchyBar
type MoonPhasePlugin struct {
	config  *config.GlobalConfig
	logger  *utils.Logger
	updater *utils.SketchyBarUpdater
	sysinfo *utils.SystemInfo
	cache   *utils.CacheManager // Cache for slowly-changing moon phases
}

// MoonPhaseInfo represents current lunar status
type MoonPhaseInfo struct {
	Phase    string
	Emoji    string
	CycleDay int
	Percent  float64
}

// NewMoonPhasePlugin creates a new moon phase plugin
func NewMoonPhasePlugin() (*MoonPhasePlugin, error) {
	cfg, err := config.LoadConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to load config: %w", err)
	}

	logger := utils.NewLogger(pluginName)
	updater := utils.NewSketchyBarUpdater(cfg)
	sysinfo := utils.NewSystemInfo(cfg, logger)

	// Cache for moon phase data (changes very slowly)
	cacheDir := os.ExpandEnv("$HOME/.cache/sketchybar/moon_phase.db")
	cache, err := utils.NewCacheManager(cacheDir, 3600) // 1-hour default TTL (moon phases change slowly)
	if err != nil {
		logger.Warning("Failed to initialize moon phase cache: %v", err)
		cache = nil
	}

	return &MoonPhasePlugin{
		config:  cfg,
		logger:  logger,
		updater: updater,
		sysinfo: sysinfo,
		cache:   cache,
	}, nil
}

// GetMoonPhase calculates the current moon phase with aggressive caching
func (p *MoonPhasePlugin) GetMoonPhase() (*MoonPhaseInfo, error) {
	// Check cache first - moon phases change very slowly
	if p.cache != nil {
		if cached := p.getCachedMoonPhase(); cached != nil {
			p.logger.Debug("Using cached moon phase: %s (%s)", cached.Phase, cached.Emoji)
			return cached, nil
		}
	}

	info := &MoonPhaseInfo{}

	// Constants for lunar calculation
	// Jan 6, 2000 00:00:00 UTC was a new moon (reference point)
	newMoonRef := time.Date(2000, 1, 6, 0, 0, 0, 0, time.UTC)
	lunarCycleDays := 29.53059 // Average lunar cycle in days

	// Calculate days since reference new moon
	now := time.Now().UTC()
	daysSinceRef := now.Sub(newMoonRef).Hours() / 24

	// Calculate current position in lunar cycle
	cyclePosition := daysSinceRef - float64(int(daysSinceRef/lunarCycleDays))*lunarCycleDays

	// Ensure positive value
	if cyclePosition < 0 {
		cyclePosition += lunarCycleDays
	}

	info.CycleDay = int(cyclePosition)
	info.Percent = (cyclePosition / lunarCycleDays) * 100

	// Determine moon phase based on cycle position
	switch {
	case cyclePosition < 1:
		info.Emoji = "🌑"
		info.Phase = "New"
	case cyclePosition < 7:
		info.Emoji = "🌒"
		info.Phase = "Waxing Crescent"
	case cyclePosition < 9:
		info.Emoji = "🌓"
		info.Phase = "First Quarter"
	case cyclePosition < 15:
		info.Emoji = "🌔"
		info.Phase = "Waxing Gibbous"
	case cyclePosition < 16:
		info.Emoji = "🌕"
		info.Phase = "Full"
	case cyclePosition < 22:
		info.Emoji = "🌖"
		info.Phase = "Waning Gibbous"
	case cyclePosition < 24:
		info.Emoji = "🌗"
		info.Phase = "Last Quarter"
	default:
		info.Emoji = "🌘"
		info.Phase = "Waning Crescent"
	}

	// Cache the result for 6 hours (moon phases change very slowly)
	p.cacheMoonPhase(info)

	return info, nil
}

// getCachedMoonPhase retrieves cached moon phase information
func (p *MoonPhasePlugin) getCachedMoonPhase() *MoonPhaseInfo {
	if p.cache == nil {
		return nil
	}

	key := "moon_phase_info"
	if cached, exists := p.cache.Get(key); exists {
		if info, ok := cached.(*MoonPhaseInfo); ok {
			return info
		}
	}
	return nil
}

// cacheMoonPhase stores moon phase information with aggressive caching
func (p *MoonPhasePlugin) cacheMoonPhase(info *MoonPhaseInfo) {
	if p.cache == nil {
		return
	}

	key := "moon_phase_info"
	ttl := int64(6 * 3600) // 6 hours - moon phases change very slowly
	if err := p.cache.Set(key, info, ttl); err != nil {
		p.logger.Warning("Failed to cache moon phase: %v", err)
	}
}

// UpdateDisplay updates the SketchyBar display with current moon phase
func (p *MoonPhasePlugin) UpdateDisplay() error {
	// Get current moon phase
	moonInfo, err := p.GetMoonPhase()
	if err != nil {
		return fmt.Errorf("failed to get moon phase: %w", err)
	}

	p.logger.Debug("Moon phase: %s (%s), cycle day: %d, percent: %.1f%%",
		moonInfo.Phase, moonInfo.Emoji, moonInfo.CycleDay, moonInfo.Percent)

	// Update SketchyBar with moon phase
	// No label, just the emoji icon
	if err := p.updater.UpdateItem(itemName, moonInfo.Emoji, "", p.config.Colors.Text); err != nil {
		return fmt.Errorf("failed to update SketchyBar: %w", err)
	}

	return nil
}

// Run starts the moon phase plugin
func (p *MoonPhasePlugin) Run() error {
	p.logger.Info("Starting moon phase plugin")

	// Moon phase plugin doesn't have special command line arguments
	// It just displays the current phase
	return p.UpdateDisplay()
}

func main() {
	plugin, err := NewMoonPhasePlugin()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create moon phase plugin: %v\n", err)
		os.Exit(1)
	}

	if err := plugin.Run(); err != nil {
		plugin.logger.Error("Plugin execution failed: %v", err)
		fmt.Fprintf(os.Stderr, "Moon phase plugin failed: %v\n", err)
		os.Exit(1)
	}
}
