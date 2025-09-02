#!/bin/bash

# Location Cache Update Script
# Updates postal code cache from existing CSV files

set -e

# Load environment variables (API keys, etc.)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/load_env.sh"

# Load central geocoding library
source "$SCRIPT_DIR/lib/geocoding.sh"

# Configuration
CACHE_DIR="./outputs/cache"
LOCATION_CACHE_FILE="$CACHE_DIR/location_cache.csv"
CSV_DIR="./outputs/csv/unprocessed"
# Turbo mode uses faster defaults
if [[ "$GEOCODING_TURBO_MODE" == "true" ]]; then
    SLEEP_TIMER="${SLEEP_TIMER:-0.1}"  # Much faster for turbo mode  
else
    SLEEP_TIMER="${SLEEP_TIMER:-1}"    # Conservative for standard mode
fi

# Configure geocoding library
export GEOCODING_SLEEP_TIMER="$SLEEP_TIMER"
export GEOCODING_CACHE_FILE="$LOCATION_CACHE_FILE"

echo "=== LMIA Location Cache Update ==="
echo "Started at: $(date)"
echo "Configuration:"
echo "  Sleep timer: ${SLEEP_TIMER} seconds"
echo "  Cache file: $LOCATION_CACHE_FILE"
echo "  CSV directory: $CSV_DIR"
echo ""

# Initialize geocoding cache
initialize_geocoding_cache

initial_cache_size=$(tail -n +2 "$LOCATION_CACHE_FILE" | wc -l)
if [[ $initial_cache_size -gt 0 ]]; then
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

# Wrapper function for backward compatibility - delegates to central geocoding library
get_postal_code_coordinates() {
    get_coordinates_for_postal_code "$1"
}

# Function to parse CSV line with proper handling of quoted fields
parse_csv_line() {
    local line="$1"
    local format="$2"  # "employer" or "quarterly"
    
    # Clean encoding issues
    local cleaned_line=$(echo "$line" | iconv -f iso-8859-1 -t utf-8//IGNORE 2>/dev/null || echo "$line")
    
    if [[ "$format" == "quarterly" ]]; then
        # Quarterly format: Province,Stream,Employer,Address,Occupation,Status,LMIAs,Positions
        echo "$cleaned_line" | awk '
        BEGIN { FPAT = "([^,]+)|(\"[^\"]*\")" }
        {
            # Extract fields 3 and 4 (employer and address)
            gsub(/^[ \t]*"?|"?[ \t]*$/, "", $3)  # Clean field 3
            gsub(/^[ \t]*"?|"?[ \t]*$/, "", $4)  # Clean field 4
            print "emp=" $3 " addr=" $4
        }'
    else
        # Employer format: Province,Employer,Address,Occupation,Positions
        # FPAT skips empty first field, so employer=field1, address=field2
        echo "$cleaned_line" | awk '
        BEGIN { FPAT = "([^,]+)|(\"[^\"]*\")" }
        {
            # Extract fields 1 and 2 (employer and address)
            gsub(/^[ \t]*"?|"?[ \t]*$/, "", $1)  # Clean field 1
            gsub(/^[ \t]*"?|"?[ \t]*$/, "", $2)  # Clean field 2
            print "emp=" $1 " addr=" $2
        }'
    fi
}

# Wrapper function for backward compatibility - delegates to central geocoding library
cache_postal_code_location() {
    local address="$1"
    local postal_code="$2"
    local latitude="$3"
    local longitude="$4"
    local employer="$5"
    
    add_to_cache "$postal_code" "$latitude,$longitude" "$address" "$employer"
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
    echo "   Turbo mode: ${GEOCODING_TURBO_MODE:-false}"
    
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
        
        for file in $(find "$CSV_DIR/employer_format" -name "*.csv" | sort -r); do
            if [[ -f "$file" ]]; then
                local file_lines=$(wc -l < "$file")
                local file_start_time=$(date +%s)
                echo "  📄 Processing: $(basename "$file") ($file_lines lines)"
                processed_files=$((processed_files + 1))
                lines_processed=$((lines_processed + file_lines))
                
                # Process each line (skip header) - handle proper CSV parsing
                local line_count=0
                tail -n +2 "$file" | while IFS= read -r line; do
                    line_count=$((line_count + 1))
                    if (( line_count % 100 == 0 )); then
                        echo "    📊 Processed $line_count lines from $(basename "$file")"
                    fi
                    if [[ -n "$line" && "$line" != *"test "* ]]; then
                        # DEBUG: Show raw line every 500 lines
                        if (( line_count % 500 == 0 )); then
                            echo "    🔍 RAW LINE $line_count: ${line:0:100}..."
                        fi
                        
                        # Parse employer format CSV line (Employer,Address,Positions)
                        local parse_result=$(parse_csv_line "$line" "employer")
                        local employer=$(echo "$parse_result" | sed -n 's/emp=\(.*\) addr=.*/\1/p')
                        local address=$(echo "$parse_result" | sed -n 's/emp=.* addr=\(.*\)/\1/p')
                        
                        # DEBUG: Log parsing results every 1000 lines
                        if (( line_count % 1000 == 0 )); then
                            echo "    🔍 Line $line_count: emp='$employer' addr='$address'"
                        fi
                        
                        # Skip empty or invalid entries
                        if [[ -n "$employer" && -n "$address" && "$employer" != "" ]]; then
                            # Extract postal code from address
                            local pc=$(extract_postal_code "$address")
                            if [[ -n "$pc" ]]; then
                                echo "    📮 Extracted postal code: $pc from: ${address:0:50}..."
                                # Skip geocoding if already cached - MAJOR PERFORMANCE OPTIMIZATION
                                local normalized_pc=$(echo "$pc" | tr -d ' ')
                                if [[ -f "$GEOCODING_CACHE_FILE" ]] && grep -q "^$normalized_pc;" "$GEOCODING_CACHE_FILE" 2>/dev/null; then
                                    # Already cached - skip geocoding processing entirely
                                    echo "    🟢 Skipped cached: $pc"
                                    continue
                                fi
                                
                                echo "    🔍 Processing new: $pc"
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
        
        for file in $(find "$CSV_DIR/quarterly_format" -name "*.csv" | sort -r); do
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
                        local parse_result=$(parse_csv_line "$line" "quarterly")
                        local employer=$(echo "$parse_result" | sed -n 's/emp=\(.*\) addr=.*/\1/p')
                        local address=$(echo "$parse_result" | sed -n 's/emp=.* addr=\(.*\)/\1/p')
                        
                        # Skip empty or invalid entries
                        if [[ -n "$employer" && -n "$address" && "$employer" != "" ]]; then
                            # Extract postal code from address
                            local pc=$(extract_postal_code "$address")
                            if [[ -n "$pc" ]]; then
                                echo "    📮 Extracted postal code: $pc from: ${address:0:50}..."
                                # Skip geocoding if already cached - MAJOR PERFORMANCE OPTIMIZATION
                                local normalized_pc=$(echo "$pc" | tr -d ' ')
                                if [[ -f "$GEOCODING_CACHE_FILE" ]] && grep -q "^$normalized_pc;" "$GEOCODING_CACHE_FILE" 2>/dev/null; then
                                    # Already cached - skip geocoding processing entirely
                                    echo "    🟢 Skipped cached: $pc"
                                    continue
                                fi
                                
                                echo "    🔍 Processing new: $pc"
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
