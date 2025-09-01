#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
# URLs for the Open Canada data feeds
POSITIVE_FEED_URL="https://open.canada.ca/data/api/action/package_show?id=90fed587-1364-4f33-a9ee-208181dc0b97"
NEGATIVE_FEED_URL="https://open.canada.ca/data/api/action/package_show?id=f82f66f2-a22b-4511-bccf-e1d74db39ae5"
DATA_DIR="." # Directory where CSVs will be stored
FEEDS=("$POSITIVE_FEED_URL" "$NEGATIVE_FEED_URL")

# --- Logic ---
NEW_FILES_FOUND="false"
NEW_FILE_NAMES=""

echo "Starting check for new LMIA reports..."

# Loop through both the positive and negative feeds
for feed_url in "${FEEDS[@]}"; do
  echo "Checking feed: ${feed_url}"

  # Fetch the feed and parse it with jq to get the URL and creation date of each resource
  # The output is a list of lines, with URL and created date separated by a tab
  resources=$(curl -s "$feed_url" | jq -r '.result.resources[] | "\(.url)\t\(.created)"')

  # Process each resource from the feed
  while IFS=$'\t' read -r url created_ts; do
    # Extract original filename from URL (e.g., tfwp_2024q2_pos_en.xlsx)
    original_filename=$(basename "$url")

    # Format the creation date to YYYY-MM-DD
    publish_date=$(echo "$created_ts" | cut -d'T' -f1)

    # Construct the target filename for our repo
    target_filename="${DATA_DIR}/${publish_date}_${original_filename%.*}.csv"

    # Check if this file already exists in our repository
    if [ -f "$target_filename" ]; then
      continue # Skip if file already exists
    fi

    # --- Found a new file ---
    NEW_FILES_FOUND="true"
    echo "  -> Found new file: $original_filename (Published: $publish_date)"

    # Download the file to a temporary location
    temp_download="/tmp/${original_filename}"
    curl -L -s -o "$temp_download" "$url"

    echo "     Processing..."

    # Check file extension and process accordingly
    if [[ "$original_filename" == *.xlsx ]]; then
      # It's an XLSX file: convert, then remove the first line
      ssconvert "$temp_download" "/tmp/temp.csv"
      tail -n +2 "/tmp/temp.csv" > "$target_filename"
    elif [[ "$original_filename" == *.csv ]]; then
      # It's already a CSV: just remove the first line
      tail -n +2 "$temp_download" > "$target_filename"
    else
      echo "     WARNING: Unknown file type for $original_filename. Skipping."
      continue
    fi

    rm -f "$temp_download" /tmp/temp.csv &> /dev/null
    echo "     ✅ Saved as $target_filename"
    NEW_FILE_NAMES+="${target_filename}\n"
  done <<< "$resources"
done

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