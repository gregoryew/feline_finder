# API Key Rotation Guide

## Exposed Keys in Git History

The following API keys were previously committed to git and are visible in git history:

- **Gemini API Key**: `[OLD_KEY]` (ALREADY LEAKED - MUST REGENERATE)
- **YouTube API Key**: `[OLD_KEY]`
- **Google Maps API Key**: `[OLD_KEY]`

**Note**: Actual key values have been removed from this document for security.

## Action Required: Rotate All Keys

### 1. Gemini API Key (CRITICAL - Already Leaked)
- **Status**: Google detected this key as leaked
- **Action**: MUST regenerate immediately
- **Link**: https://aistudio.google.com/app/apikey
- **Steps**:
  1. Go to the link above
  2. Delete the old key
  3. Create a new key
  4. Update `~/.zshrc` with the new key

### 2. YouTube API Key
- **Action**: Regenerate to be safe
- **Link**: https://console.cloud.google.com/apis/credentials
- **Steps**:
  1. Go to Google Cloud Console
  2. Navigate to APIs & Services → Credentials
  3. Find your YouTube Data API v3 key
  4. Click "Regenerate" or create a new one
  5. Update `~/.zshrc` with the new key

### 3. Google Maps API Key
- **Action**: Regenerate to be safe
- **Link**: https://console.cloud.google.com/apis/credentials
- **Steps**:
  1. Go to Google Cloud Console
  2. Navigate to APIs & Services → Credentials
  3. Find your Maps API key
  4. Click "Regenerate" or create a new one
  5. Update `~/.zshrc` with the new key

## After Rotating Keys

1. Update `~/.zshrc`:
   ```bash
   export GEMINI_API_KEY=your-new-gemini-key
   export YOUTUBE_API_KEY=your-new-youtube-key
   export GOOGLE_MAPS_API_KEY=your-new-maps-key
   ```

2. Reload environment:
   ```bash
   source ~/.zshrc
   ```

3. Test the app to ensure everything works

## Note About Git History

The old keys remain in git history but are now invalid. This is acceptable because:
- The keys are rotated and no longer work
- Rewriting git history is complex and risky
- Current code uses environment variables (secure)

## Future Prevention

- ✅ API keys now use environment variables
- ✅ No hardcoded keys in current code
- ✅ Documentation updated to not expose keys
