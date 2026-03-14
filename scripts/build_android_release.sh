#!/usr/bin/env bash
# Build deployable Android release artifacts (AAB for Play Store, APK for direct install).
# Run from project root: ./scripts/build_android_release.sh
# Requires: Flutter SDK, Android SDK, and android/key.properties + upload-keystore.jks for signing.

set -e
cd "$(dirname "$0")/.."

export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$PWD/android/.gradle-user-home}"
mkdir -p "$GRADLE_USER_HOME"
echo "Using GRADLE_USER_HOME=$GRADLE_USER_HOME"

echo ">>> flutter pub get"
flutter pub get

echo ">>> Building release App Bundle (AAB) for Play Store..."
flutter build appbundle --release

echo ">>> Building release APK for direct install..."
flutter build apk --release

echo ""
echo "Done. Deployable artifacts:"
echo "  AAB (Play Store): build/app/outputs/bundle/release/app-release.aab"
echo "  APK (sideload):   build/app/outputs/flutter-apk/app-release.apk"
ls -la build/app/outputs/bundle/release/app-release.aab 2>/dev/null || true
ls -la build/app/outputs/flutter-apk/app-release.apk 2>/dev/null || true
