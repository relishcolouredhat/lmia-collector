#!/bin/bash

# Test the CSV parsing fix with the problematic source file
# This validates that encoding issues are properly handled

set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables (API keys, etc.)
source "$SCRIPT_DIR/load_env.sh"

# Load central geocoding library
source "$SCRIPT_DIR/lib/geocoding.sh"

# Source the updated parse_csv_line function
source "$SCRIPT_DIR/update_cache.sh"

echo "🧪 Testing CSV Parsing Fix"
echo "=========================="
echo

# Test file with known problematic entries
TEST_FILE="/home/klc/git/lmia-collector/outputs/csv/unprocessed/employer_format/2016-10-21_2015_positive_employers_en.csv"

if [[ ! -f "$TEST_FILE" ]]; then
    echo "❌ Test file not found: $TEST_FILE"
    exit 1
fi

echo "📄 Test file: $(basename "$TEST_FILE")"
echo "📊 File encoding: $(file "$TEST_FILE")"
echo

# Extract the problematic line for testing
echo "🔍 Finding problematic entries..."
PROBLEMATIC_LINE=$(grep -a "Cilantro" "$TEST_FILE" | head -1)
echo "   Found: $PROBLEMATIC_LINE"
echo

# Test the parse_csv_line function with the problematic line
echo "🧪 Testing parse_csv_line function:"
echo "=================================="

echo "📋 Parsing employer field (field 1):"
EMPLOYER=$(parse_csv_line "$PROBLEMATIC_LINE" 1)
echo "   Result: '$EMPLOYER'"

echo "📋 Parsing address field (field 2):"
ADDRESS=$(parse_csv_line "$PROBLEMATIC_LINE" 2)
echo "   Result: '$ADDRESS'"

echo

# Analyze the results
echo "🔍 Analysis:"
echo "============"

# Check for problematic patterns
if echo "$EMPLOYER" | grep -q '""'; then
    echo "   ❌ Employer field still contains double quotes"
else
    echo "   ✅ Employer field clean: '$EMPLOYER'"
fi

if echo "$ADDRESS" | grep -q '""'; then
    echo "   ❌ Address field still contains double quotes"
else
    echo "   ✅ Address field clean: '$ADDRESS'"
fi

# Check for binary characters
if echo "$EMPLOYER$ADDRESS" | grep -q '[^[:print:][:space:]]'; then
    echo "   ⚠️  Non-printable characters still present"
else
    echo "   ✅ No non-printable characters detected"
fi

# Test postal code extraction
echo
echo "📍 Testing postal code extraction:"
POSTAL_CODE=$(echo "$ADDRESS" | grep -o '[A-Z][0-9][A-Z] [0-9][A-Z][0-9]\|[A-Z][0-9][A-Z][0-9][A-Z][0-9]' | head -1 || echo "")
if [[ -n "$POSTAL_CODE" ]]; then
    echo "   ✅ Extracted postal code: '$POSTAL_CODE'"
else
    echo "   ❌ Failed to extract postal code from: '$ADDRESS'"
fi

echo
echo "💡 Summary:"
echo "==========="
if [[ -n "$EMPLOYER" && -n "$ADDRESS" && -n "$POSTAL_CODE" ]]; then
    echo "   ✅ CSV parsing successful!"
    echo "   📊 Employer: $EMPLOYER"
    echo "   📊 Address: $ADDRESS"
    echo "   📊 Postal Code: $POSTAL_CODE"
    
    # Test if this would create a proper cache entry
    echo
    echo "🧪 Testing cache entry creation..."
    # Use a temporary cache for testing
    TEST_CACHE_DIR="/tmp/csv_test_$$"
    mkdir -p "$TEST_CACHE_DIR"
    export GEOCODING_CACHE_FILE="$TEST_CACHE_DIR/test_cache.csv"
    export GEOCODING_BOGONS_FILE="$TEST_CACHE_DIR/test_bogons"
    export GEOCODING_TURBO_MODE="true"
    
    # Initialize test cache
    initialize_geocoding_cache
    
    # Test geocoding
    coordinates=$(get_coordinates_for_postal_code "$POSTAL_CODE")
    if [[ "$coordinates" != "," && -n "$coordinates" ]]; then
        echo "   ✅ Geocoding successful: $coordinates"
        
        # Test cache entry creation
        lat=$(echo "$coordinates" | cut -d',' -f1)
        lon=$(echo "$coordinates" | cut -d',' -f2)
        add_to_cache "$POSTAL_CODE" "$coordinates" "$ADDRESS" "$EMPLOYER"
        
        # Check the cache entry
        cache_entry=$(grep "^$POSTAL_CODE;" "$GEOCODING_CACHE_FILE" 2>/dev/null || echo "")
        if [[ -n "$cache_entry" ]]; then
            echo "   ✅ Cache entry created: $cache_entry"
            
            # Verify no malformed patterns
            if echo "$cache_entry" | grep -q '"".*""'; then
                echo "   ❌ Cache entry contains malformed patterns!"
            else
                echo "   ✅ Cache entry is clean and properly formatted"
            fi
        else
            echo "   ⚠️  No cache entry found"
        fi
    else
        echo "   ❌ Geocoding failed"
    fi
    
    # Cleanup
    rm -rf "$TEST_CACHE_DIR"
    
else
    echo "   ❌ CSV parsing failed - missing required fields"
fi

echo
echo "✅ CSV parsing test completed!"
