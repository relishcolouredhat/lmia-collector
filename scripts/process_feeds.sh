#!/bin/bash

# LMIA Data Collection Script
# This script fetches and processes LMIA data from Open Canada

set -e  # Exit on any error

# Configuration
POSITIVE_FEED_URL="https://open.canada.ca/data/api/action/package_show?id=90fed587-1364-4f33-a9ee-208181dc0b97"
NEGATIVE_FEED_URL="https://open.canada.ca/data/api/action/package_show?id=f82f66f2-a22b-4511-bccf-e1d74db39ae5"

DATA_DIR="." # Base directory where outputs will be stored
FEEDS=("$POSITIVE_FEED_URL" "$NEGATIVE_FEED_URL")

LANGUAGE="${LANGUAGE:-en}"

OUTPUTS_DIR="${DATA_DIR}/outputs"
CSV_DIR="${OUTPUTS_DIR}/csv"
IFLP_DIR="${OUTPUTS_DIR}/iflp"

# Separate directories for different file formats
POSITIVE_CSV_DIR="${CSV_DIR}/positive"
NEGATIVE_CSV_DIR="${CSV_DIR}/negative"
POSITIVE_IFLP_DIR="${IFLP_DIR}/positive"
NEGATIVE_IFLP_DIR="${IFLP_DIR}/negative"

# New directories for different formats
EMPLOYER_FORMAT_DIR="${CSV_DIR}/employer_format"
QUARTERLY_FORMAT_DIR="${CSV_DIR}/quarterly_format"

mkdir -p "$POSITIVE_CSV_DIR" "$NEGATIVE_CSV_DIR" "$POSITIVE_IFLP_DIR" "$NEGATIVE_IFLP_DIR"
mkdir -p "$EMPLOYER_FORMAT_DIR" "$QUARTERLY_FORMAT_DIR"

echo "Starting check for new LMIA reports (Language: ${LANGUAGE})..."

new_files_found=false
new_file_names=""

# Function to extract postal code from address
extract_postal_code() {
    local address="$1"
    # Extract Canadian postal code pattern: A1A 1A1 or A1A1A1
    echo "$address" | grep -o '[A-Z][0-9][A-Z] [0-9][A-Z][0-9]\|[A-Z][0-9][A-Z][0-9][A-Z][0-9]' | head -1 || echo ""
}

# Location cache file
LOCATION_CACHE_FILE="./outputs/cache/location_cache.csv"

# Initialize location cache if it doesn't exist
initialize_location_cache() {
    # Ensure cache directory exists
    mkdir -p "$(dirname "$LOCATION_CACHE_FILE")"
    
    if [[ ! -f "$LOCATION_CACHE_FILE" ]]; then
        echo "Employer,Address,Postal Code,Latitude,Longitude" > "$LOCATION_CACHE_FILE"
        echo "  -> Created location cache file: $LOCATION_CACHE_FILE"
    fi
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
    fi
}

# Function to get lat/lon coordinates from postal code (with caching)
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
    
    # Not in cache, query Nominatim API
    local coordinates=$(curl -s "https://nominatim.openstreetmap.org/search?postalcode=${postal_code}&country=CA&format=json&limit=1" | jq -r '.[0] | "\(.lat),\(.lon)"' 2>/dev/null || echo ",")
    
    if [[ "$coordinates" == "null,null" || "$coordinates" == "," ]]; then
        echo ","
    else
        echo "$coordinates"
    fi
    
    # Rate limiting - sleep 1 second between requests
    sleep 1
}

