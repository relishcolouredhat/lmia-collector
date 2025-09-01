#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
# URLs for the Open Canada data feeds
POSITIVE_FEED_URL="https://open.canada.ca/data/api/action/package_show?id=90fed587-1364-4f33-a9ee-208181dc0b97"
NEGATIVE_FEED_URL="https://open.canada.ca/data/api/action/package_show?id=f82f66f2-a22b-4511-bccf-e1d74db39ae5"
DATA_DIR="." # Base directory where outputs will be stored
FEEDS=("$POSITIVE_FEED_URL" "$NEGATIVE_FEED_URL")

# Language filter (default to English if not specified)
LANGUAGE="${LANGUAGE:-en}"

# Create organized output directory structure
OUTPUTS_DIR="${DATA_DIR}/outputs"
CSV_DIR="${OUTPUTS_DIR}/csv"
IFLP_DIR="${OUTPUTS_DIR}/iflp"

# Create subdirectories for positive and negative reports within each format
POSITIVE_CSV_DIR="${CSV_DIR}/positive"
NEGATIVE_CSV_DIR="${CSV_DIR}/negative"
POSITIVE_IFLP_DIR="${IFLP_DIR}/positive"
NEGATIVE_IFLP_DIR="${IFLP_DIR}/negative"

# Create all necessary directories
mkdir -p "$POSITIVE_CSV_DIR" "$NEGATIVE_CSV_DIR" "$POSITIVE_IFLP_DIR" "$NEGATIVE_IFLP_DIR"

# --- Logic ---
NEW_FILES_FOUND="false"
NEW_FILE_NAMES=""

echo "Starting check for new LMIA reports (Language: $LANGUAGE)..."

# Loop through both the positive and negative feeds
for i in "${!FEEDS[@]}"; do
  feed_url="${FEEDS[$i]}"
  feed_type=""
  
  # Determine feed type for directory organization
  if [[ "$feed_url" == *"90fed587-1364-4f33-a9ee-208181dc0b97"* ]]; then
    feed_type="positive"
    output_dir="$POSITIVE_CSV_DIR" # Changed to CSV_DIR
  else
    feed_type="negative"
    output_dir="$NEGATIVE_CSV_DIR" # Changed to CSV_DIR
  fi
  
  echo "Checking $feed_type feed: ${feed_url}"

  # Fetch the feed and parse it with jq to get the URL and creation date of each resource
  # The output is a list of lines, with URL and created date separated by a tab
  resources=$(curl -s "$feed_url" | jq -r '.result.resources[] | "\(.url)\t\(.created)"')

  # Process each resource from the feed
  while IFS=$'\t' read -r url created_ts; do
    # Extract original filename from URL (e.g., tfwp_2024q2_pos_en.xlsx)
    original_filename=$(basename "$url")
    
    # Filter by language - only process files matching the specified language
    if [[ "$original_filename" != *"_${LANGUAGE}."* ]]; then
      echo "  -> Skipping $original_filename (language mismatch, expected: ${LANGUAGE})"
      continue
    fi

    # Format the creation date to YYYY-MM-DD
    publish_date=$(echo "$created_ts" | cut -d'T' -f1)

    # Construct the target filename for our repo (in appropriate subdirectory)
    target_filename="${output_dir}/${publish_date}_${original_filename%.*}.csv"

    # Check if this file already exists in our repository
    if [ -f "$target_filename" ]; then
      echo "  -> Skipping $original_filename (already exists)"
      continue # Skip if file already exists
    fi

    # --- Found a new file ---
    NEW_FILES_FOUND="true"
    echo "  -> Found new $feed_type file: $original_filename (Published: $publish_date)"

    # Download the file to a temporary location
    temp_download="/tmp/${original_filename}"
    curl -L -s -o "$temp_download" "$url"

    echo "     Processing..."

    # Check file extension and process accordingly
    if [[ "$original_filename" == *.xlsx ]]; then
      # It's an XLSX file: convert using in2csv (lighter than ssconvert)
      # Remove the first line (header) and any trailing notes
      in2csv "$temp_download" | tail -n +2 | sed '/^Remarques:/,$d' | sed '/^Notes:/,$d' > "$target_filename"
    elif [[ "$original_filename" == *.csv ]]; then
      # It's already a CSV: remove the first line and any trailing notes
      tail -n +2 "$temp_download" | sed '/^Remarques:/,$d' | sed '/^Notes:/,$d' > "$target_filename"
    else
      echo "     WARNING: Unknown file type for $original_filename. Skipping."
      continue
    fi

    rm -f "$temp_download" /tmp/temp.csv &> /dev/null
    echo "     ✅ Saved as $target_filename"
    NEW_FILE_NAMES+="${target_filename}\n"
  done <<< "$resources"
done

# Generate Grafana Infinity plugin endpoint files
echo "Generating Grafana Infinity plugin endpoint files..."

# Function to generate endpoint JSON for a directory
generate_endpoint_json() {
  local dir="$1"
  local endpoint_file="$2"
  local base_url="https://raw.githubusercontent.com/relishcolouredhat/lmia-collector/main"
  
  echo "  -> Generating endpoint file: $endpoint_file"
  
  # Create JSON structure for Grafana Infinity plugin
  cat > "$endpoint_file" << EOF
{
  "endpoints": [
EOF
  
  # Find all CSV files in the directory and add them to the JSON
  local first=true
  while IFS= read -r -d '' csv_file; do
    if [ "$first" = true ]; then
      first=false
    else
      echo "    ," >> "$endpoint_file"
    fi
    
    # Get relative path from outputs directory
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
  
  # Close JSON structure
  cat >> "$endpoint_file" << EOF
  ]
}
EOF
  
  echo "     ✅ Generated $endpoint_file with $(find "$dir" -name "*.csv" -type f | wc -l) endpoints"
}

# Generate endpoint files for positive and negative CSV directories
generate_endpoint_json "$POSITIVE_CSV_DIR" "${OUTPUTS_DIR}/positive_endpoints.json"
generate_endpoint_json "$NEGATIVE_CSV_DIR" "${OUTPUTS_DIR}/negative_endpoints.json"

# Also generate a combined endpoints file
echo "  -> Generating combined endpoints file..."
cat > "${OUTPUTS_DIR}/all_endpoints.json" << EOF
{
  "positive_endpoints": "${OUTPUTS_DIR}/positive_endpoints.json",
  "negative_endpoints": "${OUTPUTS_DIR}/negative_endpoints.json",
  "base_url": "https://raw.githubusercontent.com/relishcolouredhat/lmia-collector/main/outputs"
}
EOF

echo "     ✅ Generated combined endpoints file"

# --- Output for GitHub Actions ---
# Use GITHUB_OUTPUT to pass variables to subsequent steps in the workflow
if [ "$NEW_FILES_FOUND" = "true" ]; then
  echo "Finished processing. New files were added."
  echo "new_files_found=true" >> "$GITHUB_OUTPUT"
  echo "new_file_names<<EOF" >> "$GITHUB_OUTPUT"
  echo -e "$NEW_FILE_NAMES" >> "$GITHUB_OUTPUT"
  echo "EOF" >> "$GITHUB_OUTPUT"
else
  echo "Finished processing. No new files found."
  echo "new_files_found=false" >> "$GITHUB_OUTPUT"
fi