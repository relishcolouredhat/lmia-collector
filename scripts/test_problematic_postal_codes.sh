#!/bin/bash

# Test specific postal codes that generated malformed cache entries
# This helps identify bugs in the cache generation logic

set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables (API keys, etc.)
source "$SCRIPT_DIR/load_env.sh"

# Load central geocoding library
source "$SCRIPT_DIR/lib/geocoding.sh"

echo "🔍 Testing Problematic Postal Codes"
echo "===================================="
echo

# Postal codes that generated malformed cache entries
PROBLEMATIC_CODES=(
    "B0J2C0"  # Cilantro, The Cooks Shop Inc
    "B3B1S3"  # Jesse Stone Productions, Inc  
    "B2H3K6"  # The Dock Food, Spirits and Ales Ltd
)

# Use a temporary cache for testing
TEST_CACHE_DIR="/tmp/postal_test_$$"
mkdir -p "$TEST_CACHE_DIR"
export GEOCODING_CACHE_FILE="$TEST_CACHE_DIR/test_cache.csv"
export GEOCODING_BOGONS_FILE="$TEST_CACHE_DIR/test_bogons"

# Initialize test cache
initialize_geocoding_cache

echo "🧪 Testing each problematic postal code:"
echo "========================================"

for postal_code in "${PROBLEMATIC_CODES[@]}"; do
    echo
    echo "📍 Testing: $postal_code"
    echo "   $(printf '=%.0s' {1..30})"
    
    # Test with turbo mode enabled
    export GEOCODING_TURBO_MODE="true"
    
    # Time the lookup
    start_time=$(date +%s.%N)
    coordinates=$(get_coordinates_for_postal_code "$postal_code")
    end_time=$(date +%s.%N)
    
    # Calculate duration
    duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "1.0")
    
    # Report results
    if [[ "$coordinates" != "," && -n "$coordinates" ]]; then
        echo "   ✅ SUCCESS: $coordinates (${duration}s)"
        echo "      🌍 https://www.google.com/maps?q=$coordinates"
        
        # Check what was added to cache
        if [[ -f "$GEOCODING_CACHE_FILE" ]]; then
            cache_entry=$(grep "^$postal_code;" "$GEOCODING_CACHE_FILE" 2>/dev/null || echo "")
            if [[ -n "$cache_entry" ]]; then
                echo "      📝 Cache entry: $cache_entry"
                
                # Analyze cache entry structure
                field_count=$(echo "$cache_entry" | awk -F';' '{print NF}')
                if [[ $field_count -eq 5 ]]; then
                    echo "      ✅ Cache entry has correct 5 fields"
                else
                    echo "      ❌ Cache entry has $field_count fields (expected 5)"
                fi
                
                # Check for problematic patterns
                if echo "$cache_entry" | grep -q '"".*""'; then
                    echo "      ⚠️  Cache entry contains double quotes!"
                fi
                if echo "$cache_entry" | grep -q '.*,.*,.*'; then
                    echo "      ⚠️  Cache entry may have embedded commas in wrong places!"
                fi
            else
                echo "      ⚠️  No cache entry found (might not have been cached)"
            fi
        fi
    else
        echo "   ❌ FAILED: No coordinates found (${duration}s)"
    fi
done

echo
echo "📊 Summary:"
echo "==========="
cache_entries=$(tail -n +2 "$GEOCODING_CACHE_FILE" 2>/dev/null | wc -l)
echo "   Cache entries created: $cache_entries"
echo "   Cache file: $GEOCODING_CACHE_FILE"

# Show all cache entries for review
if [[ $cache_entries -gt 0 ]]; then
    echo
    echo "📋 All cache entries created:"
    tail -n +2 "$GEOCODING_CACHE_FILE" | while IFS=';' read -r pc lat lon addr emp; do
        echo "   $pc → $addr | $emp"
    done
fi

echo
echo "🔍 Looking for potential issues in cache generation..."
malformed_entries=$(tail -n +2 "$GEOCODING_CACHE_FILE" 2>/dev/null | grep -c '"".*""' || echo "0")
if [[ $malformed_entries -gt 0 ]]; then
    echo "   ❌ Found $malformed_entries entries with double quote issues"
    echo "   🐛 This indicates a bug in the cache generation logic!"
else
    echo "   ✅ No malformed entries detected in fresh test"
fi

# Cleanup
echo
echo "🧹 Test completed. Cache files in: $TEST_CACHE_DIR"
echo "   (Will be cleaned up on next reboot)"

print_geocoding_summary
