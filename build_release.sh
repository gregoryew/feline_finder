#!/bin/bash

# Build iOS release with API keys (for device install or archive)
# Usage: ./build_release.sh
# Then install: flutter install --release -d <device-id>

set -e

cd "$(dirname "$0")"

# Source environment variables from ~/.zshrc
if [ -f ~/.zshrc ]; then
    source ~/.zshrc
fi

# Verify API keys are set
if [ -z "${GEMINI_API_KEY}" ] || [ -z "${YOUTUBE_API_KEY}" ] || [ -z "${GOOGLE_MAPS_API_KEY}" ]; then
    echo "❌ Error: API keys not found in ~/.zshrc"
    echo "Please ensure GEMINI_API_KEY, YOUTUBE_API_KEY, and GOOGLE_MAPS_API_KEY are set"
    exit 1
fi

echo "🔑 Building iOS release with API keys..."
echo "   GEMINI_API_KEY: ${GEMINI_API_KEY:0:10}..."
echo "   YOUTUBE_API_KEY: ${YOUTUBE_API_KEY:0:10}..."
echo "   GOOGLE_MAPS_API_KEY: ${GOOGLE_MAPS_API_KEY:0:10}..."
echo ""

flutter build ios --release \
    --dart-define=GEMINI_API_KEY="${GEMINI_API_KEY}" \
    --dart-define=YOUTUBE_API_KEY="${YOUTUBE_API_KEY}" \
    --dart-define=GOOGLE_MAPS_API_KEY="${GOOGLE_MAPS_API_KEY}"

echo ""
echo "✅ Release build complete!"
echo "Install on device: flutter install --release -d <device-id>"
echo "List devices: flutter devices"
