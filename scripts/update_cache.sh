#!/bin/bash

# Location Cache Update Script
# Updates postal code cache from existing CSV files

set -e

# Configuration
CACHE_DIR="./outputs/cache"
LOCATION_CACHE_FILE="$CACHE_DIR/location_cache.csv"
CSV_DIR="./outputs/csv"
SLEEP_TIMER="${SLEEP_TIMER:-1}"  # Default 1 second, configurable via environment

echo "=== LMIA Location Cache Update ==="
echo "Sleep timer between API calls: ${SLEEP_TIMER} seconds"
echo "Cache file: $LOCATION_CACHE_FILE"

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Initialize cache if it doesn't exist
if [[ ! -f "$LOCATION_CACHE_FILE" ]]; then
    echo "Employer,Address,Postal Code,Latitude,Longitude" > "$LOCATION_CACHE_FILE"
    echo "✓ Created new cache file"
else
    echo "✓ Using existing cache file"
fi

# Function to extract postal code from address
extract_postal_code() {
    local address="$1"
    # Extract Canadian postal code pattern: A1A 1A1 or A1A1A1
    echo "$address" | grep -o '[A-Z][0-9][A-Z] [0-9][A-Z][0-9]\|[A-Z][0-9][A-Z][0-9][A-Z][0-9]' | head -1 || echo ""
}

# Function to get coordinates for a postal code using OpenStreetMap Nominatim
get_postal_code_coordinates() {
    local postal_code="$1"
    
    if [[ -z "$postal_code" ]]; then
        echo ","
        return
    fi
    
    # Check cache first
    local cached_coords=$(grep ",$postal_code," "$LOCATION_CACHE_FILE" 2>/dev/null | head -1 | cut -d',' -f4,5)
    
    if [[ -n "$cached_coords" && "$cached_coords" != "," ]]; then
        echo "$cached_coords"
        return
    fi
    
    echo "  → Looking up postal code: $postal_code"
    
    # Query Nominatim API for Canadian postal codes
    local coordinates=$(curl -s "https://nominatim.openstreetmap.org/search?postalcode=${postal_code}&country=CA&format=json&limit=1" | jq -r '.[0] | "\(.lat),\(.lon)"' 2>/dev/null || echo ",")
    
    if [[ "$coordinates" == "null,null" || "$coordinates" == "," ]]; then
        echo ","
    else
        echo "$coordinates"
    fi
    
    # Rate limiting
    sleep "$SLEEP_TIMER"
}

# Function to cache employer location data
cache_employer_location() {
    local employer="$1"
    local address="$2"
    local postal_code="$3"
    local latitude="$4"
    local longitude="$5"
    
    # Skip if essential data is missing
    if [[ -z "$employer" || -z "$postal_code" ]]; then
        return
    fi
    
    # Clean fields for CSV (escape quotes, remove commas from within fields)
    employer=$(echo "$employer" | sed 's/"/""/g' | sed 's/,/;/g')
    address=$(echo "$address" | sed 's/"/""/g' | sed 's/,/;/g')
    
    # Check if this employer+postal code combination already exists
    local cache_key="${employer}.*${postal_code}"
    if ! grep -q "$cache_key" "$LOCATION_CACHE_FILE" 2>/dev/null; then
        echo "\"$employer\",\"$address\",$postal_code,$latitude,$longitude" >> "$LOCATION_CACHE_FILE"
        echo "    ✓ Cached: $employer ($postal_code)"
    fi
}

# Main processing function
process_csv_files() {
    local total_files=0
    local processed_files=0
    local new_entries=0
    local initial_cache_size=$(tail -n +2 "$LOCATION_CACHE_FILE" | wc -l)
    
    echo ""
    echo "=== Scanning for CSV files to process ==="
    
    # Count total files
    total_files=$(find "$CSV_DIR" -name "*.csv" | wc -l)
    echo "Found $total_files CSV files to scan"
    
    # Process employer format files
    if [[ -d "$CSV_DIR/employer_format" ]]; then
        echo ""
        echo "Processing employer format files..."
        
        for file in "$CSV_DIR/employer_format"/*.csv; do
            if [[ -f "$file" ]]; then
                echo "  Processing: $(basename "$file")"
                processed_files=$((processed_files + 1))
                
                # Process each line (skip header)
                tail -n +2 "$file" | while IFS=',' read -r employer address positions postal_code lat lon rest; do
                    if [[ -n "$employer" && -n "$address" && -z "$postal_code" ]]; then
                        # File doesn't have postal codes yet, extract and look up
                        local pc=$(extract_postal_code "$address")
                        if [[ -n "$pc" ]]; then
                            local coords=$(get_postal_code_coordinates "$pc")
                            local latitude=$(echo "$coords" | cut -d',' -f1)
                            local longitude=$(echo "$coords" | cut -d',' -f2)
                            
                            if [[ -n "$latitude" && -n "$longitude" && "$latitude" != "" && "$longitude" != "" ]]; then
                                cache_employer_location "$employer" "$address" "$pc" "$latitude" "$longitude"
                            fi
                        fi
                    elif [[ -n "$employer" && -n "$address" && -n "$postal_code" && -n "$lat" && -n "$lon" ]]; then
                        # File already has coordinates, just cache them
                        cache_employer_location "$employer" "$address" "$postal_code" "$lat" "$lon"
                    fi
                done
            fi
        done
    fi
    
    # Process quarterly format files
    if [[ -d "$CSV_DIR/quarterly_format" ]]; then
        echo ""
        echo "Processing quarterly format files..."
        
        for file in "$CSV_DIR/quarterly_format"/*.csv; do
            if [[ -f "$file" ]]; then
                echo "  Processing: $(basename "$file")"
                processed_files=$((processed_files + 1))
                
                # Process each line (skip header)
                tail -n +2 "$file" | while IFS=',' read -r period stream employer address positions postal_code lat lon rest; do
                    if [[ -n "$employer" && -n "$address" && -z "$postal_code" ]]; then
                        # File doesn't have postal codes yet, extract and look up
                        local pc=$(extract_postal_code "$address")
                        if [[ -n "$pc" ]]; then
                            local coords=$(get_postal_code_coordinates "$pc")
                            local latitude=$(echo "$coords" | cut -d',' -f1)
                            local longitude=$(echo "$coords" | cut -d',' -f2)
                            
                            if [[ -n "$latitude" && -n "$longitude" && "$latitude" != "" && "$longitude" != "" ]]; then
                                cache_employer_location "$employer" "$address" "$pc" "$latitude" "$longitude"
                            fi
                        fi
                    elif [[ -n "$employer" && -n "$address" && -n "$postal_code" && -n "$lat" && -n "$lon" ]]; then
                        # File already has coordinates, just cache them
                        cache_employer_location "$employer" "$address" "$postal_code" "$lat" "$lon"
                    fi
                done
            fi
        done
    fi
    
    local final_cache_size=$(tail -n +2 "$LOCATION_CACHE_FILE" | wc -l)
    new_entries=$((final_cache_size - initial_cache_size))
    
    echo ""
    echo "=== Cache Update Summary ==="
    echo "Files processed: $processed_files"
    echo "Initial cache entries: $initial_cache_size"
    echo "Final cache entries: $final_cache_size"
    echo "New entries added: $new_entries"
    echo "Cache file: $LOCATION_CACHE_FILE"
}

# Run the processing
process_csv_files

echo ""
echo "✅ Cache update complete!"
