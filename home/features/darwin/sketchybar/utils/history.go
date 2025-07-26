package utils

import (
	"fmt"
	"os"
	"strconv"
	"strings"

	"sketchybar-plugins/config"
)

// HistoryManager manages historical data for trends
type HistoryManager struct {
	config *config.GlobalConfig
	logger *Logger
}

// NewHistoryManager creates a new history manager
func NewHistoryManager(cfg *config.GlobalConfig, logger *Logger) *HistoryManager {
	// Ensure cache directory exists
	if err := cfg.Cache.EnsureCacheDir(); err != nil {
		logger.Error("Failed to create cache directory: %v", err)
	}

	return &HistoryManager{
		config: cfg,
		logger: logger,
	}
}

// AppendValue appends a new value to the history file
func (hm *HistoryManager) AppendValue(filename string, value float64) error {
	historyFile := hm.config.Cache.GetCacheFile(filename)

	// Read existing history
	var history []float64
	if data, err := os.ReadFile(historyFile); err == nil {
		lines := strings.Split(strings.TrimSpace(string(data)), "\n")
		for _, line := range lines {
			if line == "" {
				continue
			}
			if val, err := strconv.ParseFloat(line, 64); err == nil {
				history = append(history, val)
			}
		}
	}

	// Add new value
	history = append(history, value)

	// Maintain max length
	if len(history) > hm.config.Cache.HistoryLength {
		history = history[len(history)-hm.config.Cache.HistoryLength:]
	}

	// Write back to file
	var lines []string
	for _, val := range history {
		lines = append(lines, fmt.Sprintf("%.2f", val))
	}

	content := strings.Join(lines, "\n") + "\n"
	if err := os.WriteFile(historyFile, []byte(content), 0644); err != nil {
		return fmt.Errorf("failed to write history file: %w", err)
	}

	return nil
}

// GetHistory returns the history values
func (hm *HistoryManager) GetHistory(filename string) ([]float64, error) {
	historyFile := hm.config.Cache.GetCacheFile(filename)

	data, err := os.ReadFile(historyFile)
	if err != nil {
		return nil, err
	}

	var history []float64
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	for _, line := range lines {
		if line == "" {
			continue
		}
		if val, err := strconv.ParseFloat(line, 64); err == nil {
			history = append(history, val)
		}
	}

	return history, nil
}

// GetTrendDirection returns a simple trend indicator
func (hm *HistoryManager) GetTrendDirection(filename string) string {
	history, err := hm.GetHistory(filename)
	if err != nil || len(history) < 2 {
		return "→" // Neutral if no data or insufficient data
	}

	latest := history[len(history)-1]
	previous := history[len(history)-2]

	if latest > previous*1.1 { // 10% increase threshold
		return "↗"
	} else if latest < previous*0.9 { // 10% decrease threshold
		return "↘"
	}

	return "→" // Stable
}

// ClearHistory removes the history file
func (hm *HistoryManager) ClearHistory(filename string) error {
	historyFile := hm.config.Cache.GetCacheFile(filename)
	return os.Remove(historyFile)
}

// GetHistoryStats returns statistics about the history data
func (hm *HistoryManager) GetHistoryStats(filename string) (map[string]float64, error) {
	history, err := hm.GetHistory(filename)
	if err != nil || len(history) == 0 {
		return nil, fmt.Errorf("no history data available")
	}

	stats := make(map[string]float64)

	// Calculate basic statistics
	var sum, min, max float64
	min = history[0]
	max = history[0]

	for _, value := range history {
		sum += value
		if value < min {
			min = value
		}
		if value > max {
			max = value
		}
	}

	stats["count"] = float64(len(history))
	stats["sum"] = sum
	stats["average"] = sum / float64(len(history))
	stats["min"] = min
	stats["max"] = max
	stats["range"] = max - min

	// Calculate recent trend (last 3 values vs previous 3 values)
	if len(history) >= 6 {
		recentSum := history[len(history)-3] + history[len(history)-2] + history[len(history)-1]
		previousSum := history[len(history)-6] + history[len(history)-5] + history[len(history)-4]

		recentAvg := recentSum / 3
		previousAvg := previousSum / 3

		stats["recent_avg"] = recentAvg
		stats["previous_avg"] = previousAvg
		stats["trend_change"] = ((recentAvg - previousAvg) / previousAvg) * 100 // Percentage change
	}

	return stats, nil
}
