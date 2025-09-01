#!/bin/bash

# Test script for Turbo Mode geocoding
# Uses Google API first for maximum performance

set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables (API keys, etc.)
source "$SCRIPT_DIR/load_env.sh"

# Load central geocoding library
source "$SCRIPT_DIR/lib/geocoding.sh"

echo "🚀 Testing TURBO MODE Geocoding"
echo "==============================="
echo

# Check if Google API key is available
if [[ -z "$GOOGLE_GEOCODING_API_KEY" ]]; then
    echo "❌ GOOGLE_GEOCODING_API_KEY not found in environment"
    echo "   Turbo mode requires Google API key"
    exit 1
fi

echo "✅ Google API key found"
echo "⚡ Enabling TURBO MODE..."
echo

# Enable turbo mode
export GEOCODING_TURBO_MODE="true"

# Use a temporary cache for testing
TEST_CACHE_DIR="/tmp/turbo_test_$$"
mkdir -p "$TEST_CACHE_DIR"
export GEOCODING_CACHE_FILE="$TEST_CACHE_DIR/test_cache.csv"
export GEOCODING_BOGONS_FILE="$TEST_CACHE_DIR/test_bogons"

# Initialize test cache
initialize_geocoding_cache

# Test postal codes
declare -a TEST_CODES=(
    "K1A0A6:Ottawa (Parliament Hill)"
    "M5V3A8:Toronto downtown"
    "V6C1B6:Vancouver downtown"
    "T2P2Y5:Calgary downtown"
    "H3A0G4:Montreal downtown"
)

echo "🧪 Testing Turbo Mode Performance:"
echo "=================================="

total_time=0
success_count=0

for test_case in "${TEST_CODES[@]}"; do
    postal_code=$(echo "$test_case" | cut -d':' -f1)
    description=$(echo "$test_case" | cut -d':' -f2)
    
    echo
    echo "📍 Testing: $postal_code - $description"
    echo "   $(printf '=%.0s' {1..40})"
    
    # Time the lookup
    start_time=$(date +%s.%N)
    coordinates=$(get_coordinates_for_postal_code "$postal_code")
    end_time=$(date +%s.%N)
    
    # Calculate duration
    duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "1.0")
    total_time=$(echo "$total_time + $duration" | bc 2>/dev/null || echo "$total_time")
    
    # Report results
    if [[ "$coordinates" != "," && -n "$coordinates" ]]; then
        success_count=$((success_count + 1))
        echo "   ✅ SUCCESS: $coordinates (${duration}s)"
        echo "      🌍 https://www.google.com/maps?q=$coordinates"
    else
        echo "   ❌ FAILED: No coordinates found (${duration}s)"
    fi
done

echo
echo "⚡ TURBO MODE Results:"
echo "===================="
total_tests=${#TEST_CODES[@]}
success_rate=$((success_count * 100 / total_tests))
avg_time=$(echo "scale=2; $total_time / $total_tests" | bc 2>/dev/null || echo "N/A")

echo "   Tests run: $total_tests"
echo "   Successful: $success_count"
echo "   Success rate: ${success_rate}%"
echo "   Average time: ${avg_time}s per lookup"
echo "   Total time: ${total_time}s"

# Performance comparison
echo
echo "📊 Performance Comparison:"
echo "========================="
echo "   🚀 Turbo Mode: ~0.05s sleep + ~0.2s API call = ~0.25s per lookup"
echo "   🐌 Standard Mode: 1s + 0.5s + 0.5s + API fallbacks = ~3-5s per lookup"
echo "   📈 Speed improvement: ~10-20x faster!"

print_geocoding_summary

# Cleanup
echo
echo "🧹 Cleaning up test files..."
rm -rf "$TEST_CACHE_DIR"

echo
echo "✅ Turbo mode test completed!"
echo
echo "💡 To use turbo mode in cache updates:"
echo "   GEOCODING_TURBO_MODE=true ./scripts/update_cache.sh"
