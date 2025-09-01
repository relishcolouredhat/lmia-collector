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
: ${GEOCODING_BOGONS_FILE:="./outputs/cache/bogons"}

# Optional API keys (can be set via environment variables)
: ${GOOGLE_GEOCODING_API_KEY:=""}
: ${MAPBOX_ACCESS_TOKEN:=""}
: ${OPENCAGE_API_KEY:=""}

# Turbo mode configuration - prioritize Google API for max performance
: ${GEOCODING_TURBO_MODE:="false"}

# Helper functions for bogon management
# Bogons are postal codes that have repeatedly failed geocoding and should not be retried

# Check if a postal code is in the bogons list
# Usage: is_postal_code_bogon "A1C6C9"
# Returns: 0 if bogon (found), 1 if not bogon
is_postal_code_bogon() {
    local postal_code="$1"
    local normalized_pc=$(echo "$postal_code" | tr -d ' ')
    
    if [[ -f "$GEOCODING_BOGONS_FILE" ]]; then
        grep -q "^$normalized_pc$" "$GEOCODING_BOGONS_FILE" 2>/dev/null
        return $?
    fi
    return 1  # Not a bogon if file doesn't exist
}

# Add a postal code to the bogons list
# Usage: add_postal_code_to_bogons "A1C6C9"
add_postal_code_to_bogons() {
    local postal_code="$1"
    local normalized_pc=$(echo "$postal_code" | tr -d ' ')
    
    # Ensure bogons directory exists
    local bogons_dir=$(dirname "$GEOCODING_BOGONS_FILE")
    mkdir -p "$bogons_dir"
    
    # Add to bogons if not already present
    if ! is_postal_code_bogon "$normalized_pc"; then
        echo "$normalized_pc" >> "$GEOCODING_BOGONS_FILE"
        echo "    ⚠️  Added to bogons: $postal_code (will not retry API calls)" >&2
    fi
}

