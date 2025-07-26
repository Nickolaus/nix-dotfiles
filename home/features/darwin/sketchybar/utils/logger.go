package utils

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"

	"sketchybar-plugins/config"
)

// LogLevel defines the severity level of log messages
type LogLevel int

const (
	LogLevelTrace LogLevel = iota
	LogLevelDebug
	LogLevelInfo
	LogLevelWarning
	LogLevelError
	LogLevelFatal
	LogLevelOff
)

// String returns the string representation of LogLevel
func (ll LogLevel) String() string {
	switch ll {
	case LogLevelTrace:
		return "TRACE"
	case LogLevelDebug:
		return "DEBUG"
	case LogLevelInfo:
		return "INFO"
	case LogLevelWarning:
		return "WARN"
	case LogLevelError:
		return "ERROR"
	case LogLevelFatal:
		return "FATAL"
	case LogLevelOff:
		return "OFF"
	default:
		return "UNKNOWN"
	}
}

// Color returns ANSI color code for the log level
func (ll LogLevel) Color() string {
	switch ll {
	case LogLevelTrace:
		return "\033[0;37m" // White
	case LogLevelDebug:
		return "\033[0;36m" // Cyan
	case LogLevelInfo:
		return "\033[0;32m" // Green
	case LogLevelWarning:
		return "\033[0;33m" // Yellow
	case LogLevelError:
		return "\033[0;31m" // Red
	case LogLevelFatal:
		return "\033[0;35m" // Magenta
	default:
		return "\033[0m" // Reset
	}
}

// LogEntry represents a structured log entry
type LogEntry struct {
	Timestamp time.Time
	Level     LogLevel
	Plugin    string
	Message   string
	Fields    map[string]interface{}
	File      string
	Line      int
	Function  string
}

// LogFormatter defines how log entries are formatted
type LogFormatter interface {
	Format(entry *LogEntry) string
}

// SimpleFormatter provides basic log formatting
type SimpleFormatter struct {
	UseColors    bool
	ShowFile     bool
	ShowFunction bool
	TimeFormat   string
}

// Format formats a log entry using simple format
func (sf *SimpleFormatter) Format(entry *LogEntry) string {
	timestamp := entry.Timestamp.Format(sf.TimeFormat)
	level := entry.Level.String()

	if sf.UseColors {
		level = fmt.Sprintf("%s%-5s\033[0m", entry.Level.Color(), level)
	}

	message := fmt.Sprintf("[%s] %s [%s]: %s", timestamp, level, entry.Plugin, entry.Message)

	// Add fields if present
	if len(entry.Fields) > 0 {
		var fields []string
		for k, v := range entry.Fields {
			fields = append(fields, fmt.Sprintf("%s=%v", k, v))
		}
		message += fmt.Sprintf(" | %s", strings.Join(fields, ", "))
	}

	// Add file/line info if enabled
	if sf.ShowFile && entry.File != "" {
		message += fmt.Sprintf(" (%s:%d)", filepath.Base(entry.File), entry.Line)
	}

	if sf.ShowFunction && entry.Function != "" {
		message += fmt.Sprintf(" [%s]", entry.Function)
	}

	return message
}

// JSONFormatter provides JSON log formatting
type JSONFormatter struct{}

// Format formats a log entry as JSON
func (jf *JSONFormatter) Format(entry *LogEntry) string {
	// Simple JSON formatting (could use encoding/json for more complex cases)
	fields := make([]string, 0)
	fields = append(fields, fmt.Sprintf(`"timestamp":"%s"`, entry.Timestamp.Format(time.RFC3339)))
	fields = append(fields, fmt.Sprintf(`"level":"%s"`, entry.Level.String()))
	fields = append(fields, fmt.Sprintf(`"plugin":"%s"`, entry.Plugin))
	fields = append(fields, fmt.Sprintf(`"message":"%s"`, entry.Message))

	if entry.File != "" {
		fields = append(fields, fmt.Sprintf(`"file":"%s"`, entry.File))
		fields = append(fields, fmt.Sprintf(`"line":%d`, entry.Line))
	}

	if entry.Function != "" {
		fields = append(fields, fmt.Sprintf(`"function":"%s"`, entry.Function))
	}

	// Add custom fields
	for k, v := range entry.Fields {
		fields = append(fields, fmt.Sprintf(`"%s":"%v"`, k, v))
	}

	return fmt.Sprintf("{%s}", strings.Join(fields, ","))
}

