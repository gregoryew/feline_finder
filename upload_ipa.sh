#!/bin/bash

# Upload IPA to TestFlight using xcrun altool
# Usage: ./upload_ipa.sh [APPLE_ID] [APP_SPECIFIC_PASSWORD]
#
# To create an App-Specific Password:
# 1. Go to https://appleid.apple.com
# 2. Sign in with your Apple ID
# 3. Go to "Sign-In and Security" > "App-Specific Passwords"
# 4. Generate a new password for "Xcode" or "App Store Connect API"
# 5. Use that password here (not your regular Apple ID password)

set -e

IPA_PATH="build/ios/ipa/Feline Finder.ipa"

if [ ! -f "$IPA_PATH" ]; then
    echo "❌ Error: IPA file not found at $IPA_PATH"
    echo "Please run ./build_ipa.sh first to create the IPA"
    exit 1
fi

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: ./upload_ipa.sh [APPLE_ID] [APP_SPECIFIC_PASSWORD]"
    echo ""
    echo "Example:"
    echo "  ./upload_ipa.sh your.email@example.com abcd-efgh-ijkl-mnop"
    echo ""
    echo "To create an App-Specific Password:"
    echo "1. Go to https://appleid.apple.com"
    echo "2. Sign in with your Apple ID"
    echo "3. Go to 'Sign-In and Security' > 'App-Specific Passwords'"
    echo "4. Generate a new password for 'Xcode' or 'App Store Connect API'"
    exit 1
fi

APPLE_ID="$1"
APP_PASSWORD="$2"

echo "📤 Uploading Feline Finder.ipa to App Store Connect..."
echo "   Apple ID: $APPLE_ID"
echo "   IPA: $IPA_PATH"
echo ""

xcrun altool --upload-app \
    --type ios \
    --file "$IPA_PATH" \
    --username "$APPLE_ID" \
    --password "$APP_PASSWORD"

echo ""
echo "✅ Upload complete! Check App Store Connect for processing status."
