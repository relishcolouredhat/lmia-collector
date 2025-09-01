#!/bin/bash

# Environment Loading Script for LMIA Collector
# Safely loads environment variables from .env file if it exists

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load .env file if it exists
ENV_FILE="$PROJECT_ROOT/.env"
if [[ -f "$ENV_FILE" ]]; then
    echo "📄 Loading environment from $ENV_FILE" >&2
    
    # Export variables from .env file
    # This safely handles quotes and special characters
    set -a  # automatically export all variables
    source "$ENV_FILE"
    set +a  # turn off automatic export
    
    echo "✅ Environment loaded successfully" >&2
    
    # Report which API keys are available (without revealing the keys)
    if [[ -n "$GOOGLE_GEOCODING_API_KEY" ]]; then
        echo "   🗝️  Google Geocoding API key available" >&2
    fi
    if [[ -n "$MAPBOX_ACCESS_TOKEN" ]]; then
        echo "   🗝️  MapBox access token available" >&2
    fi
    if [[ -n "$OPENCAGE_API_KEY" ]]; then
        echo "   🗝️  OpenCage API key available" >&2
    fi
else
    echo "⚠️  No .env file found at $ENV_FILE" >&2
    echo "   Copy .env.example to .env and add your API keys for enhanced geocoding" >&2
fi
