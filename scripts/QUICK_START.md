# Quick Start: YouTube Video Finder

## 1. Install Dependencies

```bash
pip3 install google-api-python-client
```

## 2. Get YouTube API Key

1. Visit: https://console.cloud.google.com/
2. Create/select a project
3. Enable "YouTube Data API v3"
4. Create an API key in "Credentials"

## 3. Set API Key

```bash
export YOUTUBE_API_KEY='your-api-key-here'
```

## 4. Run Script

```bash
cd /Users/gregoryedwardwilliams/FelineFinderLive/feline_finder
python3 scripts/youtube_video_finder.py
```

## Output

The script creates `breed_videos.csv` with format:
```
breed_name,youtube_title,https_url,youtube_id
```

One line per video, sorted by breed name.

## Example Output

```
breed_name,youtube_title,https_url,youtube_id
Persian,Cats 101 - Persian,https://www.youtube.com/watch?v=abc123,abc123
Persian,Persian Cat Breed Guide,https://www.youtube.com/watch?v=def456,def456
Ragdoll,Cats 101 - Ragdoll,https://www.youtube.com/watch?v=ghi789,ghi789
```

See `README_YOUTUBE_API.md` for detailed instructions.

