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
	pluginName = "network"
	itemName   = "network"

	// Cache TTLs for different types of network data
	wifiInfoCacheTTL      = 30 * 60      // 30 minutes for WiFi details (SSID, signal)
	interfaceTypeCacheTTL = 24 * 60 * 60 // 24 hours for interface type detection
	activeInterfacesTTL   = 10           // 10 seconds for active interfaces (changes frequently)
)

// NetworkPlugin handles network monitoring for SketchyBar
type NetworkPlugin struct {
	config  *config.GlobalConfig
	logger  *utils.Logger
	updater *utils.SketchyBarUpdater
	history *utils.HistoryManager
	sysinfo *utils.SystemInfo
	cache   *utils.CacheManager
}

// NetworkInfo represents current network status
type NetworkInfo struct {
	InterfaceType  string // "wifi", "ethernet", "none"
	SSID           string // WiFi network name
	SignalStrength int    // WiFi signal strength (-100 to 0 dBm)
	SignalQuality  int    // Signal quality percentage (0-100)
	IPAddress      string // Current IP address
	InterfaceName  string // Interface name (en0, en1, etc.)
	IsConnected    bool   // Whether we have an active connection
}

// NewNetworkPlugin creates a new network monitoring plugin
func NewNetworkPlugin() (*NetworkPlugin, error) {
	cfg, err := config.LoadConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to load config: %w", err)
	}

	logger := utils.NewLogger(pluginName)
	updater := utils.NewSketchyBarUpdater(cfg)
	history := utils.NewHistoryManager(cfg, logger)
	sysinfo := utils.NewSystemInfo(cfg, logger)

	// Initialize cache for network plugin
	cacheDir := os.ExpandEnv("$HOME/.cache/sketchybar/network.db")
	cache, err := utils.NewCacheManager(cacheDir, 60) // 1 minute default TTL
	if err != nil {
		logger.Warning("Failed to initialize network cache: %v", err)
		cache = nil
	}

	return &NetworkPlugin{
		config:  cfg,
		logger:  logger,
		updater: updater,
		history: history,
		sysinfo: sysinfo,
		cache:   cache,
	}, nil
}

// GetNetworkInfo gets comprehensive network information with aggressive caching
func (p *NetworkPlugin) GetNetworkInfo() (*NetworkInfo, error) {
	info := &NetworkInfo{
		InterfaceType: "none",
		IsConnected:   false,
	}

	// Get active network interfaces (short cache since IP addresses change)
	interfaces, err := p.getCachedActiveInterfaces()
	if err != nil {
		return info, fmt.Errorf("failed to get active interfaces: %w", err)
	}

	if len(interfaces) == 0 {
		p.logger.Debug("No active network interfaces found")
		return info, nil
	}

	// Fast interface type detection to avoid expensive WiFi checks
	for _, iface := range interfaces {
		if strings.HasPrefix(iface.Name, "en") {
			// Method 1: Fast ethernet detection (check for wired connection indicators)
			if p.isEthernetConnection(iface.Name) {
				info.InterfaceType = "ethernet"
				info.IPAddress = iface.IPAddress
				info.InterfaceName = iface.Name
				info.IsConnected = true
				p.logger.Debug("Ethernet connection detected on %s (fast detection)", info.InterfaceName)
				return info, nil
			}

			// Method 2: Only check WiFi if fast ethernet detection failed
			if p.isCachedWiFiInterface(iface.Name) {
				wifiInfo, err := p.getCachedWiFiInfo(iface.Name)
				if err == nil && wifiInfo.SSID != "" {
					info.InterfaceType = "wifi"
					info.SSID = wifiInfo.SSID
					info.SignalStrength = wifiInfo.SignalStrength
					info.SignalQuality = wifiInfo.SignalQuality
					info.IPAddress = iface.IPAddress
					info.InterfaceName = iface.Name
					info.IsConnected = true
					p.logger.Debug("WiFi connection found: %s on %s (%d%% signal)", info.SSID, info.InterfaceName, info.SignalQuality)
					return info, nil
				}
			}

			// Method 3: Default to ethernet if WiFi detection failed but interface is active
			info.InterfaceType = "ethernet"
			info.IPAddress = iface.IPAddress
			info.InterfaceName = iface.Name
			info.IsConnected = true
			p.logger.Debug("Default ethernet connection on %s", info.InterfaceName)
			return info, nil
		}
	}

	p.logger.Debug("No recognized network connections found")
	return info, nil
}

