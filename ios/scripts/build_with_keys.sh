#!/bin/bash

# This script loads API keys from ~/.zshrc and passes them to Flutter build
# It modifies the Flutter build command to include --dart-define flags

set -e

# Source the user's zshrc to get API keys
if [ -f ~/.zshrc ]; then
    source ~/.zshrc
fi

# Build the --dart-define flags
DART_DEFINE_FLAGS=""
if [ -n "${GEMINI_API_KEY}" ]; then
    DART_DEFINE_FLAGS="${DART_DEFINE_FLAGS} --dart-define=GEMINI_API_KEY=${GEMINI_API_KEY}"
fi
if [ -n "${YOUTUBE_API_KEY}" ]; then
    DART_DEFINE_FLAGS="${DART_DEFINE_FLAGS} --dart-define=YOUTUBE_API_KEY=${YOUTUBE_API_KEY}"
fi
if [ -n "${GOOGLE_MAPS_API_KEY}" ]; then
    DART_DEFINE_FLAGS="${DART_DEFINE_FLAGS} --dart-define=GOOGLE_MAPS_API_KEY=${GOOGLE_MAPS_API_KEY}"
fi

# Export the flags as an environment variable that xcode_backend.sh can use
# Note: xcode_backend.sh doesn't directly support this, so we'll need to patch it
# For now, we'll modify the Flutter build command directly
export FLUTTER_BUILD_ARGS="${DART_DEFINE_FLAGS}"

# Print confirmation
echo "🔑 Building with API keys..."
if [ -n "${GEMINI_API_KEY}" ]; then
    echo "   GEMINI_API_KEY: ${GEMINI_API_KEY:0:10}..."
fi
if [ -n "${YOUTUBE_API_KEY}" ]; then
    echo "   YOUTUBE_API_KEY: ${YOUTUBE_API_KEY:0:10}..."
fi
if [ -n "${GOOGLE_MAPS_API_KEY}" ]; then
    echo "   GOOGLE_MAPS_API_KEY: ${GOOGLE_MAPS_API_KEY:0:10}..."
fi

# Call the original Flutter build script
# The xcode_backend.sh script will need to be modified to use FLUTTER_BUILD_ARGS
exec /bin/sh "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" build