// LogOutput defines where logs are written
type LogOutput struct {
	Writer io.Writer
	Level  LogLevel
}

// Logger provides advanced structured logging for plugins
type Logger struct {
	name      string
	level     LogLevel
	outputs   []LogOutput
	formatter LogFormatter
	mutex     sync.Mutex
	config    *config.GlobalConfig
}

// NewLogger creates a new advanced logger for a plugin
func NewLogger(pluginName string) *Logger {
	logger := &Logger{
		name:  pluginName,
		level: LogLevelInfo, // Default level
		outputs: []LogOutput{
			{Writer: os.Stderr, Level: LogLevelInfo},
		},
		formatter: &SimpleFormatter{
			UseColors:    true,
			ShowFile:     false,
			ShowFunction: false,
			TimeFormat:   "2006-01-02 15:04:05",
		},
	}

	// Try to load config for log level
	if cfg, err := config.LoadConfig(); err == nil {
		logger.config = cfg
		logger.setLogLevelFromConfig()
	}

	return logger
}

// NewLoggerWithConfig creates a logger with explicit configuration
func NewLoggerWithConfig(pluginName string, cfg *config.GlobalConfig) *Logger {
	logger := NewLogger(pluginName)
	logger.config = cfg
	logger.setLogLevelFromConfig()
	return logger
}

// SetLevel sets the minimum log level
func (l *Logger) SetLevel(level LogLevel) {
	l.mutex.Lock()
	defer l.mutex.Unlock()
	l.level = level
}

// SetFormatter sets the log formatter
func (l *Logger) SetFormatter(formatter LogFormatter) {
	l.mutex.Lock()
	defer l.mutex.Unlock()
	l.formatter = formatter
}

// AddOutput adds a new log output destination
func (l *Logger) AddOutput(writer io.Writer, level LogLevel) {
	l.mutex.Lock()
	defer l.mutex.Unlock()
	l.outputs = append(l.outputs, LogOutput{Writer: writer, Level: level})
}

// AddFileOutput adds a file output for logging
func (l *Logger) AddFileOutput(filename string, level LogLevel) error {
	// Ensure log directory exists
	logDir := filepath.Dir(filename)
	if err := os.MkdirAll(logDir, 0755); err != nil {
		return fmt.Errorf("failed to create log directory: %w", err)
	}

	file, err := os.OpenFile(filename, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		return fmt.Errorf("failed to open log file: %w", err)
	}

	l.AddOutput(file, level)
	return nil
}

// Core logging methods with structured fields

// Trace logs a trace message
func (l *Logger) Trace(format string, args ...interface{}) {
	l.log(LogLevelTrace, format, args...)
}

// Debug logs a debug message
func (l *Logger) Debug(format string, args ...interface{}) {
	l.log(LogLevelDebug, format, args...)
}

// Info logs an info message
func (l *Logger) Info(format string, args ...interface{}) {
	l.log(LogLevelInfo, format, args...)
}

// Warning logs a warning message
func (l *Logger) Warning(format string, args ...interface{}) {
	l.log(LogLevelWarning, format, args...)
}

// Error logs an error message
func (l *Logger) Error(format string, args ...interface{}) {
	l.log(LogLevelError, format, args...)
}

// Fatal logs a fatal message and exits
func (l *Logger) Fatal(format string, args ...interface{}) {
	l.log(LogLevelFatal, format, args...)
	os.Exit(1)
}

// Structured logging methods with fields

// TraceWithFields logs a trace message with structured fields
func (l *Logger) TraceWithFields(message string, fields map[string]interface{}) {
	l.logWithFields(LogLevelTrace, message, fields)
}

// DebugWithFields logs a debug message with structured fields
func (l *Logger) DebugWithFields(message string, fields map[string]interface{}) {
	l.logWithFields(LogLevelDebug, message, fields)
}

// InfoWithFields logs an info message with structured fields
func (l *Logger) InfoWithFields(message string, fields map[string]interface{}) {
	l.logWithFields(LogLevelInfo, message, fields)
}

// WarningWithFields logs a warning message with structured fields
func (l *Logger) WarningWithFields(message string, fields map[string]interface{}) {
	l.logWithFields(LogLevelWarning, message, fields)
}

// ErrorWithFields logs an error message with structured fields
func (l *Logger) ErrorWithFields(message string, fields map[string]interface{}) {
	l.logWithFields(LogLevelError, message, fields)
}

