package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"sketchybar-plugins/config"
	"sketchybar-plugins/utils"
)

const (
	pluginName    = "weather"
	itemName      = "weather"
	cacheDuration = 30 * time.Minute
	apiTimeout    = 10 * time.Second
)

// WeatherPlugin handles weather monitoring for SketchyBar
type WeatherPlugin struct {
	config     *config.GlobalConfig
	logger     *utils.Logger
	updater    *utils.SketchyBarUpdater
	sysinfo    *utils.SystemInfo
	location   string
	cache      *utils.CacheManager // ISOLATED CACHE: Replace JSON file with cache manager
	httpClient *http.Client
}

// WeatherData represents weather information from wttr.in API
type WeatherData struct {
	NearestArea []struct {
		AreaName []struct {
			Value string `json:"value"`
		} `json:"areaName"`
	} `json:"nearest_area"`
	CurrentCondition []struct {
		TempC          string `json:"temp_C"`
		FeelsLikeC     string `json:"FeelsLikeC"`
		Humidity       string `json:"humidity"`
		WindspeedKmph  string `json:"windspeedKmph"`
		Winddir16Point string `json:"winddir16Point"`
		Visibility     string `json:"visibility"`
		UVIndex        string `json:"uvIndex"`
		WeatherDesc    []struct {
			Value string `json:"value"`
		} `json:"weatherDesc"`
	} `json:"current_condition"`
	Weather []struct {
		MaxtempC string `json:"maxtempC"`
		MintempC string `json:"mintempC"`
		Hourly   []struct {
			WeatherDesc []struct {
				Value string `json:"value"`
			} `json:"weatherDesc"`
		} `json:"hourly"`
	} `json:"weather"`
}

// CachedWeather represents cached weather data
type CachedWeather struct {
	Icon      string    `json:"icon"`
	Temp      string    `json:"temp"`
	Color     string    `json:"color"`
	Condition string    `json:"condition"`
	Timestamp time.Time `json:"timestamp"`
}

// WeatherInfo represents current weather status
type WeatherInfo struct {
	Icon      string
	Temp      string
	Color     string
	Condition string
	Available bool
}

// NewWeatherPlugin creates a new weather monitoring plugin
func NewWeatherPlugin() (*WeatherPlugin, error) {
	cfg, err := config.LoadConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to load config: %w", err)
	}

	logger := utils.NewLogger(pluginName)
	updater := utils.NewSketchyBarUpdater(cfg)
	sysinfo := utils.NewSystemInfo(cfg, logger)

	// ISOLATED CACHE: Initialize weather plugin's own cache manager
	cacheDir := os.ExpandEnv("$HOME/.cache/sketchybar/weather.db")
	cache, err := utils.NewCacheManager(cacheDir, 1800) // 30 minute default TTL
	if err != nil {
		logger.Warning("Failed to initialize weather cache: %v", err)
		cache = nil
	}

	// Create HTTP client with timeout
	httpClient := &http.Client{
		Timeout: apiTimeout,
	}

	// Detect location from system
	location := detectSystemLocation(logger)

	return &WeatherPlugin{
		config:     cfg,
		logger:     logger,
		updater:    updater,
		sysinfo:    sysinfo,
		location:   location, // Auto-detected from system services
		cache:      cache,
		httpClient: httpClient,
	}, nil
}

// GetWeatherInfo gets current weather information with caching
func (p *WeatherPlugin) GetWeatherInfo() (*WeatherInfo, error) {
	info := &WeatherInfo{}

	// Check cache first
	if cachedInfo, valid := p.getCachedWeather(); valid {
		p.logger.Debug("Using cached weather data")
		info.Icon = cachedInfo.Icon
		info.Temp = cachedInfo.Temp
		info.Color = cachedInfo.Color
		info.Condition = cachedInfo.Condition
		info.Available = true
		return info, nil
	}

	// Fetch fresh weather data
	if err := p.fetchWeatherData(info); err != nil {
		p.logger.Debug("Failed to fetch weather data: %v", err)
		info.Icon = "❌"
		info.Temp = "Offline"
		info.Color = p.config.Colors.Red
		info.Available = false
		return info, nil
	}

	// Cache the fresh data
	p.cacheWeatherData(info)

	return info, nil
}

