package utils

import (
	"fmt"
	"strings"

	"sketchybar-plugins/config"
)

// TrendGraphStyle defines different graph visualization styles
type TrendGraphStyle int

const (
	StyleBasic TrendGraphStyle = iota
	StyleSpark
	StyleBlocks
	StyleBars
	StyleDots
)

// TrendGraphConfig configures trend graph appearance
type TrendGraphConfig struct {
	Style     TrendGraphStyle
	Width     int
	ShowPeak  bool
	ShowAvg   bool
	ShowTrend bool
}

// TrendGraph provides trend visualization functionality
type TrendGraph struct {
	config *config.GlobalConfig
	logger *Logger
}

// NewTrendGraph creates a new trend graph generator
func NewTrendGraph(cfg *config.GlobalConfig, logger *Logger) *TrendGraph {
	return &TrendGraph{
		config: cfg,
		logger: logger,
	}
}

// GenerateTrendGraph generates a simple ASCII trend graph (legacy method)
func (tg *TrendGraph) GenerateTrendGraph(values []float64) string {
	config := TrendGraphConfig{
		Style: StyleBasic,
		Width: len(values),
	}
	return tg.GenerateEnhancedTrendGraph(values, config)
}

// GenerateEnhancedTrendGraph generates enhanced ASCII trend graphs with multiple styles
func (tg *TrendGraph) GenerateEnhancedTrendGraph(values []float64, config TrendGraphConfig) string {
	if len(values) == 0 {
		return tg.generateEmptyGraph(config)
	}

	// Resample data to fit width if needed
	displayValues := tg.resampleValues(values, config.Width)

	switch config.Style {
	case StyleSpark:
		return tg.generateSparkline(displayValues, config)
	case StyleBlocks:
		return tg.generateBlockGraph(displayValues, config)
	case StyleBars:
		return tg.generateBarGraph(displayValues, config)
	case StyleDots:
		return tg.generateDotGraph(displayValues, config)
	default: // StyleBasic
		return tg.generateBasicGraph(displayValues, config)
	}
}

// generateSparkline creates a compact sparkline using Unicode block characters
func (tg *TrendGraph) generateSparkline(values []float64, config TrendGraphConfig) string {
	if len(values) == 0 {
		return strings.Repeat("▁", config.Width)
	}

	sparkChars := []string{"▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"}
	min, max := tg.getMinMax(values)
	if max == min {
		return strings.Repeat("▄", len(values))
	}

	var result strings.Builder
	for _, value := range values {
		normalized := (value - min) / (max - min)
		charIndex := int(normalized * float64(len(sparkChars)-1))
		if charIndex >= len(sparkChars) {
			charIndex = len(sparkChars) - 1
		}
		result.WriteString(sparkChars[charIndex])
	}

	if config.ShowPeak || config.ShowAvg || config.ShowTrend {
		result.WriteString(" ")
		result.WriteString(tg.generateStats(values, config))
	}

	return result.String()
}

// generateBlockGraph creates a block-style graph using shaded Unicode blocks
func (tg *TrendGraph) generateBlockGraph(values []float64, config TrendGraphConfig) string {
	if len(values) == 0 {
		return strings.Repeat("░", config.Width)
	}

	blocks := []string{"░", "▒", "▓", "█"}
	min, max := tg.getMinMax(values)
	if max == min {
		return strings.Repeat("▒", len(values))
	}

	var result strings.Builder
	for _, value := range values {
		normalized := (value - min) / (max - min)
		blockIndex := int(normalized * float64(len(blocks)-1))
		if blockIndex >= len(blocks) {
			blockIndex = len(blocks) - 1
		}
		result.WriteString(blocks[blockIndex])
	}

	if config.ShowPeak || config.ShowAvg || config.ShowTrend {
		result.WriteString(" ")
		result.WriteString(tg.generateStats(values, config))
	}

	return result.String()
}

// generateBarGraph creates a vertical bar chart (single line representation)
func (tg *TrendGraph) generateBarGraph(values []float64, config TrendGraphConfig) string {
	if len(values) == 0 {
		return strings.Repeat("▁", config.Width)
	}

	bars := []string{"▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"}
	min, max := tg.getMinMax(values)
	if max == min {
		return strings.Repeat("▄", len(values))
	}

	var result strings.Builder
	for _, value := range values {
		normalized := (value - min) / (max - min)
		barIndex := int(normalized * float64(len(bars)-1))
		if barIndex >= len(bars) {
			barIndex = len(bars) - 1
		}
		result.WriteString(bars[barIndex])
	}

	if config.ShowPeak || config.ShowAvg || config.ShowTrend {
		result.WriteString(" ")
		result.WriteString(tg.generateStats(values, config))
	}

	return result.String()
}

