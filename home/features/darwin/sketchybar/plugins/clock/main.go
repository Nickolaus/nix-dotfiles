package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"

	"sketchybar-plugins/config"
	"sketchybar-plugins/utils"
)

const (
	pluginName = "clock"
	itemName   = "clock"

	// Cache TTLs for different types of calendar data
	eventsCache_TTL     = 15 * 60 // 15 minutes for today's events
	nextMeetingCacheTTL = 5 * 60  // 5 minutes for next meeting
)

// ClockPlugin handles clock display and calendar integration for SketchyBar
type ClockPlugin struct {
	config  *config.GlobalConfig
	logger  *utils.Logger
	updater *utils.SketchyBarUpdater
	sysinfo *utils.SystemInfo
	cache   *utils.CacheManager
}

// ClockInfo represents current time and calendar status
type ClockInfo struct {
	CurrentTime   string
	IsWeekday     bool
	NextMeeting   string
	TodayEvents   []string
	Indicator     string
	FormattedTime string
}

// NewClockPlugin creates a new clock monitoring plugin
func NewClockPlugin() (*ClockPlugin, error) {
	cfg, err := config.LoadConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to load config: %w", err)
	}

	logger := utils.NewLogger(pluginName)
	updater := utils.NewSketchyBarUpdater(cfg)
	sysinfo := utils.NewSystemInfo(cfg, logger)

	// Initialize cache for clock plugin
	cacheDir := os.ExpandEnv("$HOME/.cache/sketchybar/clock.db")
	cache, err := utils.NewCacheManager(cacheDir, 300) // 5 minute default TTL
	if err != nil {
		logger.Warning("Failed to initialize calendar cache: %v", err)
		cache = nil
	}

	return &ClockPlugin{
		config:  cfg,
		logger:  logger,
		updater: updater,
		sysinfo: sysinfo,
		cache:   cache,
	}, nil
}

// GetClockInfo gets current time and calendar information with aggressive caching
func (p *ClockPlugin) GetClockInfo() (*ClockInfo, error) {
	info := &ClockInfo{}
	now := time.Now()

	// Format current time (always fast)
	info.CurrentTime = now.Format("02.01 15:04")
	info.FormattedTime = now.Format("02.01 15:04")

	// Check if it's a weekday (always fast)
	info.IsWeekday = now.Weekday() >= time.Monday && now.Weekday() <= time.Friday

	// Get cached calendar information (avoid expensive AppleScript calls)
	if err := p.getCachedCalendarInfo(info); err != nil {
		p.logger.Debug("Failed to get cached calendar info, using empty values: %v", err)
		// Set empty values directly (no need for separate fallback function)
		info.TodayEvents = []string{}
		info.NextMeeting = ""
	}

	// Determine indicator (always fast)
	p.determineIndicator(info)

	return info, nil
}

// getCachedCalendarInfo gets calendar events using intelligent caching
func (p *ClockPlugin) getCachedCalendarInfo(info *ClockInfo) error {
	if p.cache == nil {
		return fmt.Errorf("cache not available")
	}

	// Get today's events with 15-minute cache
	todayKey := fmt.Sprintf("events_%s", time.Now().Format("2006-01-02"))
	cachedEvents, err := p.cache.GetOrSet(todayKey, eventsCache_TTL, func() (interface{}, error) {
		p.logger.Debug("Cache miss - fetching today's events")
		return p.getTodayEventsFromCalendar()
	})

	if err == nil {
		if events, ok := cachedEvents.([]string); ok {
			info.TodayEvents = events
		}
	}

	// Get next meeting with 5-minute cache (only on weekdays)
	if info.IsWeekday {
		meetingKey := fmt.Sprintf("next_meeting_%s_%02d", time.Now().Format("2006-01-02"), time.Now().Hour())
		cachedMeeting, err := p.cache.GetOrSet(meetingKey, nextMeetingCacheTTL, func() (interface{}, error) {
			p.logger.Debug("Cache miss - fetching next meeting")
			return p.getNextMeetingFromCalendar()
		})

		if err == nil {
			if meeting, ok := cachedMeeting.(string); ok {
				info.NextMeeting = meeting
			}
		}
	}

	return nil
}

// getTodayEventsFromCalendar gets today's calendar events using AppleScript (cached)
func (p *ClockPlugin) getTodayEventsFromCalendar() ([]string, error) {
	today := time.Now().Format("2006-01-02")

	// AppleScript to get current date and time
	script := fmt.Sprintf(`
tell application "Calendar"
  set todayEvents to {}
  set todayDate to date "%s"
  set endDate to todayDate + 1 * days
  
  -- Only check first 3 calendars for speed
  set calCount to 0
  repeat with cal in calendars
    set calCount to calCount + 1
    if calCount > 3 then exit repeat
    
    try
      set calEvents to events of cal whose start date ≥ todayDate and start date < endDate
      repeat with evt in calEvents
        if length of todayEvents ≥ 3 then exit repeat
        set eventInfo to (summary of evt) & " at " & (time string of start date of evt)
        set end of todayEvents to eventInfo
      end repeat
    end try
  end repeat
  
    return (todayEvents as string)
end tell`, today)

	// Use timeout to prevent hanging
	cmd := exec.Command("timeout", "3", "osascript", "-e", script)
	output, err := cmd.Output()
	if err != nil {
		return []string{}, fmt.Errorf("failed to get calendar events: %w", err)
	}

	result := strings.TrimSpace(string(output))
	if result == "" || result == "No events today" {
		return []string{}, nil
	}

	// Parse events (limit to first 3 for performance)
	events := strings.Split(result, ", ")
	var cleanEvents []string
	for i, event := range events {
		if i >= 3 {
			break
		}
		cleaned := strings.TrimSpace(event)
		if cleaned != "" {
			cleanEvents = append(cleanEvents, cleaned)
		}
	}

	return cleanEvents, nil
}