// getCachedWeather returns cached weather data if valid
func (p *WeatherPlugin) getCachedWeather() (*CachedWeather, bool) {
	if p.cache == nil {
		return nil, false
	}

	// ISOLATED CACHE: Use cache manager instead of JSON file
	key := "weather_data"
	cached, exists := p.cache.Get(key)
	if !exists {
		return nil, false
	}

	if weatherData, ok := cached.(*CachedWeather); ok {
		return weatherData, true
	}

	return nil, false
}

// cacheWeatherData saves weather data to cache
func (p *WeatherPlugin) cacheWeatherData(info *WeatherInfo) {
	if p.cache == nil {
		return
	}

	cached := &CachedWeather{
		Icon:      info.Icon,
		Temp:      info.Temp,
		Color:     info.Color,
		Condition: info.Condition,
		Timestamp: time.Now(),
	}

	// ISOLATED CACHE: Use cache manager with 30-minute TTL
	key := "weather_data"
	if err := p.cache.Set(key, cached, 1800); err != nil { // 30 minutes = 1800 seconds
		p.logger.Debug("Failed to cache weather data: %v", err)
	}
}

// fetchWeatherData fetches weather from wttr.in API
func (p *WeatherPlugin) fetchWeatherData(info *WeatherInfo) error {
	// Build URL for simple format
	var url string
	if p.location != "" {
		url = fmt.Sprintf("https://wttr.in/%s?format=%%C+%%t", p.location)
	} else {
		url = "https://wttr.in/?format=%C+%t"
	}

	resp, err := p.httpClient.Get(url)
	if err != nil {
		return fmt.Errorf("failed to fetch weather: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("failed to read response: %w", err)
	}

	weatherText := strings.TrimSpace(string(body))
	if weatherText == "" {
		return fmt.Errorf("empty weather response")
	}

	// Parse condition and temperature
	parts := strings.Fields(weatherText)
	if len(parts) < 2 {
		return fmt.Errorf("invalid weather format: %s", weatherText)
	}

	// Extract condition (everything except the last part which should be temperature)
	condition := strings.Join(parts[:len(parts)-1], " ")
	temp := parts[len(parts)-1]

	info.Condition = condition
	info.Temp = temp
	info.Available = true

	// Map condition to icon and color
	p.mapWeatherCondition(info)

	return nil
}

// mapWeatherCondition maps weather conditions to appropriate icons and colors
func (p *WeatherPlugin) mapWeatherCondition(info *WeatherInfo) {
	condition := strings.ToLower(info.Condition)

	switch {
	case strings.Contains(condition, "clear") || strings.Contains(condition, "sunny"):
		info.Icon = "☀️"
		info.Color = p.config.Colors.Yellow
	case strings.Contains(condition, "partly cloudy"):
		info.Icon = "⛅"
		info.Color = p.config.Colors.Blue
	case strings.Contains(condition, "cloudy") || strings.Contains(condition, "overcast"):
		info.Icon = "☁️"
		info.Color = p.config.Colors.Overlay2
	case strings.Contains(condition, "light rain") || strings.Contains(condition, "patchy rain"):
		info.Icon = "🌦️"
		info.Color = p.config.Colors.Sapphire
	case strings.Contains(condition, "rain") || strings.Contains(condition, "drizzle"):
		info.Icon = "🌧️"
		info.Color = p.config.Colors.Sapphire
	case strings.Contains(condition, "snow"):
		info.Icon = "❄️"
		info.Color = p.config.Colors.Rosewater
	case strings.Contains(condition, "thunderstorm") || strings.Contains(condition, "thunder"):
		info.Icon = "⛈️"
		info.Color = p.config.Colors.Mauve
	case strings.Contains(condition, "fog") || strings.Contains(condition, "mist") || strings.Contains(condition, "haze"):
		info.Icon = "🌫️"
		info.Color = p.config.Colors.Subtext0
	case strings.Contains(condition, "windy"):
		info.Icon = "💨"
		info.Color = p.config.Colors.Green
	default:
		info.Icon = "🌤️"
		info.Color = p.config.Colors.Blue
	}
}

// HandleForecastAction shows detailed weather forecast
func (p *WeatherPlugin) HandleForecastAction() error {
	p.logger.Info("Showing weather forecast")

	// Fetch detailed weather data
	var url string
	if p.location != "" {
		url = fmt.Sprintf("https://wttr.in/%s?format=j1", p.location)
	} else {
		url = "https://wttr.in/?format=j1"
	}

	resp, err := p.httpClient.Get(url)
	if err != nil {
		// Fallback message
		if err := p.updater.UpdateItem(itemName, "🌤️", "Weather forecast unavailable • Check your internet connection", p.config.Colors.Red); err != nil {
			return fmt.Errorf("failed to update forecast: %w", err)
		}
		return nil
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("failed to read forecast response: %w", err)
	}

	var data WeatherData
	if err := json.Unmarshal(body, &data); err != nil {
		return fmt.Errorf("failed to parse forecast JSON: %w", err)
	}

	// Build comprehensive forecast message
	popupMsg := p.buildForecastMessage(&data)

	if err := p.updater.UpdateItem(itemName, "", popupMsg, p.config.Colors.Text); err != nil {
		return fmt.Errorf("failed to update forecast popup: %w", err)
	}

	// Schedule reset after 12 seconds and open Weather app
	go func() {
		time.Sleep(12 * time.Second)

		// Open Weather app
		cmd := exec.Command("open", "-a", "Weather")
		if err := cmd.Run(); err != nil {
			p.logger.Error("Failed to open Weather app: %v", err)
		}

		// Reset to normal display
		if err := p.UpdateDisplay(); err != nil {
			p.logger.Error("Failed to reset display after forecast: %v", err)
		}
	}()

	return nil
}

// buildForecastMessage creates a comprehensive forecast message
func (p *WeatherPlugin) buildForecastMessage(data *WeatherData) string {
	var parts []string

	// Location
	if len(data.NearestArea) > 0 && len(data.NearestArea[0].AreaName) > 0 {
		location := data.NearestArea[0].AreaName[0].Value
		parts = append(parts, fmt.Sprintf("🌍 %s", location))
	}

	// Current conditions
	if len(data.CurrentCondition) > 0 {
		current := data.CurrentCondition[0]
		parts = append(parts, fmt.Sprintf("Now: %s°C (feels %s°C)", current.TempC, current.FeelsLikeC))
		parts = append(parts, fmt.Sprintf("Humidity: %s%%", current.Humidity))
		parts = append(parts, fmt.Sprintf("Wind: %skm/h %s", current.WindspeedKmph, current.Winddir16Point))
		parts = append(parts, fmt.Sprintf("UV: %s", current.UVIndex))
	}

	// Tomorrow's forecast
	if len(data.Weather) > 1 {
		tomorrow := data.Weather[1]
		var condition string
		if len(tomorrow.Hourly) > 4 && len(tomorrow.Hourly[4].WeatherDesc) > 0 {
			condition = tomorrow.Hourly[4].WeatherDesc[0].Value
		} else {
			condition = "N/A"
		}
		parts = append(parts, fmt.Sprintf("Tomorrow: %s %s°/%s°C", condition, tomorrow.MaxtempC, tomorrow.MintempC))
	}

	// Day 3 forecast
	if len(data.Weather) > 2 {
		day3 := data.Weather[2]
		var condition string
		if len(day3.Hourly) > 4 && len(day3.Hourly[4].WeatherDesc) > 0 {
			condition = day3.Hourly[4].WeatherDesc[0].Value
		} else {
			condition = "N/A"
		}
		parts = append(parts, fmt.Sprintf("Day 3: %s %s°/%s°C", condition, day3.MaxtempC, day3.MintempC))
	}

	return strings.Join(parts, " • ")
}

// UpdateDisplay updates the SketchyBar display with current weather
func (p *WeatherPlugin) UpdateDisplay() error {
	// Get current weather info
	weatherInfo, err := p.GetWeatherInfo()
	if err != nil {
		return fmt.Errorf("failed to get weather info: %w", err)
	}

	p.logger.Debug("Weather: %s %s, available=%v", weatherInfo.Icon, weatherInfo.Temp, weatherInfo.Available)

	// Update SketchyBar
	if err := p.updater.UpdateItem(itemName, weatherInfo.Icon, weatherInfo.Temp, weatherInfo.Color); err != nil {
		return fmt.Errorf("failed to update SketchyBar: %w", err)
	}

	return nil
}

// Run starts the weather monitoring plugin
func (p *WeatherPlugin) Run() error {
	p.logger.Info("Starting weather plugin")

	// Handle command line arguments
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "forecast":
			return p.HandleForecastAction()
		default:
			p.logger.Debug("Unknown argument: %s", os.Args[1])
		}
	}

	// Regular weather update
	return p.UpdateDisplay()
}

