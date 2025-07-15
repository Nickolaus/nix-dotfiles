#!/usr/bin/env bash
set -euo pipefail

# AI Model Performance Benchmarking Tool
# Benchmarks ollama models for OpenCommit usage with "hot" performance testing
#
# HOT BENCHMARKING CONCEPT:
# 1. WARMUP: Each model is loaded with a simple query first
# 2. BENCHMARK: Then performance is measured on the warmed-up model  
# This eliminates cold-start bias and measures true inference performance.

# Default configuration - Auto-detect available models
MODELS=()  # Will be populated from ollama list
RESULTS_DIR="results"
ITERATIONS=3
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
log() {
    echo -e "${CYAN}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Auto-detect available models
detect_models() {
    log "Detecting available ollama models..."
    
    local available_models
    available_models=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -v '^$' || echo "")
    
    if [ -z "$available_models" ]; then
        error "No ollama models found. Please install models first."
        log "Example: ollama pull qwen3:8b"
        exit 1
    fi
    
    # Convert to array
    readarray -t MODELS <<< "$available_models"
    
    log "Found ${#MODELS[@]} models: ${MODELS[*]}"
}

# Verify all models are available
verify_all_models() {
    log "Verifying model availability..."
    local available_models_list
    available_models_list=$(ollama list 2>/dev/null)
    
    if [ -z "$available_models_list" ]; then
        error "Failed to get model list from ollama"
        exit 1
    fi
    
    local verified_models=()
    for model in "${MODELS[@]}"; do
        if echo "$available_models_list" | grep -q "$model"; then
            verified_models+=("$model")
            if [ "$VERBOSE" = true ]; then
                log "✓ $model verified"
            fi
        else
            warn "Model $model not found - skipping"
            log "  Run 'ollama pull $model' to install it"
        fi
    done
    
    if [ ${#verified_models[@]} -eq 0 ]; then
        error "No valid models found for benchmarking"
        exit 1
    fi
    
    # Update MODELS array with only verified models
    MODELS=("${verified_models[@]}")
    log "Verified ${#MODELS[@]} models: ${MODELS[*]}"
}

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    if ! command -v ollama &> /dev/null; then
        error "ollama is not installed or not in PATH"
        exit 1
    fi
    
    if ! pgrep -f ollama &> /dev/null; then
        error "ollama service is not running. Please start it first."
        exit 1
    fi
    
    if ! command -v oco &> /dev/null; then
        warn "opencommit (oco) not found. Some tests may be skipped."
    fi
    
    # Auto-detect available models
    detect_models
    
    # Verify all detected models are actually available
    verify_all_models
    
    success "Dependencies check passed"
}

# Generate test files
create_test_files() {
    local test_dir="$1"
    mkdir -p "$test_dir"
    
    # Simple test file
    cat > "$test_dir/simple.js" << 'EOF'
const app = require("express")();
app.get("/test", (req, res) => res.json({status: "ok"}));
module.exports = app;
EOF

    # Complex test file
    cat > "$test_dir/complex.py" << 'EOF'
import asyncio
import logging
from typing import Dict, List, Optional, Union
from dataclasses import dataclass
from pathlib import Path

@dataclass
class Config:
    """Application configuration with validation and type hints"""
    database_url: str
    redis_url: str
    log_level: str = "INFO"
    max_connections: int = 100
    
    def __post_init__(self):
        if not self.database_url.startswith(('postgresql://', 'sqlite://')):
            raise ValueError("Invalid database URL format")

class DatabaseManager:
    """Async database manager with connection pooling and retry logic"""
    
    def __init__(self, config: Config):
        self.config = config
        self.pool = None
        self.logger = logging.getLogger(__name__)
    
    async def initialize(self) -> None:
        """Initialize database connection pool with retry logic"""
        max_retries = 3
        for attempt in range(max_retries):
            try:
                # Connection pool initialization logic here
                self.logger.info(f"Database connected on attempt {attempt + 1}")
                break
            except Exception as e:
                if attempt == max_retries - 1:
                    raise
                await asyncio.sleep(2 ** attempt)
    
    async def execute_query(self, query: str, params: Optional[Dict] = None) -> List[Dict]:
        """Execute database query with proper error handling"""
        if not self.pool:
            raise RuntimeError("Database not initialized")
        
        try:
            # Query execution logic
            return []
        except Exception as e:
            self.logger.error(f"Query failed: {e}")
            raise

# Main application class with comprehensive error handling
class Application:
    def __init__(self, config_path: Union[str, Path]):
        self.config = self._load_config(config_path)
        self.db_manager = DatabaseManager(self.config)
    
    def _load_config(self, path: Union[str, Path]) -> Config:
        """Load and validate configuration from file"""
        # Config loading implementation
        return Config(
            database_url="postgresql://localhost/app",
            redis_url="redis://localhost:6379"
        )
EOF

}

# Warmup a model to ensure it's loaded in memory
warmup_model() {
    local model="$1"
    
    if [ "$VERBOSE" = true ]; then
        log "🔥 Warming up ${PURPLE}$model${NC}..." >&2
    fi
    
    # Simple warmup query to load model into memory
    ollama run "$model" --think=false "Hello" > /dev/null 2>&1
    
    if [ "$VERBOSE" = true ]; then
        log "✓ Model ${PURPLE}$model${NC} is now hot and ready" >&2
    fi
}

# Enhanced Conventional Commit Quality Scoring
# 
# COMPREHENSIVE VALIDATION: Follows GitHub standards, conventional commit spec,
# and OpenCommit configuration requirements.
#
# Scoring (0-5):
# - 0: ❌ Broken - Invalid format, critical errors
# - 1: ⚠️ Poor - Basic format but major style issues
# - 2: 🔶 Basic - Valid conventional commit, some issues
# - 3: ✅ Good - Clean conventional commit, proper format
# - 4: ⭐ Very Good - Excellent commit with semantic quality
# - 5: 🏆 Perfect - Flawless commit message
# 
# VALIDATION RULES:
# - Whitespace: No leading/trailing spaces (critical)
# - Capitalization: Lowercase after colon ("feat:" not "Feat:")
# - Punctuation: No trailing periods or exclamation marks
# - Length: 50-72 characters optimal for GitHub display
# - Mood: Imperative mood ("add" not "adds" or "added")
# - Semantics: Meaningful verbs, specific descriptions
score_commit_quality() {
    local commit_output="$1"
    local score=0
    local commit_count=0
    local valid_commits=0
    
    # Valid conventional commit types
    local valid_types="feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert"
    
    # Extract potential commit messages (more permissive extraction first)
    local commit_messages
    commit_messages=$(echo "$commit_output" | grep -E "^\s*[a-z]+(\(.+\))?: .+" || echo "")
    
    if [ -z "$commit_messages" ]; then
        return 0  # No commit-like messages found
    fi
    
    # Count total commits found
    commit_count=$(echo "$commit_messages" | wc -l | tr -d ' ')
    
    # Analyze each commit message
    while IFS= read -r commit_line; do
        [ -z "$commit_line" ] && continue
        
        # Check for whitespace issues (these should LOWER quality, not be ignored)
        local has_leading_space=false
        local has_trailing_space=false
        
        if echo "$commit_line" | grep -qE "^[[:space:]]"; then
            has_leading_space=true
        fi
        
        if echo "$commit_line" | grep -qE "[[:space:]]$"; then
            has_trailing_space=true
        fi
        
        # Clean version for format checking (but we'll penalize the whitespace)
        local clean_line
        clean_line=$(echo "$commit_line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        
        # Check conventional format: type(scope): description or type: description
        if echo "$clean_line" | grep -qE "^($valid_types)(\(.+\))?: .{5,}"; then
            ((valid_commits++))
            local commit_score=2  # Base score for valid conventional format
            
            # CRITICAL PENALTIES (can make score 0)
            local critical_issues=0
            
            # Whitespace issues (critical)
            if [ "$has_leading_space" = true ]; then
                ((critical_issues++))
            fi
            if [ "$has_trailing_space" = true ]; then
                ((critical_issues++))
            fi
            
            # Phase 1 Enhanced Validation
            
            # 1. Capitalization check - first letter after colon should be lowercase
            local desc_start
            desc_start=$(echo "$clean_line" | sed -E "s/^($valid_types)(\(.+\))?: (.)/\3/")
            if echo "$desc_start" | grep -qE "^[A-Z]"; then
                ((critical_issues++))  # Wrong capitalization
            fi
            
            # 2. Trailing punctuation check - no periods, exclamation marks
            if echo "$clean_line" | grep -qE "[.!]$"; then
                ((critical_issues++))  # Trailing punctuation
            fi
            
            # 3. Subject length validation (GitHub optimal: 50-72 chars)
            local total_length=${#clean_line}
            local length_score=0
            if [ "$total_length" -ge 50 ] && [ "$total_length" -le 72 ]; then
                ((length_score++))  # Optimal length
            elif [ "$total_length" -le 50 ]; then
                # Short but acceptable, no penalty
                length_score=0
            elif [ "$total_length" -gt 100 ]; then
                ((critical_issues++))  # Too long, critical issue
            fi
            
            # If critical issues exist, cap at score 1
            if [ "$critical_issues" -gt 0 ]; then
                commit_score=1
            else
                # No critical issues - award additional points
                
                # Scope usage bonus
                if echo "$clean_line" | grep -qE "^($valid_types)\(.+\): .+"; then
                    ((commit_score++))  # +1 for scoped commits
                fi
                
                # Length optimization bonus
                commit_score=$((commit_score + length_score))
                
                # Phase 2 Semantic Quality Checks
                local desc_part
                desc_part=$(echo "$clean_line" | sed -E "s/^($valid_types)(\(.+\))?: //")
                
                # Imperative mood check (basic detection)
                if echo "$desc_part" | grep -qE "^(add|fix|update|remove|create|delete|implement|refactor|optimize|improve)"; then
                    ((commit_score++))  # Good imperative verb
                elif echo "$desc_part" | grep -qE "^(adds|fixes|updates|removes|creates|deletes|implements|refactors|optimizes|improves)"; then
                    # Wrong mood, but not critical - no bonus
                    commit_score=$((commit_score))
                elif echo "$desc_part" | grep -qE "^(added|fixed|updated|removed|created|deleted|implemented|refactored|optimized|improved)"; then
                    # Past tense - minor penalty
                    commit_score=$((commit_score > 2 ? commit_score - 1 : commit_score))
                fi
                
                # Avoid filler words penalty
                if echo "$desc_part" | grep -qE "(just|simply|basically|some|stuff|things|changes)"; then
                    commit_score=$((commit_score > 2 ? commit_score - 1 : commit_score))
                fi
                
                # Specificity bonus - check for meaningful content
                if echo "$desc_part" | grep -qE "(auth|user|api|config|test|error|bug|feature|component|service|database|cache|validation)"; then
                    ((commit_score++))  # Specific technical terms
                fi
            fi
            
            # Cap score at 5, minimum at 0
            if [ "$commit_score" -gt 5 ]; then
                commit_score=5
            elif [ "$commit_score" -lt 0 ]; then
                commit_score=0
            fi
            
            # Add commit score to total
            score=$((score + commit_score))
        fi
    done <<< "$commit_messages"
    
    # Base score adjustments
    if [ "$valid_commits" -eq 0 ]; then
        score=0
    elif [ "$valid_commits" -eq "$commit_count" ] && [ "$commit_count" -gt 1 ]; then
        ((score++))  # Bonus for multiple valid commits
    fi
    
    # Ensure score doesn't go below 0 or above 5
    if [ "$score" -lt 0 ]; then
        score=0
    elif [ "$score" -gt 5 ]; then
        score=5
    fi
    
    echo "$score"
}

# Get enhanced quality rating description
get_quality_rating() {
    local score="$1"
    # Handle decimal scores by rounding
    local rounded_score
    rounded_score=$(printf "%.0f" "$score")
    
    case "$rounded_score" in
        0) echo "❌ Broken" ;;
        1) echo "⚠️ Poor" ;;
        2) echo "🔶 Basic" ;;
        3) echo "✅ Good" ;;
        4) echo "⭐ Very Good" ;;
        5) echo "🏆 Perfect" ;;
        *) echo "❓ Unknown" ;;
    esac
}

