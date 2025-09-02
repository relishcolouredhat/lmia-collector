#!/bin/bash
set -e

# Performance Benchmarking Script for Geocoding System
# Measures cache lookup performance, file I/O, and overall processing speed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/load_env.sh"

# Configuration
CACHE_FILE="$SCRIPT_DIR/../outputs/cache/location_cache.csv"
TEST_FILE="$SCRIPT_DIR/../outputs/csv/unprocessed/quarterly_format/2025-06-19_tfwp_2025q1_pos_en.csv"
SAMPLE_SIZE=1000

echo "🚀 Geocoding Performance Benchmark"
echo "=================================="
echo "Cache file: $CACHE_FILE"
echo "Test file: $TEST_FILE"
echo "Sample size: $SAMPLE_SIZE lines"
echo ""

# Benchmark 1: Cache file read performance
echo "📊 Benchmark 1: Cache File Read Performance"
echo "-------------------------------------------"
time_start=$(date +%s.%N)
for i in {1..100}; do
    wc -l "$CACHE_FILE" > /dev/null
done
time_end=$(date +%s.%N)
cache_read_time=$(echo "$time_end - $time_start" | bc -l)
echo "100 cache file reads: ${cache_read_time}s (${cache_read_time}ms per read)"
echo ""

# Benchmark 2: grep performance in cache (simulating postal code lookups)
echo "📊 Benchmark 2: Cache Lookup Performance (grep)"
echo "------------------------------------------------"
# Get a sample of postal codes to test
sample_postal_codes=$(head -1000 "$TEST_FILE" | grep -o '[A-Z][0-9][A-Z] [0-9][A-Z][0-9]\|[A-Z][0-9][A-Z][0-9][A-Z][0-9]' | head -100 | tr -d ' ')

time_start=$(date +%s.%N)
lookup_count=0
for pc in $sample_postal_codes; do
    if [[ -n "$pc" ]]; then
        grep -q "^$pc;" "$CACHE_FILE" 2>/dev/null
        lookup_count=$((lookup_count + 1))
    fi
done
time_end=$(date +%s.%N)
grep_time=$(echo "$time_end - $time_start" | bc -l)
echo "100 postal code lookups: ${grep_time}s (${grep_time}ms per lookup)"
echo ""

# Benchmark 3: File I/O performance
echo "📊 Benchmark 3: File I/O Performance"
echo "------------------------------------"
time_start=$(date +%s.%N)
for i in {1..100}; do
    head -100 "$TEST_FILE" > /dev/null
done
time_end=$(date +%s.%N)
file_io_time=$(echo "$time_end - $time_start" | bc -l)
echo "100 file I/O operations: ${file_io_time}s (${file_io_time}ms per operation)"
echo ""

# Benchmark 4: CSV parsing performance
echo "📊 Benchmark 4: CSV Parsing Performance"
echo "---------------------------------------"
time_start=$(date +%s.%N)
for i in {1..100}; do
    head -100 "$TEST_FILE" | while IFS= read -r line; do
        echo "$line" | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' > /dev/null
    done
done
time_end=$(date +%s.%N)
csv_parse_time=$(echo "$time_end - $time_start" | bc -l)
echo "100 CSV parsing operations: ${csv_parse_time}s (${csv_parse_time}ms per operation)"
echo ""

# Benchmark 5: End-to-end processing simulation
echo "📊 Benchmark 5: End-to-End Processing Simulation"
echo "------------------------------------------------"
time_start=$(date +%s.%N)
processed_lines=0
head -$SAMPLE_SIZE "$TEST_FILE" | while IFS= read -r line; do
    if [[ -n "$line" ]]; then
        # Simulate the full processing pipeline
        cleaned_line=$(echo "$line" | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        postal_code=$(echo "$cleaned_line" | grep -o '[A-Z][0-9][A-Z] [0-9][A-Z][0-9]\|[A-Z][0-9][A-Z][0-9][A-Z][0-9]' | head -1 | tr -d ' ' || echo "")
        if [[ -n "$postal_code" ]]; then
            grep -q "^$postal_code;" "$CACHE_FILE" 2>/dev/null
        fi
        processed_lines=$((processed_lines + 1))
    fi
done
time_end=$(date +%s.%N)
e2e_time=$(echo "$time_end - $time_start" | bc -l)
echo "$SAMPLE_SIZE lines processed: ${e2e_time}s (${e2e_time}ms per line)"
echo ""

# Summary and recommendations
echo "📋 Performance Summary & Recommendations"
echo "========================================"
echo "Cache file size: $(wc -l < "$CACHE_FILE") entries"
echo "Test file size: $(wc -l < "$TEST_FILE") lines"
echo ""
echo "🚀 Potential Optimizations:"
echo "1. Cache indexing: Consider creating a hash-based index for O(1) lookups"
echo "2. Batch processing: Process multiple lines in parallel"
echo "3. Memory caching: Load frequently accessed cache entries into memory"
echo "4. File format: Consider binary or more efficient formats than CSV"
echo "5. Reduce I/O: Minimize file reads and writes"
echo ""
echo "💡 Next steps:"
echo "- Run this benchmark after each optimization to measure improvement"
echo "- Focus on the slowest operations first"
echo "- Consider profiling with tools like 'strace' or 'perf' for deeper analysis"
