package utils

import (
	"fmt"
	"runtime"
	"strings"
	"time"

	"sketchybar-plugins/config"
)

// ErrorSeverity defines the severity level of errors
type ErrorSeverity int

const (
	ErrorSeverityInfo ErrorSeverity = iota
	ErrorSeverityWarning
	ErrorSeverityError
	ErrorSeverityCritical
)

// String returns the string representation of ErrorSeverity
func (es ErrorSeverity) String() string {
	switch es {
	case ErrorSeverityInfo:
		return "INFO"
	case ErrorSeverityWarning:
		return "WARNING"
	case ErrorSeverityError:
		return "ERROR"
	case ErrorSeverityCritical:
		return "CRITICAL"
	default:
		return "UNKNOWN"
	}
}

// PluginError represents an error with context and severity
type PluginError struct {
	Plugin    string
	Operation string
	Message   string
	Severity  ErrorSeverity
	Timestamp time.Time
	Stack     string
	Cause     error
}

// Error implements the error interface
func (pe *PluginError) Error() string {
	return fmt.Sprintf("[%s] %s in %s: %s", pe.Severity, pe.Plugin, pe.Operation, pe.Message)
}

// ErrorHandler provides centralized error handling and recovery
type ErrorHandler struct {
	config       *config.GlobalConfig
	logger       *Logger
	errorHistory []PluginError
	maxHistory   int
}

// NewErrorHandler creates a new error handler
func NewErrorHandler(cfg *config.GlobalConfig, logger *Logger) *ErrorHandler {
	return &ErrorHandler{
		config:       cfg,
		logger:       logger,
		errorHistory: make([]PluginError, 0),
		maxHistory:   100, // Keep last 100 errors
	}
}

// HandleError processes an error with appropriate severity and recovery actions
func (eh *ErrorHandler) HandleError(plugin, operation, message string, severity ErrorSeverity, cause error) *PluginError {
	// Create error with context
	pluginErr := &PluginError{
		Plugin:    plugin,
		Operation: operation,
		Message:   message,
		Severity:  severity,
		Timestamp: time.Now(),
		Stack:     eh.getStackTrace(),
		Cause:     cause,
	}

	// Log the error
	eh.logError(pluginErr)

	// Store in history
	eh.addToHistory(pluginErr)

	// Take recovery actions based on severity
	eh.handleRecovery(pluginErr)

	return pluginErr
}

// HandlePanic recovers from panics and converts them to critical errors
func (eh *ErrorHandler) HandlePanic(plugin, operation string) {
	if r := recover(); r != nil {
		message := fmt.Sprintf("Panic recovered: %v", r)
		eh.HandleError(plugin, operation, message, ErrorSeverityCritical, nil)
	}
}

// WrapOperation wraps a potentially failing operation with error handling
func (eh *ErrorHandler) WrapOperation(plugin, operation string, fn func() error) error {
	defer eh.HandlePanic(plugin, operation)

	if err := fn(); err != nil {
		eh.HandleError(plugin, operation, err.Error(), ErrorSeverityError, err)
		return err
	}

	return nil
}

// WrapOperationWithFallback wraps an operation with a fallback function
func (eh *ErrorHandler) WrapOperationWithFallback(plugin, operation string, fn func() error, fallback func() error) error {
	defer eh.HandlePanic(plugin, operation)

	if err := fn(); err != nil {
		eh.HandleError(plugin, operation, fmt.Sprintf("Primary operation failed: %v", err), ErrorSeverityWarning, err)

		if fallbackErr := fallback(); fallbackErr != nil {
			eh.HandleError(plugin, operation, fmt.Sprintf("Fallback also failed: %v", fallbackErr), ErrorSeverityError, fallbackErr)
			return fallbackErr
		}

		eh.logger.Info("Successfully recovered using fallback for %s in %s", operation, plugin)
		return nil
	}

	return nil
}

// GetFallbackValue provides fallback values for common data types
func (eh *ErrorHandler) GetFallbackValue(plugin, operation, dataType string) interface{} {
	eh.HandleError(plugin, operation, fmt.Sprintf("Using fallback value for %s", dataType), ErrorSeverityWarning, nil)

	switch dataType {
	case "cpu_usage":
		return 0.0
	case "memory_usage":
		return map[string]interface{}{
			"usage_percent": 0.0,
			"used_gb":       0.0,
			"total_gb":      48.0, // Apple Silicon default
		}
	case "network_status":
		return map[string]interface{}{
			"connected":  false,
			"interface":  "unknown",
			"connection": "disconnected",
		}
	case "battery_status":
		return map[string]interface{}{
			"percentage": 0,
			"charging":   false,
			"time_left":  "unknown",
		}
	case "volume_level":
		return map[string]interface{}{
			"level": 50,
			"muted": false,
		}
	case "app_name":
		return "Unknown"
	case "notification_count":
		return 0
	case "weather_data":
		return map[string]interface{}{
			"temperature": "??°C",
			"condition":   "Unknown",
		}
	case "time_string":
		return time.Now().Format("15:04")
	case "moon_phase":
		return "🌑"
	case "spotify_track":
		return map[string]interface{}{
			"playing": false,
			"track":   "Not playing",
			"artist":  "",
		}
	default:
		return "N/A"
	}
}

// IsRetryableError determines if an error should trigger a retry
func (eh *ErrorHandler) IsRetryableError(err error) bool {
	if err == nil {
		return false
	}

	errorMsg := strings.ToLower(err.Error())

	// Network-related errors that might be temporary
	retryableErrors := []string{
		"connection refused",
		"timeout",
		"temporary failure",
		"network unreachable",
		"no route to host",
		"connection reset",
		"broken pipe",
		"operation timed out",
	}

	for _, retryable := range retryableErrors {
		if strings.Contains(errorMsg, retryable) {
			return true
		}
	}

	return false
}