# Benchmark a specific model with OpenCommit
benchmark_model() {
    local model="$1"
    local test_file="$2"
    local test_type="$3"
    
    log "Testing ${PURPLE}$model${NC} on ${BLUE}$test_type${NC} file..." >&2
    
    # Switch to the model using oco-model
    if ! oco-model "$(get_model_size_from_name "$model")" >/dev/null 2>&1; then
        warn "Failed to switch to model $model - using direct OCO_MODEL config" >&2
        # Fallback: set model directly
        opencommit config set OCO_MODEL="$model" >/dev/null 2>&1 || {
            error "Failed to configure model $model" >&2
            echo "ERROR,ERROR"
            return 1
        }
    fi
    
    local total_time=0
    local total_quality=0
    local successful_runs=0
    
    for i in $(seq 1 $ITERATIONS); do
        if [ "$VERBOSE" = true ]; then
            log "  Run $i/$ITERATIONS..." >&2
        fi
        
        # Create git staged changes for testing
        git add "$test_file" 2>/dev/null || true
        
        # Time the OpenCommit dry run
        local start_time=$(date +%s.%N)
        
        # Use real OpenCommit with dry-run and auto-confirm
        local oco_output
        oco_output=$(oco --dry-run --yes 2>&1)
        local oco_exit_code=$?
        
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l)
        
        if [ "$oco_exit_code" -eq 0 ] && [ -n "$oco_output" ]; then
            total_time=$(echo "$total_time + $duration" | bc -l)
            
            # Score commit quality
            local quality_score
            quality_score=$(score_commit_quality "$oco_output")
            total_quality=$((total_quality + quality_score))
            
            ((successful_runs++))
            
            if [ "$VERBOSE" = true ]; then
                local quality_rating
                quality_rating=$(get_quality_rating "$quality_score")
                printf "    Time: %.2fs, Quality: %s\n" "$duration" "$quality_rating" >&2
            fi
        else
            warn "Run $i failed for $model (exit code: $oco_exit_code)" >&2
            if [ "$VERBOSE" = true ]; then
                warn "Output: $oco_output" >&2
            fi
        fi
        
        # Unstage files for next iteration
        git reset HEAD "$test_file" >/dev/null 2>&1 || true
        
        # Small delay between runs
        sleep 1
    done
    
    if [ "$successful_runs" -gt 0 ]; then
        local avg_time=$(echo "scale=2; $total_time / $successful_runs" | bc -l)
        local avg_quality=$(echo "scale=1; $total_quality / $successful_runs" | bc -l)
        printf "%.2f,%.1f" "$avg_time" "$avg_quality"
        return 0
    else
        error "All runs failed for $model on $test_type" >&2
        echo "ERROR,ERROR"
        return 1
    fi
}

