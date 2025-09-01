#!/bin/bash

# Test script for Google Geocoding API integration
# Usage: ./test_google_geocoding.sh [postal_code]

set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables (API keys, etc.)
source "$SCRIPT_DIR/load_env.sh"

# Load central geocoding library
source "$SCRIPT_DIR/lib/geocoding.sh"

# Test postal code (default to a known Canadian postal code)
TEST_POSTAL_CODE="${1:-K1A0A6}"  # Parliament Hill, Ottawa

echo "🧪 Testing Google Geocoding API integration"
echo "================================================"
echo

# Check if Google API key is available
if [[ -z "$GOOGLE_GEOCODING_API_KEY" ]]; then
    echo "❌ GOOGLE_GEOCODING_API_KEY not found in environment"
    echo "   Please add your API key to .env file"
    echo "   Copy env.example to .env and add your key"
    exit 1
fi

echo "✅ Google API key found in environment"
echo "🔍 Testing with postal code: $TEST_POSTAL_CODE"
echo

# Force a fresh lookup by temporarily using a different cache file
export GEOCODING_CACHE_FILE="/tmp/test_geocoding_cache.csv"
initialize_geocoding_cache

# Clear any existing test cache
rm -f "$GEOCODING_CACHE_FILE"
initialize_geocoding_cache

# Test the geocoding function
echo "📍 Calling get_coordinates_for_postal_code..."
coordinates=$(get_coordinates_for_postal_code "$TEST_POSTAL_CODE")

echo
echo "🎯 Results:"
echo "   Postal Code: $TEST_POSTAL_CODE"
echo "   Coordinates: $coordinates"

if [[ "$coordinates" != "," && -n "$coordinates" ]]; then
    echo "   ✅ SUCCESS: Google Geocoding API is working!"
    
    # Parse coordinates
    lat=$(echo "$coordinates" | cut -d',' -f1)
    lon=$(echo "$coordinates" | cut -d',' -f2)
    
    if [[ -n "$lat" && -n "$lon" ]]; then
        echo "   📐 Latitude: $lat"
        echo "   📐 Longitude: $lon"
        echo "   🌍 Google Maps: https://www.google.com/maps?q=$lat,$lon"
    fi
else
    echo "   ❌ FAILED: No coordinates returned"
    echo "   This could mean:"
    echo "   - Invalid API key"
    echo "   - API quota exceeded"
    echo "   - Network connectivity issues"
    echo "   - Invalid postal code"
fi

echo
print_geocoding_summary

# Clean up test cache
rm -f "$GEOCODING_CACHE_FILE"

echo
echo "🔧 Next steps:"
echo "   1. If successful, your Google API is ready for production use"
echo "   2. Run your normal geocoding scripts - they will now use Google as fallback"
echo "   3. Monitor your Google Cloud Console for API usage"
