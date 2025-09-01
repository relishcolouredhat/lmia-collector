#!/bin/bash

# Test geocoding with a curated sample of real postal codes from cache
# This gives us a controlled test with known good postal codes

set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables (API keys, etc.)
source "$SCRIPT_DIR/load_env.sh"

# Load central geocoding library
source "$SCRIPT_DIR/lib/geocoding.sh"

echo "🧪 Testing Geocoding with Sample Real Postal Codes"
echo "=================================================="
echo

# Use a temporary cache for testing
TEST_CACHE_DIR="/tmp/sample_test_$$"
mkdir -p "$TEST_CACHE_DIR"
export GEOCODING_CACHE_FILE="$TEST_CACHE_DIR/test_cache.csv"
export GEOCODING_BOGONS_FILE="$TEST_CACHE_DIR/test_bogons"

# Initialize test cache
initialize_geocoding_cache

# Sample of real postal codes from your existing cache
# These are known to be from your actual LMIA data
declare -a REAL_POSTAL_CODES=(
    "B3G1M5:Halifax area (from existing cache)"
    "B3H2Y9:Halifax (Capital District Health Authority)"
    "J0E1A0:Quebec (Saint-Paul-d'Abbotsford)"
    "K1A0A6:Ottawa (Parliament Hill - control)"
    "M5V3A8:Toronto downtown (control)"
    "V6C1B6:Vancouver (typical BC code)"
    "T2P2Y5:Calgary (typical AB code)"
    "S7K1J5:Saskatoon (typical SK code)"
)

echo "🎯 Testing Curated Real Postal Codes:"
echo "===================================="

success_count=0
total_count=${#REAL_POSTAL_CODES[@]}

for test_case in "${REAL_POSTAL_CODES[@]}"; do
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
        
        # Validate coordinates are reasonable for Canada
        if command -v bc >/dev/null 2>&1; then
            if [[ $(echo "$lat > 41 && $lat < 84" | bc 2>/dev/null || echo "0") -eq 1 ]] && \
               [[ $(echo "$lon > -142 && $lon < -52" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
                echo "      ✅ Coordinates are within Canadian bounds"
            else
                echo "      ⚠️  Coordinates outside expected Canadian bounds"
            fi
        fi
        
        success_count=$((success_count + 1))
    else
        echo "   ❌ FAILED: No coordinates found (${duration}s)"
    fi
    
    # Rate limiting
    sleep 1
done

echo
echo "📊 Test Summary:"
echo "================"
echo "   Successful lookups: $success_count/$total_count"
success_rate=$(( success_count * 100 / total_count ))
echo "   Success rate: ${success_rate}%"

print_geocoding_summary

echo
echo "🔍 Service Usage Analysis:"
echo "=========================="
if [[ -f "$GEOCODING_CACHE_FILE" ]]; then
    cached_count=$(tail -n +2 "$GEOCODING_CACHE_FILE" | wc -l)
    echo "   Entries added to cache: $cached_count"
    
    if [[ $cached_count -gt 0 ]]; then
        echo "   Sample cached entries:"
        tail -n +2 "$GEOCODING_CACHE_FILE" | head -3 | while IFS=';' read -r pc lat lon addr emp; do
            echo "      $pc → $lat,$lon"
        done
    fi
else
    echo "   No cache entries created"
fi

stats=$(get_cache_stats)
api_calls=$(echo "$stats" | cut -d',' -f3)

echo
echo "💰 Cost Analysis:"
echo "================="
echo "   Total API calls: $api_calls"

if [[ -n "$GOOGLE_GEOCODING_API_KEY" ]] && [[ $api_calls -gt 0 ]]; then
    echo "   Google API calls: Estimated from fallback usage"
    echo "   Google pricing: ~\$5.00 per 1,000 requests"
    if command -v bc >/dev/null 2>&1; then
        cost_estimate=$(echo "scale=4; $api_calls * 5 / 1000" | bc 2>/dev/null || echo "N/A")
        echo "   Estimated cost for this test: ~\$${cost_estimate}"
    fi
    echo "   Free tier: 200/day, 40,000/month"
fi

echo
echo "🎯 Production Readiness:"
echo "======================="
if [[ $success_rate -ge 90 ]]; then
    echo "   ✅ EXCELLENT - System ready for production use"
elif [[ $success_rate -ge 75 ]]; then
    echo "   ✅ GOOD - System ready with monitoring recommended"
elif [[ $success_rate -ge 50 ]]; then
    echo "   ⚠️  MODERATE - Consider investigating failed lookups"
else
    echo "   ❌ POOR - Review API configuration and connectivity"
fi

# Cleanup
echo
echo "🧹 Cleaning up test files..."
rm -rf "$TEST_CACHE_DIR"

echo
echo "✅ Sample postal code test completed!"
