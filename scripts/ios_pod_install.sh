#!/usr/bin/env bash
# Update CocoaPods specs and install iOS pods. Run this if you see
# "CocoaPods could not find compatible versions for pod Firebase/Functions"
# or "specs repository is too out-of-date". Then run: flutter run -d <device>
# From project root: ./scripts/ios_pod_install.sh

set -e
cd "$(dirname "$0")/.."

echo ">>> Updating CocoaPods specs (so Firebase 12.9.0 and others are available)..."
cd ios
pod repo update

echo ">>> Installing pods..."
pod install

echo "Done. You can now run: flutter run -d <your-ios-device-id>"
