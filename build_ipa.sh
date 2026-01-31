#!/bin/bash

# Build IPA for TestFlight with API keys
# Usage: ./build_ipa.sh

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

echo "🔑 Building IPA with API keys..."
echo "   GEMINI_API_KEY: ${GEMINI_API_KEY:0:10}..."
echo "   YOUTUBE_API_KEY: ${YOUTUBE_API_KEY:0:10}..."
echo "   GOOGLE_MAPS_API_KEY: ${GOOGLE_MAPS_API_KEY:0:10}..."
echo ""

# Build the IPA with --dart-define flags
flutter build ipa --release \
    --dart-define=GEMINI_API_KEY="${GEMINI_API_KEY}" \
    --dart-define=YOUTUBE_API_KEY="${YOUTUBE_API_KEY}" \
    --dart-define=GOOGLE_MAPS_API_KEY="${GOOGLE_MAPS_API_KEY}"

echo ""
echo "✅ IPA built successfully!"
echo "📦 Location: build/ios/ipa/Feline Finder.ipa"
echo ""
echo "Next steps:"
echo "1. Open Xcode"
echo "2. Go to Window > Organizer"
echo "3. Click 'Distribute App' (or use Transporter app)"
echo "4. Select: build/ios/ipa/Feline Finder.ipa"
echo "5. Choose 'App Store Connect'"
echo "6. Upload to TestFlight"