// generateDotGraph creates a dot-based graph showing data points
func (tg *TrendGraph) generateDotGraph(values []float64, config TrendGraphConfig) string {
	if len(values) == 0 {
		return strings.Repeat("·", config.Width)
	}

	dots := []string{"·", "∘", "○", "●"}
	min, max := tg.getMinMax(values)
	if max == min {
		return strings.Repeat("○", len(values))
	}

	var result strings.Builder
	for _, value := range values {
		normalized := (value - min) / (max - min)
		dotIndex := int(normalized * float64(len(dots)-1))
		if dotIndex >= len(dots) {
			dotIndex = len(dots) - 1
		}
		result.WriteString(dots[dotIndex])
	}

	if config.ShowPeak || config.ShowAvg || config.ShowTrend {
		result.WriteString(" ")
		result.WriteString(tg.generateStats(values, config))
	}

	return result.String()
}

// generateBasicGraph creates the original basic ASCII graph
func (tg *TrendGraph) generateBasicGraph(values []float64, config TrendGraphConfig) string {
	if len(values) == 0 {
		return ""
	}

	var result strings.Builder
	for _, value := range values {
		switch {
		case value > 85:
			result.WriteString("█") // Full bar - critical
		case value > 70:
			result.WriteString("▇") // High
		case value > 50:
			result.WriteString("▅") // Medium-high
		case value > 30:
			result.WriteString("▃") // Medium
		case value > 15:
			result.WriteString("▂") // Low
		default:
			result.WriteString("▁") // Very low
		}
	}

	if config.ShowPeak || config.ShowAvg || config.ShowTrend {
		result.WriteString(" ")
		result.WriteString(tg.generateStats(values, config))
	}

	return result.String()
}

// generateStats creates a statistics summary for the graph
func (tg *TrendGraph) generateStats(values []float64, config TrendGraphConfig) string {
	if len(values) == 0 {
		return ""
	}

	var parts []string

	if config.ShowPeak {
		_, max := tg.getMinMax(values)
		parts = append(parts, fmt.Sprintf("↑%.0f%%", max))
	}

	if config.ShowAvg {
		avg := tg.calculateAverage(values)
		parts = append(parts, fmt.Sprintf("~%.0f%%", avg))
	}

	if config.ShowTrend {
		trend := tg.calculateTrend(values)
		switch trend {
		case "rising":
			parts = append(parts, "↗")
		case "falling":
			parts = append(parts, "↘")
		default:
			parts = append(parts, "→")
		}
	}

	return strings.Join(parts, " ")
}

// generateEmptyGraph creates an empty graph placeholder
func (tg *TrendGraph) generateEmptyGraph(config TrendGraphConfig) string {
	switch config.Style {
	case StyleSpark, StyleBars:
		return strings.Repeat("▁", config.Width)
	case StyleBlocks:
		return strings.Repeat("░", config.Width)
	case StyleDots:
		return strings.Repeat("·", config.Width)
	default:
		return strings.Repeat("_", config.Width)
	}
}

// Helper functions

// getMinMax finds the minimum and maximum values
func (tg *TrendGraph) getMinMax(values []float64) (float64, float64) {
	if len(values) == 0 {
		return 0, 100
	}

	min, max := values[0], values[0]
	for _, value := range values[1:] {
		if value < min {
			min = value
		}
		if value > max {
			max = value
		}
	}

	return min, max
}

// resampleValues resamples values to fit the target width
func (tg *TrendGraph) resampleValues(values []float64, targetWidth int) []float64 {
	if len(values) <= targetWidth || targetWidth <= 0 {
		return values
	}

	step := float64(len(values)) / float64(targetWidth)
	resampled := make([]float64, targetWidth)

	for i := 0; i < targetWidth; i++ {
		sourceIndex := int(float64(i) * step)
		if sourceIndex >= len(values) {
			sourceIndex = len(values) - 1
		}
		resampled[i] = values[sourceIndex]
	}

	return resampled
}

// calculateAverage calculates the average value
func (tg *TrendGraph) calculateAverage(values []float64) float64 {
	if len(values) == 0 {
		return 0
	}

	sum := 0.0
	for _, value := range values {
		sum += value
	}

	return sum / float64(len(values))
}

// calculateTrend determines the trend direction
func (tg *TrendGraph) calculateTrend(values []float64) string {
	if len(values) < 3 {
		return "stable"
	}

	// Compare recent third to older third
	third := len(values) / 3
	if third == 0 {
		third = 1
	}

	recent := values[len(values)-third:]
	older := values[:third]

	avgRecent := tg.calculateAverage(recent)
	avgOlder := tg.calculateAverage(older)

	diff := avgRecent - avgOlder
	threshold := 2.0 // 2% threshold

	if diff > threshold {
		return "rising"
	} else if diff < -threshold {
		return "falling"
	}
	return "stable"
}

// GetTrendFromHistory combines history and trend analysis
func (tg *TrendGraph) GetTrendFromHistory(historyManager *HistoryManager, filename string) (string, error) {
	values, err := historyManager.GetHistory(filename)
	if err != nil || len(values) < 2 {
		return "→", err
	}

	trend := tg.calculateTrend(values)
	switch trend {
	case "rising":
		return "↗", nil
	case "falling":
		return "↘", nil
	default:
		return "→", nil
	}
}
