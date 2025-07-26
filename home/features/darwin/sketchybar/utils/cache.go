package utils

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// CacheEntry represents a cached value with metadata
type CacheEntry struct {
	Value     interface{} `json:"value"`
	Timestamp int64       `json:"timestamp"`
	TTL       int64       `json:"ttl"` // Time to live in seconds
	Key       string      `json:"key"`
}

// CacheManager handles intelligent caching of system information
type CacheManager struct {
	cacheDir   string
	memCache   map[string]*CacheEntry
	mutex      sync.RWMutex
	defaultTTL int64
}

// CacheConfig defines caching behavior for different types of data
type CacheConfig struct {
	// Static system info (rarely changes)
	StaticTTL int64 // Hardware specs, architecture, total memory

	// Semi-static info (changes occasionally)
	SemiStaticTTL int64 // Network interfaces, installed apps, capabilities

	// Dynamic info (changes frequently)
	DynamicTTL int64 // CPU usage, memory usage, network status

	// Temporary info (very short lived)
	TemporaryTTL int64 // API responses, command outputs
}

// DefaultCacheConfig returns sensible default cache durations
func DefaultCacheConfig() CacheConfig {
	return CacheConfig{
		StaticTTL:     3600 * 24, // 24 hours - hardware specs
		SemiStaticTTL: 3600,      // 1 hour - network interfaces, apps
		DynamicTTL:    60,        // 1 minute - system stats
		TemporaryTTL:  30,        // 30 seconds - command outputs
	}
}

// NewCacheManager creates a new cache manager with the specified cache directory
func NewCacheManager(cacheDir string, defaultTTL int64) (*CacheManager, error) {
	if err := os.MkdirAll(cacheDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create cache directory: %w", err)
	}

	return &CacheManager{
		cacheDir:   cacheDir,
		memCache:   make(map[string]*CacheEntry),
		defaultTTL: defaultTTL,
	}, nil
}

// Set stores a value in the cache with the specified TTL
func (cm *CacheManager) Set(key string, value interface{}, ttl int64) error {
	cm.mutex.Lock()
	defer cm.mutex.Unlock()

	if ttl <= 0 {
		ttl = cm.defaultTTL
	}

	entry := &CacheEntry{
		Value:     value,
		Timestamp: time.Now().Unix(),
		TTL:       ttl,
		Key:       key,
	}

	// Store in memory cache
	cm.memCache[key] = entry

	// Persist to disk for longer-lived entries (TTL > 5 minutes)
	if ttl > 300 {
		return cm.persistToDisk(key, entry)
	}

	return nil
}

// Get retrieves a value from the cache, checking both memory and disk
func (cm *CacheManager) Get(key string) (interface{}, bool) {
	// FIXED: Use proper write lock when modifying cache to prevent deadlocks
	cm.mutex.Lock()
	defer cm.mutex.Unlock()

	// Check memory cache first
	if entry, exists := cm.memCache[key]; exists {
		if cm.isValid(entry) {
			return entry.Value, true
		}
		// Remove expired entry from memory (requires write lock)
		delete(cm.memCache, key)
	}

	// Check disk cache for persistent entries
	if entry := cm.loadFromDisk(key); entry != nil && cm.isValid(entry) {
		// Restore to memory cache if still valid (requires write lock)
		cm.memCache[key] = entry
		return entry.Value, true
	}

	return nil, false
}

// GetOrSet retrieves a value from cache, or sets it using the provided function
func (cm *CacheManager) GetOrSet(key string, ttl int64, fn func() (interface{}, error)) (interface{}, error) {
	// Try to get from cache first
	if value, exists := cm.Get(key); exists {
		return value, nil
	}

	// Cache miss - compute value
	value, err := fn()
	if err != nil {
		return nil, err
	}

	// Store in cache
	if setErr := cm.Set(key, value, ttl); setErr != nil {
		// Log error but don't fail the operation
		fmt.Printf("Warning: Failed to cache value for key '%s': %v\n", key, setErr)
	}

	return value, nil
}

// SetStatic stores static system information (24 hour TTL)
func (cm *CacheManager) SetStatic(key string, value interface{}) error {
	config := DefaultCacheConfig()
	return cm.Set(key, value, config.StaticTTL)
}

// SetSemiStatic stores semi-static system information (1 hour TTL)
func (cm *CacheManager) SetSemiStatic(key string, value interface{}) error {
	config := DefaultCacheConfig()
	return cm.Set(key, value, config.SemiStaticTTL)
}

// SetDynamic stores dynamic system information (1 minute TTL)
func (cm *CacheManager) SetDynamic(key string, value interface{}) error {
	config := DefaultCacheConfig()
	return cm.Set(key, value, config.DynamicTTL)
}

// SetTemporary stores temporary information (30 second TTL)
func (cm *CacheManager) SetTemporary(key string, value interface{}) error {
	config := DefaultCacheConfig()
	return cm.Set(key, value, config.TemporaryTTL)
}

// Invalidate removes a specific key from the cache
func (cm *CacheManager) Invalidate(key string) {
	cm.mutex.Lock()
	defer cm.mutex.Unlock()

	delete(cm.memCache, key)
	cm.removeFromDisk(key)
}

// InvalidatePattern removes all keys matching a pattern (basic wildcard support)
func (cm *CacheManager) InvalidatePattern(pattern string) {
	cm.mutex.Lock()
	defer cm.mutex.Unlock()

	// Simple wildcard matching - for more complex patterns, could use regex
	for key := range cm.memCache {
		if cm.matchesPattern(key, pattern) {
			delete(cm.memCache, key)
			cm.removeFromDisk(key)
		}
	}
}

