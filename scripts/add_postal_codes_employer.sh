#!/bin/bash

# Add postal codes and coordinates to employer format CSV files
set -e

FILE="$1"
SLEEP_TIMER="${2:-1}"
CACHE_FILE="./outputs/cache/location_cache.csv"

if [[ ! -f "$FILE" ]]; then
    echo "Error: File not found: $FILE"
    exit 1
fi

echo "Adding postal codes to employer format file: $(basename "$FILE")"

# Function to extract postal code from address
extract_postal_code() {
    local address="$1"
    # Extract Canadian postal code pattern: A1A 1A1 or A1A1A1
    echo "$address" | grep -o '[A-Z][0-9][A-Z] [0-9][A-Z][0-9]\|[A-Z][0-9][A-Z][0-9][A-Z][0-9]' | head -1 || echo ""
}

# Function to get coordinates from cache or API
get_postal_code_coordinates() {
    local postal_code="$1"
    
    if [[ -z "$postal_code" ]]; then
        echo ","
        return
    fi
    
    # Check cache first
    if [[ -f "$CACHE_FILE" ]]; then
        local cached_coords=$(grep "^$postal_code," "$CACHE_FILE" 2>/dev/null | head -1 | cut -d',' -f2,3)
        if [[ -n "$cached_coords" && "$cached_coords" != "," ]]; then
            echo "$cached_coords"
            return
        fi
    fi
    
    # Not in cache, query Nominatim API
    echo "  → Looking up postal code: $postal_code" >&2
    local coordinates=$(curl -s "https://nominatim.openstreetmap.org/search?postalcode=${postal_code}&country=CA&format=json&limit=1" | jq -r '.[0] | "\(.lat),\(.lon)"' 2>/dev/null || echo ",")
    
    if [[ "$coordinates" == "null,null" || "$coordinates" == "," ]]; then
        echo ","
    else
        echo "$coordinates"
        # Cache the result if we have valid coordinates
        if [[ -f "$CACHE_FILE" ]] && [[ "$coordinates" != "," ]]; then
            local lat=$(echo "$coordinates" | cut -d',' -f1)
            local lon=$(echo "$coordinates" | cut -d',' -f2)
            if [[ -n "$lat" && -n "$lon" ]]; then
                # Add to cache if not already present
                if ! grep -q "^$postal_code," "$CACHE_FILE" 2>/dev/null; then
                    echo "$postal_code,$lat,$lon,\"Sample Address\",\"Sample Employer\"" >> "$CACHE_FILE"
                fi
            fi
        fi
    fi
    
    # Rate limiting
    sleep "$SLEEP_TIMER"
}

# Create temporary file
TEMP_FILE="${FILE}.tmp"

# Create header with postal code and coordinates columns
head -1 "$FILE" | sed 's/$/,Postal Code,Latitude,Longitude/' > "$TEMP_FILE"

# Process each line to extract postal code and coordinates from address
tail -n +2 "$FILE" | while IFS= read -r line; do
    if [[ -n "$line" ]]; then
        # Extract address from the line (assuming it's the second field in CSV)
        address=$(echo "$line" | cut -d',' -f2 | sed 's/"//g')
        postal_code=$(extract_postal_code "$address")
        coordinates=$(get_postal_code_coordinates "$postal_code")
        lat=$(echo "$coordinates" | cut -d',' -f1)
        lon=$(echo "$coordinates" | cut -d',' -f2)
        
        echo "${line},${postal_code},${lat},${lon}" >> "$TEMP_FILE"
    fi
done

# Replace original file with processed version
mv "$TEMP_FILE" "$FILE"

echo "✅ Added postal codes to $(basename "$FILE")"
