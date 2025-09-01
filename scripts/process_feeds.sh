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

# Function to determine file format and process accordingly
process_file_by_format() {
    local temp_file="$1"
    local target_file="$2"
    local original_filename="$3"
    
    # Check if this is an employer format file (contains "Employer,Address,Positions approved")
    if head -1 "$temp_file" | grep -q "Employer,Address,Positions approved"; then
        echo "  -> Detected employer format file"
        local output_dir="$EMPLOYER_FORMAT_DIR"
        local format_type="employer"
    else
        echo "  -> Detected quarterly format file"
        local output_dir="$QUARTERLY_FORMAT_DIR"
        local format_type="quarterly"
    fi
    
    # Create the appropriate output directory
    mkdir -p "$output_dir"
    
    # Update target filename to use the correct directory
    local filename=$(basename "$target_file")
    local new_target_file="${output_dir}/${filename}"
    
    if [[ "$original_filename" == *.xlsx ]]; then
        if command -v in2csv >/dev/null 2>&1; then
            in2csv "$temp_file" | tail -n +2 | sed '/^Remarques:/,$d' | sed '/^Notes:/,$d' > "$new_target_file"
        else
            # Fallback: copy as-is if in2csv not available
            cp "$temp_file" "$new_target_file"
        fi
    elif [[ "$original_filename" == *.csv ]]; then
        tail -n +2 "$temp_file" | sed '/^Remarques:/,$d' | sed '/^Notes:/,$d' > "$new_target_file"
    fi
    
    # Add postal code column based on format
    if [[ "$format_type" == "employer" ]]; then
        add_postal_code_column_employer "$new_target_file"
    else
        add_postal_code_column_quarterly "$new_target_file"
    fi
    
    echo "     ✅ Saved as $new_target_file (${format_type} format)"
    return 0
}

# Function to add postal code column for employer format files
add_postal_code_column_employer() {
    local file="$1"
    local temp_file="${file}.tmp"
    
    # Create header with postal code column
    head -1 "$file" | sed 's/Positions approved/Positions approved,Postal Code/' > "$temp_file"
    
    # Process each line to extract postal code from address
    tail -n +2 "$file" | while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Extract address (3rd field) and get postal code
            local address=$(echo "$line" | cut -d',' -f3)
            local postal_code=$(extract_postal_code "$address")
            echo "${line},${postal_code}" >> "$temp_file"
        fi
    done
    
    mv "$temp_file" "$file"
}

# Function to add postal code column for quarterly format files
add_postal_code_column_quarterly() {
    local file="$1"
    local temp_file="${file}.tmp"
    
    # Create header with postal code column
    head -1 "$file" | sed 's/Positions Approved/Positions Approved,Postal Code/' > "$temp_file"
    
    # Process each line to extract postal code from address
    tail -n +2 "$file" | while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Extract address (4th field) and get postal code
            local address=$(echo "$line" | cut -d',' -f4)
            local postal_code=$(extract_postal_code "$address")
            echo "${line},${postal_code}" >> "$temp_file"
        fi
    done
    
    mv "$temp_file" "$file"
}

# Process each feed
for feed_url in "${FEEDS[@]}"; do
    echo "Checking feed: $feed_url"
    
    # Determine feed type based on URL
    if [[ "$feed_url" == *"90fed587-1364-4f33-a9ee-208181dc0b97"* ]]; then
        feed_type="positive"
        output_dir="$POSITIVE_CSV_DIR"
    else
        feed_type="negative"
        output_dir="$NEGATIVE_CSV_DIR"
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
    files=$(echo "$response" | jq -r '.result.resources[] | select(.format == "CSV" or .format == "XLSX") | "\(.name)|\(.url)|\(.created)"' 2>/dev/null || echo "")
    
    if [[ -z "$files" ]]; then
        echo "  ⚠️  No CSV/XLSX files found in feed"
        continue
    fi
    
    # Process each file
    while IFS='|' read -r filename url created; do
        if [[ -z "$filename" || -z "$url" ]]; then
            continue
        fi
        
        # Check language filter
        if [[ "$filename" != *"_${LANGUAGE}."* ]]; then
            echo "  -> Skipping $filename (language mismatch, expected: ${LANGUAGE})"
            continue
        fi
        
        # Extract publish date from created timestamp
        publish_date=$(echo "$created" | cut -d'T' -f1)
        
        # Create target filename
        target_filename="${output_dir}/${publish_date}_${filename%.*}.csv"
        
        # Check if file already exists
        if [[ -f "$target_filename" ]]; then
            echo "  -> Skipping $filename (already exists)"
            continue
        fi
        
        echo "  -> Found new $feed_type file: $filename (Published: $publish_date)"
        echo "     Processing..."
        
        # Download and process the file
        temp_download=$(mktemp)
        if curl -s -L "$url" -o "$temp_download"; then
            # Process file based on its format
            if process_file_by_format "$temp_download" "$target_filename" "$filename"; then
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