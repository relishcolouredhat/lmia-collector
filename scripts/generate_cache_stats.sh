#!/bin/bash

# Generate location cache statistics for web interface
set -e

CACHE_FILE="./outputs/cache/location_cache.csv"
STATS_OUTPUT="./outputs/cache_statistics.json"

echo "=== Generating Location Cache Statistics ==="

# Initialize statistics
total_postal_codes=0
total_employers=0
total_addresses=0
cache_file_size=0
last_updated=""

if [[ -f "$CACHE_FILE" ]]; then
    # Count total postal codes (excluding header)
    total_postal_codes=$(tail -n +2 "$CACHE_FILE" | wc -l)
    
    # Count unique employers (column 5)
    total_employers=$(tail -n +2 "$CACHE_FILE" | cut -d',' -f5 | sed 's/"//g' | sort -u | wc -l)
    
    # Count unique addresses (column 4) 
    total_addresses=$(tail -n +2 "$CACHE_FILE" | cut -d',' -f4 | sed 's/"//g' | sort -u | wc -l)
    
    # Get file size in human readable format
    cache_file_size=$(du -h "$CACHE_FILE" | cut -f1)
    
    # Get last modified date
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        last_updated=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$CACHE_FILE")
    else
        # Linux
        last_updated=$(stat -c "%y" "$CACHE_FILE" | cut -d'.' -f1)
    fi
    
    echo "✓ Found cache file with $total_postal_codes postal codes"
else
    echo "✗ Cache file not found: $CACHE_FILE"
fi

# Create statistics JSON
cat > "$STATS_OUTPUT" << EOF
{
  "cache_statistics": {
    "total_postal_codes": $total_postal_codes,
    "unique_employers": $total_employers,
    "unique_addresses": $total_addresses,
    "file_size": "$cache_file_size",
    "last_updated": "$last_updated",
    "cache_file_exists": $(if [[ -f "$CACHE_FILE" ]]; then echo "true"; else echo "false"; fi)
  },
  "metadata": {
    "generated_at": "$(date -u +"%Y-%m-%d %H:%M:%S UTC")",
    "cache_file_path": "$CACHE_FILE"
  }
}
EOF

echo "✅ Statistics generated: $STATS_OUTPUT"
echo "   - Postal codes: $total_postal_codes"
echo "   - Unique employers: $total_employers" 
echo "   - Unique addresses: $total_addresses"
echo "   - File size: $cache_file_size"
echo "   - Last updated: $last_updated"