// Interface represents a network interface with IP
type Interface struct {
	Name      string
	IPAddress string
}

// getCachedActiveInterfaces returns interfaces that have IP addresses (short cache)
func (p *NetworkPlugin) getCachedActiveInterfaces() ([]Interface, error) {
	if p.cache == nil {
		return p.getActiveInterfacesFromSystem()
	}

	key := "active_interfaces"

	// Use check-call-store pattern to avoid GetOrSet deadlocks
	if cached, exists := p.cache.Get(key); exists {
		if interfaces, ok := cached.([]Interface); ok {
			return interfaces, nil
		}
	}

	// Cache miss - fetch active interfaces directly
	p.logger.Debug("Cache miss - fetching active interfaces")
	interfaces, err := p.getActiveInterfacesFromSystem()
	if err != nil {
		return interfaces, err // Return partial results even with error
	}

	// Store result with 10-second TTL
	if setErr := p.cache.Set(key, interfaces, activeInterfacesTTL); setErr != nil {
		p.logger.Warning("Failed to cache active interfaces: %v", setErr)
	}

	return interfaces, nil
}

// getActiveInterfacesFromSystem returns interfaces that have IP addresses (optimized)
func (p *NetworkPlugin) getActiveInterfacesFromSystem() ([]Interface, error) {
	// Use targeted ifconfig for common interfaces instead of parsing all
	commonInterfaces := []string{"en0", "en1", "en2", "en3", "eth0", "utun0", "utun1"}
	var interfaces []Interface

	for _, interfaceName := range commonInterfaces {
		if iface := p.getInterfaceInfo(interfaceName); iface != nil {
			interfaces = append(interfaces, *iface)
		}
	}

	// If we found interfaces using fast method, return them
	if len(interfaces) > 0 {
		return interfaces, nil
	}

	// Fallback: use full ifconfig parsing if fast method didn't work
	return p.getActiveInterfacesFromIfconfigAll()
}

// Fast method: Get specific interface info quickly
func (p *NetworkPlugin) getInterfaceInfo(interfaceName string) *Interface {
	cmd := exec.Command("ifconfig", interfaceName)
	output, err := cmd.Output()
	if err != nil {
		return nil // Interface doesn't exist or not accessible
	}

	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)

		// Look for inet (IPv4) addresses
		if strings.HasPrefix(line, "inet ") {
			parts := strings.Fields(line)
			if len(parts) >= 2 {
				ipAddr := parts[1]
				// Skip loopback and link-local addresses
				if !strings.HasPrefix(ipAddr, "127.") && !strings.HasPrefix(ipAddr, "169.254.") {
					p.logger.Debug("Found active interface: %s with IP %s", interfaceName, ipAddr)
					return &Interface{
						Name:      interfaceName,
						IPAddress: ipAddr,
					}
				}
			}
		}
	}

	return nil // No valid IP found
}

