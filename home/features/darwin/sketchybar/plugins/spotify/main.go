package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"sketchybar-plugins/config"
	"sketchybar-plugins/utils"
)

const (
	pluginName = "spotify"
	itemName   = "spotify"
)

// SpotifyPlugin handles Spotify media control for SketchyBar
type SpotifyPlugin struct {
	config  *config.GlobalConfig
	logger  *utils.Logger
	updater *utils.SketchyBarUpdater
	sysinfo *utils.SystemInfo
	cache   *utils.CacheManager // Cache for Spotify data
}

// SpotifyInfo represents current Spotify status
type SpotifyInfo struct {
	IsRunning bool
	State     string // "playing", "paused", "stopped"
	Track     string
	Artist    string
	Icon      string
	Color     string
	Label     string
}

// NewSpotifyPlugin creates a new Spotify media control plugin
func NewSpotifyPlugin() (*SpotifyPlugin, error) {
	cfg, err := config.LoadConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to load config: %w", err)
	}

	logger := utils.NewLogger(pluginName)
	updater := utils.NewSketchyBarUpdater(cfg)
	sysinfo := utils.NewSystemInfo(cfg, logger)

	// Initialize cache for Spotify data
	cacheDir := os.ExpandEnv("$HOME/.cache/sketchybar/spotify.db")
	cache, err := utils.NewCacheManager(cacheDir, 2) // 2-second default TTL for responsive media control
	if err != nil {
		logger.Warning("Failed to initialize Spotify cache: %v", err)
		cache = nil
	}

	return &SpotifyPlugin{
		config:  cfg,
		logger:  logger,
		updater: updater,
		sysinfo: sysinfo,
		cache:   cache,
	}, nil
}

// GetSpotifyInfo gets current Spotify playback information with caching
func (p *SpotifyPlugin) GetSpotifyInfo() (*SpotifyInfo, error) {
	// Check cache first
	if p.cache != nil {
		if cached := p.getCachedSpotifyInfo(); cached != nil {
			p.logger.Debug("Using cached Spotify info (state: %s, track: %s)", cached.State, cached.Track)
			return cached, nil
		}
	}

	info := &SpotifyInfo{}

	// Check if Spotify is running
	if !p.isSpotifyRunning() {
		info.IsRunning = false
		info.Icon = "󰓇"
		info.Label = "Not playing"
		info.Color = p.config.Colors.Overlay2
		p.cacheSpotifyInfo(info) // Cache negative result too
		return info, nil
	}

	info.IsRunning = true

	// Use combined AppleScript call instead of 3 separate calls
	if err := p.getSpotifyInfoOptimized(info); err == nil {
		p.cacheSpotifyInfo(info)
		return info, nil
	}

	// Fallback: Use individual calls if combined method fails
	p.logger.Debug("Optimized Spotify method failed, using fallback")
	return p.getSpotifyInfoFallback(info)
}

// getCachedSpotifyInfo retrieves cached Spotify information
func (p *SpotifyPlugin) getCachedSpotifyInfo() *SpotifyInfo {
	if p.cache == nil {
		return nil
	}

	key := "spotify_info"
	if cached, exists := p.cache.Get(key); exists {
		if info, ok := cached.(*SpotifyInfo); ok {
			return info
		}
	}
	return nil
}

// cacheSpotifyInfo stores Spotify information with short TTL for responsiveness
func (p *SpotifyPlugin) cacheSpotifyInfo(info *SpotifyInfo) {
	if p.cache == nil {
		return
	}

	key := "spotify_info"
	ttl := int64(1) // 1 second - very responsive for media control
	if err := p.cache.Set(key, info, ttl); err != nil {
		p.logger.Warning("Failed to cache Spotify info: %v", err)
	}
}

// Single AppleScript call for all Spotify data
func (p *SpotifyPlugin) getSpotifyInfoOptimized(info *SpotifyInfo) error {
	// Combined AppleScript call - much faster than 3 separate calls
	cmd := exec.Command("osascript", "-e", `
		tell application "Spotify"
			set playerState to player state as string
			set trackName to ""
			set artistName to ""
			try
				if player state is not stopped then
					set trackName to name of current track as string
					set artistName to artist of current track as string
				end if
			end try
			return playerState & "|" & trackName & "|" & artistName
		end tell
	`)

	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("optimized Spotify script failed: %w", err)
	}

	// Parse combined output
	outputStr := strings.TrimSpace(string(output))
	parts := strings.Split(outputStr, "|")
	if len(parts) != 3 {
		return fmt.Errorf("unexpected Spotify script output format: %s", outputStr)
	}

	// Parse state
	info.State = parts[0]

	// Parse track and artist (only if playing/paused)
	if info.State == "playing" || info.State == "paused" {
		if parts[1] != "" {
			info.Track = p.truncateString(parts[1], 20)
		}
		if parts[2] != "" {
			info.Artist = p.truncateString(parts[2], 15)
		}
	}

	// Set display elements based on state
	p.setDisplayElements(info)

	return nil
}

