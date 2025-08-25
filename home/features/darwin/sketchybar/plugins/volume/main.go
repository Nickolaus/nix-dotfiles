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
	pluginName = "volume"
	itemName   = "volume"
)

// VolumePlugin handles audio monitoring and control for SketchyBar
type VolumePlugin struct {
	config       *config.GlobalConfig
	logger       *utils.Logger
	updater      *utils.SketchyBarUpdater
	sysinfo      *utils.SystemInfo
	cache        *utils.CacheManager // Cache for audio settings
	colorManager *VolumeColorManager
}

// VolumeInfo represents current audio status
type VolumeInfo struct {
	Volume        int
	IsMuted       bool
	CurrentDevice string
}

// NewVolumePlugin creates a new volume monitoring plugin
func NewVolumePlugin() (*VolumePlugin, error) {
	cfg, err := config.LoadConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to load config: %w", err)
	}

	logger := utils.NewLogger(pluginName)
	updater := utils.NewSketchyBarUpdater(cfg)
	sysinfo := utils.NewSystemInfo(cfg, logger)

	// Initialize cache for audio settings
	cacheDir := os.ExpandEnv("$HOME/.cache/sketchybar/volume.db")
	cache, err := utils.NewCacheManager(cacheDir, 5) // 5-second default TTL for responsive audio
	if err != nil {
		logger.Warning("Failed to initialize volume cache: %v", err)
		cache = nil
	}

	return &VolumePlugin{
		config:       cfg,
		logger:       logger,
		updater:      updater,
		sysinfo:      sysinfo,
		cache:        cache,
		colorManager: NewVolumeColorManager(),
	}, nil
}

// GetVolumeInfo gets current audio status with caching
func (p *VolumePlugin) GetVolumeInfo() (*VolumeInfo, error) {
	// Check cache first
	if p.cache != nil {
		if cached := p.getCachedVolumeInfo(); cached != nil {
			p.logger.Debug("Using cached volume info (vol: %d%%, muted: %t)", cached.Volume, cached.IsMuted)
			return cached, nil
		}
	}

	info := &VolumeInfo{}

	// Combine multiple AppleScript calls into single call
	if err := p.getVolumeInfoOptimized(info); err == nil {
		p.cacheVolumeInfo(info)
		return info, nil
	}

	// Fallback: Use individual calls if combined method fails
	p.logger.Debug("Optimized volume method failed, using fallback")
	return p.getVolumeInfoFallback(info)
}

// getCachedVolumeInfo retrieves cached volume information
func (p *VolumePlugin) getCachedVolumeInfo() *VolumeInfo {
	if p.cache == nil {
		return nil
	}

	key := "volume_info"
	if cached, exists := p.cache.Get(key); exists {
		if info, ok := cached.(*VolumeInfo); ok {
			return info
		}
	}
	return nil
}

// cacheVolumeInfo stores volume information with short TTL for responsiveness
func (p *VolumePlugin) cacheVolumeInfo(info *VolumeInfo) {
	if p.cache == nil {
		return
	}

	key := "volume_info"
	ttl := int64(3) // 3 seconds cache TTL
	if err := p.cache.Set(key, info, ttl); err != nil {
		p.logger.Warning("Failed to cache volume info: %v", err)
	}
}

// 🚀 OPTIMIZED METHOD: Single AppleScript call for all volume data
func (p *VolumePlugin) getVolumeInfoOptimized(info *VolumeInfo) error {
	// Combined AppleScript call - much faster than multiple separate calls
	cmd := exec.Command("osascript", "-e", `
		set volSettings to get volume settings
		set volLevel to output volume of volSettings
		set volMuted to output muted of volSettings
		return (volLevel as string) & "|" & (volMuted as string)
	`)

	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("optimized volume script failed: %w", err)
	}

	// Parse combined output
	outputStr := strings.TrimSpace(string(output))
	parts := strings.Split(outputStr, "|")
	if len(parts) != 2 {
		return fmt.Errorf("unexpected volume script output format: %s", outputStr)
	}

	// Parse volume level
	if volume, err := strconv.Atoi(parts[0]); err == nil {
		info.Volume = volume
	} else {
		return fmt.Errorf("failed to parse volume level: %s", parts[0])
	}

	// Parse mute status
	info.IsMuted = parts[1] == "true"

	// Get current audio device (cached separately with longer TTL)
	if device := p.getCachedCurrentDevice(); device != "" {
		info.CurrentDevice = device
	} else {
		p.getCurrentDeviceOptimized(info)
	}

	return nil
}

