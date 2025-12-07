# YouTube Video Finder Setup Guide

This script automatically searches YouTube for cat breed videos using the YouTube Data API v3.

## Prerequisites

1. **Python 3.6+** (already installed on your system)
2. **Google Cloud Account** (free tier is sufficient)
3. **YouTube Data API Key**

## Step 1: Get YouTube Data API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (or select an existing one)
   - Click "Select a project" → "New Project"
   - Give it a name like "FelineFinder-YouTube"
   - Click "Create"
3. Enable YouTube Data API v3:
   - Go to "APIs & Services" → "Library"
   - Search for "YouTube Data API v3"
   - Click on it and press "Enable"
4. Create API Key:
   - Go to "APIs & Services" → "Credentials"
   - Click "Create Credentials" → "API Key"
   - Copy the API key (you'll need it in Step 2)
   - Optional: Restrict the key to "YouTube Data API v3" for security

## Step 2: Install Python Dependencies

```bash
pip3 install google-api-python-client
```

Or if you prefer using a virtual environment:

```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install google-api-python-client
```

## Step 3: Set API Key

**Option A: Environment Variable (Recommended)**
```bash
export YOUTUBE_API_KEY='your-api-key-here'
```

**Option B: Enter when prompted**
The script will ask for the API key if it's not set as an environment variable.

## Step 4: Run the Script

```bash
cd /Users/gregoryedwardwilliams/FelineFinderLive/feline_finder
python3 scripts/youtube_video_finder.py
```

## Output

The script will:
1. Search YouTube for each breed (prioritizing "Cats 101" videos)
2. Find up to 3 embeddable videos per breed
3. Output a CSV file: `breed_videos.csv`
4. Display results in the console

## CSV Format

The output CSV has the following format:
```csv
breed_name,youtube_title,https_url,youtube_id
Persian,Cats 101 - Persian,https://www.youtube.com/watch?v=VIDEO_ID,VIDEO_ID
Persian,Persian Cat Breed Information,https://www.youtube.com/watch?v=VIDEO_ID2,VIDEO_ID2
...
```

## Notes

- The script only finds **embeddable** videos (can be played in your app)
- Videos are sorted by view count (most popular first)
- Searches prioritize "Cats 101" videos, then alternatives
- If a breed has no "Cats 101" video, it will find alternative breed explanation videos
- The script respects YouTube API rate limits (100 units per 100 seconds per user)

## Troubleshooting

**Error: "google-api-python-client not installed"**
- Run: `pip3 install google-api-python-client`

**Error: "API key not valid"**
- Verify your API key in Google Cloud Console
- Make sure YouTube Data API v3 is enabled
- Check that the API key isn't restricted incorrectly

**Error: "Quota exceeded"**
- YouTube API has a default quota of 10,000 units per day
- Each search uses ~100 units
- For 27 breeds × 3 videos = ~8,100 units (well within limit)
- If you hit the limit, wait 24 hours or request a quota increase

**No videos found for a breed**
- Some breeds may not have "Cats 101" videos
- The script will try alternative search terms
- You may need to manually search for rare breeds

