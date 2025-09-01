#!/bin/bash

# Test cache performance - cache hits should be lightning fast now!

set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables (API keys, etc.)
source "$SCRIPT_DIR/load_env.sh"

# Load central geocoding library
source "$SCRIPT_DIR/lib/geocoding.sh"

echo "⚡ Testing Cache Performance"
echo "==========================="
echo

# Test postal codes that should be in cache
CACHED_CODES=("A1C6C9" "A0P1G0" "A0P1C0" "A0A1G0" "A1W3A6")

echo "🧪 Testing cache hits (should be INSTANT):"
echo "=========================================="

total_time=0
for postal_code in "${CACHED_CODES[@]}"; do
    echo -n "📍 $postal_code: "
    
    # Time the lookup
    start_time=$(date +%s.%N)
    coordinates=$(get_coordinates_for_postal_code "$postal_code" 2>/dev/null)
    end_time=$(date +%s.%N)
    
    # Calculate duration
    duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0.1")
    total_time=$(echo "$total_time + $duration" | bc 2>/dev/null || echo "$total_time")
    
    if [[ "$coordinates" != "," && -n "$coordinates" ]]; then
        echo "✅ ${duration}s - $coordinates"
    else
        echo "❌ ${duration}s - Not found"
    fi
done

echo
echo "📊 Performance Results:"
echo "======================"
num_tests=${#CACHED_CODES[@]}
avg_time=$(echo "scale=3; $total_time / $num_tests" | bc 2>/dev/null || echo "N/A")

echo "   Tests run: $num_tests"
echo "   Total time: ${total_time}s"
echo "   Average time: ${avg_time}s per lookup"

if (( $(echo "$avg_time < 0.1" | bc -l 2>/dev/null || echo "0") )); then
    echo "   🚀 EXCELLENT! Cache hits are lightning fast!"
elif (( $(echo "$avg_time < 0.5" | bc -l 2>/dev/null || echo "0") )); then
    echo "   ✅ Good! Cache performance is acceptable"
else
    echo "   ⚠️  Slow! Cache performance needs improvement"
fi

print_geocoding_summary
