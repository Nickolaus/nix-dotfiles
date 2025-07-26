#!/bin/bash

# SketchyBar Plugin Performance Benchmark Suite
# ==============================================
# Tests all plugins and measures execution time, cache effectiveness, and system impact

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$SCRIPT_DIR/results"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create results directory
mkdir -p "$RESULTS_DIR"

echo -e "${BLUE}🚀 SketchyBar Plugin Performance Benchmark${NC}"
echo "=============================================="
echo "Date: $(date)"
echo "Project: $PROJECT_DIR"
echo "Results: $RESULTS_DIR"
echo ""

# Ensure plugins are built
echo -e "${YELLOW}📦 Building all plugins...${NC}"
cd "$PROJECT_DIR"
make build-all >/dev/null 2>&1
echo "✅ Build completed"
echo ""

# Function to benchmark a single plugin
benchmark_plugin() {
    local plugin_name="$1"
    local binary_path="$PROJECT_DIR/bin/$plugin_name"
    local output_file="$RESULTS_DIR/${plugin_name}_profile.txt"
    
    if [[ ! -f "$binary_path" ]]; then
        echo -e "${RED}❌ $plugin_name: Binary not found${NC}"
        return 1
    fi
    
    echo -n -e "${BLUE}⏱️  Testing $plugin_name...${NC} "
    
    # Clear any existing cache for clean testing
    rm -rf ~/.cache/sketchybar/${plugin_name}.db 2>/dev/null || true
    
    # Warm up run (don't count this)
    timeout 10s "$binary_path" >/dev/null 2>&1 || true
    
    # Benchmark runs
    local times=()
    local runs=5
    
    for i in $(seq 1 $runs); do
        local start_time=$(python3 -c "import time; print(time.time())")
        timeout 10s "$binary_path" >/dev/null 2>&1
        local exit_code=$?
        local end_time=$(python3 -c "import time; print(time.time())")
        
        if [[ $exit_code -eq 0 ]]; then
            local duration=$(python3 -c "print(f'{$end_time - $start_time:.3f}')")
            times+=("$duration")
        else
            echo -e "${RED}FAILED (exit code: $exit_code)${NC}"
            return 1
        fi
    done
    
    # Calculate statistics
    local total_time=0
    for time in "${times[@]}"; do
        total_time=$(python3 -c "print(f'{$total_time + $time:.3f}')")
    done
    
    local avg_time=$(python3 -c "print(f'{$total_time / $runs:.3f}')")
    local min_time=$(printf '%s\n' "${times[@]}" | sort -n | head -1)
    local max_time=$(printf '%s\n' "${times[@]}" | sort -n | tail -1)
    local ms_avg=$(python3 -c "print(f'{$avg_time * 1000:.0f}')")
    
    # Performance rating
    local rating
    local color
    if (( $(echo "$avg_time < 0.1" | bc -l) )); then
        rating="⚡ EXCELLENT"
        color="$GREEN"
    elif (( $(echo "$avg_time < 0.5" | bc -l) )); then
        rating="✅ GOOD"
        color="$GREEN"
    elif (( $(echo "$avg_time < 2.0" | bc -l) )); then
        rating="⚠️  ACCEPTABLE"
        color="$YELLOW"
    else
        rating="🔴 NEEDS OPTIMIZATION"
        color="$RED"
    fi
    
    echo -e "${color}${ms_avg}ms $rating${NC}"
    
    # Save detailed results
    cat > "$output_file" << EOF
Plugin: $plugin_name
Benchmark Date: $(date)
Runs: $runs
Average Time: ${avg_time}s (${ms_avg}ms)
Min Time: ${min_time}s
Max Time: ${max_time}s
Rating: $rating
Individual Times: ${times[*]}
Binary Path: $binary_path
Cache Path: ~/.cache/sketchybar/${plugin_name}.db
EOF
    
    return 0
}