// getVolumeInfoFallback uses individual calls as fallback
func (p *VolumePlugin) getVolumeInfoFallback(info *VolumeInfo) (*VolumeInfo, error) {
	// Get volume level
	cmd := exec.Command("osascript", "-e", "output volume of (get volume settings)")
	output, err := cmd.Output()
	if err != nil {
		return info, fmt.Errorf("failed to get volume: %w", err)
	}

	volumeStr := strings.TrimSpace(string(output))
	if volume, err := strconv.Atoi(volumeStr); err == nil {
		info.Volume = volume
	}

	// Get mute status
	cmd = exec.Command("osascript", "-e", "output muted of (get volume settings)")
	output, err = cmd.Output()
	if err != nil {
		return info, fmt.Errorf("failed to get mute status: %w", err)
	}

	muteStr := strings.TrimSpace(string(output))
	info.IsMuted = muteStr == "true"

	// Cache the result and get current device
	if err := p.getCurrentDevice(info); err != nil {
		p.logger.Debug("Failed to get current device: %v", err)
	}

	// Cache the fallback result
	p.cacheVolumeInfo(info)

	return info, nil
}

// getCachedCurrentDevice retrieves cached current audio device
func (p *VolumePlugin) getCachedCurrentDevice() string {
	if p.cache == nil {
		return ""
	}

	key := "current_device"
	if cached, exists := p.cache.Get(key); exists {
		if device, ok := cached.(string); ok {
			return device
		}
	}
	return ""
}

// getCurrentDeviceOptimized gets current device with caching
func (p *VolumePlugin) getCurrentDeviceOptimized(info *VolumeInfo) {
	// Try to get current device and cache it
	if err := p.getCurrentDevice(info); err == nil && p.cache != nil {
		// Cache device name for 30 seconds (longer than volume info)
		key := "current_device"
		ttl := int64(30) // Device changes less frequently than volume
		if setErr := p.cache.Set(key, info.CurrentDevice, ttl); setErr != nil {
			p.logger.Warning("Failed to cache current device: %v", setErr)
		}
	}
}

// getCurrentDevice gets the current audio output device
func (p *VolumePlugin) getCurrentDevice(info *VolumeInfo) error {
	cmd := exec.Command("SwitchAudioSource", "-c")
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("SwitchAudioSource not available: %w", err)
	}

	device := strings.TrimSpace(string(output))
	// Shorten device name for display
	if len(device) > 12 {
		device = device[:9] + "..."
	}
	info.CurrentDevice = device

	return nil
}

// HandleToggleAction toggles mute/unmute
func (p *VolumePlugin) HandleToggleAction() error {
	p.logger.Info("Toggling mute/unmute")

	cmd := exec.Command("osascript", "-e", "set volume output muted not (output muted of (get volume settings))")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to toggle mute: %w", err)
	}

	// Update display after toggle
	return p.UpdateDisplay()
}

// HandleDeviceSwitch cycles through available audio devices
func (p *VolumePlugin) HandleDeviceSwitch() error {
	p.logger.Info("Switching audio device")

	// Get current device
	currentCmd := exec.Command("SwitchAudioSource", "-c")
	currentOutput, err := currentCmd.Output()
	if err != nil {
		return fmt.Errorf("failed to get current device: %w", err)
	}
	currentDevice := strings.TrimSpace(string(currentOutput))

	// Get all available output devices
	allCmd := exec.Command("SwitchAudioSource", "-a", "-t", "output")
	allOutput, err := allCmd.Output()
	if err != nil {
		return fmt.Errorf("failed to get available devices: %w", err)
	}

	devices := strings.Split(strings.TrimSpace(string(allOutput)), "\n")
	if len(devices) <= 1 {
		p.logger.Debug("Only one or no audio devices available")
		return nil
	}

	// Find next device in list
	var nextDevice string
	foundCurrent := false

	for i, device := range devices {
		device = strings.TrimSpace(device)
		if device == "" {
			continue
		}

		if foundCurrent {
			nextDevice = device
			break
		}

		if device == currentDevice {
			foundCurrent = true
			// If this is the last device, wrap to first
			if i == len(devices)-1 {
				nextDevice = devices[0]
			}
		}
	}

	// If no next device found, wrap to first
	if nextDevice == "" && len(devices) > 0 {
		nextDevice = devices[0]
	}

	if nextDevice == "" {
		return fmt.Errorf("no suitable next device found")
	}

	// Switch to next device
	switchCmd := exec.Command("SwitchAudioSource", "-s", nextDevice)
	if err := switchCmd.Run(); err != nil {
		return fmt.Errorf("failed to switch device: %w", err)
	}

	p.logger.Debug("Switched audio device from '%s' to '%s'", currentDevice, nextDevice)

	// Show temporary notification
	deviceName := nextDevice
	if len(deviceName) > 12 {
		deviceName = deviceName[:9] + "..."
	}

	icon := p.GetVolumeIcon(&VolumeInfo{Volume: 50, IsMuted: false}) // Use default icon
	notificationLabel := fmt.Sprintf("→ %s", deviceName)

	if err := p.updater.UpdateItem(itemName, icon, notificationLabel, p.colorManager.GetNotificationColor()); err != nil {
		return fmt.Errorf("failed to update notification: %w", err)
	}

	// Reset to normal display after 2 seconds
	go func() {
		time.Sleep(2 * time.Second)
		if err := p.UpdateDisplay(); err != nil {
			p.logger.Error("Failed to reset display after device switch: %v", err)
		}
	}()

	return nil
}

