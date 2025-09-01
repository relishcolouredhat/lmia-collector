#!/bin/bash

echo "=== DEBUGGING SCRIPT ==="

# Download one file manually
echo "1. Downloading test file..."
temp_file=$(mktemp)
curl -s -L "https://open.canada.ca/data/dataset/90fed587-1364-4f33-a9ee-208181dc0b97/resource/bd5dab03-02dc-4542-8e01-c04dca9a0337/download/positive_employers_en.csv" -o "$temp_file"
echo "   Downloaded to: $temp_file"
echo "   Size: $(du -h "$temp_file")"
echo "   Lines: $(wc -l < "$temp_file")"

# Check format detection
echo "2. Testing format detection..."
if grep -q "Employer.*Address.*Positions" "$temp_file"; then
    echo "   ✅ Detected employer format"
    format_type="employer"
else
    echo "   ❌ NOT detected as employer format"
    format_type="quarterly"
fi

# Test directory creation
echo "3. Testing directory creation..."
output_dir="./outputs/csv/employer_format"
mkdir -p "$output_dir"
echo "   Directory created: $output_dir"

# Test file processing
echo "4. Testing file processing..."
target_file="${output_dir}/test_output.csv"
echo "   Target file: $target_file"

if [[ "$format_type" == "employer" ]]; then
    echo "   Running AWK command..."
    awk '/Employer.*Address.*Positions/{p=1} p' "$temp_file" | sed '/^Remarques:/,$d' | sed '/^Notes:/,$d' > "$target_file"
    echo "   AWK completed"
    echo "   Output file size: $(du -h "$target_file" 2>/dev/null || echo "FILE NOT FOUND")"
    echo "   Output file lines: $(wc -l < "$target_file" 2>/dev/null || echo "FILE NOT FOUND")"
    if [[ -f "$target_file" ]]; then
        echo "   First 3 lines:"
        head -3 "$target_file"
    fi
else
    echo "   ❌ Wrong format type, cannot test"
fi

# Cleanup
rm -f "$temp_file"
echo "=== DEBUG COMPLETE ==="
