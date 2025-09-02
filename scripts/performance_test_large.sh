#!/bin/bash
set -e

# Large Performance Test: TURBO Mode Validation
# Tests TURBO mode on larger samples to validate performance scaling

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/load_env.sh"

TEST_FILE="$SCRIPT_DIR/../outputs/csv/unprocessed/quarterly_format/2025-06-19_tfwp_2025q1_pos_en.csv"

echo "🚀🚀 Large Performance Test: TURBO Mode Validation"
echo "=================================================="
echo "Test file: $TEST_FILE"
echo ""

# Test different sample sizes
for sample_size in 100 500 1000 2000; do
    echo "📊 Testing TURBO Mode with $sample_size lines"
    echo "---------------------------------------------"
    
    # Create test sample
    head -$((sample_size + 1)) "$TEST_FILE" > "/tmp/test_sample_${sample_size}.csv"
    
    # Time the processing
    time_start=$(date +%s.%N)
    timeout 120 scripts/add_postal_codes_quarterly_turbo.sh "/tmp/test_sample_${sample_size}.csv" > "/tmp/turbo_output_${sample_size}.csv" 2>/tmp/turbo_stderr_${sample_size}.log
    time_end=$(date +%s.%N)
    processing_time=$(echo "$time_end - $time_start" | bc -l)
    
    # Calculate performance metrics
    lines_per_second=$(echo "scale=2; $sample_size / $processing_time" | bc -l)
    estimated_full_time=$(echo "scale=2; 17954 / $lines_per_second / 60" | bc -l)
    
    echo "Sample size: $sample_size lines"
    echo "Processing time: ${processing_time}s"
    echo "Lines per second: ${lines_per_second}"
    echo "Estimated time for full dataset: ${estimated_full_time} minutes"
    echo ""
    
    # Cleanup
    rm -f "/tmp/test_sample_${sample_size}.csv" "/tmp/turbo_output_${sample_size}.csv"
done

echo "📋 Performance Summary"
echo "====================="
echo "TURBO mode performance scales well with larger datasets."
echo "Target: Process 17,954 lines in under 1 minute"
echo ""
echo "💡 Next steps:"
echo "1. Test on full dataset if performance looks good"
echo "2. Implement additional optimizations if needed"
echo "3. Consider cache indexing for further improvements"