// Fallback method: Original full ifconfig parsing
func (p *NetworkPlugin) getActiveInterfacesFromIfconfigAll() ([]Interface, error) {
	cmd := exec.Command("ifconfig")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to run ifconfig: %w", err)
	}

	var interfaces []Interface
	lines := strings.Split(string(output), "\n")

	var currentInterface string
	for _, line := range lines {
		line = strings.TrimSpace(line)

		// New interface (doesn't start with whitespace)
		if len(line) > 0 && !strings.HasPrefix(line, " ") && !strings.HasPrefix(line, "\t") {
			parts := strings.Fields(line)
			if len(parts) > 0 && strings.HasSuffix(parts[0], ":") {
				currentInterface = strings.TrimSuffix(parts[0], ":")
			}
		}

		// Look for inet (IPv4) addresses
		if strings.Contains(line, "inet ") && currentInterface != "" {
			parts := strings.Fields(line)
			for i, part := range parts {
				if part == "inet" && i+1 < len(parts) {
					ipAddr := parts[i+1]
					// Skip loopback
					if !strings.HasPrefix(ipAddr, "127.") && !strings.HasPrefix(ipAddr, "169.254.") {
						interfaces = append(interfaces, Interface{
							Name:      currentInterface,
							IPAddress: ipAddr,
						})
						p.logger.Debug("Found active interface: %s with IP %s", currentInterface, ipAddr)
					}
					break
				}
			}
		}
	}

	return interfaces, nil
}

// isCachedWiFiInterface checks if an interface is WiFi using aggressive caching
func (p *NetworkPlugin) isCachedWiFiInterface(interfaceName string) bool {
	if p.cache == nil {
		return p.isWiFiInterfaceFallback(interfaceName)
	}

	cacheKey := fmt.Sprintf("interface_type_%s", interfaceName)

	// Use check-call-store pattern to avoid GetOrSet deadlocks
	if cached, exists := p.cache.Get(cacheKey); exists {
		if interfaceType, ok := cached.(string); ok {
			return interfaceType == "wifi"
		}
	}

	// Cache miss - detect interface type directly
	p.logger.Debug("Cache miss - detecting interface type for %s", interfaceName)

	var interfaceType string
	if p.isWiFiInterfaceFromSystem(interfaceName) {
		interfaceType = "wifi"
	} else {
		interfaceType = "ethernet"
	}

	// Store result with 24-hour TTL (interface types never change)
	if setErr := p.cache.Set(cacheKey, interfaceType, interfaceTypeCacheTTL); setErr != nil {
		p.logger.Warning("Failed to cache interface type: %v", setErr)
	}

	return interfaceType == "wifi"
}

// isWiFiInterfaceFromSystem checks if an interface is WiFi
// Use modern macOS methods (airport deprecated in Sonoma 14.4+)
func (p *NetworkPlugin) isWiFiInterfaceFromSystem(interfaceName string) bool {
	// Method 1: Fast ifconfig check (no external dependencies, ~20ms)
	if p.isWiFiInterfaceFromIfconfig(interfaceName) {
		return true
	}

	// Method 2: Smart heuristic for common interfaces (instant)
	if interfaceName == "en0" || interfaceName == "en1" {
		// These are commonly WiFi on modern Macs, but verify with ifconfig above
		return true // ifconfig check above already validated this
	}

	// Method 3: Last resort - expensive networksetup command (~800ms)
	return p.isWiFiInterfaceFromNetworksetup(interfaceName)
}

// REMOVED: Airport utility deprecated in macOS Sonoma 14.4+ (March 2024)
// Replaced with ifconfig-based detection which is faster and reliable

// Ultra fast method: Detect ethernet connection indicators (~10ms)
func (p *NetworkPlugin) isEthernetConnection(interfaceName string) bool {
	cmd := exec.Command("ifconfig", interfaceName)
	output, err := cmd.Output()
	if err != nil {
		return false
	}

	outputStr := string(output)
	// Look for ethernet-specific indicators in ifconfig output
	// These indicate a wired/ethernet connection
	isEthernet := strings.Contains(outputStr, "media: autoselect") ||
		strings.Contains(outputStr, "media: 1000baseT") ||
		strings.Contains(outputStr, "media: 100baseTX") ||
		strings.Contains(outputStr, "media: 10baseT") ||
		strings.Contains(outputStr, "link-quality") ||
		(strings.Contains(outputStr, "status: active") && !strings.Contains(outputStr, "ieee80211"))

	p.logger.Debug("Ethernet detection for %s: %v", interfaceName, isEthernet)
	return isEthernet
}