# Function to determine file format and process accordingly
process_file_by_format() {
    local temp_file="$1"
    local target_file="$2"
    local original_filename="$3"
    local publish_date="$4"
    local file_url="$5"
    
    # Check format - quarterly format first (more specific pattern)
    if grep -q "Province.*Territory.*Stream.*Employer" "$temp_file"; then
        echo "  -> Detected quarterly format file"
        local output_dir="$QUARTERLY_FORMAT_DIR"
        local format_type="quarterly"
    elif grep -q "Employer.*Address.*Positions" "$temp_file"; then
        echo "  -> Detected employer format file"
        local output_dir="$EMPLOYER_FORMAT_DIR"
        local format_type="employer"
    else
        echo "  -> Detected quarterly format file (default)"
        local output_dir="$QUARTERLY_FORMAT_DIR"
        local format_type="quarterly"
    fi
    
    # Create the appropriate output directory
    mkdir -p "$output_dir"
    
    # Extract clean filename from URL
    local url_filename=$(basename "$file_url" | sed 's/\.csv$//' | sed 's/\.xlsx$//')
    local new_target_file="${output_dir}/${publish_date}_${url_filename}.csv"

    
    # Check if file already exists
    if [[ -f "$new_target_file" ]]; then
        echo "  -> Skipping $original_filename (already exists)"
        return 1
    fi
    
    # Determine file type from URL (since original_filename might not have extension)
    if [[ "$temp_file" == *.xlsx ]] || [[ "$original_filename" == *".xlsx" ]]; then
        if command -v in2csv >/dev/null 2>&1; then
            in2csv "$temp_file" | sed '/^Remarques:/,$d' | sed '/^Notes:/,$d' > "$new_target_file"
        else
            # Fallback: copy as-is if in2csv not available
            cp "$temp_file" "$new_target_file"
        fi
    else
        # Assume CSV format
        # Find the header line and process from there
        if [[ "$format_type" == "employer" ]]; then
            # For employer format, find line with "Employer" and process from there
            awk '/Employer.*Address.*Positions/{p=1} p' "$temp_file" | sed '/^Remarques:/,$d' | sed '/^Notes:/,$d' > "$new_target_file"
        else
            # For quarterly format, find line with appropriate headers and process from there
            awk '/Province.*Territory.*Stream.*Employer/{p=1} p' "$temp_file" | sed '/^Remarques:/,$d' | sed '/^Notes:/,$d' > "$new_target_file"
        fi
    fi
    
    # Add postal code column based on format (with caching enabled)
    if [[ "$format_type" == "employer" ]]; then
        echo "  -> Adding postal codes and coordinates (employer format)..."
        add_postal_code_column_employer "$new_target_file"
    else
        echo "  -> Adding postal codes and coordinates (quarterly format)..."
        add_postal_code_column_quarterly "$new_target_file"
    fi
    
    echo "     ✅ Saved as $new_target_file (${format_type} format)"
    return 0
}

# Function to add postal code and coordinates columns for employer format files
add_postal_code_column_employer() {
    local file="$1"
    local temp_file="${file}.tmp"
    
    # Create header with postal code and coordinates columns
    head -1 "$file" | sed 's/Positions/Positions,Postal Code,Latitude,Longitude/' > "$temp_file"
    
    # Process each line to extract postal code and coordinates from address
    tail -n +2 "$file" | while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Extract employer (1st field), address (3rd field) and get postal code
            local employer=$(echo "$line" | cut -d',' -f1)
            local address=$(echo "$line" | cut -d',' -f3)
            local postal_code=$(extract_postal_code "$address")
            local coordinates=$(get_postal_code_coordinates "$postal_code")
            local lat=$(echo "$coordinates" | cut -d',' -f1)
            local lon=$(echo "$coordinates" | cut -d',' -f2)
            
            # Cache the location data if we have valid coordinates
            if [[ -n "$lat" && -n "$lon" && "$lat" != "" && "$lon" != "" ]]; then
                cache_employer_location "$employer" "$address" "$postal_code" "$lat" "$lon"
            fi
            
            echo "${line},${postal_code},${lat},${lon}" >> "$temp_file"
        fi
    done
    
    mv "$temp_file" "$file"
}

# Function to add postal code and coordinates columns for quarterly format files
add_postal_code_column_quarterly() {
    local file="$1"
    local temp_file="${file}.tmp"
    
    # Create header with postal code and coordinates columns
    head -1 "$file" | sed 's/Positions Approved/Positions Approved,Postal Code,Latitude,Longitude/' > "$temp_file"
    
    # Process each line to extract postal code and coordinates from address
    tail -n +2 "$file" | while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Extract employer (3rd field), address (4th field) and get postal code
            local employer=$(echo "$line" | cut -d',' -f3)
            local address=$(echo "$line" | cut -d',' -f4)
            local postal_code=$(extract_postal_code "$address")
            local coordinates=$(get_postal_code_coordinates "$postal_code")
            local lat=$(echo "$coordinates" | cut -d',' -f1)
            local lon=$(echo "$coordinates" | cut -d',' -f2)
            
            # Cache the location data if we have valid coordinates
            if [[ -n "$lat" && -n "$lon" && "$lat" != "" && "$lon" != "" ]]; then
                cache_employer_location "$employer" "$address" "$postal_code" "$lat" "$lon"
            fi
            
            echo "${line},${postal_code},${lat},${lon}" >> "$temp_file"
        fi
    done
    
    mv "$temp_file" "$file"
}

# Initialize location cache
initialize_location_cache

