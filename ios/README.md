# iOS Build Notes

## "No such module Flutter" in AppDelegate

The Flutter framework is built by the Run Script phase (not CocoaPods). Xcode needs to know where to find it.

1. **Open the workspace, not the project**  
   In Xcode, open **`Runner.xcworkspace`** (not `Runner.xcodeproj`).

2. **Build from the command line first** (so `Flutter.framework` exists before opening Xcode):
   ```bash
   flutter pub get
   cd ios && pod install && cd ..
   flutter build ios
   ```
   Or run the app once: `flutter run -d <device-id>`.

3. **Then open Xcode**: `open ios/Runner.xcworkspace`  
   The `Flutter/Debug.xcconfig` (and Release/Profile) now add the Flutter framework search path so the "No such module Flutter" error goes away.

4. **If the error still appears**: Product → Clean Build Folder (Shift+Cmd+K), then build again (Cmd+B). The first build creates the framework; the second build sees it.