// detectSystemLocation detects location using system services
func detectSystemLocation(logger *utils.Logger) string {
	logger.Debug("Starting system location detection")

	// Method 1: Try CoreLocationCLI for precise macOS location
	if location := tryCoreLocationCLI(logger); location != "" {
		logger.Info("Location detected via CoreLocationCLI: %s", location)
		return location
	}

	// Method 2: Try Swift/Python Core Location (if available)
	if location := tryMacOSLocation(logger); location != "" {
		logger.Info("Location detected via macOS Core Location API: %s", location)
		return location
	}

	// Method 3: Try IP-based geolocation (reliable fallback)
	if location := tryIPGeolocation(logger); location != "" {
		logger.Info("Location detected via IP geolocation: %s", location)
		return location
	}

	// Method 4: Use timezone as last resort (broad area)
	if location := getLocationFromTimezone(logger); location != "" {
		logger.Info("Location detected via timezone (approximate): %s", location)
		return location
	}

	// Fallback: empty string means wttr.in will try its own detection
	logger.Warning("Could not detect location, using wttr.in auto-detection")
	return ""
}

// tryCoreLocationCLI attempts to get location using CoreLocationCLI
func tryCoreLocationCLI(logger *utils.Logger) string {
	logger.Debug("Trying CoreLocationCLI for precise location")

	// Try to run CoreLocationCLI with JSON output for structured parsing
	cmd := exec.Command("CoreLocationCLI", "--json", "--timeout", "10")
	output, err := cmd.Output()
	if err != nil {
		logger.Debug("CoreLocationCLI failed: %v", err)

		// Try without JSON for a simple coordinate format
		cmd = exec.Command("CoreLocationCLI", "--format", "%latitude,%longitude")
		output, err = cmd.Output()
		if err != nil {
			logger.Debug("CoreLocationCLI simple format also failed: %v", err)
			return ""
		}
	}

	result := strings.TrimSpace(string(output))
	if result == "" {
		logger.Debug("CoreLocationCLI returned empty result")
		return ""
	}

	logger.Debug("CoreLocationCLI raw output: %s", result)

	// Check for error messages in the output
	if strings.Contains(result, "Location services are disabled") ||
		strings.Contains(result, "location access denied") ||
		strings.Contains(result, "❌") {
		logger.Debug("CoreLocationCLI: Location services disabled or access denied")
		return ""
	}

	// If we have JSON output, parse it
	if strings.HasPrefix(result, "{") {
		return parseCoreLocationJSON(result, logger)
	}

	// If we have coordinates in "lat,lon" format, validate and return
	if coords := parseCoordinates(result, logger); coords != "" {
		return coords
	}

	logger.Debug("Unable to parse CoreLocationCLI output: %s", result)
	return ""
}

