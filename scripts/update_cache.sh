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
echo "Started at: $(date)"
echo "Configuration:"
echo "  Sleep timer: ${SLEEP_TIMER} seconds"
echo "  Cache file: $LOCATION_CACHE_FILE"
echo "  CSV directory: $CSV_DIR"
echo ""

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Initialize cache if it doesn't exist
if [[ ! -f "$LOCATION_CACHE_FILE" ]]; then
    echo "📄 Creating new cache file..."
    echo "Postal Code;Latitude;Longitude;Sample Address;Sample Employer" > "$LOCATION_CACHE_FILE"
    echo "✓ Created new cache file: $LOCATION_CACHE_FILE"
else
    initial_cache_size=$(tail -n +2 "$LOCATION_CACHE_FILE" | wc -l)
    echo "📄 Using existing cache file"
    echo "   Current cache size: $initial_cache_size postal codes"
    echo "   Last updated: $(stat -c %y "$LOCATION_CACHE_FILE" 2>/dev/null | cut -d'.' -f1 || echo "unknown")"
fi

# Function to extract postal code from address
extract_postal_code() {
    local address="$1"
    # Extract Canadian postal code pattern: A1A 1A1 or A1A1A1
    echo "$address" | grep -o '[A-Z][0-9][A-Z] [0-9][A-Z][0-9]\|[A-Z][0-9][A-Z][0-9][A-Z][0-9]' | head -1 || echo ""
}

# Global counters for statistics
CACHE_HITS=0
API_CALLS=0
FAILED_LOOKUPS=0

# Function to get coordinates for a postal code using OpenStreetMap Nominatim
get_postal_code_coordinates() {
    local postal_code="$1"
    
    if [[ -z "$postal_code" ]]; then
        echo ","
        return
    fi
    
    # Check cache first - postal code is now the first column
    local cached_coords=$(grep "^$postal_code;" "$LOCATION_CACHE_FILE" 2>/dev/null | head -1 | cut -d';' -f2,3 | tr ';' ',')
    
    if [[ -n "$cached_coords" && "$cached_coords" != "," ]]; then
        CACHE_HITS=$((CACHE_HITS + 1))
        echo "  ✓ Cache hit: $postal_code" >&2
        echo "$cached_coords"
        return
    fi
    
    # Not in cache, try multiple geocoding sources
    API_CALLS=$((API_CALLS + 1))
    echo "  → Looking up postal code: $postal_code (API call #$API_CALLS)" >&2
    
    # Try Nominatim first (OpenStreetMap) - 1 second rate limit
    echo "    → Trying Nominatim (OpenStreetMap)..." >&2
    local coordinates=$(curl -s "https://nominatim.openstreetmap.org/search?postalcode=${postal_code}&country=CA&format=json&limit=1" | jq -r '.[0] | "\(.lat),\(.lon)"' 2>/dev/null || echo ",")
    local source="Nominatim"
    
    # If Nominatim failed, try geocoder.ca as fallback
    if [[ "$coordinates" == "null,null" || "$coordinates" == "," ]]; then
        echo "    → Nominatim failed, trying geocoder.ca..." >&2
        sleep 0.5  # geocoder.ca rate limit: max 2 requests/second, so 0.5s between requests
        
        # geocoder.ca API format: http://geocoder.ca/?postal=POSTALCODE&geoit=xml
        local geocoder_response=$(curl -s "http://geocoder.ca/?postal=${postal_code}&geoit=xml" 2>/dev/null || echo "")
        
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
    
    # Check final result
    if [[ "$coordinates" == "null,null" || "$coordinates" == "," || -z "$coordinates" ]]; then
        FAILED_LOOKUPS=$((FAILED_LOOKUPS + 1))
        echo "    ❌ No coordinates found for $postal_code (tried both sources)" >&2
        echo ","
    else
        echo "    ✅ Found coordinates: $coordinates (source: $source)" >&2
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
    if ! grep -q "^$postal_code;" "$LOCATION_CACHE_FILE" 2>/dev/null; then
        echo "$postal_code;$latitude;$longitude;$address;$employer" >> "$LOCATION_CACHE_FILE"
        echo "    ✓ Cached postal code: $postal_code ($latitude,$longitude) [$employer]" >&2
    fi
}