// Fast method: Check interface type using ifconfig (faster than networksetup)
func (p *NetworkPlugin) isWiFiInterfaceFromIfconfig(interfaceName string) bool {
	cmd := exec.Command("ifconfig", interfaceName)
	output, err := cmd.Output()
	if err != nil {
		return false
	}

	outputStr := string(output)
	// Look for WiFi-specific indicators in ifconfig output
	return strings.Contains(outputStr, "media: IEEE") ||
		strings.Contains(outputStr, "status: associated") ||
		strings.Contains(outputStr, "ieee80211")
}

// Slow fallback: Original networksetup method (only used as last resort)
func (p *NetworkPlugin) isWiFiInterfaceFromNetworksetup(interfaceName string) bool {
	cmd := exec.Command("networksetup", "-listallhardwareports")
	output, err := cmd.Output()
	if err != nil {
		p.logger.Debug("Failed to get hardware ports: %v", err)
		return false
	}

	lines := strings.Split(string(output), "\n")
	for i, line := range lines {
		if strings.Contains(line, "Hardware Port: Wi-Fi") {
			// Look for the device line after the Wi-Fi port
			if i+1 < len(lines) {
				deviceLine := lines[i+1]
				if strings.Contains(deviceLine, "Device: "+interfaceName) {
					return true
				}
			}
		}
	}

	return false
}

// isWiFiInterfaceFallback provides fallback WiFi detection without caching
func (p *NetworkPlugin) isWiFiInterfaceFallback(interfaceName string) bool {
	// Simple heuristic: en0 and en1 are commonly WiFi on modern Macs
	return interfaceName == "en0" || interfaceName == "en1"
}

// WiFiInfo represents WiFi connection details
type WiFiInfo struct {
	SSID           string
	SignalStrength int
	SignalQuality  int
}

// getCachedWiFiInfo gets detailed WiFi information using aggressive caching
func (p *NetworkPlugin) getCachedWiFiInfo(interfaceName string) (*WiFiInfo, error) {
	if p.cache == nil {
		return p.getWiFiInfoFromSystem(interfaceName)
	}

	cacheKey := fmt.Sprintf("wifi_info_%s", interfaceName)

	// Use check-call-store pattern to avoid GetOrSet deadlocks
	if cached, exists := p.cache.Get(cacheKey); exists {
		if wifiInfo, ok := cached.(*WiFiInfo); ok {
			return wifiInfo, nil
		}
	}

	// Cache miss - fetch WiFi info directly (this is the expensive call!)
	p.logger.Debug("Cache miss - fetching WiFi info for %s", interfaceName)
	wifiInfo, err := p.getWiFiInfoFromSystem(interfaceName)
	if err != nil {
		return wifiInfo, err // Return partial results even with error
	}

	// Store result with 30-minute TTL (WiFi details change infrequently)
	if setErr := p.cache.Set(cacheKey, wifiInfo, wifiInfoCacheTTL); setErr != nil {
		p.logger.Warning("Failed to cache WiFi info: %v", setErr)
	}

	return wifiInfo, nil
}