// parseCoreLocationJSON parses JSON output from CoreLocationCLI
func parseCoreLocationJSON(jsonOutput string, logger *utils.Logger) string {
	// Simple JSON parsing without importing json package
	if strings.Contains(jsonOutput, `"latitude"`) && strings.Contains(jsonOutput, `"longitude"`) {
		lines := strings.Split(jsonOutput, ",")
		var lat, lon string

		for _, line := range lines {
			line = strings.TrimSpace(line)
			if strings.Contains(line, `"latitude":`) {
				parts := strings.Split(line, ":")
				if len(parts) >= 2 {
					lat = strings.Trim(strings.TrimSpace(parts[1]), ` ,"`)
				}
			}
			if strings.Contains(line, `"longitude":`) {
				parts := strings.Split(line, ":")
				if len(parts) >= 2 {
					lon = strings.Trim(strings.TrimSpace(parts[1]), ` ,"`)
				}
			}
		}

		if lat != "" && lon != "" {
			coords := fmt.Sprintf("%s,%s", lat, lon)
			logger.Debug("Parsed CoreLocationCLI coordinates: %s", coords)
			return coords
		}
	}

	return ""
}

// parseCoordinates validates and returns coordinate string
func parseCoordinates(coords string, logger *utils.Logger) string {
	// Check if it looks like "lat,lon" format
	parts := strings.Split(coords, ",")
	if len(parts) == 2 {
		lat := strings.TrimSpace(parts[0])
		lon := strings.TrimSpace(parts[1])

		// Basic validation - should be numbers (with possible decimal points and minus signs)
		if isValidCoordinate(lat) && isValidCoordinate(lon) {
			result := fmt.Sprintf("%s,%s", lat, lon)
			logger.Debug("Valid coordinates detected: %s", result)
			return result
		}
	}

	return ""
}

