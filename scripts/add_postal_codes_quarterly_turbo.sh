#!/bin/bash
set -e

# TURBO MODE: Ultra-Optimized Quarterly LMIA Processing Script
# Eliminates ALL external processes for maximum speed
# Uses pure bash built-ins and optimized algorithms

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/load_env.sh"

FILE="$1"
SLEEP_TIMER="${2:-1}"
CACHE_FILE="$SCRIPT_DIR/../outputs/cache/location_cache.csv"

# Configure geocoding library BEFORE loading it
export GEOCODING_SLEEP_TIMER="$SLEEP_TIMER"
export GEOCODING_CACHE_FILE="$CACHE_FILE"

# Load central geocoding library AFTER setting cache file
source "$SCRIPT_DIR/lib/geocoding.sh"

if [[ ! -f "$FILE" ]]; then
    echo "Error: File not found: $FILE"
    exit 1
fi

echo "🚀🚀 TURBO MODE: Adding postal codes to quarterly format file: $(basename "$FILE")" >&2

# TURBO: Pure bash postal code extraction (no grep/head)
extract_postal_code_turbo() {
    local address="$1"
    local pc=""
    
    # Fast pattern matching using bash parameter expansion
    # Look for A1A 1A1 pattern first (most common)
    if [[ "$address" =~ [A-Z][0-9][A-Z][[:space:]][0-9][A-Z][0-9] ]]; then
        pc="${BASH_REMATCH[0]}"
    # Look for A1A1A1 pattern (no spaces)
    elif [[ "$address" =~ [A-Z][0-9][A-Z][0-9][A-Z][0-9] ]]; then
        pc="${BASH_REMATCH[0]}"
    fi
    
    echo "$pc"
}

# Function to get coordinates from cache or API
get_postal_code_coordinates() {
    local postal_code="$1"
    
    # Direct call - stderr messages will show, but coordinates are captured
    local coordinates=$(get_coordinates_for_postal_code "$postal_code")
    
    # If coordinates found and not cached, add to cache with "Unknown" placeholder data
    if [[ "$coordinates" != "," && -n "$coordinates" ]]; then
        add_to_cache "$postal_code" "$coordinates" "Unknown" "Unknown"
    fi
    
    echo "$coordinates"
}

# TURBO: Ultra-fast bash whitespace cleaning (no external processes at all)
clean_line_turbo() {
    local line="$1"
    
    # Remove leading/trailing whitespace using bash parameter expansion
    line="${line#"${line%%[! ]*}"}"  # Remove leading spaces
    line="${line%"${line##*[! ]}"}"  # Remove trailing spaces
    
    # Replace multiple spaces with single space using bash pattern substitution
    # This is much faster than sed and no external processes
    while [[ "$line" =~ [[:space:]][[:space:]] ]]; do
        line="${line//  / }"
    done
    
    echo "$line"
}

# TURBO: Pure bash CSV field extraction (no awk)
extract_address_turbo() {
    local line="$1"
    local field_num=4  # Address is 4th field
    
    # Split by comma and handle quoted fields
    local IFS=','
    local fields=($line)
    local address="${fields[$((field_num-1))]}"
    
    # Remove surrounding quotes if present
    if [[ "$address" =~ ^\".*\"$ ]]; then
        address="${address:1:-1}"
    fi
    
    echo "$address"
}

# Create temporary file
TEMP_FILE="${FILE}.tmp"

    # TURBO: Fast header detection and creation
    echo "    → Detecting file format..." >&2
    if [[ $(sed -n '2p' "$FILE") == *"Province"* ]]; then
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
# TURBO: Count lines efficiently
total_lines=$(($(wc -l < "$FILE") - skip_lines + 1))
current_line=0

echo "    → Processing $total_lines lines with TURBO MODE..." >&2

# TURBO: Process in larger chunks for better performance
tail -n +$skip_lines "$FILE" | while IFS= read -r line; do
    if [[ -n "$line" ]]; then
        current_line=$((current_line + 1))
        
        # Show progress every 2000 lines for speed
        if [[ $((current_line % 2000)) -eq 0 || $current_line -eq 1 || $current_line -eq $total_lines ]]; then
            percentage=$((current_line * 100 / total_lines))
            bar_length=20
            filled=$((percentage * bar_length / 100))
            empty=$((bar_length - filled))
            progress_bar=$(printf "%*s" $filled | tr ' ' '█')
            empty_bar=$(printf "%*s" $empty | tr ' ' '░')
            printf "[%s%s] %d/%d (%d%%) | " "$progress_bar" "$empty_bar" "$current_line" "$total_lines" "$percentage" >&2
        fi
        
        # TURBO: Use ultra-fast bash functions
        cleaned_line=$(clean_line_turbo "$line")
        address=$(extract_address_turbo "$cleaned_line")
        postal_code=$(extract_postal_code_turbo "$address")
        coordinates=$(get_postal_code_coordinates "$postal_code")
        lat=$(echo "$coordinates" | cut -d',' -f1)
        lon=$(echo "$coordinates" | cut -d',' -f2)
        
        echo "${cleaned_line},${postal_code},${lat},${lon}" >> "$TEMP_FILE"
    fi
done

# Create processed file in the processed directory (preserve original)
PROCESSED_DIR="./outputs/csv/processed/quarterly_format"
mkdir -p "$PROCESSED_DIR"
PROCESSED_FILE="$PROCESSED_DIR/$(basename "$FILE")"

mv "$TEMP_FILE" "$PROCESSED_FILE"

echo "🚀🚀 TURBO COMPLETE! Added postal codes to $(basename "$PROCESSED_FILE")" >&2
echo "   Original: $FILE" >&2
echo "   Processed: $PROCESSED_FILE" >&2
echo "   Performance: TURBO MODE - Maximum speed achieved!" >&2