# Map model names to oco-model size codes
get_model_size_from_name() {
    local model="$1"
    case "$model" in
        "mistral:7b") echo "xs" ;;
        "llama3.2:latest") echo "s" ;;
        "tavernari/git-commit-message:latest") echo "m" ;;
        "gemma3:4b") echo "l" ;;
        "devstral:24b") echo "xl" ;;
        "gemma3:12b") echo "xxl" ;;
        "gemma3:27b") echo "xxxl" ;;
        *) echo "" ;;  # Unknown model - will fallback to direct config
    esac
}

# Performance rating based on time
get_performance_rating() {
    local time="$1"
    local rating=""
    
    if (( $(echo "$time < 2.0" | bc -l) )); then
        rating="⚡ Excellent"
    elif (( $(echo "$time < 4.0" | bc -l) )); then
        rating="🚀 Good"
    elif (( $(echo "$time < 6.0" | bc -l) )); then
        rating="✅ Average"
    elif (( $(echo "$time < 10.0" | bc -l) )); then
        rating="⏱️ Slow"
    else
        rating="🐌 Very Slow"
    fi
    
    echo "$rating"
}

# Generate results report
generate_report() {
    local results_file="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local test_env="$(uname -s) $(uname -m)"
    
    log "Generating comprehensive report..."
    
    cat > "$results_file" << EOF
# AI Model Performance Benchmark Results

**Generated:** $timestamp  
**Environment:** $test_env  
**Iterations per test:** $ITERATIONS

## Test Configuration

- **Simple File**: Basic Express.js server (3 lines)
- **Complex File**: Python async database manager with error handling (~70 lines)
- **Hot Benchmarking**: Each model is warmed up with a simple query before testing

## Performance Results

EOF

    # Read results and generate summary tables
    local temp_results="/tmp/benchmark_results.tmp"
    
    # Sort models by average performance
    {
        echo "| Model | Simple (s) | Simple Quality | Complex (s) | Complex Quality | Avg (s) | Avg Quality | Rating |"
        echo "|-------|------------|----------------|-------------|-----------------|---------|-------------|--------|"
        
        while IFS=',' read -r model simple_time simple_quality complex_time complex_quality avg_time avg_quality; do
            [ "$model" = "Model" ] && continue  # Skip header
            local rating=$(get_performance_rating "$avg_time")
            local simple_quality_rating=$(get_quality_rating $(printf "%.0f" "$simple_quality"))
            local complex_quality_rating=$(get_quality_rating $(printf "%.0f" "$complex_quality"))
            local avg_quality_rating=$(get_quality_rating $(printf "%.0f" "$avg_quality"))
            printf "| \`%s\` | %.2f | %s | %.2f | %s | %.2f | %s | %s |\n" \
                "$model" "$simple_time" "$simple_quality_rating" "$complex_time" "$complex_quality_rating" "$avg_time" "$avg_quality_rating" "$rating"
        done < "$RESULTS_DIR/raw_results.csv" | sort -t'|' -k6 -n
    } >> "$results_file"
    
    cat >> "$results_file" << 'EOF'

## Recommendations

### For OpenCommit Usage:
- **Best Overall**: Models with < 4s average response time AND ✅ Good or ⭐ Excellent quality
- **Quick Commits**: Use models rated ⚡ Excellent performance with ✅+ quality for rapid development
- **Complex Projects**: Models with ⭐ Excellent quality scores for detailed conventional commits
- **Quality Priority**: Choose models with ⭐ Excellent quality even if slightly slower

### Model Selection Guide:
- **Performance Tiers**: ⚡ Excellent (< 2s), 🚀 Good (2-4s), ✅ Average (4-6s), 🐌 Slow (>10s)
- **Quality Tiers**: ⭐ Excellent (3/3), ✅ Good (2/3), ⚠️ Basic (1/3), ❌ Poor (0/3)
- **Balanced Choice**: Models with both good performance and quality ratings
- **Speed vs Quality**: Faster models may sacrifice conventional commit format quality

### Quality Scoring Criteria:
- **Conventional Format**: Proper `type(scope): description` structure
- **Valid Types**: feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert
- **Scope Usage**: Appropriate and helpful scope definitions
- **Description Quality**: Clear, concise, and meaningful descriptions (10-100 chars)
- **Multi-commit Breakdown**: Logical separation of different changes

## Technical Notes

- **Hot Benchmarking**: Each model is warmed up before performance testing
- **Real OpenCommit Testing**: Uses `oco --dry-run --yes` for authentic workflow testing
- **Quality Analysis**: Automated scoring of conventional commit compliance (0-3 scale)
- Tests measure true OpenCommit performance including prompt processing and response generation
- Results may vary based on system resources and model cache status

EOF
}

