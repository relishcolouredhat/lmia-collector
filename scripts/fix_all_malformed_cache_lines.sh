#!/bin/bash

# Fix all malformed cache lines with CSV escaping issues
# This addresses lines with double quotes and embedded commas

set -e

CACHE_FILE="./outputs/cache/location_cache.csv"
BACKUP_FILE="${CACHE_FILE}.backup.comprehensive_$(date +%Y%m%d_%H%M%S)"

echo "🔧 Fixing ALL Malformed Cache Lines"
echo "==================================="
echo

if [[ ! -f "$CACHE_FILE" ]]; then
    echo "❌ Cache file not found: $CACHE_FILE"
    exit 1
fi

echo "📄 Creating backup: $BACKUP_FILE"
cp "$CACHE_FILE" "$BACKUP_FILE"

echo "🔍 Finding all malformed lines..."
MALFORMED_LINES=$(grep -n '"".*"".*,' "$CACHE_FILE" | wc -l)
echo "   Found $MALFORMED_LINES malformed lines"

if [[ $MALFORMED_LINES -eq 0 ]]; then
    echo "✅ No malformed lines found!"
    exit 0
fi

echo "📋 Processing each malformed line..."

# Create a temporary file for processing
TEMP_FILE="${CACHE_FILE}.tmp"
cp "$CACHE_FILE" "$TEMP_FILE"

# Fix line patterns - extract clean company names and addresses
while IFS= read -r line_info; do
    LINE_NUM=$(echo "$line_info" | cut -d':' -f1)
    FULL_LINE=$(echo "$line_info" | cut -d':' -f2-)
    
    echo "   Line $LINE_NUM: Processing..."
    
    # Extract the basic info (postal code, lat, lon)
    POSTAL_CODE=$(echo "$FULL_LINE" | cut -d';' -f1)
    LATITUDE=$(echo "$FULL_LINE" | cut -d';' -f2)
    LONGITUDE=$(echo "$FULL_LINE" | cut -d';' -f3)
    
    # Extract clean company name and address from the malformed data
    # Pattern: ""Company Name"",""Address"",number -> Company Name and Address
    COMPANY_PATTERN='""([^"]+)"".*""([^"]+)""'
    if [[ "$FULL_LINE" =~ $COMPANY_PATTERN ]]; then
        COMPANY_NAME="${BASH_REMATCH[1]}"
        ADDRESS="${BASH_REMATCH[2]}"
    else
        # Fallback: try to extract from the mess
        COMPANY_NAME=$(echo "$FULL_LINE" | sed 's/.*""\([^"]*\)"".*/\1/' | head -1)
        ADDRESS=$(echo "$FULL_LINE" | sed 's/.*""\([^"]*\)"",.*""\([^"]*\)"".*/\2/')
    fi
    
    # Clean up extracted data
    COMPANY_NAME=$(echo "$COMPANY_NAME" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    ADDRESS=$(echo "$ADDRESS" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # If extraction failed, use defaults
    [[ -z "$COMPANY_NAME" ]] && COMPANY_NAME="Unknown Company"
    [[ -z "$ADDRESS" ]] && ADDRESS="Unknown Address"
    
    # Create the fixed line
    FIXED_LINE="$POSTAL_CODE;$LATITUDE;$LONGITUDE;$ADDRESS;$COMPANY_NAME"
    
    echo "      Original: $(echo "$FULL_LINE" | cut -c1-60)..."
    echo "      Fixed:    $FIXED_LINE"
    
    # Replace the line in the temp file
    awk -v line_num="$LINE_NUM" -v new_line="$FIXED_LINE" \
        'NR==line_num {print new_line; next} {print}' "$TEMP_FILE" > "${TEMP_FILE}.new"
    mv "${TEMP_FILE}.new" "$TEMP_FILE"
    
done < <(grep -n '"".*"".*,' "$CACHE_FILE")

# Replace the original file
mv "$TEMP_FILE" "$CACHE_FILE"

echo "✅ All malformed lines fixed!"

# Verify the fixes
echo "🔍 Verifying fixes..."
REMAINING_MALFORMED=$(grep -c '"".*"".*,' "$CACHE_FILE" 2>/dev/null || echo "0")
if [[ $REMAINING_MALFORMED -eq 0 ]]; then
    echo "✅ No malformed lines remaining!"
else
    echo "⚠️  $REMAINING_MALFORMED malformed lines still exist"
fi

# Check field consistency
echo "📊 Checking field consistency..."
FIELD_ISSUES=$(awk -F';' 'NF != 5 {count++} END {print count+0}' "$CACHE_FILE")
if [[ $FIELD_ISSUES -eq 0 ]]; then
    echo "✅ All lines have correct field count (5 fields)"
else
    echo "⚠️  $FIELD_ISSUES lines have incorrect field count"
fi

echo "💾 Backup saved: $BACKUP_FILE"
echo "✅ Comprehensive malformed line fix completed!"