# Main processing function
process_csv_files() {
    local total_files=0
    local processed_files=0
    local new_entries=0
    local cache_hits=0
    local api_calls=0
    local failed_lookups=0
    local postal_codes_found=0
    local lines_processed=0
    local initial_cache_size=$(tail -n +2 "$LOCATION_CACHE_FILE" | wc -l)
    local start_time=$(date +%s)
    
    echo ""
    echo "=== 🔍 Scanning for CSV files to process ==="
    echo "📊 Initial Statistics:"
    echo "   Cache size: $initial_cache_size postal codes"
    echo "   Scan directory: $CSV_DIR"
    
    # Count total files and get breakdown
    total_files=$(find "$CSV_DIR" -name "*.csv" | wc -l)
    employer_files=$(find "$CSV_DIR/employer_format" -name "*.csv" 2>/dev/null | wc -l)
    quarterly_files=$(find "$CSV_DIR/quarterly_format" -name "*.csv" 2>/dev/null | wc -l)
    
    echo ""
    echo "📁 File Discovery:"
    echo "   Total files found: $total_files"
    echo "   Employer format: $employer_files files"
    echo "   Quarterly format: $quarterly_files files"
    echo ""
    
    # Process employer format files
    if [[ -d "$CSV_DIR/employer_format" ]]; then
        echo ""
        echo "🏢 Processing employer format files..."
        
        for file in "$CSV_DIR/employer_format"/*.csv; do
            if [[ -f "$file" ]]; then
                local file_lines=$(wc -l < "$file")
                local file_start_time=$(date +%s)
                echo "  📄 Processing: $(basename "$file") ($file_lines lines)"
                processed_files=$((processed_files + 1))
                lines_processed=$((lines_processed + file_lines))
                
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
        echo "📊 Processing quarterly format files..."
        
        for file in "$CSV_DIR/quarterly_format"/*.csv; do
            if [[ -f "$file" ]]; then
                local file_lines=$(wc -l < "$file")
                local file_start_time=$(date +%s)
                echo "  📄 Processing: $(basename "$file") ($file_lines lines)"
                processed_files=$((processed_files + 1))
                lines_processed=$((lines_processed + file_lines))
                
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
    local new_entries=$((final_cache_size - initial_cache_size))
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    local success_rate=0
    
    if [[ $API_CALLS -gt 0 ]]; then
        success_rate=$(( (API_CALLS - FAILED_LOOKUPS) * 100 / API_CALLS ))
    fi
    
    echo ""
    echo "=== 📈 COMPREHENSIVE CACHE UPDATE SUMMARY ==="
    echo "⏱️  Processing Time:"
    echo "   Total duration: ${total_time}s"
    echo "   Started: $(date -d "@$start_time" '+%Y-%m-%d %H:%M:%S')"
    echo "   Completed: $(date)"
    echo ""
    echo "📁 Files Processed:"
    echo "   Total files: $processed_files of $total_files found"
    echo "   Total lines: $lines_processed"
    echo "   Employer format: $employer_files files"
    echo "   Quarterly format: $quarterly_files files"
    echo ""
    echo "🎯 Cache Performance:"
    echo "   Cache hits: $CACHE_HITS (instant lookups)"
    echo "   API calls: $API_CALLS"
    echo "   Failed lookups: $FAILED_LOOKUPS"
    echo "   Success rate: ${success_rate}%"
    echo ""
    echo "📊 Cache Growth:"
    echo "   Initial entries: $initial_cache_size"
    echo "   Final entries: $final_cache_size"
    echo "   New entries added: $new_entries"
    echo "   Growth rate: $(( new_entries * 100 / (initial_cache_size + 1) ))%"
    echo ""
    echo "⚡ Performance Metrics:"
    if [[ $total_time -gt 0 ]]; then
        echo "   Files per second: $(( processed_files * 60 / total_time ))/min"
        echo "   Lines per second: $(( lines_processed / total_time ))"
        if [[ $API_CALLS -gt 0 ]]; then
            echo "   Avg API response time: $(( total_time / API_CALLS ))s"
        fi
    fi
    echo "   Cache hit ratio: $(( CACHE_HITS * 100 / (CACHE_HITS + API_CALLS + 1) ))%"
    echo ""
    echo "💾 Output:"
    echo "   Cache file: $LOCATION_CACHE_FILE"
    echo "   File size: $(du -h "$LOCATION_CACHE_FILE" 2>/dev/null | cut -f1 || echo "unknown")"
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