// isValidCoordinate checks if a string looks like a valid coordinate
func isValidCoordinate(coord string) bool {
	coord = strings.TrimSpace(coord)
	if coord == "" {
		return false
	}

	// Should contain only digits, decimal points, and optional minus sign
	for i, char := range coord {
		if char == '-' && i == 0 {
			continue // minus sign at beginning is ok
		}
		if char == '.' {
			continue // decimal point is ok
		}
		if char >= '0' && char <= '9' {
			continue // digits are ok
		}
		return false
	}

	return true
}

// tryMacOSLocation attempts to get precise location via macOS Core Location
func tryMacOSLocation(logger *utils.Logger) string {
	// Method 1: Try Swift script with Core Location (most accurate)
	if location := trySwiftLocation(logger); location != "" {
		return location
	}

	// Method 2: Try Python with Core Location (if available)
	if location := tryPythonLocation(logger); location != "" {
		return location
	}

	// Method 3: Check if location services are enabled and try system location cache
	if location := trySystemLocationCache(logger); location != "" {
		return location
	}

	logger.Debug("macOS Core Location not accessible")
	return ""
}

// trySwiftLocation uses a Swift script to access Core Location
func trySwiftLocation(logger *utils.Logger) string {
	// Create a temporary Swift script that uses Core Location
	swiftScript := `
import CoreLocation
import Foundation

class LocationDelegate: NSObject, CLLocationManagerDelegate {
    let manager = CLLocationManager()
    var completion: ((CLLocation?) -> Void)?
    
    override init() {
        super.init()
        manager.delegate = self
    }
    
    func requestLocation(completion: @escaping (CLLocation?) -> Void) {
        self.completion = completion
        
        guard CLLocationManager.locationServicesEnabled() else {
            completion(nil)
            return
        }
        
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        } else {
            completion(nil)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        completion?(locations.first)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completion?(nil)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        } else if status != .notDetermined {
            completion?(nil)
        }
    }
}

let delegate = LocationDelegate()
let semaphore = DispatchSemaphore(value: 0)

delegate.requestLocation { location in
    if let loc = location {
        print("\(loc.coordinate.latitude),\(loc.coordinate.longitude)")
    }
    semaphore.signal()
}

_ = semaphore.wait(timeout: .now() + 10)
`

	// Write Swift script to temporary file
	tmpDir := os.TempDir()
	tmpFile := filepath.Join(tmpDir, "location.swift")

	if err := os.WriteFile(tmpFile, []byte(swiftScript), 0644); err != nil {
		logger.Debug("Failed to write Swift location script: %v", err)
		return ""
	}
	defer os.Remove(tmpFile)

	// Execute Swift script
	cmd := exec.Command("swift", tmpFile)
	output, err := cmd.Output()
	if err != nil {
		logger.Debug("Swift location script failed: %v", err)
		return ""
	}

	result := strings.TrimSpace(string(output))
	if result != "" && strings.Contains(result, ",") {
		logger.Debug("Swift Core Location result: %s", result)
		return result // Return coordinates for wttr.in
	}

	return ""
}