// Clear removes all entries from the cache
func (cm *CacheManager) Clear() {
	cm.mutex.Lock()
	defer cm.mutex.Unlock()

	cm.memCache = make(map[string]*CacheEntry)

	// Clear disk cache
	if err := os.RemoveAll(cm.cacheDir); err == nil {
		os.MkdirAll(cm.cacheDir, 0755)
	}
}

// Stats returns cache statistics
func (cm *CacheManager) Stats() map[string]interface{} {
	cm.mutex.RLock()
	defer cm.mutex.RUnlock()

	validCount := 0
	expiredCount := 0
	totalSize := 0

	for _, entry := range cm.memCache {
		if cm.isValid(entry) {
			validCount++
		} else {
			expiredCount++
		}
		totalSize++
	}

	return map[string]interface{}{
		"total_entries":   totalSize,
		"valid_entries":   validCount,
		"expired_entries": expiredCount,
		"cache_dir":       cm.cacheDir,
		"memory_entries":  len(cm.memCache),
	}
}

// CleanupExpired removes expired entries from memory and disk
func (cm *CacheManager) CleanupExpired() {
	cm.mutex.Lock()
	defer cm.mutex.Unlock()

	// Clean memory cache
	for key, entry := range cm.memCache {
		if !cm.isValid(entry) {
			delete(cm.memCache, key)
			cm.removeFromDisk(key)
		}
	}

	// Clean disk cache files
	cm.cleanupDiskCache()
}

// GetCacheKey generates a standardized cache key
func (cm *CacheManager) GetCacheKey(category, subcategory, identifier string) string {
	if subcategory == "" {
		return fmt.Sprintf("%s:%s", category, identifier)
	}
	return fmt.Sprintf("%s:%s:%s", category, subcategory, identifier)
}

// Private helper methods

// isValid checks if a cache entry is still valid based on TTL
func (cm *CacheManager) isValid(entry *CacheEntry) bool {
	return time.Now().Unix()-entry.Timestamp < entry.TTL
}

// persistToDisk saves a cache entry to disk
func (cm *CacheManager) persistToDisk(key string, entry *CacheEntry) error {
	filename := cm.getCacheFilePath(key)

	data, err := json.MarshalIndent(entry, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal cache entry: %w", err)
	}

	return os.WriteFile(filename, data, 0644)
}

// loadFromDisk loads a cache entry from disk
func (cm *CacheManager) loadFromDisk(key string) *CacheEntry {
	filename := cm.getCacheFilePath(key)

	data, err := os.ReadFile(filename)
	if err != nil {
		return nil
	}

	var entry CacheEntry
	if err := json.Unmarshal(data, &entry); err != nil {
		return nil
	}

	return &entry
}

// removeFromDisk deletes a cache entry from disk
func (cm *CacheManager) removeFromDisk(key string) {
	filename := cm.getCacheFilePath(key)
	os.Remove(filename)
}

// getCacheFilePath returns the file path for a cache key
func (cm *CacheManager) getCacheFilePath(key string) string {
	// Use a safe filename by replacing special characters
	safeKey := cm.sanitizeKey(key)
	return filepath.Join(cm.cacheDir, safeKey+".json")
}

// sanitizeKey makes a cache key safe for use as a filename
func (cm *CacheManager) sanitizeKey(key string) string {
	// Replace problematic characters with safe alternatives
	safe := key
	safe = string([]rune(safe)) // Ensure valid UTF-8
	replacements := map[string]string{
		"/":  "_slash_",
		"\\": "_backslash_",
		":":  "_colon_",
		"*":  "_star_",
		"?":  "_question_",
		"\"": "_quote_",
		"<":  "_lt_",
		">":  "_gt_",
		"|":  "_pipe_",
	}

	for old, new := range replacements {
		safe = filepath.Join(filepath.Dir(safe), filepath.Base(safe))
		safe = string([]rune(safe))
		for i, r := range safe {
			if string(r) == old {
				safe = safe[:i] + new + safe[i+1:]
			}
		}
	}

	return safe
}

// matchesPattern performs basic wildcard matching
func (cm *CacheManager) matchesPattern(text, pattern string) bool {
	// Simple wildcard matching - supports * for any characters
	if pattern == "*" {
		return true
	}

	// For now, just check if pattern is a prefix (could be enhanced)
	if len(pattern) > 0 && pattern[len(pattern)-1] == '*' {
		prefix := pattern[:len(pattern)-1]
		return len(text) >= len(prefix) && text[:len(prefix)] == prefix
	}

	return text == pattern
}

// cleanupDiskCache removes expired files from disk cache
func (cm *CacheManager) cleanupDiskCache() {
	entries, err := os.ReadDir(cm.cacheDir)
	if err != nil {
		return
	}

	for _, entry := range entries {
		if !entry.IsDir() && filepath.Ext(entry.Name()) == ".json" {
			filePath := filepath.Join(cm.cacheDir, entry.Name())
			data, err := os.ReadFile(filePath)
			if err != nil {
				continue
			}

			var cacheEntry CacheEntry
			if err := json.Unmarshal(data, &cacheEntry); err != nil {
				// Remove corrupted cache files
				os.Remove(filePath)
				continue
			}

			if !cm.isValid(&cacheEntry) {
				os.Remove(filePath)
			}
		}
	}
}
 