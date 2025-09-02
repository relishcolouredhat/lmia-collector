#!/bin/bash
CACHE_FILE="../outputs/cache/location_cache.csv"
export GEOCODING_CACHE_FILE="$CACHE_FILE"

source load_env.sh >/dev/null 2>&1
source lib/geocoding.sh

echo "Cache file set to: $GEOCODING_CACHE_FILE"
echo "File exists: $([[ -f "$GEOCODING_CACHE_FILE" ]] && echo "YES" || echo "NO")"

result=$(get_coordinates_for_postal_code "A2A 1X3")
echo "Result: $result"