// getSpotifyInfoFallback uses individual calls as fallback
func (p *SpotifyPlugin) getSpotifyInfoFallback(info *SpotifyInfo) (*SpotifyInfo, error) {
	// Get Spotify state
	state, err := p.getSpotifyState()
	if err != nil {
		p.logger.Debug("Failed to get Spotify state: %v", err)
		info.State = "stopped"
	} else {
		info.State = state
	}

	// Get track information if playing or paused
	if info.State == "playing" || info.State == "paused" {
		track, artist, err := p.getTrackInfo()
		if err != nil {
			p.logger.Debug("Failed to get track info: %v", err)
		} else {
			info.Track = p.truncateString(track, 20)
			info.Artist = p.truncateString(artist, 15)
		}
	}

	// Set display elements based on state
	p.setDisplayElements(info)

	// Cache the fallback result
	p.cacheSpotifyInfo(info)

	return info, nil
}

// isSpotifyRunning checks if Spotify application is running
func (p *SpotifyPlugin) isSpotifyRunning() bool {
	cmd := exec.Command("pgrep", "-x", "Spotify")
	err := cmd.Run()
	return err == nil
}

// getSpotifyState gets the current playback state from Spotify
func (p *SpotifyPlugin) getSpotifyState() (string, error) {
	cmd := exec.Command("osascript", "-e", "tell application \"Spotify\" to player state as string")
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to get Spotify state: %w", err)
	}

	state := strings.TrimSpace(string(output))
	return state, nil
}

// getTrackInfo gets current track name and artist from Spotify
func (p *SpotifyPlugin) getTrackInfo() (string, string, error) {
	// Get track name
	trackCmd := exec.Command("osascript", "-e", "tell application \"Spotify\" to name of current track as string")
	trackOutput, err := trackCmd.Output()
	if err != nil {
		return "", "", fmt.Errorf("failed to get track name: %w", err)
	}
	track := strings.TrimSpace(string(trackOutput))

	// Get artist name
	artistCmd := exec.Command("osascript", "-e", "tell application \"Spotify\" to artist of current track as string")
	artistOutput, err := artistCmd.Output()
	if err != nil {
		return "", "", fmt.Errorf("failed to get artist name: %w", err)
	}
	artist := strings.TrimSpace(string(artistOutput))

	return track, artist, nil
}

// truncateString truncates a string to specified length with ellipsis
func (p *SpotifyPlugin) truncateString(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen-3] + "..."
}

// setDisplayElements sets the appropriate icon, color, and label based on Spotify state
func (p *SpotifyPlugin) setDisplayElements(info *SpotifyInfo) {
	switch info.State {
	case "playing":
		info.Icon = "󰏤" // Playing icon
		info.Color = p.config.Colors.Green
		if info.Track != "" && info.Artist != "" {
			info.Label = fmt.Sprintf("%s - %s", info.Artist, info.Track)
		} else {
			info.Label = "Playing"
		}
	case "paused":
		info.Icon = "󰐊" // Paused icon
		info.Color = p.config.Colors.Yellow
		if info.Track != "" && info.Artist != "" {
			info.Label = fmt.Sprintf("%s - %s", info.Artist, info.Track)
		} else {
			info.Label = "Paused"
		}
	default:
		info.Icon = "󰓇" // Spotify icon
		info.Color = p.config.Colors.Overlay2
		info.Label = "Ready"
	}
}

// HandleToggleAction toggles Spotify play/pause
func (p *SpotifyPlugin) HandleToggleAction() error {
	p.logger.Info("Toggling Spotify play/pause")

	cmd := exec.Command("osascript", "-e", "tell application \"Spotify\" to playpause")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to toggle Spotify: %w", err)
	}

	// Update display after toggle
	return p.UpdateDisplay()
}

// UpdateDisplay updates the SketchyBar display with current Spotify status
func (p *SpotifyPlugin) UpdateDisplay() error {
	// Get current Spotify info
	spotifyInfo, err := p.GetSpotifyInfo()
	if err != nil {
		return fmt.Errorf("failed to get Spotify info: %w", err)
	}

	p.logger.Debug("Spotify: running=%v, state=%s, track=%s, artist=%s",
		spotifyInfo.IsRunning, spotifyInfo.State, spotifyInfo.Track, spotifyInfo.Artist)

	// Update SketchyBar with enhanced styling for media controls
	if err := p.updater.UpdateItemDetailed(itemName, spotifyInfo.Icon, spotifyInfo.Label,
		spotifyInfo.Color, p.config.Colors.Text, p.config.Colors.Surface0); err != nil {
		return fmt.Errorf("failed to update SketchyBar: %w", err)
	}

	return nil
}

// Run starts the Spotify monitoring plugin
func (p *SpotifyPlugin) Run() error {
	p.logger.Info("Starting Spotify plugin")

	// 🛠️ MEDIA CHANGE FIX: Check if triggered by media events
	sender := os.Getenv("SENDER")
	if sender == "media_change" {
		p.logger.Info("Media status changed - forcing immediate Spotify refresh")
		// Force immediate update when media state changes
		return p.UpdateDisplay()
	}

	// Handle command line arguments
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "toggle":
			return p.HandleToggleAction()
		default:
			p.logger.Debug("Unknown argument: %s", os.Args[1])
		}
	}

	// Regular Spotify status update
	return p.UpdateDisplay()
}

func main() {
	plugin, err := NewSpotifyPlugin()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create Spotify plugin: %v\n", err)
		os.Exit(1)
	}

	if err := plugin.Run(); err != nil {
		plugin.logger.Error("Plugin execution failed: %v", err)
		fmt.Fprintf(os.Stderr, "Spotify plugin failed: %v\n", err)
		os.Exit(1)
	}
}
