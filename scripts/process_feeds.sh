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
EMPLOYER_FORMAT_DIR="${CSV_DIR}/unprocessed/employer_format"
QUARTERLY_FORMAT_DIR="${CSV_DIR}/unprocessed/quarterly_format"

mkdir -p "$POSITIVE_CSV_DIR" "$NEGATIVE_CSV_DIR" "$POSITIVE_IFLP_DIR" "$NEGATIVE_IFLP_DIR"
mkdir -p "$EMPLOYER_FORMAT_DIR" "$QUARTERLY_FORMAT_DIR"

echo "Starting check for new LMIA reports (Language: ${LANGUAGE})..."

new_files_found=false
new_file_names=""

# Note: Postal code geocoding has been moved to separate update_cache.sh script

# Note: Location cache functionality moved to update_cache.sh

# Note: Cache functions moved to update_cache.sh

# Note: Geocoding functions moved to update_cache.sh

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
    
    # Determine file type from URL (since temp_file won't have extension and original_filename might not have extension)
    if [[ "$file_url" == *.xlsx ]] || [[ "$original_filename" == *".xlsx" ]]; then
        if command -v in2csv >/dev/null 2>&1; then
            echo "  -> Converting Excel file with in2csv..." >&2
            # Convert Excel to CSV with error handling (specify format explicitly)
            if in2csv --format xlsx "$temp_file" | tail -n +2 | sed '/^Remarques:/,$d' | sed '/^Notes:/,$d' > "$new_target_file" 2>&1; then
                # Check if conversion was successful (file has content)
                if [[ -s "$new_target_file" ]]; then
                    echo "  -> ✅ Excel conversion successful: $(wc -l < "$new_target_file") lines" >&2
                else
                    echo "  -> ❌ Excel conversion failed: empty output file" >&2
                    echo "  -> 🔧 Attempting direct conversion without sed filters..." >&2
                    # Try without sed filters as fallback
                    if in2csv --format xlsx "$temp_file" | tail -n +2 > "$new_target_file" 2>&1 && [[ -s "$new_target_file" ]]; then
                        echo "  -> ✅ Direct conversion successful: $(wc -l < "$new_target_file") lines" >&2
                    else
                        echo "  -> ❌ All Excel conversion attempts failed" >&2
                        rm -f "$new_target_file"
                        return 1
                    fi
                fi
            else
                echo "  -> ❌ in2csv command failed" >&2
                return 1
            fi
        else
            # Fallback: copy as-is if in2csv not available
            echo "  -> ⚠️  in2csv not available, copying Excel file as-is" >&2
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
    
    # Note: Postal code processing moved to separate update_cache.sh workflow
    echo "  -> Raw CSV saved (postal code processing will be done separately)"
    
    echo "     ✅ Saved as $new_target_file (${format_type} format)"
    return 0
}

# Note: Postal code processing functions moved to update_cache.sh

# Note: Quarterly format postal code processing moved to update_cache.sh

# Note: Location cache initialization moved to update_cache.sh

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

        local relative_path="${csv_file#./}"
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