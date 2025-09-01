#!/bin/bash

# Central Geocoding Library
# Provides multi-source geocoding functionality with fallback support
# Sources: Nominatim (OpenStreetMap) → geocoder.ca

# Global counters for statistics (should be initialized by calling script)
: ${CACHE_HITS:=0}
: ${API_CALLS:=0}
: ${FAILED_LOOKUPS:=0}

# Default configuration (can be overridden by calling script)
: ${GEOCODING_SLEEP_TIMER:=1}
: ${GEOCODING_CACHE_FILE:="./outputs/cache/location_cache.csv"}

# Multi-source geocoding function
# Usage: get_coordinates_for_postal_code "A1C6C9"
# Returns: "lat,lon" or "," if not found
# Side effects: Updates cache file if new coordinates found
get_coordinates_for_postal_code() {
    local postal_code="$1"
    
    if [[ -z "$postal_code" ]]; then
        echo ","
        return
    fi
    
    # Normalize postal code format (remove spaces for consistent lookup/storage)
    local normalized_pc=$(echo "$postal_code" | tr -d ' ')
    
    # Check cache first - postal code is the first column
    if [[ -f "$GEOCODING_CACHE_FILE" ]]; then
        local cached_coords=$(grep "^$normalized_pc;" "$GEOCODING_CACHE_FILE" 2>/dev/null | head -1 | cut -d';' -f2,3 | tr ';' ',')
        if [[ -n "$cached_coords" && "$cached_coords" != "," ]]; then
            CACHE_HITS=$((CACHE_HITS + 1))
            echo "  ✓ Cache hit: $postal_code" >&2
            echo "$cached_coords"
            return
        fi
    fi
    
    # Not in cache, try multiple geocoding sources
    API_CALLS=$((API_CALLS + 1))
    echo "  → Looking up postal code: $postal_code (API call #$API_CALLS)" >&2
    
    # Try Nominatim first (OpenStreetMap) - 1 second rate limit
    echo "    → Trying Nominatim (OpenStreetMap)..." >&2
    local coordinates=$(curl -s "https://nominatim.openstreetmap.org/search?postalcode=${normalized_pc}&country=CA&format=json&limit=1" | jq -r '.[0] | "\(.lat),\(.lon)"' 2>/dev/null || echo ",")
    local source="Nominatim"
    
    # If Nominatim failed, try geocoder.ca as fallback
    if [[ "$coordinates" == "null,null" || "$coordinates" == "," ]]; then
        echo "    → Nominatim failed, trying geocoder.ca..." >&2
        sleep 0.5  # geocoder.ca rate limit: max 2 requests/second, so 0.5s between requests
        
        # geocoder.ca API format: http://geocoder.ca/?postal=POSTALCODE&geoit=xml
        local geocoder_response=$(curl -s "http://geocoder.ca/?postal=${normalized_pc}&geoit=xml" 2>/dev/null || echo "")
        
        if [[ -n "$geocoder_response" && "$geocoder_response" != *"error"* ]]; then
            # Extract lat/lon from XML response
            local lat=$(echo "$geocoder_response" | grep -o '<latt>[^<]*</latt>' | sed 's/<[^>]*>//g' 2>/dev/null || echo "")
            local lon=$(echo "$geocoder_response" | grep -o '<longt>[^<]*</longt>' | sed 's/<[^>]*>//g' 2>/dev/null || echo "")
            
            if [[ -n "$lat" && -n "$lon" && "$lat" != "" && "$lon" != "" ]]; then
                coordinates="$lat,$lon"
                source="geocoder.ca"
            fi
        fi
    fi
    
    # Check final result
    if [[ "$coordinates" == "null,null" || "$coordinates" == "," || -z "$coordinates" ]]; then
        FAILED_LOOKUPS=$((FAILED_LOOKUPS + 1))
        echo "    ❌ No coordinates found for $postal_code (tried both sources)" >&2
        echo ","
    else
        echo "    ✅ Found coordinates: $coordinates (source: $source)" >&2
        echo "$coordinates"
    fi
    
    # Rate limiting for primary source (Nominatim)
    sleep "$GEOCODING_SLEEP_TIMER"
}

