#!/usr/bin/env python3
"""
Automated YouTube video finder for cat breeds using YouTube Data API v3.
Searches for "Cats 101" videos first, then alternatives.
Outputs CSV format: breed_name,youtube_title,https_url,youtube_id
"""

import csv
import json
import os
import sys
from typing import List, Dict, Optional

try:
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError
except ImportError:
    print("ERROR: google-api-python-client not installed.")
    print("Install it with: pip3 install google-api-python-client")
    sys.exit(1)

# List of breeds to find videos for
BREEDS = [
    "Cymric",
    "Extra-Toes Cat",
    "Havana",
    "Japanese Bobtail",
    "Korat",
    "LaPerm",
    "Munchkin",
    "Nebelung",
    "Ocicat",
    "Persian",
    "Pixie-Bob",
    "Ragamuffin",
    "Ragdoll",
    "Russian Blue",
    "Scottish Fold",
    "Siberian",
    "Silver",
    "Singapura",
    "Snowshoe",
    "Somali",
    "Sphynx",
    "Tabby",
    "Tonkinese",
    "Torbie",
    "Tortoiseshell",
    "Turkish Van",
    "Tuxedo"
]

def get_youtube_service(api_key: str):
    """Build and return YouTube API service."""
    return build('youtube', 'v3', developerKey=api_key)

def search_videos(youtube, query: str, max_results: int = 3) -> List[Dict]:
    """
    Search YouTube for videos matching the query.
    Returns list of video dictionaries with title, url, and id.
    """
    try:
        request = youtube.search().list(
            part='snippet',
            q=query,
            type='video',
            maxResults=max_results,
            order='viewCount',  # Sort by view count (popularity)
            videoEmbeddable='true',  # Only embeddable videos
            videoSyndicated='true'   # Only videos that can be played outside YouTube
        )
        response = request.execute()
        
        videos = []
        for item in response.get('items', []):
            video_id = item['id']['videoId']
            title = item['snippet']['title']
            url = f"https://www.youtube.com/watch?v={video_id}"
            
            videos.append({
                'title': title,
                'url': url,
                'id': video_id
            })
        
        return videos
    except HttpError as e:
        print(f"Error searching for '{query}': {e}")
        return []

def find_breed_videos(youtube, breed: str, max_videos: int = 3) -> List[Dict]:
    """
    Find videos for a breed, prioritizing Cats 101.
    Returns list of video dictionaries.
    """
    # Search queries in priority order
    queries = [
        f"Cats 101 {breed}",
        f"{breed} cat breed information",
        f"{breed} cat breed facts",
        f"{breed} cat characteristics",
        f"{breed} cat breed guide",
        f"{breed} cat breed"
    ]
    
    all_videos = []
    seen_ids = set()
    
    # Try each query until we have enough videos
    for query in queries:
        if len(all_videos) >= max_videos:
            break
        
        videos = search_videos(youtube, query, max_results=max_videos)
        
        for video in videos:
            if video['id'] not in seen_ids:
                all_videos.append(video)
                seen_ids.add(video['id'])
                
                if len(all_videos) >= max_videos:
                    break
    
    return all_videos[:max_videos]

def main():
    # Get API key from environment or user input
    api_key = os.environ.get('YOUTUBE_API_KEY')
    
    if not api_key:
        print("=" * 80)
        print("YouTube Data API Key Required")
        print("=" * 80)
        print("\nTo get a YouTube Data API key:")
        print("1. Go to https://console.cloud.google.com/")
        print("2. Create a new project or select an existing one")
        print("3. Enable 'YouTube Data API v3'")
        print("4. Go to 'Credentials' and create an API key")
        print("5. Set it as an environment variable:")
        print("   export YOUTUBE_API_KEY='your-api-key-here'")
        print("\nOr enter it now (it will not be saved):")
        api_key = input("YouTube API Key: ").strip()
        
        if not api_key:
            print("ERROR: API key is required.")
            sys.exit(1)
    
    print("\n" + "=" * 80)
    print("Searching YouTube for cat breed videos...")
    print("=" * 80 + "\n")
    
    # Build YouTube service
    try:
        youtube = get_youtube_service(api_key)
    except Exception as e:
        print(f"ERROR: Failed to initialize YouTube API: {e}")
        sys.exit(1)
    
    # Find videos for each breed
    results = []
    
    for i, breed in enumerate(BREEDS, 1):
        print(f"[{i}/{len(BREEDS)}] Searching for: {breed}...", end=' ', flush=True)
        
        videos = find_breed_videos(youtube, breed, max_videos=3)
        
        if videos:
            print(f"Found {len(videos)} video(s)")
            for video in videos:
                results.append({
                    'breed': breed,
                    'title': video['title'],
                    'url': video['url'],
                    'id': video['id']
                })
        else:
            print("No videos found")
    
    # Sort by breed name
    results.sort(key=lambda x: x['breed'])
    
    # Write to CSV file
    output_file = 'breed_videos.csv'
    with open(output_file, 'w', newline='', encoding='utf-8') as csvfile:
        fieldnames = ['breed_name', 'youtube_title', 'https_url', 'youtube_id']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        
        writer.writeheader()
        for result in results:
            writer.writerow({
                'breed_name': result['breed'],
                'youtube_title': result['title'],
                'https_url': result['url'],
                'youtube_id': result['id']
            })
    
    # Also print to console
    print("\n" + "=" * 80)
    print("RESULTS (CSV Format)")
    print("=" * 80)
    print("breed_name,youtube_title,https_url,youtube_id")
    for result in results:
        # Escape commas in titles
        title = result['title'].replace(',', ';')
        print(f"{result['breed']},{title},{result['url']},{result['id']}")
    
    print(f"\n\nResults saved to: {output_file}")
    print(f"Total videos found: {len(results)}")
    
    # Summary by breed
    breed_counts = {}
    for result in results:
        breed_counts[result['breed']] = breed_counts.get(result['breed'], 0) + 1
    
    print("\nVideos per breed:")
    for breed in sorted(breed_counts.keys()):
        print(f"  {breed}: {breed_counts[breed]} video(s)")

if __name__ == "__main__":
    main()

