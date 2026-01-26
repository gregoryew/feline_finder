# YouTube Video Test Report

## Test Results Summary

**Test Date:** $(date)
**Total Breeds:** 65

### Key Findings

1. **cats101URL field** - This is the primary field used in the app (via `widget.breed.cats101URL`)
   - Most videos in this field are playable
   - This is the field displayed on the breed detail screen

2. **youTubeURL field** - Many videos in this field are returning 404 errors
   - This field appears to contain older/outdated video IDs
   - Not directly used in the breed detail screen display

### Recommendations

1. **Focus on cats101URL** - Since this is what's actually displayed, ensure all cats101URL values are valid
2. **Update youTubeURL** - Consider updating or removing invalid youTubeURL values
3. **Verify in app** - Test actual video playback in the app to confirm functionality

## How to Run the Test

```bash
cd feline_finder
python3 scripts/test_youtube_videos.py
```

## Next Steps

1. Review the detailed error list from the test output
2. Update any invalid cats101URL values
3. Test video playback in the actual app
4. Consider using YouTube Data API v3 for more reliable checking (requires API key)