// getNextMeetingFromCalendar gets the next meeting today using AppleScript (cached)
func (p *ClockPlugin) getNextMeetingFromCalendar() (string, error) {
	// AppleScript to get current time with timeout
	script := `
tell application "Calendar"
  set now to current date
  set endOfDay to now + (24 * 60 * 60 - (time of now))
  
  -- Only check first 3 calendars for speed
  set calCount to 0
  repeat with cal in calendars
    set calCount to calCount + 1
    if calCount > 3 then exit repeat
    
    try
      set upcomingEvents to events of cal whose start date > now and start date ≤ endOfDay
      if length of upcomingEvents > 0 then
        set nextEvent to item 1 of upcomingEvents
        return (time string of start date of nextEvent)
      end if
    end try
  end repeat
  
  return ""
end tell`

	// Use timeout to prevent hanging
	cmd := exec.Command("timeout", "2", "osascript", "-e", script)
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to get next meeting: %w", err)
	}

	result := strings.TrimSpace(string(output))
	return result, nil
}

// determineIndicator sets the appropriate indicator based on day and events
func (p *ClockPlugin) determineIndicator(info *ClockInfo) {
	if info.IsWeekday {
		// Weekday - check for next meeting
		if info.NextMeeting != "" {
			info.Indicator = "🕐" // Clock for upcoming meeting
		} else {
			info.Indicator = "" // No indicator if no meetings
		}
	} else {
		// Weekend
		info.Indicator = "🌟" // Star for weekend
	}
}

// HandlePopupAction shows calendar popup with today's events
func (p *ClockPlugin) HandlePopupAction() error {
	p.logger.Info("Showing calendar popup")

	// Get current clock info (fast with caching)
	clockInfo, err := p.GetClockInfo()
	if err != nil {
		return fmt.Errorf("failed to get clock info for popup: %w", err)
	}

	// Create popup message
	var popupLabel string
	if len(clockInfo.TodayEvents) > 0 {
		// Show events
		eventsStr := strings.Join(clockInfo.TodayEvents, " • ")
		popupLabel = fmt.Sprintf("📅 %s", eventsStr)
	} else {
		popupLabel = "📅 No events today"
	}

	// Update with popup message
	if err := p.updater.UpdateItem(itemName, "", popupLabel, p.config.Colors.Text); err != nil {
		return fmt.Errorf("failed to update popup: %w", err)
	}

	// Schedule reset after 5 seconds and open Calendar
	go func() {
		time.Sleep(5 * time.Second)

		// Open Calendar app
		cmd := exec.Command("open", "-a", "Calendar")
		if err := cmd.Run(); err != nil {
			p.logger.Error("Failed to open Calendar: %v", err)
		}

		// Reset to normal display
		if err := p.UpdateDisplay(); err != nil {
			p.logger.Error("Failed to reset display after popup: %v", err)
		}
	}()

	return nil
}

// UpdateDisplay updates the SketchyBar display with current time and indicators
func (p *ClockPlugin) UpdateDisplay() error {
	// Get current clock info (now fast with caching)
	clockInfo, err := p.GetClockInfo()
	if err != nil {
		return fmt.Errorf("failed to get clock info: %w", err)
	}

	p.logger.Debug("Clock: %s, weekday=%v, next_meeting=%s, events=%d",
		clockInfo.CurrentTime, clockInfo.IsWeekday, clockInfo.NextMeeting, len(clockInfo.TodayEvents))

	// Update SketchyBar with time and indicator
	icon := clockInfo.Indicator
	label := clockInfo.FormattedTime
	color := p.config.Colors.Text

	if err := p.updater.UpdateItem(itemName, icon, label, color); err != nil {
		return fmt.Errorf("failed to update SketchyBar: %w", err)
	}

	return nil
}

// Run starts the clock monitoring plugin
func (p *ClockPlugin) Run() error {
	p.logger.Info("Starting clock plugin")

	// Handle command line arguments
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "popup":
			return p.HandlePopupAction()
		default:
			p.logger.Debug("Unknown argument: %s", os.Args[1])
		}
	}

	// Regular clock update (now much faster)
	return p.UpdateDisplay()
}

func main() {
	plugin, err := NewClockPlugin()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create clock plugin: %v\n", err)
		os.Exit(1)
	}

	if err := plugin.Run(); err != nil {
		plugin.logger.Error("Plugin execution failed: %v", err)
		fmt.Fprintf(os.Stderr, "Clock plugin failed: %v\n", err)
		os.Exit(1)
	}
}
