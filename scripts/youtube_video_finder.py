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

def is_video_relevant(video_title: str, breed: str) -> bool:
    """
    Check if a video title is relevant to the breed.
    Returns True if the breed name (or key terms) appear in the title.
    """
    title_lower = video_title.lower()
    breed_lower = breed.lower()
    
    # Handle special cases with alternative search terms
    breed_terms = {
        'extra-toes cat': ['extra-toes', 'polydactyl', 'extra toes'],
        'havana': ['havana brown', 'havana'],
        'japanese bobtail': ['japanese bobtail', 'japan bobtail'],
        'pixie-bob': ['pixie-bob', 'pixie bob', 'pixiebob'],
        'russian blue': ['russian blue'],
        'scottish fold': ['scottish fold'],
        'turkish van': ['turkish van'],
        'silver': ['silver tabby', 'silver cat breed', 'silver cat'],
        'tabby': ['tabby cat', 'tabby breed', 'tabby'],
        'tortoiseshell': ['tortoiseshell', 'tortie', 'tortoiseshell cat'],
        'tuxedo': ['tuxedo cat', 'tuxedo', 'tuxedo breed'],
        'torbie': ['torbie', 'tortoiseshell tabby', 'torbie cat'],
        'snowshoe': ['snowshoe', 'snowshoe cat'],
        'somali': ['somali', 'somali cat'],
        'sphynx': ['sphynx', 'sphynx cat', 'hairless cat'],
        'tonkinese': ['tonkinese', 'tonkinese cat'],
    }
    
    # Get search terms for this breed
    if breed_lower in breed_terms:
        terms = breed_terms[breed_lower]
    else:
        # For other breeds, use the breed name and common variations
        terms = [breed_lower]
        # Add variations (e.g., "Scottish Fold" -> "scottish fold", "scottishfold")
        if ' ' in breed_lower:
            terms.append(breed_lower.replace(' ', ''))
            terms.append(breed_lower.replace(' ', '-'))
    
    # Check if any term appears in the title
    for term in terms:
        if term in title_lower:
            return True
    
    return False

def find_breed_videos(youtube, breed: str, max_videos: int = 3) -> List[Dict]:
    """
    Find videos for a breed, prioritizing Cats 101.
    Only returns videos that are actually relevant to the breed.
    Returns list of video dictionaries.
    """
    # Handle special cases with alternative search terms
    search_breed_map = {
        'Extra-Toes Cat': 'polydactyl cat',
        'Havana': 'Havana Brown',
        'Silver': 'silver tabby cat breed',
        'Tabby': 'tabby cat breed',
        'Tortoiseshell': 'tortoiseshell cat breed',
        'Tuxedo': 'tuxedo cat breed',
        'Torbie': 'torbie cat tortoiseshell tabby',
    }
    
    search_breed = search_breed_map.get(breed, breed)
    
    # Search queries in priority order
    queries = [
        f'"Cats 101" {search_breed}',  # Use quotes to require exact phrase
        f'Cats 101 {search_breed}',
        f'"{search_breed}" cat breed',
        f'{search_breed} cat breed information',
        f'{search_breed} cat breed facts',
        f'{search_breed} cat characteristics',
    ]
    
    all_videos = []
    seen_ids = set()
    
    # Try each query until we have enough videos
    for query in queries:
        if len(all_videos) >= max_videos:
            break
        
        videos = search_videos(youtube, query, max_results=10)  # Get more to filter
        
        for video in videos:
            if video['id'] in seen_ids:
                continue
            
            # Check if video is relevant to the breed
            if is_video_relevant(video['title'], breed):
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

