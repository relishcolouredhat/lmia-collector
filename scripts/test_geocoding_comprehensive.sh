#!/bin/bash

# Comprehensive geocoding test script
# Tests multiple scenarios including cache, bogons, and API fallbacks

set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables (API keys, etc.)
source "$SCRIPT_DIR/load_env.sh"

# Load central geocoding library
source "$SCRIPT_DIR/lib/geocoding.sh"

echo "🧪 Comprehensive Geocoding System Test"
echo "======================================"
echo

# Use a temporary cache for testing
TEST_CACHE_DIR="/tmp/geocoding_test_$$"
mkdir -p "$TEST_CACHE_DIR"
export GEOCODING_CACHE_FILE="$TEST_CACHE_DIR/test_cache.csv"
export GEOCODING_BOGONS_FILE="$TEST_CACHE_DIR/test_bogons"

# Initialize test cache
initialize_geocoding_cache

echo "🔧 Test Configuration:"
echo "   Cache file: $GEOCODING_CACHE_FILE"
echo "   Bogons file: $GEOCODING_BOGONS_FILE"
echo "   Google API: $([ -n "$GOOGLE_GEOCODING_API_KEY" ] && echo "✅ Available" || echo "❌ Not configured")"
echo "   MapBox API: $([ -n "$MAPBOX_ACCESS_TOKEN" ] && echo "✅ Available" || echo "❌ Not configured")"
echo "   OpenCage API: $([ -n "$OPENCAGE_API_KEY" ] && echo "✅ Available" || echo "❌ Not configured")"
echo

# Test cases
declare -a TEST_CASES=(
    "K1A0A6:Parliament Hill, Ottawa (should work with any service)"
    "M5V3A8:Toronto downtown (major city)"
    "T5K2M5:Edmonton (western Canada)"
    "H3A0G4:Montreal (Quebec)"
    "V6B1A1:Vancouver (Pacific)"
    "R3C4A2:Winnipeg (prairies)"
    "A1C6H5:St. John's (eastern)"
    "INVALID:Invalid postal code (should become bogon)"
)

echo "🎯 Running Test Cases:"
echo "====================="

for test_case in "${TEST_CASES[@]}"; do
    postal_code=$(echo "$test_case" | cut -d':' -f1)
    description=$(echo "$test_case" | cut -d':' -f2)
    
    echo
    echo "📍 Testing: $postal_code - $description"
    echo "   $(printf '=%.0s' {1..50})"
    
    # Test geocoding
    start_time=$(date +%s)
    coordinates=$(get_coordinates_for_postal_code "$postal_code")
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    # Report results
    if [[ "$coordinates" != "," && -n "$coordinates" ]]; then
        lat=$(echo "$coordinates" | cut -d',' -f1)
        lon=$(echo "$coordinates" | cut -d',' -f2)
        echo "   ✅ SUCCESS: $coordinates (${duration}s)"
        echo "      🌍 Maps: https://www.google.com/maps?q=$lat,$lon"
    else
        echo "   ❌ FAILED: No coordinates found (${duration}s)"
    fi
    
    # Small delay between tests
    sleep 1
done

echo
echo "🔄 Testing Cache Functionality:"
echo "==============================="

# Test cache hit by repeating a successful lookup
echo "📍 Re-testing K1A0A6 (should be cache hit)..."
start_time=$(date +%s)
coordinates=$(get_coordinates_for_postal_code "K1A0A6")
end_time=$(date +%s)
duration=$((end_time - start_time))

if [[ $duration -lt 2 ]]; then
    echo "   ✅ Cache working - lookup completed in ${duration}s"
else
    echo "   ⚠️  Cache might not be working - lookup took ${duration}s"
fi

echo
echo "📊 Final Statistics:"
echo "==================="
print_geocoding_summary

echo
echo "📄 Cache Contents:"
echo "=================="
if [[ -f "$GEOCODING_CACHE_FILE" ]]; then
    echo "   Cache entries: $(tail -n +2 "$GEOCODING_CACHE_FILE" | wc -l)"
    echo "   Sample entries:"
    tail -n +2 "$GEOCODING_CACHE_FILE" | head -3 | while IFS=';' read -r pc lat lon addr emp; do
        echo "      $pc → $lat,$lon"
    done
else
    echo "   No cache file created"
fi

echo
echo "🚫 Bogons (Failed Lookups):"
echo "============================"
if [[ -f "$GEOCODING_BOGONS_FILE" ]]; then
    bogon_count=$(wc -l < "$GEOCODING_BOGONS_FILE")
    echo "   Bogon entries: $bogon_count"
    if [[ $bogon_count -gt 0 ]]; then
        echo "   Bogons:"
        cat "$GEOCODING_BOGONS_FILE" | while read -r bogon; do
            echo "      $bogon (will not retry API calls)"
        done
    fi
else
    echo "   No bogons file created"
fi

echo
echo "🔍 Performance Analysis:"
echo "========================"
stats=$(get_cache_stats)
total_entries=$(echo "$stats" | cut -d',' -f1)
cache_hits=$(echo "$stats" | cut -d',' -f2)
api_calls=$(echo "$stats" | cut -d',' -f3)
failed_lookups=$(echo "$stats" | cut -d',' -f4)

if [[ $api_calls -gt 0 ]]; then
    success_rate=$(( (api_calls - failed_lookups) * 100 / api_calls ))
    echo "   API Success Rate: ${success_rate}%"
    
    if [[ $success_rate -ge 80 ]]; then
        echo "   ✅ Excellent success rate"
    elif [[ $success_rate -ge 60 ]]; then
        echo "   ⚠️  Moderate success rate - check API keys/connectivity"
    else
        echo "   ❌ Poor success rate - likely API or connectivity issues"
    fi
fi

if [[ $((cache_hits + api_calls)) -gt 0 ]]; then
    cache_ratio=$(( cache_hits * 100 / (cache_hits + api_calls) ))
    echo "   Cache Hit Ratio: ${cache_ratio}%"
fi

# Cleanup
echo
echo "🧹 Cleaning up test files..."
rm -rf "$TEST_CACHE_DIR"

echo
echo "✅ Comprehensive test completed!"
echo
echo "💡 Next Steps:"
echo "   1. If Google API tests passed, your integration is working"
echo "   2. Run real geocoding scripts on your CSV files"
echo "   3. Monitor the cache growth and API usage"
echo "   4. Check Google Cloud Console for API usage metrics"