// RetryOperation retries an operation with exponential backoff
func (eh *ErrorHandler) RetryOperation(plugin, operation string, fn func() error, maxRetries int) error {
	var lastErr error

	for attempt := 0; attempt <= maxRetries; attempt++ {
		if attempt > 0 {
			// Exponential backoff: 100ms, 200ms, 400ms, 800ms, etc.
			delay := time.Duration(100*1<<uint(attempt-1)) * time.Millisecond
			if delay > 5*time.Second {
				delay = 5 * time.Second // Cap at 5 seconds
			}

			eh.logger.Debug("Retrying %s in %s after %v (attempt %d/%d)", operation, plugin, delay, attempt+1, maxRetries+1)
			time.Sleep(delay)
		}

		lastErr = fn()
		if lastErr == nil {
			if attempt > 0 {
				eh.logger.Info("Operation %s in %s succeeded after %d retries", operation, plugin, attempt)
			}
			return nil
		}

		if !eh.IsRetryableError(lastErr) {
			eh.HandleError(plugin, operation, fmt.Sprintf("Non-retryable error: %v", lastErr), ErrorSeverityError, lastErr)
			break
		}
	}

	eh.HandleError(plugin, operation, fmt.Sprintf("Operation failed after %d retries: %v", maxRetries+1, lastErr), ErrorSeverityError, lastErr)
	return lastErr
}

// GetErrorStats returns statistics about errors
func (eh *ErrorHandler) GetErrorStats() map[string]interface{} {
	stats := make(map[string]interface{})

	// Count by severity
	severityCounts := make(map[string]int)
	pluginCounts := make(map[string]int)

	for _, err := range eh.errorHistory {
		severityCounts[err.Severity.String()]++
		pluginCounts[err.Plugin]++
	}

	stats["total_errors"] = len(eh.errorHistory)
	stats["by_severity"] = severityCounts
	stats["by_plugin"] = pluginCounts
	stats["history_size"] = eh.maxHistory

	return stats
}

// ClearErrorHistory clears the error history
func (eh *ErrorHandler) ClearErrorHistory() {
	eh.errorHistory = make([]PluginError, 0)
	eh.logger.Info("Error history cleared")
}

// Private helper methods

func (eh *ErrorHandler) logError(pluginErr *PluginError) {
	switch pluginErr.Severity {
	case ErrorSeverityInfo:
		eh.logger.Info("[%s] %s: %s", pluginErr.Plugin, pluginErr.Operation, pluginErr.Message)
	case ErrorSeverityWarning:
		eh.logger.Warning("[%s] %s: %s", pluginErr.Plugin, pluginErr.Operation, pluginErr.Message)
	case ErrorSeverityError:
		eh.logger.Error("[%s] %s: %s", pluginErr.Plugin, pluginErr.Operation, pluginErr.Message)
	case ErrorSeverityCritical:
		eh.logger.Error("[CRITICAL] [%s] %s: %s", pluginErr.Plugin, pluginErr.Operation, pluginErr.Message)
		if pluginErr.Stack != "" {
			eh.logger.Error("Stack trace: %s", pluginErr.Stack)
		}
	}
}

func (eh *ErrorHandler) addToHistory(pluginErr *PluginError) {
	eh.errorHistory = append(eh.errorHistory, *pluginErr)

	// Keep only the last maxHistory errors
	if len(eh.errorHistory) > eh.maxHistory {
		eh.errorHistory = eh.errorHistory[len(eh.errorHistory)-eh.maxHistory:]
	}
}

func (eh *ErrorHandler) handleRecovery(pluginErr *PluginError) {
	switch pluginErr.Severity {
	case ErrorSeverityCritical:
		// For critical errors, we might want to reset plugin state or disable features
		eh.logger.Error("Critical error in %s - consider plugin restart", pluginErr.Plugin)

	case ErrorSeverityError:
		// For regular errors, just log and continue
		eh.logger.Warning("Error in %s - continuing with fallback", pluginErr.Plugin)

	case ErrorSeverityWarning:
		// Warnings are logged but don't require action

	case ErrorSeverityInfo:
		// Info level errors are just for tracking
	}
}

func (eh *ErrorHandler) getStackTrace() string {
	buf := make([]byte, 4096)
	n := runtime.Stack(buf, false)
	return string(buf[:n])
}

// Predefined error creation helpers

// NewTimeoutError creates a timeout error
func (eh *ErrorHandler) NewTimeoutError(plugin, operation string, timeout time.Duration) *PluginError {
	message := fmt.Sprintf("Operation timed out after %v", timeout)
	return eh.HandleError(plugin, operation, message, ErrorSeverityWarning, nil)
}

// NewNetworkError creates a network-related error
func (eh *ErrorHandler) NewNetworkError(plugin, operation string, cause error) *PluginError {
	message := fmt.Sprintf("Network error: %v", cause)
	return eh.HandleError(plugin, operation, message, ErrorSeverityWarning, cause)
}

// NewConfigError creates a configuration error
func (eh *ErrorHandler) NewConfigError(plugin, operation string, cause error) *PluginError {
	message := fmt.Sprintf("Configuration error: %v", cause)
	return eh.HandleError(plugin, operation, message, ErrorSeverityError, cause)
}

// NewSystemError creates a system-level error
func (eh *ErrorHandler) NewSystemError(plugin, operation string, cause error) *PluginError {
	message := fmt.Sprintf("System error: %v", cause)
	return eh.HandleError(plugin, operation, message, ErrorSeverityError, cause)
}