// tryPythonLocation tries using Python with CoreLocation
func tryPythonLocation(logger *utils.Logger) string {
	pythonScript := `
try:
    import CoreLocation
    import Foundation
    import time
    
    manager = CoreLocation.CLLocationManager.alloc().init()
    
    if not CoreLocation.CLLocationManager.locationServicesEnabled():
        exit(1)
    
    # This won't work without proper app entitlements, but let's try
    status = manager.authorizationStatus()
    if status == 3 or status == 4:  # kCLAuthorizationStatusAuthorizedWhenInUse or Always
        manager.requestLocation()
        time.sleep(2)  # Wait briefly
    
except ImportError:
    exit(1)
except Exception:
    exit(1)
`

	cmd := exec.Command("python3", "-c", pythonScript)
	output, err := cmd.Output()
	if err != nil {
		logger.Debug("Python CoreLocation not available: %v", err)
		return ""
	}

	result := strings.TrimSpace(string(output))
	if result != "" {
		logger.Debug("Python CoreLocation result: %s", result)
		return result
	}

	return ""
}

// trySystemLocationCache attempts to get location from system cache/logs
func trySystemLocationCache(logger *utils.Logger) string {
	// Check if location services are enabled
	cmd := exec.Command("defaults", "read", "/var/db/locationd/Library/Preferences/ByHost/com.apple.locationd", "LocationServicesEnabled")
	output, err := cmd.Output()
	if err != nil || strings.TrimSpace(string(output)) != "1" {
		logger.Debug("Location services not enabled")
		return ""
	}

	// Try to get approximate location from system logs (requires admin access usually)
	// This is a long shot but might work
	cmd = exec.Command("log", "show", "--predicate", "subsystem == 'com.apple.locationd'", "--info", "--debug", "--start", "2023-01-01", "|", "grep", "-i", "coordinate", "|", "tail", "-1")
	output, err = cmd.Output()
	if err == nil && len(output) > 0 {
		result := strings.TrimSpace(string(output))
		logger.Debug("System location log result: %s", result)
		// Parse coordinates if found
		// This is very system-dependent and may not work
	}

	return ""
}

// getLocationFromTimezone maps timezone to major city for weather
func getLocationFromTimezone(logger *utils.Logger) string {
	// Read the timezone symlink to get the timezone info
	timezonePath, err := filepath.EvalSymlinks("/etc/localtime")
	if err != nil {
		logger.Debug("Failed to read timezone symlink: %v", err)
		return ""
	}

	logger.Debug("Timezone path: %s", timezonePath)

	// Extract timezone from path like /var/db/timezone/zoneinfo/Europe/Berlin
	parts := strings.Split(timezonePath, "/")
	if len(parts) < 2 {
		return ""
	}

	// Get the last two parts (e.g., Europe/Berlin)
	var timezone string
	if len(parts) >= 2 {
		timezone = parts[len(parts)-2] + "/" + parts[len(parts)-1]
	}

	logger.Debug("Detected timezone: %s", timezone)

	// Map common timezones to major cities for accurate weather
	timezoneMap := map[string]string{
		"Europe/Berlin":       "Berlin",
		"Europe/Amsterdam":    "Amsterdam",
		"Europe/London":       "London",
		"Europe/Paris":        "Paris",
		"Europe/Rome":         "Rome",
		"Europe/Madrid":       "Madrid",
		"Europe/Vienna":       "Vienna",
		"Europe/Zurich":       "Zurich",
		"America/New_York":    "New York",
		"America/Los_Angeles": "Los Angeles",
		"America/Chicago":     "Chicago",
		"Asia/Tokyo":          "Tokyo",
		"Asia/Shanghai":       "Shanghai",
		"Australia/Sydney":    "Sydney",
	}

	if city, exists := timezoneMap[timezone]; exists {
		return city
	}

	// If exact match not found, try to use the city name from timezone
	if len(parts) >= 1 {
		cityName := parts[len(parts)-1]
		// Clean up city name (remove underscores, etc.)
		cityName = strings.ReplaceAll(cityName, "_", " ")
		return cityName
	}

	return ""
}