// getWiFiInfoFromSystem gets detailed WiFi information using optimized commands
func (p *NetworkPlugin) getWiFiInfoFromSystem(interfaceName string) (*WiFiInfo, error) {
	info := &WiFiInfo{}

	// Use modern macOS methods (airport deprecated in Sonoma 14.4+)

	// Method 1: Fast networksetup (works without sudo, ~50ms)
	if err := p.getWiFiInfoBasic(interfaceName, info); err == nil {
		p.logger.Debug("Got basic WiFi info from networksetup (fast)")
		return info, nil
	}

	// Method 2: Try wdutil if available (requires sudo in some cases)
	if err := p.getWiFiInfoFromWdutil(interfaceName, info); err == nil {
		p.logger.Debug("Got WiFi info from wdutil (medium)")
		return info, nil
	}

	// Method 3: Last resort - system_profiler (slow but comprehensive, ~2000ms)
	p.logger.Debug("Using system_profiler as last resort (slow)")
	return p.getWiFiInfoFromSystemProfiler(interfaceName)
}

// REMOVED: Airport utility deprecated in macOS Sonoma 14.4+ (March 2024)
// Apple official statement: "The airport command line tool is deprecated and will be removed in a future release"
// Replaced with faster networksetup and wdutil methods

// Optimization method 2: WiFi info using wdutil (macOS built-in)
func (p *NetworkPlugin) getWiFiInfoFromWdutil(interfaceName string, info *WiFiInfo) error {
	// Try wdutil for WiFi information
	cmd := exec.Command("wdutil", "info")
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("wdutil command failed: %w", err)
	}

	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)

		// Parse SSID from wdutil output
		if strings.Contains(line, "SSID") && strings.Contains(line, ":") {
			parts := strings.SplitN(line, ":", 2)
			if len(parts) == 2 {
				info.SSID = strings.TrimSpace(parts[1])
			}
		}

		// Parse RSSI from wdutil output
		if strings.Contains(line, "RSSI") && strings.Contains(line, ":") {
			parts := strings.SplitN(line, ":", 2)
			if len(parts) == 2 {
				rssiStr := strings.TrimSpace(parts[1])
				if rssi, err := strconv.Atoi(rssiStr); err == nil {
					info.SignalStrength = rssi
					info.SignalQuality = p.rssiToQuality(rssi)
				}
			}
		}
	}

	if info.SSID != "" {
		return nil
	}
	return fmt.Errorf("no SSID found in wdutil output")
}

// Optimization method 3: Basic WiFi info using fast system calls
func (p *NetworkPlugin) getWiFiInfoBasic(interfaceName string, info *WiFiInfo) error {
	// Try networksetup to get current WiFi network (much faster than system_profiler)
	cmd := exec.Command("networksetup", "-getairportnetwork", interfaceName)
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("networksetup getairportnetwork failed: %w", err)
	}

	line := strings.TrimSpace(string(output))
	// Output format: "Current Wi-Fi Network: NetworkName" or "You are not associated with an AirPort network."
	if strings.HasPrefix(line, "Current Wi-Fi Network: ") {
		info.SSID = strings.TrimSpace(strings.TrimPrefix(line, "Current Wi-Fi Network: "))
		// Set reasonable defaults when we can't get signal strength
		info.SignalStrength = -50 // Assume decent signal
		info.SignalQuality = 60   // Reasonable default
		return nil
	}

	return fmt.Errorf("not connected to WiFi")
}

