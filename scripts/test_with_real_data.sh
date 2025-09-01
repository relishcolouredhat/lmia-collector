#!/bin/bash

# Test geocoding with real postal codes from your dataset
# Extracts a few postal codes from actual CSV files and tests them

set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables (API keys, etc.)
source "$SCRIPT_DIR/load_env.sh"

# Load central geocoding library
source "$SCRIPT_DIR/lib/geocoding.sh"

echo "🧪 Testing Geocoding with Real Dataset Postal Codes"
echo "==================================================="
echo

# Use a temporary cache for testing
TEST_CACHE_DIR="/tmp/real_data_test_$$"
mkdir -p "$TEST_CACHE_DIR"
export GEOCODING_CACHE_FILE="$TEST_CACHE_DIR/test_cache.csv"
export GEOCODING_BOGONS_FILE="$TEST_CACHE_DIR/test_bogons"

# Initialize test cache
initialize_geocoding_cache

# Find some CSV files to extract postal codes from
CSV_FILES=(
    "./outputs/csv/unprocessed/quarterly_format/2024-10-24_tfwp_2024q2_pos_en.csv"
    "./outputs/csv/unprocessed/quarterly_format/2025-03-18_tfwp_2024q4_pos_en.csv"
)

echo "📄 Extracting postal codes from real data files..."

# Function to extract postal codes from a CSV file
extract_postal_codes() {
    local file="$1"
    local limit="$2"
    
    if [[ ! -f "$file" ]]; then
        echo "   ⚠️  File not found: $file"
        return
    fi
    
    echo "   📂 Processing: $(basename "$file")"
    
    # Extract postal codes from the address field (assuming it's in a standard format)
    # Look for Canadian postal code pattern: Letter-Number-Letter Number-Letter-Number
    grep -oE '[A-Z][0-9][A-Z] ?[0-9][A-Z][0-9]' "$file" | \
        tr -d ' ' | \
        sort -u | \
        head -n "$limit"
}

# Collect unique postal codes from multiple files
echo "🔍 Extracting unique postal codes..."
declare -a REAL_POSTAL_CODES=()

for csv_file in "${CSV_FILES[@]}"; do
    if [[ -f "$csv_file" ]]; then
        # Get 3 postal codes from each file
        while IFS= read -r pc; do
            REAL_POSTAL_CODES+=("$pc")
        done < <(extract_postal_codes "$csv_file" 3)
    fi
done

# Remove duplicates and limit to reasonable number for testing
REAL_POSTAL_CODES=($(printf '%s\n' "${REAL_POSTAL_CODES[@]}" | sort -u | head -8))

echo "   Found ${#REAL_POSTAL_CODES[@]} unique postal codes to test"
echo

if [[ ${#REAL_POSTAL_CODES[@]} -eq 0 ]]; then
    echo "❌ No postal codes found in CSV files"
    echo "   Please check that CSV files exist and contain valid Canadian postal codes"
    exit 1
fi

echo "🎯 Testing Real Postal Codes:"
echo "============================="

for postal_code in "${REAL_POSTAL_CODES[@]}"; do
    echo
    echo "📍 Testing: $postal_code"
    echo "   $(printf '=%.0s' {1..30})"
    
    # Test geocoding
    start_time=$(date +%s)
    coordinates=$(get_coordinates_for_postal_code "$postal_code")
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    # Report results
    if [[ "$coordinates" != "," && -n "$coordinates" ]]; then
        lat=$(echo "$coordinates" | cut -d',' -f1)
        lon=$(echo "$coordinates" | cut -d',' -f2)
        echo "   ✅ SUCCESS: $coordinates (${duration}s)"
        echo "      🌍 Maps: https://www.google.com/maps?q=$lat,$lon"
        
        # Validate coordinates are reasonable for Canada
        # Canada spans roughly: Lat 41.7-83.1, Lon -141.0 to -52.6
        if [[ $(echo "$lat > 41 && $lat < 84" | bc 2>/dev/null || echo "0") -eq 1 ]] && \
           [[ $(echo "$lon > -142 && $lon < -52" | bc 2>/dev/null || echo "0") -eq 1 ]]; then
            echo "      ✅ Coordinates are within Canadian bounds"
        else
            echo "      ⚠️  Coordinates seem outside Canadian bounds - verify manually"
        fi
    else
        echo "   ❌ FAILED: No coordinates found (${duration}s)"
    fi
    
    # Rate limiting
    sleep 1
done

echo
echo "📊 Final Statistics:"
echo "==================="
print_geocoding_summary

echo
echo "🔍 Which Services Were Used:"
echo "============================"
if [[ -f "$GEOCODING_CACHE_FILE" ]]; then
    echo "   Successful lookups by source:"
    # This would require modifying the geocoding library to track sources
    # For now, just show that we have results
    success_count=$(tail -n +2 "$GEOCODING_CACHE_FILE" | wc -l)
    echo "   Total successful: $success_count"
else
    echo "   No successful lookups recorded"
fi

echo
echo "💰 API Usage Estimate:"
echo "======================"
stats=$(get_cache_stats)
api_calls=$(echo "$stats" | cut -d',' -f3)
echo "   Total API calls made: $api_calls"

if [[ -n "$GOOGLE_GEOCODING_API_KEY" ]] && [[ $api_calls -gt 0 ]]; then
    echo "   Google Geocoding pricing: ~\$5 per 1,000 requests"
    cost_estimate=$(echo "scale=4; $api_calls * 5 / 1000" | bc 2>/dev/null || echo "N/A")
    echo "   Estimated cost for this test: ~\$${cost_estimate}"
    echo "   Note: Free tier includes 200/day, 40,000/month"
fi

# Cleanup
echo
echo "🧹 Cleaning up test files..."
rm -rf "$TEST_CACHE_DIR"

echo
echo "✅ Real data test completed!"
echo
echo "💡 Insights:"
echo "   - Test shows how your actual postal codes perform"
echo "   - Failed lookups become 'bogons' to save future API costs"
echo "   - Successful lookups are cached for instant reuse"
echo "   - API fallback chain provides maximum coverage"
