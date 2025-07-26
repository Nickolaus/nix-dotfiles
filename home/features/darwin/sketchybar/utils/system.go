package utils

import (
	"runtime"

	"sketchybar-plugins/config"
)

// SystemInfo provides basic system information utilities
// SIMPLIFIED: No caching - each plugin manages its own cache as needed
type SystemInfo struct {
	config *config.GlobalConfig
	logger *Logger
}

// NewSystemInfo creates a new system info handler
func NewSystemInfo(cfg *config.GlobalConfig, logger *Logger) *SystemInfo {
	return &SystemInfo{
		config: cfg,
		logger: logger,
	}
}

// GetCPUCores returns the number of CPU cores (no caching)
func (si *SystemInfo) GetCPUCores() int {
	return runtime.NumCPU()
}

// GetArchitecture returns the system architecture (no caching)
func (si *SystemInfo) GetArchitecture() string {
	return runtime.GOARCH
}

// REMOVED: All shared cache infrastructure that caused lock contention
// REMOVED: SystemInfoCache and its methods (GetTotalMemory, GetNetworkInterfaces, etc.)
// REMOVED: Global cache singleton that caused plugin interference
//
// Each plugin now implements its own:
// - Dedicated cache (e.g., ~/.cache/sketchybar/memory.db)
// - System detection methods as needed
// - No shared dependencies or lock contention
//
// This provides better:
// ✅ Isolation between plugins
// ✅ Performance (no shared bottlenecks)
// ✅ Debuggability (each plugin has its own cache)
// ✅ Maintainability (simpler architecture)
