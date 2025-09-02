#!/bin/bash
set -e

# Final Comprehensive Performance Test: All Optimizations
# Tests all four versions to determine the best approach

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/load_env.sh"

TEST_FILE="$SCRIPT_DIR/../outputs/csv/unprocessed/quarterly_format/2025-06-19_tfwp_2025q1_pos_en.csv"
SAMPLE_SIZE=500  # Larger sample for better accuracy

echo "🚀🚀🚀 Final Performance Test: All Optimizations"
echo "================================================"
echo "Test file: $TEST_FILE"
echo "Sample size: $SAMPLE_SIZE lines"
echo ""

# Create test sample
echo "📋 Creating test sample..."
head -$((SAMPLE_SIZE + 1)) "$TEST_FILE" > /tmp/test_sample_final.csv
echo ""

# Test 1: Original processing (with sed bottleneck)
echo "📊 Test 1: Original Processing (with sed bottleneck)"
echo "---------------------------------------------------"
time_start=$(date +%s.%N)
timeout 60 scripts/add_postal_codes_quarterly.sh /tmp/test_sample_final.csv > /tmp/original_output_final.csv 2>/tmp/original_stderr_final.log
time_end=$(date +%s.%N)
original_time=$(echo "$time_end - $time_start" | bc -l)
echo "Original processing time: ${original_time}s" >&2
echo ""

# Test 2: Optimized processing (bash built-ins)
echo "📊 Test 2: Optimized Processing (bash built-ins)"
echo "------------------------------------------------"
time_start=$(date +%s.%N)
timeout 60 scripts/add_postal_codes_quarterly_optimized.sh /tmp/test_sample_final.csv > /tmp/optimized_output_final.csv 2>/tmp/optimized_stderr_final.log
time_end=$(date +%s.%N)
optimized_time=$(echo "$time_end - $time_start" | bc -l)
echo "Optimized processing time: ${optimized_time}s" >&2
echo ""

# Test 3: TURBO processing (pure bash, no external processes)
echo "📊 Test 3: TURBO Processing (pure bash, no external processes)"
echo "-------------------------------------------------------------"
time_start=$(date +%s.%N)
timeout 60 scripts/add_postal_codes_quarterly_turbo.sh /tmp/test_sample_final.csv > /tmp/turbo_output_final.csv 2>/tmp/turbo_stderr_final.log
time_end=$(date +%s.%N)
turbo_time=$(echo "$time_end - $time_start" | bc -l)
echo "TURBO processing time: ${turbo_time}s" >&2
echo ""

# Test 4: TURBO INDEXED processing (in-memory cache index)
echo "📊 Test 4: TURBO INDEXED Processing (in-memory cache index)"
echo "------------------------------------------------------------"
time_start=$(date +%s.%N)
timeout 60 scripts/add_postal_codes_quarterly_turbo_indexed.sh /tmp/test_sample_final.csv > /tmp/turbo_indexed_output_final.csv 2>/tmp/turbo_indexed_stderr_final.log
time_end=$(date +%s.%N)
turbo_indexed_time=$(echo "$time_end - $time_start" | bc -l)
echo "TURBO INDEXED processing time: ${turbo_indexed_time}s" >&2
echo ""

# Calculate all improvements
if [[ -n "$original_time" && -n "$optimized_time" && -n "$turbo_time" && -n "$turbo_indexed_time" && "$original_time" != "0" ]]; then
    speedup_opt=$(echo "scale=2; $original_time / $optimized_time" | bc -l)
    speedup_turbo=$(echo "scale=2; $original_time / $turbo_time" | bc -l)
    speedup_turbo_indexed=$(echo "scale=2; $original_time / $turbo_indexed_time" | bc -l)
    
    echo "📈 Final Performance Results:"
    echo "=============================="
    echo "Original time: ${original_time}s"
    echo "Optimized time: ${optimized_time}s"
    echo "TURBO time: ${turbo_time}s"
    echo "TURBO INDEXED time: ${turbo_indexed_time}s"
    echo ""
    echo "Speedup (Optimized): ${speedup_opt}x faster"
    echo "Speedup (TURBO): ${speedup_turbo}x faster"
    echo "Speedup (TURBO INDEXED): ${speedup_turbo_indexed}x faster"
    echo ""
    
    # Calculate lines per second for each version
    original_lps=$(echo "scale=2; $SAMPLE_SIZE / $original_time" | bc -l)
    optimized_lps=$(echo "scale=2; $SAMPLE_SIZE / $optimized_time" | bc -l)
    turbo_lps=$(echo "scale=2; $SAMPLE_SIZE / $turbo_time" | bc -l)
    turbo_indexed_lps=$(echo "scale=2; $SAMPLE_SIZE / $turbo_indexed_time" | bc -l)
    
    echo "📊 Performance Metrics:"
    echo "======================="
    echo "Original: ${original_lps} lines/sec"
    echo "Optimized: ${optimized_lps} lines/sec"
    echo "TURBO: ${turbo_lps} lines/sec"
    echo "TURBO INDEXED: ${turbo_indexed_lps} lines/sec"
    echo ""
    
    # Estimate full dataset processing time
    full_dataset_lines=17954
    original_full_time=$(echo "scale=2; $full_dataset_lines / $original_lps / 60" | bc -l)
    optimized_full_time=$(echo "scale=2; $full_dataset_lines / $optimized_lps / 60" | bc -l)
    turbo_full_time=$(echo "scale=2; $full_dataset_lines / $turbo_lps / 60" | bc -l)
    turbo_indexed_full_time=$(echo "scale=2; $full_dataset_lines / $turbo_indexed_lps / 60" | bc -l)
    
    echo "📋 Full Dataset Estimates (17,954 lines):"
    echo "========================================="
    echo "Original: ${original_full_time} minutes"
    echo "Optimized: ${optimized_full_time} minutes"
    echo "TURBO: ${turbo_full_time} minutes"
    echo "TURBO INDEXED: ${turbo_indexed_full_time} minutes"
    echo ""
    
    # Determine if we hit our target
    target_achieved=false
    if (( $(echo "$turbo_indexed_full_time < 1" | bc -l) )); then
        echo "🎉🎉🎉 TARGET ACHIEVED! TURBO INDEXED mode can process 17,954 lines in under 1 minute!"
        target_achieved=true
    elif (( $(echo "$turbo_indexed_full_time < 2" | bc -l) )); then
        echo "🎉🎉 EXCELLENT! TURBO INDEXED mode is very close to target."
    elif (( $(echo "$turbo_indexed_full_time < 5" | bc -l) )); then
        echo "🎉 GOOD! TURBO INDEXED mode provides significant improvement."
    else
        echo "⚠️  Still need more optimization to reach target."
    fi
    
    echo ""
    echo "🏆 WINNER: TURBO INDEXED MODE with ${speedup_turbo_indexed}x speedup!"
    
else
    echo "⚠️  Could not complete performance test. Check error logs."
    echo "Original stderr: /tmp/original_stderr_final.log"
    echo "Optimized stderr: /tmp/optimized_stderr_final.log"
    echo "TURBO stderr: /tmp/turbo_stderr_final.log"
    echo "TURBO INDEXED stderr: /tmp/turbo_indexed_stderr_final.log"
fi

# Cleanup
rm -f /tmp/test_sample_final.csv /tmp/original_output_final.csv /tmp/optimized_output_final.csv /tmp/turbo_output_final.csv /tmp/turbo_indexed_output_final.csv
echo ""
echo "🧹 Test files cleaned up."