# Update README.md with results
update_readme() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local test_env="$(uname -s) $(uname -m)"
    local model_count=$(wc -l < "$RESULTS_DIR/raw_results.csv" | tr -d ' ')
    ((model_count--))  # Subtract header line
    
    log "Updating README.md with latest results..."
    
    # Create the benchmark results section
    local temp_section="/tmp/benchmark_section.tmp"
    
    cat > "$temp_section" << EOF
**Last Updated:** $timestamp  
**Models Tested:** $model_count  
**Test Environment:** $test_env

### 🏆 Top Performers

#### Simple Files (Fastest)
| Rank | Model | Time | Performance |
|------|-------|------|-------------|
EOF

    # Add top 3 performers for simple files (CSV: Model,Simple_Time,Simple_Quality,Complex_Time,Complex_Quality,Avg_Time,Avg_Quality)
    tail -n +2 "$RESULTS_DIR/raw_results.csv" | sort -t',' -k2 -n | head -3 | \
    awk -F',' 'BEGIN{rank=1} {
        rating = ($2 < 2.0) ? "⚡ Excellent" : ($2 < 4.0) ? "🚀 Good" : "✅ Average"
        quality = ($3 == 0) ? "❌ Poor" : ($3 == 1) ? "⚠️ Basic" : ($3 == 2) ? "✅ Good" : "⭐ Excellent"
        printf "| %d | `%s` | %.2fs (%s) | %s |\n", rank++, $1, $2, quality, rating
    }' >> "$temp_section"
    
    cat >> "$temp_section" << EOF