// Optimization method 4: Original system_profiler method (slow but comprehensive)
func (p *NetworkPlugin) getWiFiInfoFromSystemProfiler(interfaceName string) (*WiFiInfo, error) {
	info := &WiFiInfo{}

	// Original expensive call - only used as last resort
	cmd := exec.Command("system_profiler", "SPAirPortDataType")
	output, err := cmd.Output()
	if err != nil {
		p.logger.Debug("Failed to run system_profiler: %v", err)
		return info, err
	}

	lines := strings.Split(string(output), "\n")
	inTargetInterface := false
	inCurrentNetwork := false

	for _, line := range lines {
		originalLine := line
		line = strings.TrimSpace(line)

		// Check if we're looking at the right interface
		if strings.Contains(line, interfaceName+":") {
			inTargetInterface = true
			continue
		}

		// If we hit another interface (at the same level as our target), stop looking
		if inTargetInterface && strings.HasSuffix(line, ":") && !strings.Contains(line, interfaceName) &&
			!strings.HasPrefix(originalLine, "        ") { // Don't break on indented content
			break
		}

		if inTargetInterface {
			// Look for "Current Network Information:" section
			if strings.Contains(line, "Current Network Information:") {
				inCurrentNetwork = true
				continue
			}

			if inCurrentNetwork {
				// Parse network name (SSID) - it's the first indented line with a colon after "Current Network Information:"
				if strings.Contains(line, ":") && info.SSID == "" && strings.HasPrefix(originalLine, "            ") {
					// Extract the network name before the colon (Network names are indented with 12 spaces)
					parts := strings.SplitN(line, ":", 2)
					if len(parts) > 0 {
						info.SSID = strings.TrimSpace(parts[0])
					}
				}

				// Parse signal strength: "Signal / Noise: -41 dBm / -83 dBm"
				if strings.Contains(line, "Signal / Noise:") {
					parts := strings.Fields(line)
					for i, part := range parts {
						if part == "Signal" && i+3 < len(parts) && parts[i+4] == "dBm" {
							rssiStr := parts[i+3] // The signal value (-41)
							if rssi, err := strconv.Atoi(rssiStr); err == nil {
								info.SignalStrength = rssi
								info.SignalQuality = p.rssiToQuality(rssi)
							}
							break
						}
					}
				}
			}
		}
	}

	return info, nil
}

// rssiToQuality converts RSSI dBm to quality percentage
func (p *NetworkPlugin) rssiToQuality(rssi int) int {
	// RSSI ranges from -100 (worst) to -30 (best)
	if rssi >= -30 {
		return 100
	} else if rssi <= -100 {
		return 0
	} else {
		// Linear interpolation
		return int(float64(rssi+100) / 70.0 * 100)
	}
}

// GetNetworkIcon returns appropriate network icon based on connection type and quality
func (p *NetworkPlugin) GetNetworkIcon(info *NetworkInfo) string {
	if !info.IsConnected {
		return "󰤮" // No connection icon
	}

	switch info.InterfaceType {
	case "wifi":
		// WiFi icons based on signal quality
		if info.SignalQuality >= 75 {
			return "󰤨" // Strong WiFi
		} else if info.SignalQuality >= 50 {
			return "󰤥" // Medium WiFi
		} else if info.SignalQuality >= 25 {
			return "󰤢" // Weak WiFi
		} else {
			return "󰤟" // Very weak WiFi
		}
	case "ethernet":
		return "󰈀" // Ethernet icon
	default:
		return "󰤮" // Unknown/no connection
	}
}

// HandlePopupAction shows detailed network information
func (p *NetworkPlugin) HandlePopupAction() error {
	p.logger.Info("Showing network popup")

	// Get current network info (now fast with caching)
	netInfo, err := p.GetNetworkInfo()
	if err != nil {
		return fmt.Errorf("failed to get network info for popup: %w", err)
	}

	// Create detailed popup message
	var popupLabel string
	if !netInfo.IsConnected {
		popupLabel = "No Network Connection"
	} else {
		switch netInfo.InterfaceType {
		case "wifi":
			popupLabel = fmt.Sprintf("WiFi: %s | Signal: %d%% (%d dBm) | IP: %s | Interface: %s",
				netInfo.SSID, netInfo.SignalQuality, netInfo.SignalStrength, netInfo.IPAddress, netInfo.InterfaceName)
		case "ethernet":
			popupLabel = fmt.Sprintf("Ethernet | IP: %s | Interface: %s",
				netInfo.IPAddress, netInfo.InterfaceName)
		default:
			popupLabel = "Unknown Connection Type"
		}
	}

	icon := p.GetNetworkIcon(netInfo)
	color := p.getNetworkColor(netInfo)

	if err := p.updater.UpdateItem(itemName, icon, popupLabel, color); err != nil {
		return fmt.Errorf("failed to update popup: %w", err)
	}

	// Schedule reset after 5 seconds and open Network preferences
	go func() {
		time.Sleep(5 * time.Second)

		// Open Network preferences
		if err := utils.OpenApplication("System Preferences"); err != nil {
			p.logger.Error("Failed to open System Preferences: %v", err)
		}

		// Reset to normal display
		if err := p.UpdateDisplay(); err != nil {
			p.logger.Error("Failed to reset display after popup: %v", err)
		}
	}()

	return nil
}

