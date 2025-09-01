#!/bin/bash

# Add postal codes and coordinates to quarterly format CSV files
set -e

# Load environment variables (API keys, etc.)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/load_env.sh"

# Load central geocoding library
source "$SCRIPT_DIR/lib/geocoding.sh"

FILE="$1"
SLEEP_TIMER="${2:-1}"
CACHE_FILE="./outputs/cache/location_cache.csv"

# Configure geocoding library
export GEOCODING_SLEEP_TIMER="$SLEEP_TIMER"
export GEOCODING_CACHE_FILE="$CACHE_FILE"

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
# Wrapper function that delegates to central geocoding library and handles caching
get_postal_code_coordinates() {
    local postal_code="$1"
    local coordinates=$(get_coordinates_for_postal_code "$postal_code")
    
    # If coordinates found and not cached, add to cache with "Unknown" placeholder data
    if [[ "$coordinates" != "," && -n "$coordinates" ]]; then
        add_to_cache "$postal_code" "$coordinates" "Unknown" "Unknown"
    fi
    
    echo "$coordinates"
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