#### Complex Files (Fastest)
| Rank | Model | Time | Performance |
|------|-------|------|-------------|
EOF

    # Add top 3 performers for complex files (column 4 is complex_time, column 5 is complex_quality)
    tail -n +2 "$RESULTS_DIR/raw_results.csv" | sort -t',' -k4 -n | head -3 | \
    awk -F',' 'BEGIN{rank=1} {
        rating = ($4 < 2.0) ? "⚡ Excellent" : ($4 < 4.0) ? "🚀 Good" : "✅ Average"
        quality = ($5 == 0) ? "❌ Poor" : ($5 == 1) ? "⚠️ Basic" : ($5 == 2) ? "✅ Good" : "⭐ Excellent"
        printf "| %d | `%s` | %.2fs (%s) | %s |\n", rank++, $1, $4, quality, rating
    }' >> "$temp_section"
    
    cat >> "$temp_section" << EOF

### 📈 All Models Summary
| Model | Simple (s) | Simple Quality | Complex (s) | Complex Quality | Avg (s) | Avg Quality |
|-------|------------|----------------|-------------|-----------------|---------|-------------|
EOF

    # Add all models summary (CSV: Model,Simple_Time,Simple_Quality,Complex_Time,Complex_Quality,Avg_Time,Avg_Quality)
    tail -n +2 "$RESULTS_DIR/raw_results.csv" | sort -t',' -k6 -n | \
    awk -F',' '{
        simple_quality = ($3 == 0) ? "❌" : ($3 == 1) ? "⚠️" : ($3 == 2) ? "✅" : "⭐"
        complex_quality = ($5 == 0) ? "❌" : ($5 == 1) ? "⚠️" : ($5 == 2) ? "✅" : "⭐"
        avg_quality = ($7 == 0) ? "❌" : ($7 == 1) ? "⚠️" : ($7 == 2) ? "✅" : "⭐"
        printf "| `%s` | %.2f | %s | %.2f | %s | %.2f | %s |\n", $1, $2, simple_quality, $4, complex_quality, $6, avg_quality
    }' >> "$temp_section"
    
    echo >> "$temp_section"
    echo "**📋 For detailed analysis and recommendations, see:** \`results/benchmark-results-all.md\`" >> "$temp_section"
    
    # Replace the section in README.md
    sed -i.bak '/<!-- BENCHMARK_RESULTS_START -->/,/<!-- BENCHMARK_RESULTS_END -->/c\
<!-- BENCHMARK_RESULTS_START -->\
'"$(cat "$temp_section" | sed 's/$/\\/')"'
<!-- BENCHMARK_RESULTS_END -->' README.md
    
    rm "$temp_section"
    success "README.md updated with latest benchmark results"
}