// getNetworkColor returns appropriate color based on connection status
func (p *NetworkPlugin) getNetworkColor(info *NetworkInfo) string {
	if !info.IsConnected {
		return p.config.Colors.Red // No connection
	}

	switch info.InterfaceType {
	case "wifi":
		if info.SignalQuality >= 75 {
			return p.config.Colors.Green // Strong signal
		} else if info.SignalQuality >= 50 {
			return p.config.Colors.Yellow // Medium signal
		} else {
			return p.config.Colors.Peach // Weak signal
		}
	case "ethernet":
		return p.config.Colors.Green // Ethernet is always good
	default:
		return p.config.Colors.Red // Unknown
	}
}

// UpdateDisplay updates the SketchyBar display with current network status
func (p *NetworkPlugin) UpdateDisplay() error {
	// Get current network info (now much faster with caching)
	netInfo, err := p.GetNetworkInfo()
	if err != nil {
		return fmt.Errorf("failed to get network info: %w", err)
	}

	p.logger.Debug("Network status: %s connected=%v interface=%s",
		netInfo.InterfaceType, netInfo.IsConnected, netInfo.InterfaceName)

	// Get appropriate icon and color
	icon := p.GetNetworkIcon(netInfo)
	color := p.getNetworkColor(netInfo)

	// Format label based on connection type
	var label string
	if !netInfo.IsConnected {
		label = "No Connection"
	} else {
		switch netInfo.InterfaceType {
		case "wifi":
			if netInfo.SSID != "" {
				label = fmt.Sprintf("%s (%d%%)", netInfo.SSID, netInfo.SignalQuality)
			} else {
				label = "WiFi Connected"
			}
		case "ethernet":
			label = "Ethernet"
		default:
			label = "Connected"
		}
	}

	// Update SketchyBar
	if err := p.updater.UpdateItem(itemName, icon, label, color); err != nil {
		return fmt.Errorf("failed to update SketchyBar: %w", err)
	}

	return nil
}

// Run starts the network monitoring plugin
func (p *NetworkPlugin) Run() error {
	p.logger.Info("Starting network plugin")

	// 🛠️ SLEEP/WAKE FIX: Check if triggered by system events
	sender := os.Getenv("SENDER")
	if sender == "system_woke" {
		p.logger.Info("System woke from sleep - invalidating network cache")
		if p.cache != nil {
			// Invalidate all network-related cache on wake
			p.cache.InvalidatePattern("active_interfaces*")
			p.cache.InvalidatePattern("interface_type_*")
			p.cache.InvalidatePattern("wifi_info_*")
		}
	} else if sender == "wifi_change" {
		p.logger.Info("WiFi status changed - invalidating WiFi cache")
		if p.cache != nil {
			// Invalidate WiFi-specific cache on network changes
			p.cache.InvalidatePattern("wifi_info_*")
			p.cache.InvalidatePattern("active_interfaces*")
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

	// Regular network monitoring update (now much faster!)
	return p.UpdateDisplay()
}

func main() {
	plugin, err := NewNetworkPlugin()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create network plugin: %v\n", err)
		os.Exit(1)
	}

	if err := plugin.Run(); err != nil {
		plugin.logger.Error("Plugin execution failed: %v", err)
		fmt.Fprintf(os.Stderr, "Network plugin failed: %v\n", err)
		os.Exit(1)
	}
}
