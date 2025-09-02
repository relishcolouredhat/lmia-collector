#!/bin/bash
set -e

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/load_env.sh"

FILE="$1"
CACHE_FILE="../outputs/cache/location_cache.csv"

# Configure before loading library
export GEOCODING_CACHE_FILE="$CACHE_FILE"
export GEOCODING_TURBO_MODE=true

echo "DEBUG: GEOCODING_CACHE_FILE before loading library: $GEOCODING_CACHE_FILE" >&2
echo "DEBUG: File exists check: $([[ -f "$GEOCODING_CACHE_FILE" ]] && echo "YES" || echo "NO")" >&2

# Load library
source "$SCRIPT_DIR/lib/geocoding.sh"

echo "DEBUG: GEOCODING_CACHE_FILE after loading library: $GEOCODING_CACHE_FILE" >&2
echo "DEBUG: File exists check: $([[ -f "$GEOCODING_CACHE_FILE" ]] && echo "YES" || echo "NO")" >&2

# Test one lookup
echo "DEBUG: Testing A2A 1X3 lookup:" >&2
result=$(get_coordinates_for_postal_code "A2A 1X3")
echo "DEBUG: Result: $result" >&2
