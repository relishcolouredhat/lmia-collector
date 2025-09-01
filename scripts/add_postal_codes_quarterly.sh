#!/bin/bash

# Add postal codes and coordinates to quarterly format CSV files
set -e

FILE="$1"
SLEEP_TIMER="${2:-1}"
CACHE_FILE="./outputs/cache/location_cache.csv"

if [[ ! -f "$FILE" ]]; then
    echo "Error: File not found: $FILE"
    exit 1
fi

echo "Adding postal codes to quarterly format file: $(basename "$FILE")"

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
    
    # Check cache first - normalize postal code format (remove spaces for lookup)
    local normalized_pc=$(echo "$postal_code" | tr -d ' ')
    if [[ -f "$CACHE_FILE" ]]; then
        local cached_coords=$(grep "^$normalized_pc," "$CACHE_FILE" 2>/dev/null | head -1 | cut -d',' -f2,3)
        if [[ -n "$cached_coords" && "$cached_coords" != "," ]]; then
            echo "  ✓ Cache hit: $postal_code" >&2
            echo "$cached_coords"
            return
        fi
    fi
    
    # Not in cache, query Nominatim API (API requires postal code without spaces)
    echo "  → Looking up postal code: $postal_code" >&2
    local coordinates=$(curl -s "https://nominatim.openstreetmap.org/search?postalcode=${normalized_pc}&country=CA&format=json&limit=1" | jq -r '.[0] | "\(.lat),\(.lon)"' 2>/dev/null || echo ",")
    
    if [[ "$coordinates" == "null,null" || "$coordinates" == "," ]]; then
        echo ","
    else
        echo "$coordinates"
        # Cache the result if we have valid coordinates
        if [[ -f "$CACHE_FILE" ]] && [[ "$coordinates" != "," ]]; then
            local lat=$(echo "$coordinates" | cut -d',' -f1)
            local lon=$(echo "$coordinates" | cut -d',' -f2)
            if [[ -n "$lat" && -n "$lon" ]]; then
                # Add to cache if not already present (normalize format)
                if ! grep -q "^$normalized_pc," "$CACHE_FILE" 2>/dev/null; then
                    echo "$normalized_pc,$lat,$lon,\"API Lookup\",\"API Result\"" >> "$CACHE_FILE"
                fi
            fi
        fi
    fi
    
    # Rate limiting - ONLY for API calls (not cache hits)
    sleep "$SLEEP_TIMER"
}

# Create temporary file
TEMP_FILE="${FILE}.tmp"

# Create header with postal code and coordinates columns
head -1 "$FILE" | sed 's/$/,Postal Code,Latitude,Longitude/' > "$TEMP_FILE"

# Process each line to extract postal code and coordinates from address
# Quarterly format typically has address in the 4th column
tail -n +2 "$FILE" | while IFS= read -r line; do
    if [[ -n "$line" ]]; then
        # Extract address using proper CSV parsing - address is in quotes as 4th field
        # Use awk to properly parse CSV with quoted fields
        address=$(echo "$line" | awk -F',' '{
            field_num = 4
            # If field starts with quote, find the matching end quote
            if ($field_num ~ /^"/) {
                result = $field_num
                for (i = field_num + 1; i <= NF; i++) {
                    if ($i ~ /"$/) {
                        result = result "," $i
                        break
                    } else {
                        result = result "," $i
                    }
                }
                # Remove surrounding quotes
                gsub(/^"|"$/, "", result)
                print result
            } else {
                print $field_num
            }
        }')
        
        postal_code=$(extract_postal_code "$address")
        coordinates=$(get_postal_code_coordinates "$postal_code")
        lat=$(echo "$coordinates" | cut -d',' -f1)
        lon=$(echo "$coordinates" | cut -d',' -f2)
        
        echo "${line},${postal_code},${lat},${lon}" >> "$TEMP_FILE"
    fi
done

# Create processed file in the processed directory (preserve original)
PROCESSED_DIR="./outputs/csv/processed/quarterly_format"
mkdir -p "$PROCESSED_DIR"
PROCESSED_FILE="$PROCESSED_DIR/$(basename "$FILE")"

mv "$TEMP_FILE" "$PROCESSED_FILE"

echo "✅ Added postal codes to $(basename "$PROCESSED_FILE")"
echo "   Original: $FILE"
echo "   Processed: $PROCESSED_FILE"
