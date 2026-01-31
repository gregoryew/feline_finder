# Xcode Environment Variables Setup

## Method 1: Add Environment Variables to Xcode Scheme (Recommended)

1. Open Xcode
2. Open the project: `ios/Runner.xcworkspace`
3. Click on the scheme dropdown (next to the Run/Stop buttons)
4. Select "Edit Scheme..."
5. Select "Run" in the left sidebar
6. Go to the "Arguments" tab
7. Under "Environment Variables", click the "+" button
8. Add these three environment variables (use values from your `~/.zshrc`):
   - Name: `GEMINI_API_KEY`, Value: `[your-gemini-key-from-zshrc]`
   - Name: `YOUTUBE_API_KEY`, Value: `[your-youtube-key-from-zshrc]`
   - Name: `GOOGLE_MAPS_API_KEY`, Value: `[your-maps-key-from-zshrc]`
9. Click "Close"

**Note:** This method sets environment variables, but Flutter on iOS may not see them via `Platform.environment`. Use Method 2 for better compatibility.

## Method 2: Use --dart-define in Build Settings (Best for Flutter)

1. Open Xcode
2. Open the project: `ios/Runner.xcworkspace`
3. Select the "Runner" project in the navigator
4. Select the "Runner" target
5. Go to "Build Settings" tab
6. Search for "Other Swift Flags" or "Other C++ Flags"
7. Add these flags:
   ```
   -DGEMINI_API_KEY=$(GEMINI_API_KEY)
   -DYOUTUBE_API_KEY=$(YOUTUBE_API_KEY)
   -DGOOGLE_MAPS_API_KEY=$(GOOGLE_MAPS_API_KEY)
   ```

However, Flutter uses `--dart-define` which is handled differently. See Method 3.

## Method 3: Create a Script to Load from .zshrc (Easiest)

Create a script that Xcode can run to load environment variables from your `~/.zshrc` file.

### Steps:

1. Create a script file: `ios/load_env_vars.sh`
2. Add it to Xcode's build phases
3. The script will source `~/.zshrc` and export variables

See the script below.

## Method 4: Use Flutter's --dart-define in Xcode (Recommended for Flutter)

Since Flutter uses `--dart-define` flags, you need to configure Xcode to pass these to Flutter.

### Option A: Modify the Flutter build script

1. In Xcode, select the "Runner" target
2. Go to "Build Phases"
3. Find "Run Script" phase (usually named "Run Script" or "Thin Binary")
4. Before the Flutter build command, add:
   ```bash
   source ~/.zshrc
   export FLUTTER_BUILD_ARGS="--dart-define=GEMINI_API_KEY=${GEMINI_API_KEY} --dart-define=YOUTUBE_API_KEY=${YOUTUBE_API_KEY} --dart-define=GOOGLE_MAPS_API_KEY=${GOOGLE_MAPS_API_KEY}"
   ```

### Option B: Use a custom build script

See `ios/scripts/load_env_and_build.sh` below.
