#!/bin/bash

# Fix specific malformed cache line that's causing Grafana errors
# This addresses line 292 with complex CSV escaping issues

set -e

CACHE_FILE="./outputs/cache/location_cache.csv"
BACKUP_FILE="${CACHE_FILE}.backup.malformed_$(date +%Y%m%d_%H%M%S)"

echo "🔧 Fixing Malformed Cache Line"
echo "============================="
echo

if [[ ! -f "$CACHE_FILE" ]]; then
    echo "❌ Cache file not found: $CACHE_FILE"
    exit 1
fi

echo "📄 Creating backup: $BACKUP_FILE"
cp "$CACHE_FILE" "$BACKUP_FILE"

echo "🔍 Identifying problematic line 292..."
LINE_292=$(awk 'NR==292' "$CACHE_FILE")
echo "   Current: $LINE_292"

# Check if this is the specific malformed line we expect
if [[ "$LINE_292" == *'""Cilantro, The Cooks Shop Inc""'* ]]; then
    echo "✅ Found the expected malformed line"
    
    # Create the corrected line
    FIXED_LINE="B0J2C0;44.3698843;-64.2836766;PO Box219, Lunenburg, NS B0J2C0;Cilantro, The Cooks Shop Inc"
    echo "   Fixed:   $FIXED_LINE"
    
    # Replace line 292 with the fixed version
    awk -v new_line="$FIXED_LINE" 'NR==292 {print new_line; next} {print}' "$CACHE_FILE" > "${CACHE_FILE}.tmp"
    mv "${CACHE_FILE}.tmp" "$CACHE_FILE"
    
    echo "✅ Line 292 fixed successfully!"
    
    # Verify the fix
    echo "🔍 Verifying fix..."
    NEW_LINE_292=$(awk 'NR==292' "$CACHE_FILE")
    echo "   New line 292: $NEW_LINE_292"
    
    # Check field count
    FIELD_COUNT=$(echo "$NEW_LINE_292" | awk -F';' '{print NF}')
    if [[ $FIELD_COUNT -eq 5 ]]; then
        echo "✅ Field count correct: $FIELD_COUNT fields"
    else
        echo "❌ Field count incorrect: $FIELD_COUNT fields (expected 5)"
    fi
    
else
    echo "⚠️  Line 292 doesn't match expected pattern. Manual review needed."
    echo "   Found: $LINE_292"
fi

echo "💾 Backup saved: $BACKUP_FILE"
echo "✅ Malformed line fix completed!"