# Get bogons count for statistics
# Usage: get_bogons_count
get_bogons_count() {
    if [[ -f "$GEOCODING_BOGONS_FILE" ]]; then
        wc -l < "$GEOCODING_BOGONS_FILE" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

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
    
    # Check if postal code is in bogons (known failures) - avoid repeated API calls
    if is_postal_code_bogon "$normalized_pc"; then
        echo "  ⚠️  Bogon (known failure): $postal_code - skipping API calls" >&2
        echo ","
        return
    fi
    
    # Not in cache and not a bogon, try multiple geocoding sources
    API_CALLS=$((API_CALLS + 1))
    echo "  → Looking up postal code: $postal_code (API call #$API_CALLS)" >&2
    
    # TURBO MODE: Try Google first if API key available and turbo mode enabled
    if [[ "$GEOCODING_TURBO_MODE" == "true" && -n "$GOOGLE_GEOCODING_API_KEY" ]]; then
        echo "    🚀 TURBO MODE: Trying Google Geocoding API first..." >&2
        sleep 0.05  # Google can handle ~50 requests/second, so 0.05s = 20/sec (conservative)
        
        # Google Geocoding API with country component filtering
        local google_response=$(curl -s "https://maps.googleapis.com/maps/api/geocode/json?components=postal_code:${normalized_pc}|country:CA&key=${GOOGLE_GEOCODING_API_KEY}" 2>/dev/null || echo "")
        
        if [[ -n "$google_response" && "$google_response" != *"error"* ]]; then
            local lat=$(echo "$google_response" | jq -r '.results[0].geometry.location.lat // empty' 2>/dev/null || echo "")
            local lon=$(echo "$google_response" | jq -r '.results[0].geometry.location.lng // empty' 2>/dev/null || echo "")
            
            if [[ -n "$lat" && -n "$lon" && "$lat" != "" && "$lon" != "" && "$lat" != "null" && "$lon" != "null" ]]; then
                coordinates="$lat,$lon"
                source="Google-Turbo"
                echo "    ✅ Found coordinates: $coordinates (source: $source)" >&2
                echo "$coordinates"
                return  # Early return - we got our result fast!
            fi
        fi
        echo "    → Google failed, falling back to free services..." >&2
    fi
    
    # Standard mode: Try Nominatim first (OpenStreetMap) - 1 second rate limit
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
    
    # If geocoder.ca failed, try additional fallback sources
    if [[ "$coordinates" == "null,null" || "$coordinates" == "," ]]; then
        echo "    → geocoder.ca failed, trying GeoNames..." >&2
        sleep 0.5  # GeoNames rate limit: be conservative
        
        # GeoNames postal code lookup (free service, requires country=CA)
        local geonames_response=$(curl -s "http://api.geonames.org/postalCodeSearchJSON?postalcode=${normalized_pc}&country=CA&maxRows=1&username=demo" 2>/dev/null || echo "")
        
        if [[ -n "$geonames_response" && "$geonames_response" != *"error"* ]]; then
            # Extract lat/lon from JSON response
            local lat=$(echo "$geonames_response" | jq -r '.postalCodes[0].lat // empty' 2>/dev/null || echo "")
            local lon=$(echo "$geonames_response" | jq -r '.postalCodes[0].lng // empty' 2>/dev/null || echo "")
            
            if [[ -n "$lat" && -n "$lon" && "$lat" != "" && "$lon" != "" && "$lat" != "null" && "$lon" != "null" ]]; then
                coordinates="$lat,$lon"
                source="GeoNames"
            fi
        fi
    fi
    
    # If GeoNames failed, try Google Geocoding API (if API key available)
    if [[ "$coordinates" == "null,null" || "$coordinates" == "," ]] && [[ -n "$GOOGLE_GEOCODING_API_KEY" ]]; then
        echo "    → GeoNames failed, trying Google Geocoding API..." >&2
        sleep 0.5  # Google rate limiting
        
        # Google Geocoding API with country component filtering
        local google_response=$(curl -s "https://maps.googleapis.com/maps/api/geocode/json?components=postal_code:${normalized_pc}|country:CA&key=${GOOGLE_GEOCODING_API_KEY}" 2>/dev/null || echo "")
        
        if [[ -n "$google_response" && "$google_response" != *"error"* ]]; then
            local lat=$(echo "$google_response" | jq -r '.results[0].geometry.location.lat // empty' 2>/dev/null || echo "")
            local lon=$(echo "$google_response" | jq -r '.results[0].geometry.location.lng // empty' 2>/dev/null || echo "")
            
            if [[ -n "$lat" && -n "$lon" && "$lat" != "" && "$lon" != "" && "$lat" != "null" && "$lon" != "null" ]]; then
                coordinates="$lat,$lon"
                source="Google"
            fi
        fi
    fi
    
    # If Google failed or unavailable, try MapBox Geocoding API (if API key available)
    if [[ "$coordinates" == "null,null" || "$coordinates" == "," ]] && [[ -n "$MAPBOX_ACCESS_TOKEN" ]]; then
        echo "    → Trying MapBox Geocoding API..." >&2
        sleep 0.5  # MapBox rate limiting
        
        # MapBox Geocoding API
        local mapbox_response=$(curl -s "https://api.mapbox.com/geocoding/v5/mapbox.places/${normalized_pc}.json?country=CA&access_token=${MAPBOX_ACCESS_TOKEN}" 2>/dev/null || echo "")
        
        if [[ -n "$mapbox_response" && "$mapbox_response" != *"error"* ]]; then
            local lat=$(echo "$mapbox_response" | jq -r '.features[0].center[1] // empty' 2>/dev/null || echo "")
            local lon=$(echo "$mapbox_response" | jq -r '.features[0].center[0] // empty' 2>/dev/null || echo "")
            
            if [[ -n "$lat" && -n "$lon" && "$lat" != "" && "$lon" != "" && "$lat" != "null" && "$lon" != "null" ]]; then
                coordinates="$lat,$lon"
                source="MapBox"
            fi
        fi
    fi
    
    # If all premium services failed, try OpenCage Data (if API key available)
    if [[ "$coordinates" == "null,null" || "$coordinates" == "," ]] && [[ -n "$OPENCAGE_API_KEY" ]]; then
        echo "    → Trying OpenCage Data API..." >&2
        sleep 0.5  # OpenCage rate limiting
        
        # OpenCage Data API
        local opencage_response=$(curl -s "https://api.opencagedata.com/geocode/v1/json?q=${normalized_pc}&countrycode=ca&key=${OPENCAGE_API_KEY}" 2>/dev/null || echo "")
        
        if [[ -n "$opencage_response" && "$opencage_response" != *"error"* ]]; then
            local lat=$(echo "$opencage_response" | jq -r '.results[0].geometry.lat // empty' 2>/dev/null || echo "")
            local lon=$(echo "$opencage_response" | jq -r '.results[0].geometry.lng // empty' 2>/dev/null || echo "")
            
            if [[ -n "$lat" && -n "$lon" && "$lat" != "" && "$lon" != "" && "$lat" != "null" && "$lon" != "null" ]]; then
                coordinates="$lat,$lon"
                source="OpenCage"
            fi
        fi
    fi
    
    # Final fallback: try a simple geographic lookup service
    if [[ "$coordinates" == "null,null" || "$coordinates" == "," ]]; then
        echo "    → Trying final fallback: postal-code lookup..." >&2
        sleep 0.5
        
        # Try a different approach: simple REST API for Canadian postal codes
        local fallback_response=$(curl -s "https://geocoder.ca/?locate=${normalized_pc}&geoit=json" 2>/dev/null || echo "")
        
        if [[ -n "$fallback_response" && "$fallback_response" != *"error"* ]]; then
            local lat=$(echo "$fallback_response" | jq -r '.latt // empty' 2>/dev/null || echo "")
            local lon=$(echo "$fallback_response" | jq -r '.longt // empty' 2>/dev/null || echo "")
            
            if [[ -n "$lat" && -n "$lon" && "$lat" != "" && "$lon" != "" && "$lat" != "null" && "$lon" != "null" ]]; then
                coordinates="$lat,$lon"
                source="geocoder.ca-json"
            fi
        fi
    fi
    
    # Check final result
    if [[ "$coordinates" == "null,null" || "$coordinates" == "," || -z "$coordinates" ]]; then
        FAILED_LOOKUPS=$((FAILED_LOOKUPS + 1))
        echo "    ❌ No coordinates found for $postal_code (tried all available sources)" >&2
        # Add to bogons to prevent future API calls for this postal code
        add_postal_code_to_bogons "$normalized_pc"
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
    
    # Defensive: Remove obvious duplications (same text repeated twice)
    address=$(echo "$address" | sed 's/\(.*\) \1$/\1/')
    employer=$(echo "$employer" | sed 's/\(.*\) \1$/\1/')
    
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
    local bogons_count=$(get_bogons_count)
    
    echo "📍 Geocoding Performance Summary:" >&2
    echo "   Cache entries: $total_entries" >&2
    echo "   Cache hits: $cache_hits" >&2
    echo "   API calls: $api_calls" >&2
    echo "   Failed lookups: $failed_lookups" >&2
    echo "   Bogons (known failures): $bogons_count" >&2
    
    if [[ $api_calls -gt 0 ]]; then
        local success_rate=$(( (api_calls - failed_lookups) * 100 / api_calls ))
        echo "   API success rate: ${success_rate}%" >&2
    fi
    
    if [[ $((cache_hits + api_calls)) -gt 0 ]]; then
        local cache_hit_ratio=$(( cache_hits * 100 / (cache_hits + api_calls) ))
        echo "   Cache hit ratio: ${cache_hit_ratio}%" >&2
    fi
    
    if [[ $bogons_count -gt 0 ]]; then
        echo "   📄 Bogons file: $GEOCODING_BOGONS_FILE" >&2
    fi
}
