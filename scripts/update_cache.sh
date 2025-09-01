#!/bin/bash

# Location Cache Update Script
# Updates postal code cache from existing CSV files

set -e

# Configuration
CACHE_DIR="./outputs/cache"
LOCATION_CACHE_FILE="$CACHE_DIR/location_cache.csv"
CSV_DIR="./outputs/csv/unprocessed"
SLEEP_TIMER="${SLEEP_TIMER:-1}"  # Default 1 second, configurable via environment

echo "=== LMIA Location Cache Update ==="
echo "Sleep timer between API calls: ${SLEEP_TIMER} seconds"
echo "Cache file: $LOCATION_CACHE_FILE"

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Initialize cache if it doesn't exist
if [[ ! -f "$LOCATION_CACHE_FILE" ]]; then
    echo "Postal Code,Latitude,Longitude,Sample Address,Sample Employer" > "$LOCATION_CACHE_FILE"
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
    
    # Check cache first - postal code is now the first column
    local cached_coords=$(grep "^$postal_code," "$LOCATION_CACHE_FILE" 2>/dev/null | head -1 | cut -d',' -f2,3)
    
    if [[ -n "$cached_coords" && "$cached_coords" != "," ]]; then
        echo "$cached_coords"
        return
    fi
    
    echo "  → Looking up postal code: $postal_code" >&2
    
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

# Function to parse CSV line with proper handling of quoted fields
parse_csv_line() {
    local line="$1"
    local field_num="$2"
    
    # Clean the line of problematic characters first
    local cleaned_line=$(echo "$line" | iconv -f utf-8 -t utf-8//IGNORE 2>/dev/null || echo "$line" | tr -d '\200-\377')
    
    # Simple but effective CSV parsing for our specific format
    if [[ $field_num -eq 1 ]]; then
        # Extract first field (employer) - everything before first comma outside quotes
        echo "$cleaned_line" | sed 's/^\([^"]*\),.*$/\1/' | sed 's/^"//' | sed 's/"$//' | sed 's/[[:space:]]*$//'
    elif [[ $field_num -eq 2 ]]; then
        # Extract second field (address) - quoted field between first and last comma
        echo "$cleaned_line" | sed 's/^[^,]*,"\([^"]*\)".*$/\1/' | sed 's/[[:space:]]*$//'
    elif [[ $field_num -eq 3 ]]; then
        # Extract employer for quarterly format (third field)
        echo "$cleaned_line" | sed 's/^[^,]*,[^,]*,\([^,]*\),.*$/\1/' | sed 's/^"//' | sed 's/"$//' | sed 's/[[:space:]]*$//'
    elif [[ $field_num -eq 4 ]]; then
        # Extract address for quarterly format (fourth field) 
        echo "$cleaned_line" | sed 's/^[^,]*,[^,]*,[^,]*,"\([^"]*\)".*$/\1/' | sed 's/[[:space:]]*$//'
    else
        echo ""
    fi
}

# Function to cache postal code location data (one entry per postal code)
cache_postal_code_location() {
    local address="$1"
    local postal_code="$2"
    local latitude="$3"
    local longitude="$4"
    local employer="$5"
    
    # Skip if essential data is missing
    if [[ -z "$postal_code" || -z "$latitude" || -z "$longitude" ]]; then
        return
    fi
    
    # Clean fields for CSV (normalize whitespace, escape problematic characters)
    address=$(echo "$address" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | sed 's/^ *//;s/ *$//' | sed 's/"/""/g')
    employer=$(echo "$employer" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | sed 's/^ *//;s/ *$//' | sed 's/"/""/g')
    
    # Check if this postal code already exists in cache
    if ! grep -q "^$postal_code," "$LOCATION_CACHE_FILE" 2>/dev/null; then
        echo "$postal_code,$latitude,$longitude,\"$address\",\"$employer\"" >> "$LOCATION_CACHE_FILE"
        echo "    ✓ Cached postal code: $postal_code ($latitude,$longitude) [$employer]" >&2
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
                
                # Process each line (skip header) - handle proper CSV parsing
                tail -n +2 "$file" | while IFS= read -r line; do
                    if [[ -n "$line" && "$line" != *"test "* ]]; then
                        # Parse employer format CSV line (Employer,Address,Positions)
                        local employer=$(parse_csv_line "$line" 1)
                        local address=$(parse_csv_line "$line" 2)
                        
                        # Skip empty or invalid entries
                        if [[ -n "$employer" && -n "$address" && "$employer" != "" ]]; then
                            # Extract postal code from address
                            local pc=$(extract_postal_code "$address")
                            if [[ -n "$pc" ]]; then
                                local coords=$(get_postal_code_coordinates "$pc")
                                local latitude=$(echo "$coords" | cut -d',' -f1)
                                local longitude=$(echo "$coords" | cut -d',' -f2)
                                
                                if [[ -n "$latitude" && -n "$longitude" && "$latitude" != "" && "$longitude" != "" ]]; then
                                    cache_postal_code_location "$address" "$pc" "$latitude" "$longitude" "$employer"
                                fi
                            fi
                        fi
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
                
                # Detect file format and skip appropriate number of lines
                # Check if second line is a proper header (contains "Province" or "Territory")
                second_line=$(sed -n '2p' "$file")
                if [[ "$second_line" == *"Province"* || "$second_line" == *"Territory"* ]]; then
                    # Excel-converted format: has title row + header, skip 2 lines
                    echo "    → Detected Excel format (title + header), skipping 2 lines"
                    skip_lines=3
                else
                    # Direct CSV format: header only, skip 1 line  
                    echo "    → Detected CSV format (header only), skipping 1 line"
                    skip_lines=2
                fi
                
                # Process each line after skipping the appropriate number of header lines
                tail -n +$skip_lines "$file" | while IFS= read -r line; do
                    if [[ -n "$line" ]]; then
                        # Parse quarterly CSV line (Period,Stream,Employer,Address,Positions)
                        local employer=$(parse_csv_line "$line" 3)
                        local address=$(parse_csv_line "$line" 4)
                        
                        # Skip empty or invalid entries
                        if [[ -n "$employer" && -n "$address" && "$employer" != "" ]]; then
                            # Extract postal code from address
                            local pc=$(extract_postal_code "$address")
                            if [[ -n "$pc" ]]; then
                                local coords=$(get_postal_code_coordinates "$pc")
                                local latitude=$(echo "$coords" | cut -d',' -f1)
                                local longitude=$(echo "$coords" | cut -d',' -f2)
                                
                                if [[ -n "$latitude" && -n "$longitude" && "$latitude" != "" && "$longitude" != "" ]]; then
                                    cache_postal_code_location "$address" "$pc" "$latitude" "$longitude" "$employer"
                                fi
                            fi
                        fi
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

# Generate cache statistics for web interface
echo ""
echo "=== Generating Cache Statistics ==="
if [[ -f "./scripts/generate_cache_stats.sh" ]]; then
    ./scripts/generate_cache_stats.sh
else
    echo "⚠️ Cache statistics generator not found"
fi