// tryIPGeolocation attempts IP-based location detection using multiple services
func tryIPGeolocation(logger *utils.Logger) string {
	client := &http.Client{Timeout: 10 * time.Second}

	// List of IP geolocation services to try (in order of preference)
	services := []struct {
		name  string
		url   string
		parse func(body string) string
	}{
		{
			name: "ipapi.co",
			url:  "https://ipapi.co/json/",
			parse: func(body string) string {
				// Parse JSON response from ipapi.co
				if strings.Contains(body, `"city"`) && strings.Contains(body, `"country_name"`) {
					// Simple JSON parsing without importing json package
					lines := strings.Split(body, ",")
					var city string
					for _, line := range lines {
						if strings.Contains(line, `"city":`) {
							city = strings.Trim(strings.Split(line, ":")[1], ` "`)
						}
						// We also have country info available but don't need it for city name
						if strings.Contains(line, `"country_name":`) {
							_ = strings.Trim(strings.Split(line, ":")[1], ` "`)
						}
					}
					if city != "" && city != "null" {
						return city
					}
				}
				return ""
			},
		},
		{
			name: "ipinfo.io",
			url:  "https://ipinfo.io/json",
			parse: func(body string) string {
				// Parse JSON response from ipinfo.io
				if strings.Contains(body, `"city"`) {
					lines := strings.Split(body, ",")
					for _, line := range lines {
						if strings.Contains(line, `"city":`) {
							city := strings.Trim(strings.Split(line, ":")[1], ` "`)
							if city != "" && city != "null" {
								return city
							}
						}
					}
				}
				return ""
			},
		},
		{
			name: "ip-api.com",
			url:  "http://ip-api.com/line/?fields=city,country",
			parse: func(body string) string {
				lines := strings.Split(strings.TrimSpace(body), "\n")
				if len(lines) >= 2 && lines[0] != "" && lines[0] != "null" {
					city := strings.TrimSpace(lines[0])
					return city
				}
				return ""
			},
		},
		{
			name: "ipapi.co-simple",
			url:  "https://ipapi.co/city/",
			parse: func(body string) string {
				city := strings.TrimSpace(body)
				if city != "" && city != "null" && city != "None" {
					return city
				}
				return ""
			},
		},
	}

	// Try each service
	for _, service := range services {
		logger.Debug("Trying IP geolocation service: %s", service.name)

		resp, err := client.Get(service.url)
		if err != nil {
			logger.Debug("IP geolocation service %s failed: %v", service.name, err)
			continue
		}

		body, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			logger.Debug("Failed to read response from %s: %v", service.name, err)
			continue
		}

		// Parse the response
		city := service.parse(string(body))
		if city != "" {
			logger.Debug("IP geolocation success via %s: %s", service.name, city)
			return city
		}

		logger.Debug("Service %s returned empty/invalid location", service.name)
	}

	logger.Debug("All IP geolocation services failed")
	return ""
}

func main() {
	plugin, err := NewWeatherPlugin()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create weather plugin: %v\n", err)
		os.Exit(1)
	}

	if err := plugin.Run(); err != nil {
		plugin.logger.Error("Plugin execution failed: %v", err)
		fmt.Fprintf(os.Stderr, "Weather plugin failed: %v\n", err)
		os.Exit(1)
	}
}
