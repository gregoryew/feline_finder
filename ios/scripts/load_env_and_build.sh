#!/bin/bash

# Load environment variables from ~/.zshrc
# This script is meant to be called from Xcode build phases

# Source the user's zshrc to get API keys
if [ -f ~/.zshrc ]; then
    source ~/.zshrc
fi

# Export the API keys so they're available to Flutter
export GEMINI_API_KEY="${GEMINI_API_KEY}"
export YOUTUBE_API_KEY="${YOUTUBE_API_KEY}"
export GOOGLE_MAPS_API_KEY="${GOOGLE_MAPS_API_KEY}"

# Print confirmation (first few chars only)
echo "🔑 Loaded API keys:"
echo "   GEMINI_API_KEY: ${GEMINI_API_KEY:0:10}..."
echo "   YOUTUBE_API_KEY: ${YOUTUBE_API_KEY:0:10}..."
echo "   GOOGLE_MAPS_API_KEY: ${GOOGLE_MAPS_API_KEY:0:10}..."

# The Flutter build will use these via --dart-define flags
# Note: You'll need to modify the Flutter build script to use these
