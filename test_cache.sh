#!/bin/bash

# Source the functions from process_feeds.sh
source scripts/process_feeds.sh

echo "=== Testing Location Cache System ==="

# Initialize cache
initialize_location_cache

echo "Created cache file:"
cat location_cache.csv

echo -e "\n=== Testing postal code lookup ==="

# Test getting coordinates for a postal code
echo "Testing postal code: A1C 6C9"
coords=$(get_postal_code_coordinates "A1C 6C9")
echo "Coordinates: $coords"

# Test caching an employer
lat=$(echo "$coords" | cut -d',' -f1)
lon=$(echo "$coords" | cut -d',' -f2)
echo -e "\n=== Testing cache function ==="
echo "Caching: Aker Solutions, St. John's Address, A1C 6C9, $lat, $lon"
cache_employer_location "Aker Solutions AIM" "215 Water Street, St. John's, NL A1C 6C9" "A1C 6C9" "$lat" "$lon"

echo -e "\nCache file contents:"
cat location_cache.csv

echo -e "\n=== Testing cache retrieval ==="
echo "Looking up A1C 6C9 again (should be cached):"
cached_coords=$(get_postal_code_coordinates "A1C 6C9")
echo "Cached coordinates: $cached_coords"

echo -e "\n=== Cache test complete ==="