# Process each feed
for feed_url in "${FEEDS[@]}"; do
    echo "Checking feed: $feed_url"
    
    # Determine feed type based on URL
    if [[ "$feed_url" == *"90fed587-1364-4f33-a9ee-208181dc0b97"* ]]; then
        feed_type="positive"
    else
        feed_type="negative"
    fi
    
    echo "              
  -> Processing $feed_type feed..."
    
    # Fetch the feed data
    response=$(curl -s "$feed_url")
    
    if [[ $? -ne 0 ]]; then
        echo "  ❌ Failed to fetch feed: $feed_url"
        continue
    fi
    
    # Extract file information
    files=$(echo "$response" | jq -r '.result.resources[] | select(.format == "CSV" or .format == "XLSX") | "\(.name)|\(.url)|\(.created)|\(.language)"' 2>/dev/null || echo "")
    
    if [[ -z "$files" ]]; then
        echo "  ⚠️  No CSV/XLSX files found in feed"
        continue
    fi
    
    # Process each file
    while IFS='|' read -r filename url created language; do
        if [[ -z "$filename" || -z "$url" ]]; then
            continue
        fi
        
        # Check language filter from JSON metadata
        if [[ "$language" != *"\"${LANGUAGE}\""* ]]; then
            echo "  -> Skipping $filename (language mismatch, expected: ${LANGUAGE}, got: $language)"
            continue
        fi
        
        # Extract publish date from created timestamp
        publish_date=$(echo "$created" | cut -d'T' -f1)
        
        # Create target filename (will be overridden by process_file_by_format)
        target_filename="temp_${publish_date}_${filename%.*}.csv"
        
        echo "  -> Found new $feed_type file: $filename (Published: $publish_date)"
        echo "     Processing..."
        
        # Download and process the file
        temp_download=$(mktemp)
        if curl -s -L "$url" -o "$temp_download"; then
                    # Process file based on its format
        if process_file_by_format "$temp_download" "$target_filename" "$filename" "$publish_date" "$url"; then
                new_files_found=true
                new_file_names="$new_file_names $target_filename"
            fi
        else
            echo "     ❌ Failed to download $filename"
        fi
        
        # Clean up temporary file
        rm -f "$temp_download"
        
    done <<< "$files"
done

# Generate Grafana Infinity plugin endpoint files
echo "Generating Grafana Infinity plugin endpoint files..."

# Function to generate endpoint JSON for a specific directory
generate_endpoint_json() {
    local dir="$1"
    local endpoint_file="$2"
    local base_url="https://raw.githubusercontent.com/relishcolouredhat/lmia-collector/main"

    echo "  -> Generating endpoint file: $endpoint_file"

    cat > "$endpoint_file" << EOF
{
  "endpoints": [
EOF

    local first=true
    while IFS= read -r -d '' csv_file; do
        if [ "$first" = true ]; then
            first=false
        else
            echo "    ," >> "$endpoint_file"
        fi

        local relative_path="${csv_file#./outputs/}"
        local url="${base_url}/${relative_path}"
        local filename=$(basename "$csv_file")

        cat >> "$endpoint_file" << EOF
    {
      "name": "${filename%.csv}",
      "url": "${url}",
      "type": "csv",
      "format": "table"
    }
EOF
    done < <(find "$dir" -name "*.csv" -type f -print0 | sort -z)

    cat >> "$endpoint_file" << EOF
  ]
}
EOF
    echo "     ✅ Generated $endpoint_file with $(find "$dir" -name "*.csv" -type f | wc -l) endpoints"
}

# Generate endpoints for each format directory
generate_endpoint_json "$EMPLOYER_FORMAT_DIR" "${OUTPUTS_DIR}/employer_format_endpoints.json"
generate_endpoint_json "$QUARTERLY_FORMAT_DIR" "${OUTPUTS_DIR}/quarterly_format_endpoints.json"

# Combined endpoints file
cat > "${OUTPUTS_DIR}/all_endpoints.json" << EOF
{
  "employer_format_endpoints": "${OUTPUTS_DIR}/employer_format_endpoints.json",
  "quarterly_format_endpoints": "${OUTPUTS_DIR}/quarterly_format_endpoints.json",
  "base_url": "https://raw.githubusercontent.com/relishcolouredhat/lmia-collector/main/outputs"
}
EOF

echo "     ✅ Generated combined endpoints file"

if [[ "$new_files_found" == true ]]; then
    echo "Finished processing. New files were added."
    if [[ -n "$GITHUB_OUTPUT" ]]; then
        echo "new_files_found=true" >> "$GITHUB_OUTPUT"
        echo "new_file_names=$new_file_names" >> "$GITHUB_OUTPUT"
    fi
else
    echo "Finished processing. No new files were found."
    if [[ -n "$GITHUB_OUTPUT" ]]; then
        echo "new_files_found=false" >> "$GITHUB_OUTPUT"
        echo "new_file_names=" >> "$GITHUB_OUTPUT"
    fi
fi