// Performance logging helpers

// LogDuration logs the duration of an operation
func (l *Logger) LogDuration(operation string, duration time.Duration) {
	fields := map[string]interface{}{
		"operation":   operation,
		"duration":    duration.String(),
		"duration_ms": duration.Milliseconds(),
	}

	level := LogLevelDebug
	if duration > 1*time.Second {
		level = LogLevelWarning
	}

	l.logWithFields(level, fmt.Sprintf("Operation '%s' completed", operation), fields)
}

// LogPerformance logs performance metrics
func (l *Logger) LogPerformance(metrics map[string]interface{}) {
	l.logWithFields(LogLevelDebug, "Performance metrics", metrics)
}

// Context logging helpers

// WithContext creates a new logger with additional context
func (l *Logger) WithContext(fields map[string]interface{}) *ContextLogger {
	return &ContextLogger{
		logger: l,
		fields: fields,
	}
}

// ContextLogger provides logging with persistent context
type ContextLogger struct {
	logger *Logger
	fields map[string]interface{}
}

// Debug logs a debug message with context
func (cl *ContextLogger) Debug(format string, args ...interface{}) {
	message := fmt.Sprintf(format, args...)
	cl.logger.logWithFields(LogLevelDebug, message, cl.fields)
}

// Info logs an info message with context
func (cl *ContextLogger) Info(format string, args ...interface{}) {
	message := fmt.Sprintf(format, args...)
	cl.logger.logWithFields(LogLevelInfo, message, cl.fields)
}

// Warning logs a warning message with context
func (cl *ContextLogger) Warning(format string, args ...interface{}) {
	message := fmt.Sprintf(format, args...)
	cl.logger.logWithFields(LogLevelWarning, message, cl.fields)
}

// Error logs an error message with context
func (cl *ContextLogger) Error(format string, args ...interface{}) {
	message := fmt.Sprintf(format, args...)
	cl.logger.logWithFields(LogLevelError, message, cl.fields)
}

// Private methods

func (l *Logger) log(level LogLevel, format string, args ...interface{}) {
	l.logWithFields(level, fmt.Sprintf(format, args...), nil)
}

func (l *Logger) logWithFields(level LogLevel, message string, fields map[string]interface{}) {
	if level < l.level {
		return
	}

	entry := &LogEntry{
		Timestamp: time.Now(),
		Level:     level,
		Plugin:    l.name,
		Message:   message,
		Fields:    fields,
	}

	// Add caller information
	if pc, file, line, ok := runtime.Caller(3); ok {
		entry.File = file
		entry.Line = line

		if fn := runtime.FuncForPC(pc); fn != nil {
			entry.Function = fn.Name()
		}
	}

	l.writeToOutputs(entry)
}

func (l *Logger) writeToOutputs(entry *LogEntry) {
	l.mutex.Lock()
	defer l.mutex.Unlock()

	formatted := l.formatter.Format(entry)

	for _, output := range l.outputs {
		if entry.Level >= output.Level {
			fmt.Fprintln(output.Writer, formatted)
		}
	}
}

func (l *Logger) setLogLevelFromConfig() {
	// This would read from config if logging configuration was added
	// For now, we'll use environment variables as fallback
	if logLevel := os.Getenv("SKETCHYBAR_LOG_LEVEL"); logLevel != "" {
		switch strings.ToUpper(logLevel) {
		case "TRACE":
			l.level = LogLevelTrace
		case "DEBUG":
			l.level = LogLevelDebug
		case "INFO":
			l.level = LogLevelInfo
		case "WARNING", "WARN":
			l.level = LogLevelWarning
		case "ERROR":
			l.level = LogLevelError
		case "FATAL":
			l.level = LogLevelFatal
		case "OFF":
			l.level = LogLevelOff
		}
	}
}

// Package-level convenience functions

var defaultLogger = NewLogger("default")

// SetDefaultLogLevel sets the default log level for all new loggers
func SetDefaultLogLevel(level LogLevel) {
	defaultLogger.SetLevel(level)
}

// EnableFileLogging enables logging to a file for all loggers
func EnableFileLogging(filename string) error {
	return defaultLogger.AddFileOutput(filename, LogLevelDebug)
}

// EnableJSONLogging switches to JSON formatting for structured logging
func EnableJSONLogging() {
	defaultLogger.SetFormatter(&JSONFormatter{})
}
