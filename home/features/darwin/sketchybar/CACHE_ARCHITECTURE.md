# Cache Architecture

## Problem Solved

The previous shared cache system caused:
- **Lock contention**: Multiple plugins blocking each other during cache operations
- **Memory interference**: Plugins overwriting each other's cached data
- **Performance degradation**: Bottlenecks when multiple plugins accessed cache simultaneously

## Solution: Isolated Plugin Caches

Each plugin now has its own dedicated cache instance:

```
~/.cache/sketchybar/
├── cpu.db          # CPU plugin cache
├── memory.db       # Memory plugin cache
├── network.db      # Network plugin cache
├── battery.db      # Battery plugin cache
├── volume.db       # Volume plugin cache
├── notifications.db # Notifications plugin cache
├── clock.db        # Clock plugin cache
├── weather.db      # Weather plugin cache
├── spotify.db      # Spotify plugin cache
└── moon_phase.db   # Moon phase plugin cache
```

## Benefits

### Performance
- **No lock contention**: Each plugin operates independently
- **Optimized TTL**: Cache expiration tuned per plugin's data characteristics
- **Parallel execution**: Multiple plugins can access their caches simultaneously

### Reliability
- **Data isolation**: Plugin A cannot corrupt Plugin B's cache
- **Independent recovery**: Individual plugin cache failures don't affect others
- **Easier debugging**: Plugin-specific cache files simplify troubleshooting

### Maintainability
- **Clear ownership**: Each plugin manages its own cache lifecycle
- **Simple cleanup**: Plugin-specific cache files can be cleared independently
- **Predictable behavior**: No shared state between plugins

## Implementation Details

### Cache Initialization
Each plugin creates its own cache manager:

```go
cacheDir := os.ExpandEnv("$HOME/.cache/sketchybar/plugin_name.db")
cache, err := utils.NewCacheManager(cacheDir, defaultTTL)
```

### TTL Strategy
Cache expiration times are optimized per data type:
- **CPU/Memory**: 2-5 seconds (frequent updates)
- **Network/Battery**: 30-60 seconds (moderate updates)
- **Weather**: 30 minutes (infrequent updates)
- **Moon Phase**: 6 hours (very slow changes)

### Thread Safety
Each cache manager provides thread-safe operations using `sync.RWMutex` for concurrent access within the same plugin.

## Migration

The shared cache system has been completely removed:
- ❌ `utils.CachedSystemInfo()` - removed
- ❌ `utils.GetSystemCache()` - removed
- ❌ Global `systemCache` singleton - removed
- ✅ Plugin-specific `utils.NewCacheManager()` - implemented

This ensures clean separation and eliminates all shared cache bottlenecks. 