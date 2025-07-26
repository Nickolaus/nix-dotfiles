package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
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

	return &WeatherPlugin{
		config:     cfg,
		logger:     logger,
		updater:    updater,
		sysinfo:    sysinfo,
		location:   "", // Empty = auto-detect
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
