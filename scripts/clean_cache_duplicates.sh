#!/bin/bash

# Clean up duplicated entries in the location cache
# Fixes the issue where address and employer fields contain duplicated data

set -e

CACHE_FILE="./outputs/cache/location_cache.csv"
BACKUP_FILE="${CACHE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

echo "🧹 Cleaning Cache Duplicates"
echo "============================"
echo

if [[ ! -f "$CACHE_FILE" ]]; then
    echo "❌ Cache file not found: $CACHE_FILE"
    exit 1
fi

echo "📄 Processing cache file: $CACHE_FILE"
echo "💾 Creating backup: $BACKUP_FILE"

# Create backup
cp "$CACHE_FILE" "$BACKUP_FILE"

# Count original entries
original_count=$(tail -n +2 "$CACHE_FILE" | wc -l)
echo "📊 Original entries: $original_count"

# Process the file to remove duplications
echo "🔧 Cleaning duplicated address and employer fields..."

# Create temporary file
TEMP_FILE="${CACHE_FILE}.tmp"

# Keep header
head -1 "$CACHE_FILE" > "$TEMP_FILE"

# Process each line
tail -n +2 "$CACHE_FILE" | while IFS=';' read -r postal_code lat lon address employer; do
    # Clean duplicated addresses (remove repeated content)
    # Pattern: "text text" -> "text"
    clean_address=$(echo "$address" | sed 's/\(.*\) \1$/\1/' | sed 's/^\(.*\) \1 \1$/\1/')
    
    # Clean duplicated employers
    # Pattern: "text text" -> "text"  
    clean_employer=$(echo "$employer" | sed 's/\(.*\) \1$/\1/' | sed 's/^\(.*\) \1 \1$/\1/')
    
    # Write cleaned line
    echo "$postal_code;$lat;$lon;$clean_address;$clean_employer" >> "$TEMP_FILE"
done

# Replace original with cleaned version
mv "$TEMP_FILE" "$CACHE_FILE"

# Count cleaned entries
cleaned_count=$(tail -n +2 "$CACHE_FILE" | wc -l)

echo "✅ Cleaning completed!"
echo "📊 Cleaned entries: $cleaned_count"
echo "💾 Backup saved: $BACKUP_FILE"

# Show sample of cleaned data
echo
echo "📋 Sample cleaned entries:"
head -6 "$CACHE_FILE" | tail -5 | while IFS=';' read -r pc lat lon addr emp; do
    echo "   $pc → Address: ${addr:0:50}..."
    echo "        Employer: ${emp:0:50}..."
done

echo
echo "🔍 Checking for remaining duplicates..."
duplicate_count=$(tail -n +2 "$CACHE_FILE" | grep -E '(.+) \1' | wc -l)
if [[ $duplicate_count -eq 0 ]]; then
    echo "✅ No duplicates found!"
else
    echo "⚠️  Found $duplicate_count potential duplicates that need manual review"
fi

echo
echo "✅ Cache cleaning completed!"
