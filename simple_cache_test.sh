#!/bin/bash

# Define variables and functions from process_feeds.sh
LOCATION_CACHE_FILE="./location_cache.csv"

initialize_location_cache() {
    if [[ ! -f "$LOCATION_CACHE_FILE" ]]; then
        echo "Employer,Address,Postal Code,Latitude,Longitude" > "$LOCATION_CACHE_FILE"
        echo "  -> Created location cache file: $LOCATION_CACHE_FILE"
    fi
}

cache_employer_location() {
    local employer="$1"
    local address="$2"
    local postal_code="$3"
    local latitude="$4"
    local longitude="$5"
    
    if [[ -z "$employer" || -z "$postal_code" ]]; then
        return
    fi
    
    employer=$(echo "$employer" | sed 's/"/""/g' | sed 's/,/;/g')
    address=$(echo "$address" | sed 's/"/""/g' | sed 's/,/;/g')
    
    local cache_key="${employer}.*${postal_code}"
    if ! grep -q "$cache_key" "$LOCATION_CACHE_FILE" 2>/dev/null; then
        echo "\"$employer\",\"$address\",$postal_code,$latitude,$longitude" >> "$LOCATION_CACHE_FILE"
    fi
}

get_postal_code_coordinates() {
    local postal_code="$1"
    
    if [[ -z "$postal_code" ]]; then
        echo ","
        return
    fi
    
    # Check cache first
    local cached_coords=$(grep ",$postal_code," "$LOCATION_CACHE_FILE" 2>/dev/null | head -1 | cut -d',' -f4,5)
    
    if [[ -n "$cached_coords" && "$cached_coords" != "," ]]; then
        echo "Found in cache: $cached_coords"
        echo "$cached_coords"
        return
    fi
    
    echo "Not in cache, making API call for $postal_code..."
    echo "47.5615,-52.7126"  # Mock coordinates for testing
}

echo "=== Testing Location Cache System ==="

# Test the system
initialize_location_cache
echo "Cache initialized."

echo -e "\nTesting postal code lookup (should make API call):"
coords=$(get_postal_code_coordinates "A1C 6C9")
echo "Got coordinates: $coords"

echo -e "\nCaching the result:"
cache_employer_location "Test Company" "Test Address" "A1C 6C9" "47.5615" "-52.7126"

echo -e "\nCache contents:"
cat "$LOCATION_CACHE_FILE"

echo -e "\nTesting postal code lookup again (should use cache):"
coords2=$(get_postal_code_coordinates "A1C 6C9")
echo "Got coordinates: $coords2"