# Add coordinates to cache with sample address and employer
# Usage: add_to_cache "A1C6C9" "47.5630653,-52.7076773" "Sample Address" "Sample Employer"
add_to_cache() {
    local postal_code="$1"
    local coordinates="$2"
    local address="$3"
    local employer="$4"
    
    if [[ -z "$postal_code" || -z "$coordinates" || "$coordinates" == "," ]]; then
        return
    fi
    
    # Normalize postal code format
    local normalized_pc=$(echo "$postal_code" | tr -d ' ')
    
    # Extract lat/lon from coordinates
    local lat=$(echo "$coordinates" | cut -d',' -f1)
    local lon=$(echo "$coordinates" | cut -d',' -f2)
    
    if [[ -z "$lat" || -z "$lon" ]]; then
        return
    fi
    
    # Clean fields for cache storage (normalize whitespace, no extra escaping needed for semicolon format)
    address=$(echo "$address" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | sed 's/^ *//;s/ *$//')
    employer=$(echo "$employer" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | sed 's/^ *//;s/ *$//')
    
    # Use "Unknown" as default for missing data
    [[ -z "$address" ]] && address="Unknown"
    [[ -z "$employer" ]] && employer="Unknown"
    
    # Check if this postal code already exists in cache
    if [[ -f "$GEOCODING_CACHE_FILE" ]] && ! grep -q "^$normalized_pc;" "$GEOCODING_CACHE_FILE" 2>/dev/null; then
        echo "$normalized_pc;$lat;$lon;$address;$employer" >> "$GEOCODING_CACHE_FILE"
        echo "    ✓ Cached postal code: $normalized_pc ($lat,$lon) [$employer]" >&2
    fi
}

# Initialize cache file with proper header if it doesn't exist
# Usage: initialize_geocoding_cache
initialize_geocoding_cache() {
    local cache_dir=$(dirname "$GEOCODING_CACHE_FILE")
    mkdir -p "$cache_dir"
    
    if [[ ! -f "$GEOCODING_CACHE_FILE" ]]; then
        echo "📄 Creating new geocoding cache file..." >&2
        echo "Postal Code;Latitude;Longitude;Sample Address;Sample Employer" > "$GEOCODING_CACHE_FILE"
        echo "✓ Created new cache file: $GEOCODING_CACHE_FILE" >&2
    fi
}

# Get cache statistics
# Usage: get_cache_stats
# Returns: "total_entries,cache_hits,api_calls,failed_lookups"
get_cache_stats() {
    local total_entries=0
    if [[ -f "$GEOCODING_CACHE_FILE" ]]; then
        total_entries=$(tail -n +2 "$GEOCODING_CACHE_FILE" | wc -l)
    fi
    echo "$total_entries,$CACHE_HITS,$API_CALLS,$FAILED_LOOKUPS"
}

# Print geocoding performance summary
# Usage: print_geocoding_summary
print_geocoding_summary() {
    local stats=$(get_cache_stats)
    local total_entries=$(echo "$stats" | cut -d',' -f1)
    local cache_hits=$(echo "$stats" | cut -d',' -f2)
    local api_calls=$(echo "$stats" | cut -d',' -f3)
    local failed_lookups=$(echo "$stats" | cut -d',' -f4)
    
    echo "📍 Geocoding Performance Summary:" >&2
    echo "   Cache entries: $total_entries" >&2
    echo "   Cache hits: $cache_hits" >&2
    echo "   API calls: $api_calls" >&2
    echo "   Failed lookups: $failed_lookups" >&2
    
    if [[ $api_calls -gt 0 ]]; then
        local success_rate=$(( (api_calls - failed_lookups) * 100 / api_calls ))
        echo "   API success rate: ${success_rate}%" >&2
    fi
    
    if [[ $((cache_hits + api_calls)) -gt 0 ]]; then
        local cache_hit_ratio=$(( cache_hits * 100 / (cache_hits + api_calls) ))
        echo "   Cache hit ratio: ${cache_hit_ratio}%" >&2
    fi
}