// HandleVolumeUp increases volume by 5%
func (p *VolumePlugin) HandleVolumeUp() error {
	p.logger.Info("Increasing volume")

	// Get current volume
	cmd := exec.Command("osascript", "-e", "output volume of (get volume settings)")
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to get current volume: %w", err)
	}

	currentStr := strings.TrimSpace(string(output))
	current, err := strconv.Atoi(currentStr)
	if err != nil {
		return fmt.Errorf("failed to parse current volume: %w", err)
	}

	// Increase by 5%, cap at 100
	newVolume := current + 5
	if newVolume > 100 {
		newVolume = 100
	}

	// Set new volume
	cmd = exec.Command("osascript", "-e", fmt.Sprintf("set volume output volume %d", newVolume))
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to set volume: %w", err)
	}

	// Update display
	return p.UpdateDisplay()
}

// HandleVolumeDown decreases volume by 5%
func (p *VolumePlugin) HandleVolumeDown() error {
	p.logger.Info("Decreasing volume")

	// Get current volume
	cmd := exec.Command("osascript", "-e", "output volume of (get volume settings)")
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to get current volume: %w", err)
	}

	currentStr := strings.TrimSpace(string(output))
	current, err := strconv.Atoi(currentStr)
	if err != nil {
		return fmt.Errorf("failed to parse current volume: %w", err)
	}

	// Decrease by 5%, floor at 0
	newVolume := current - 5
	if newVolume < 0 {
		newVolume = 0
	}

	// Set new volume
	cmd = exec.Command("osascript", "-e", fmt.Sprintf("set volume output volume %d", newVolume))
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to set volume: %w", err)
	}

	// Update display
	return p.UpdateDisplay()
}

// GetVolumeIcon returns appropriate volume icon based on level and mute status
func (p *VolumePlugin) GetVolumeIcon(info *VolumeInfo) string {
	if info.IsMuted {
		return "󰸈" // Muted icon
	}

	switch {
	case info.Volume >= 80:
		return "󰕾" // High volume
	case info.Volume >= 60:
		return "󰖀" // Medium-high volume
	case info.Volume >= 30:
		return "󰕿" // Medium volume
	case info.Volume >= 10:
		return "󰖁" // Low volume
	case info.Volume > 0:
		return "󰕿" // Very low volume
	default:
		return "󰖁" // Zero volume
	}
}

// GetVolumeColor returns appropriate color using standardized color logic
func (p *VolumePlugin) GetVolumeColor(info *VolumeInfo) string {
	return p.colorManager.GetVolumeColor(info)
}

// UpdateDisplay updates the SketchyBar display with current volume status
func (p *VolumePlugin) UpdateDisplay() error {
	// Get current volume info
	volumeInfo, err := p.GetVolumeInfo()
	if err != nil {
		return fmt.Errorf("failed to get volume info: %w", err)
	}

	p.logger.Debug("Volume: %d%%, Muted: %v, Device: %s",
		volumeInfo.Volume, volumeInfo.IsMuted, volumeInfo.CurrentDevice)

	// Get appropriate icon and color
	icon := p.GetVolumeIcon(volumeInfo)
	color := p.GetVolumeColor(volumeInfo)

	// Format label
	var label string
	if volumeInfo.IsMuted {
		if volumeInfo.CurrentDevice != "" {
			label = fmt.Sprintf("Muted (%s)", volumeInfo.CurrentDevice)
		} else {
			label = "Muted"
		}
	} else {
		if volumeInfo.CurrentDevice != "" {
			label = fmt.Sprintf("%d%% (%s)", volumeInfo.Volume, volumeInfo.CurrentDevice)
		} else {
			label = fmt.Sprintf("%d%%", volumeInfo.Volume)
		}
	}

	// Update SketchyBar
	if err := p.updater.UpdateItem(itemName, icon, label, color); err != nil {
		return fmt.Errorf("failed to update SketchyBar: %w", err)
	}

	return nil
}

// Run starts the volume monitoring plugin
func (p *VolumePlugin) Run() error {
	p.logger.Info("Starting volume plugin")

	// Handle command line arguments
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "toggle":
			return p.HandleToggleAction()
		case "device":
			return p.HandleDeviceSwitch()
		case "up":
			return p.HandleVolumeUp()
		case "down":
			return p.HandleVolumeDown()
		default:
			p.logger.Debug("Unknown argument: %s", os.Args[1])
		}
	}

	// Regular volume monitoring update
	return p.UpdateDisplay()
}

func main() {
	plugin, err := NewVolumePlugin()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create volume plugin: %v\n", err)
		os.Exit(1)
	}

	if err := plugin.Run(); err != nil {
		plugin.logger.Error("Plugin execution failed: %v", err)
		fmt.Fprintf(os.Stderr, "Volume plugin failed: %v\n", err)
		os.Exit(1)
	}
}