# Test cache effectiveness
test_cache_effectiveness() {
    echo -e "${YELLOW}🗄️  Testing cache effectiveness...${NC}"
    
    # Test a few plugins with cache timing
    local test_plugins=("cpu" "network" "weather")
    local cache_results="$RESULTS_DIR/cache_effectiveness.txt"
    
    echo "Cache Effectiveness Test" > "$cache_results"
    echo "========================" >> "$cache_results"
    echo "Date: $(date)" >> "$cache_results"
    echo "" >> "$cache_results"
    
    for plugin in "${test_plugins[@]}"; do
        local binary_path="$PROJECT_DIR/bin/$plugin"
        if [[ ! -f "$binary_path" ]]; then
            continue
        fi
        
        echo "Testing $plugin cache..." >> "$cache_results"
        
        # Clear cache and measure cold start
        rm -rf ~/.cache/sketchybar/${plugin}.db 2>/dev/null || true
        local cold_start=$(python3 -c "
import time
start = time.time()
import subprocess
subprocess.run(['$binary_path'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
end = time.time()
print(f'{end - start:.3f}')
" 2>/dev/null || echo "0.000")
        
        # Measure warm cache hit
        local warm_start=$(python3 -c "
import time
start = time.time()
import subprocess
subprocess.run(['$binary_path'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
end = time.time()
print(f'{end - start:.3f}')
" 2>/dev/null || echo "0.000")
        
        echo "  Cold start: ${cold_start}s" >> "$cache_results"
        echo "  Warm cache: ${warm_start}s" >> "$cache_results"
        
        if [[ "$cold_start" != "0.000" ]] && [[ "$warm_start" != "0.000" ]]; then
            local improvement=$(python3 -c "print(f'{($cold_start - $warm_start) / $cold_start * 100:.1f}')" 2>/dev/null || echo "0.0")
            echo "  Cache improvement: ${improvement}%" >> "$cache_results"
        fi
        echo "" >> "$cache_results"
    done
    
    echo "✅ Cache effectiveness test completed"
}

# Generate summary report
generate_summary() {
    echo -e "${YELLOW}📊 Generating summary report...${NC}"
    
    local summary_file="$RESULTS_DIR/performance_summary.txt"
    local csv_file="$RESULTS_DIR/performance_data.csv"
    
    # CSV header
    echo "Plugin,Average_Time_ms,Rating,Min_Time_ms,Max_Time_ms" > "$csv_file"
    
    # Summary header
    cat > "$summary_file" << EOF
SketchyBar Plugin Performance Summary
====================================
Generated: $(date)
Project: $PROJECT_DIR

Performance Ratings:
⚡ EXCELLENT: <100ms
✅ GOOD: 100-500ms
⚠️  ACCEPTABLE: 500ms-2s
🔴 NEEDS OPTIMIZATION: >2s

Individual Plugin Results:
EOF
    
    # Process individual plugin results
    for profile_file in "$RESULTS_DIR"/*_profile.txt; do
        if [[ -f "$profile_file" ]]; then
            local plugin_name=$(basename "$profile_file" _profile.txt)
            local avg_time=$(grep "Average Time:" "$profile_file" | cut -d'(' -f2 | cut -d'm' -f1)
            local rating=$(grep "Rating:" "$profile_file" | cut -d' ' -f2-)
            local min_time=$(grep "Min Time:" "$profile_file" | cut -d' ' -f3 | cut -d's' -f1)
            local max_time=$(grep "Max Time:" "$profile_file" | cut -d' ' -f3 | cut -d's' -f1)
            
            # Convert to ms for CSV
            local min_ms=$(python3 -c "print(f'{$min_time * 1000:.0f}')" 2>/dev/null || echo "0")
            local max_ms=$(python3 -c "print(f'{$max_time * 1000:.0f}')" 2>/dev/null || echo "0")
            
            echo "  $plugin_name: ${avg_time}ms $rating" >> "$summary_file"
            echo "$plugin_name,$avg_time,$rating,$min_ms,$max_ms" >> "$csv_file"
        fi
    done
    
    echo "" >> "$summary_file"
    echo "Detailed results available in individual *_profile.txt files" >> "$summary_file"
    
    echo "✅ Summary report generated"
}

# Main execution
main() {
    # List of plugins to test
    local plugins=("cpu" "memory" "network" "battery" "volume" "notifications" "clock" "weather" "spotify" "moon_phase" "front_app")
    
    echo -e "${BLUE}🔍 Testing individual plugin performance:${NC}"
    echo ""
    
    local failed_plugins=()
    for plugin in "${plugins[@]}"; do
        if ! benchmark_plugin "$plugin"; then
            failed_plugins+=("$plugin")
        fi
    done
    
    echo ""
    test_cache_effectiveness
    echo ""
    generate_summary
    
    echo ""
    echo -e "${GREEN}📊 BENCHMARK COMPLETED${NC}"
    echo "======================="
    echo "Results saved to: $RESULTS_DIR"
    echo "Summary: $RESULTS_DIR/performance_summary.txt"
    echo "CSV Data: $RESULTS_DIR/performance_data.csv"
    
    if [[ ${#failed_plugins[@]} -gt 0 ]]; then
        echo -e "${RED}⚠️  Failed plugins: ${failed_plugins[*]}${NC}"
        return 1
    else
        echo -e "${GREEN}✅ All plugins tested successfully${NC}"
        return 0
    fi
}

# Run the benchmark
main "$@" 