# Show usage information
show_usage() {
    cat << EOF
${CYAN}AI Model Performance Benchmarking Tool${NC}

${YELLOW}Usage:${NC}
  $0 [OPTIONS]

${YELLOW}Options:${NC}
  -m, --models MODEL1,MODEL2    Comma-separated list of models to test
  -i, --iterations N            Number of iterations per test (default: $ITERATIONS)
  -v, --verbose                 Verbose output
  -h, --help                    Show this help message
  --no-readme                   Skip README.md update
  --list-models                 List available ollama models and exit

${YELLOW}Examples:${NC}
  # Test all default models
  $0

  # Test specific models (use 'ollama list' to see available)
  $0 -m "qwen3:8b,qwen3:14b"

  # Verbose testing with more iterations
  $0 -v -i 5

  # Quick test without updating README
  $0 --no-readme -i 1

${YELLOW}Available Models:${NC}
  (Auto-detected from 'ollama list')

${YELLOW}Output:${NC}
  - Raw results: ${RESULTS_DIR}/raw_results.csv
  - Detailed report: ${RESULTS_DIR}/benchmark-results-all.md
  - README.md updated with summary (unless --no-readme)
EOF
}

# Parse command line arguments - modifies global variables
parse_args() {
    UPDATE_README=true
    CUSTOM_MODELS=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--models)
                IFS=',' read -ra MODELS <<< "$2"
                CUSTOM_MODELS=true
                shift 2
                ;;
            -i|--iterations)
                ITERATIONS="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --no-readme)
                UPDATE_README=false
                shift
                ;;
            --list-models)
                echo "Available ollama models:"
                ollama list
                exit 0
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Main benchmarking function
main() {
    parse_args "$@"
    
    log "${CYAN}AI Model Performance Benchmarking Tool${NC}"
    
    # Check dependencies (will auto-detect models if not custom)
    if [ "$CUSTOM_MODELS" = "true" ]; then
        log "Using custom models: ${PURPLE}${MODELS[*]}${NC}"
        # Basic dependency check without model detection
        if ! command -v ollama &> /dev/null; then
            error "ollama is not installed or not in PATH"
            exit 1
        fi
        if ! pgrep -f ollama &> /dev/null; then
            error "ollama service is not running. Please start it first."
            exit 1
        fi
        
        # Verify custom models
        verify_all_models
        success "Dependencies check passed"
    else
        check_dependencies  # This will auto-detect and verify models
    fi
    
    log "Models to test: ${PURPLE}${MODELS[*]}${NC}"
    log "Iterations per test: ${YELLOW}$ITERATIONS${NC}"
    log "Verbose mode: ${YELLOW}$VERBOSE${NC}"
    
    # Setup
    mkdir -p "$RESULTS_DIR"
    local test_dir="$RESULTS_DIR/test_files"
    rm -rf "$test_dir"
    create_test_files "$test_dir"
    
    # Initialize results file
    local raw_results="$RESULTS_DIR/raw_results.csv"
    echo "Model,Simple_Time,Simple_Quality,Complex_Time,Complex_Quality,Avg_Time,Avg_Quality" > "$raw_results"
    
    # Benchmark each model
    local total_models=${#MODELS[@]}
    local current_model=0
    
    for model in "${MODELS[@]}"; do
        current_model=$((current_model + 1))
        log "${YELLOW}[$current_model/$total_models]${NC} Benchmarking ${PURPLE}$model${NC}..."
        
        # Step 1: Warmup the model (ensure it's "hot")
        warmup_model "$model"
        
        # Step 2: Benchmark on warmed-up model  
        local simple_result complex_result
        
        simple_result=$(benchmark_model "$model" "$test_dir/simple.js" "simple")
        complex_result=$(benchmark_model "$model" "$test_dir/complex.py" "complex")
        
        # Parse results (format: "time,quality")
        if [[ "$simple_result" != "ERROR,ERROR" && "$complex_result" != "ERROR,ERROR" ]]; then
            local simple_time simple_quality complex_time complex_quality
            IFS=',' read -r simple_time simple_quality <<< "$simple_result"
            IFS=',' read -r complex_time complex_quality <<< "$complex_result"
            
            # Calculate averages
            local avg_time=$(echo "scale=2; ($simple_time + $complex_time) / 2" | bc -l)
            local avg_quality=$(echo "scale=1; ($simple_quality + $complex_quality) / 2" | bc -l)
            
            # Save results
            echo "$model,$simple_time,$simple_quality,$complex_time,$complex_quality,$avg_time,$avg_quality" >> "$raw_results"
            
            success "Model $model completed - Avg: ${avg_time}s, Quality: $(get_quality_rating $(printf "%.0f" "$avg_quality"))"
        else
            warn "Model $model had errors - skipping from results"
        fi
        
        # Brief pause between models
        sleep 1
        
        echo  # Empty line for readability
    done
    
    # Generate reports
    generate_report "benchmark-results.md"
    
    if [ "$UPDATE_README" = true ]; then
        update_readme
    fi
    
    # Cleanup - remove entire results directory
    rm -rf "$RESULTS_DIR"
    
    success "Benchmarking completed!"
    log "View detailed report: ${CYAN}benchmark-results.md${NC}"
    
    if [ "$UPDATE_README" = true ]; then
        log "README.md updated with latest results"
    fi
}

# Run main function with all arguments
main "$@" 