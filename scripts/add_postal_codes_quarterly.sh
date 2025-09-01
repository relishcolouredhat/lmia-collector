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
        local cached_coords=$(grep "^$normalized_pc;" "$CACHE_FILE" 2>/dev/null | head -1 | cut -d';' -f2,3 | tr ';' ',')
        if [[ -n "$cached_coords" && "$cached_coords" != "," ]]; then
            echo "  ✓ Cache hit: $postal_code" >&2
            echo "$cached_coords"
            return
        fi
    fi
    
    # Not in cache, try multiple geocoding sources (API requires postal code without spaces)
    echo "  → Looking up postal code: $postal_code" >&2
    
    # Try Nominatim first (OpenStreetMap)
    echo "    → Trying Nominatim (OpenStreetMap)..." >&2
    local coordinates=$(curl -s "https://nominatim.openstreetmap.org/search?postalcode=${normalized_pc}&country=CA&format=json&limit=1" | jq -r '.[0] | "\(.lat),\(.lon)"' 2>/dev/null || echo ",")
    local source="Nominatim"
    
    # If Nominatim failed, try geocoder.ca as fallback
    if [[ "$coordinates" == "null,null" || "$coordinates" == "," ]]; then
        echo "    → Nominatim failed, trying geocoder.ca..." >&2
        sleep 0.5  # geocoder.ca rate limit: max 2 requests/second
        
        # geocoder.ca API format: http://geocoder.ca/?postal=POSTALCODE&geoit=xml
        local geocoder_response=$(curl -s "http://geocoder.ca/?postal=${normalized_pc}&geoit=xml" 2>/dev/null || echo "")
        
        if [[ -n "$geocoder_response" && "$geocoder_response" != *"error"* ]]; then
            # Extract lat/lon from XML response
            local lat=$(echo "$geocoder_response" | grep -o '<latt>[^<]*</latt>' | sed 's/<[^>]*>//g' 2>/dev/null || echo "")
            local lon=$(echo "$geocoder_response" | grep -o '<longt>[^<]*</longt>' | sed 's/<[^>]*>//g' 2>/dev/null || echo "")
            
            if [[ -n "$lat" && -n "$lon" && "$lat" != "" && "$lon" != "" ]]; then
                coordinates="$lat,$lon"
                source="geocoder.ca"
            fi
        fi
    fi
    
    # Check final result and add source information
    if [[ "$coordinates" == "null,null" || "$coordinates" == "," || -z "$coordinates" ]]; then
        echo "    ❌ No coordinates found for $postal_code (tried both sources)" >&2
        echo ","
    else
        echo "    ✅ Found coordinates: $coordinates (source: $source)" >&2
        echo "$coordinates"
        # Cache the result if we have valid coordinates
        if [[ -f "$CACHE_FILE" ]] && [[ "$coordinates" != "," ]]; then
            local lat=$(echo "$coordinates" | cut -d',' -f1)
            local lon=$(echo "$coordinates" | cut -d',' -f2)
            if [[ -n "$lat" && -n "$lon" ]]; then
                # Add to cache if not already present (normalize format)
                if ! grep -q "^$normalized_pc;" "$CACHE_FILE" 2>/dev/null; then
                    echo "$normalized_pc;$lat;$lon;Unknown;Unknown" >> "$CACHE_FILE"
                fi
            fi
        fi
    fi
    
    # Rate limiting - ONLY for API calls (not cache hits)
    sleep "$SLEEP_TIMER"
}

# Create temporary file
TEMP_FILE="${FILE}.tmp"

# Detect file format and get proper header
second_line=$(sed -n '2p' "$FILE")
if [[ "$second_line" == *"Province"* || "$second_line" == *"Territory"* ]]; then
    # Excel-converted format: use line 2 as header
    echo "    → Excel format detected - using line 2 as header" >&2
    sed -n '2p' "$FILE" | sed 's/$/,Postal Code,Latitude,Longitude/' > "$TEMP_FILE"
    skip_lines=3
else
    # Direct CSV format: use line 1 as header
    echo "    → CSV format detected - using line 1 as header" >&2
    head -1 "$FILE" | sed 's/$/,Postal Code,Latitude,Longitude/' > "$TEMP_FILE"
    skip_lines=2
fi

# Process each line to extract postal code and coordinates from address
# Quarterly format typically has address in the 4th column
tail -n +$skip_lines "$FILE" | while IFS= read -r line; do
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
