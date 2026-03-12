# Feline Finder — iOS Distribution Guide

This guide covers building and submitting **Feline Finder** to the App Store (and TestFlight) on iPhone.

## Prerequisites

- **Apple Developer Program** membership (enrolled at [developer.apple.com](https://developer.apple.com))
- **Xcode** installed (latest stable from Mac App Store)
- **Flutter** installed and `flutter doctor` passing with iOS toolchain
- **Bundle ID** registered in App Store Connect: `com.gregorysiosgames.catapp`
- **App record** created in [App Store Connect](https://appstoreconnect.apple.com) for Feline Finder

## 1. Version and build number

- **Version** (user-facing): set in `pubspec.yaml` as `version: x.y.z+build` (e.g. `6.2.0+7`).
- **Build number** must increase for each upload to App Store Connect (e.g. `6.2.0+8` for the next build).
- iOS uses: `CFBundleShortVersionString` = x.y.z, `CFBundleVersion` = build. Flutter injects these from `pubspec.yaml` via `FLUTTER_BUILD_NAME` and `FLUTTER_BUILD_NUMBER` in the iOS project.

To bump for a new release, edit `pubspec.yaml`:

```yaml
version: 6.2.0+8   # e.g. 6.2.0+8 for build 8
```

## 2. Code signing

- The project uses **Automatic** code signing with **Team ID** `BVC6BMPCPP`.
- In Xcode: **Runner** target → **Signing & Capabilities** → ensure your Apple ID is selected and **Automatically manage signing** is on.
- For **Release** and **Archive**, use an **Apple Distribution** certificate (Xcode can create it when archiving).

## 3. Build an IPA (command line)

From the project root (e.g. `feline_finder/`):

```bash
flutter clean
flutter pub get
flutter build ipa --export-options-plist=ios/ExportOptions.plist
```

- Output: `build/ios/ipa/*.ipa` and the app is ready for upload.
- To upload directly to App Store Connect in one step, you can use:

```bash
flutter build ipa --export-options-plist=ios/ExportOptions.plist
# Then in Xcode: Window → Organizer → Distribute App → App Store Connect → Upload
# Or use: xcrun altool --upload-app -f build/ios/ipa/xxx.ipa -t ios -u YOUR_APPLE_ID -p APP_SPECIFIC_PASSWORD
```

## 4. Build via Xcode (Archive)

1. Open the iOS project:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. Select **Any iOS Device (arm64)** (or a connected device) as the run destination.
3. **Product → Archive**.
4. When the archive appears in the **Organizer**:
   - Click **Distribute App**
   - Choose **App Store Connect** → **Upload**
   - Follow the wizard (signing, options).
5. After upload, the build appears in App Store Connect under **TestFlight** and later under the app’s **App Store** version.

## 5. Export options (ios/ExportOptions.plist)

- `ios/ExportOptions.plist` is set for **App Store** distribution (`method`: `app-store`, `destination`: `upload`).
- **teamID** is set to `BVC6BMPCPP`; change it if your team ID is different.
- Used by: `flutter build ipa --export-options-plist=ios/ExportOptions.plist`.

## 6. App Store Connect and TestFlight

- In [App Store Connect](https://appstoreconnect.apple.com): **My Apps** → **Feline Finder**.
- **TestFlight**: After the first upload, the build appears under the **TestFlight** tab. Add testers and submit for Beta App Review if you want external testers.
- **App Store**: When ready for release, create or select a version, attach the build, fill in metadata (description, screenshots, privacy, etc.), and submit for review.

## 7. Info.plist and compliance

- **ITSAppUsesNonExemptEncryption**: Set to `false` in `Info.plist` (app uses only standard HTTPS; no custom encryption). Required for export compliance.
- **Location usage descriptions**: Already set for “find cats near you”.
- **Network**: `NSAppTransportSecurity` allows arbitrary loads (e.g. images from shelters). If App Review requests it, consider narrowing to specific domains.

## 8. Checklist before first submission

- [ ] Version and build number bumped in `pubspec.yaml`.
- [ ] App icons and launch screen set (Runner/Assets.xcassets, LaunchScreen.storyboard).
- [ ] Signed with Apple Distribution and archived without errors.
- [ ] App Store Connect record created; screenshots and metadata prepared.
- [ ] Privacy policy URL and contact info set in App Store Connect if required.
- [ ] Export compliance (encryption) answered in App Store Connect (e.g. “No” for custom encryption).

## 9. Useful commands

```bash
# Check iOS toolchain
flutter doctor -v

# Clean and get dependencies
flutter clean && flutter pub get

# Build IPA (from project root)
flutter build ipa --export-options-plist=ios/ExportOptions.plist

# Run release build on a connected device
flutter run --release
```

---

For more detail, see [Flutter’s iOS deployment docs](https://docs.flutter.dev/deployment/ios) and [App Store Connect Help](https://help.apple.com/app-store-connect/).
