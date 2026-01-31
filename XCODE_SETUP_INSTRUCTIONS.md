# Xcode Environment Variables Setup

## ⚠️ Important Note
Flutter on iOS doesn't reliably read `Platform.environment` variables. The best approach is to use `--dart-define` flags, which work via `String.fromEnvironment()`.

## Recommended: Use the Script or Alias

Instead of configuring Xcode, use the provided script or alias:

```bash
# From terminal
cd ~/FelineFinderLive/feline_finder
./run.sh

# Or use the alias
frun
```

This automatically passes the API keys via `--dart-define` flags.

## Alternative: Configure Xcode Scheme (Manual)

If you must run from Xcode, you can add environment variables to the scheme:

### Steps:

1. **Open Xcode**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Edit the Scheme**
   - Click the scheme dropdown (next to Run/Stop buttons)
   - Select "Edit Scheme..."
   - Select "Run" in the left sidebar
   - Go to the "Arguments" tab
   - Under "Environment Variables", click "+"

3. **Add Environment Variables**
   Add these three (use values from your `~/.zshrc`):
   - `GEMINI_API_KEY` = `[your-gemini-key-from-zshrc]`
   - `YOUTUBE_API_KEY` = `[your-youtube-key-from-zshrc]`
   - `GOOGLE_MAPS_API_KEY` = `[your-maps-key-from-zshrc]`

4. **Click "Close"**

### ⚠️ Limitation

Even with environment variables set in Xcode, Flutter on iOS may not see them via `Platform.environment`. The code will still show:
```
Platform.environment["GEMINI_API_KEY"]: "null"
```

**Solution:** Use `--dart-define` flags instead (which the script does automatically).

## Best Practice: Always Use the Script

The `./run.sh` script or `frun` alias is the most reliable way because it:
- Loads keys from `~/.zshrc`
- Passes them via `--dart-define` flags
- Works on all platforms (iOS, Android, etc.)
- Doesn't require Xcode configuration
