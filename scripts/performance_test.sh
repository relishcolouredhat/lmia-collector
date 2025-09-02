#!/bin/bash
set -e

# Quick Performance Test: Original vs Optimized vs TURBO Processing
# Tests a small sample to measure speed improvement

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/load_env.sh"

TEST_FILE="$SCRIPT_DIR/../outputs/csv/unprocessed/quarterly_format/2025-06-19_tfwp_2025q1_pos_en.csv"
SAMPLE_SIZE=100

echo "🚀 Performance Test: Original vs Optimized vs TURBO Processing"
echo "============================================================="
echo "Test file: $TEST_FILE"
echo "Sample size: $SAMPLE_SIZE lines"
echo ""

# Create test sample
echo "📋 Creating test sample..."
head -$((SAMPLE_SIZE + 1)) "$TEST_FILE" > /tmp/test_sample.csv
echo ""

# Test 1: Original processing (with sed bottleneck)
echo "📊 Test 1: Original Processing (with sed bottleneck)"
echo "---------------------------------------------------"
time_start=$(date +%s.%N)
timeout 30 scripts/add_postal_codes_quarterly.sh /tmp/test_sample.csv > /tmp/original_output.csv 2>/tmp/original_stderr.log
time_end=$(date +%s.%N)
original_time=$(echo "$time_end - $time_start" | bc -l)
echo "Original processing time: ${original_time}s" >&2
echo ""

# Test 2: Optimized processing (bash built-ins)
echo "📊 Test 2: Optimized Processing (bash built-ins)"
echo "------------------------------------------------"
time_start=$(date +%s.%N)
timeout 30 scripts/add_postal_codes_quarterly_optimized.sh /tmp/test_sample.csv > /tmp/optimized_output.csv 2>/tmp/optimized_stderr.log
time_end=$(date +%s.%N)
optimized_time=$(echo "$time_end - $time_start" | bc -l)
echo "Optimized processing time: ${optimized_time}s" >&2
echo ""

# Test 3: TURBO processing (pure bash, no external processes)
echo "📊 Test 3: TURBO Processing (pure bash, no external processes)"
echo "-------------------------------------------------------------"
time_start=$(date +%s.%N)
timeout 30 scripts/add_postal_codes_quarterly_turbo.sh /tmp/test_sample.csv > /tmp/turbo_output.csv 2>/tmp/turbo_stderr.log
time_end=$(date +%s.%N)
turbo_time=$(echo "$time_end - $time_start" | bc -l)
echo "TURBO processing time: ${turbo_time}s" >&2
echo ""

# Calculate improvements
if [[ -n "$original_time" && -n "$optimized_time" && -n "$turbo_time" && "$original_time" != "0" ]]; then
    speedup_opt=$(echo "scale=2; $original_time / $optimized_time" | bc -l)
    speedup_turbo=$(echo "scale=2; $original_time / $turbo_time" | bc -l)
    
    echo "📈 Performance Results:"
    echo "======================="
    echo "Original time: ${original_time}s"
    echo "Optimized time: ${optimized_time}s"
    echo "TURBO time: ${turbo_time}s"
    echo ""
    echo "Speedup (Optimized): ${speedup_opt}x faster"
    echo "Speedup (TURBO): ${speedup_turbo}x faster"
    echo ""
    
    if (( $(echo "$speedup_turbo > 10" | bc -l) )); then
        echo "🎉🎉 TURBO MODE SUCCESS! Massive performance improvement!"
    elif (( $(echo "$speedup_turbo > 5" | bc -l) )); then
        echo "🎉 SIGNIFICANT IMPROVEMENT! TURBO mode is working well."
    elif (( $(echo "$speedup_turbo > 2" | bc -l) )); then
        echo "✅ Good improvement! TURBO mode is helping."
    else
        echo "⚠️  Minimal improvement. May need further optimization."
    fi
else
    echo "⚠️  Could not complete performance test. Check error logs."
    echo "Original stderr: /tmp/original_stderr.log"
    echo "Optimized stderr: /tmp/optimized_stderr.log"
    echo "TURBO stderr: /tmp/turbo_stderr.log"
fi

# Cleanup
rm -f /tmp/test_sample.csv /tmp/original_output.csv /tmp/optimized_output.csv /tmp/turbo_output.csv
echo ""
echo "🧹 Test files cleaned up."
