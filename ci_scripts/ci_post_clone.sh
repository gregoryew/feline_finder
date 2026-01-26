#!/bin/bash

set -e

echo "🔧 Setting up Flutter for Xcode Cloud..."

# Navigate to the Flutter project directory
cd "$CI_WORKSPACE"

# Get Flutter dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Precache iOS artifacts (generates Generated.xcconfig)
echo "📱 Precaching iOS artifacts..."
flutter precache --ios

# Install CocoaPods dependencies
echo "🍫 Updating CocoaPods specs repository..."
pod repo update

echo "🍫 Installing CocoaPods dependencies..."
cd ios
# Use --repo-update to ensure specs are fresh and handle version conflicts
pod install --repo-update
cd ..

echo "✅ Setup complete!"
