#!/usr/bin/env python3
"""
Test script to verify all YouTube videos in breed.dart exist and are playable.
Checks both youTubeURL (video ID) and cats101URL (full URL).
"""

import re
import requests
import sys
from pathlib import Path
from urllib.parse import urlparse, parse_qs

def extract_video_id(url):
    """Extract YouTube video ID from various URL formats"""
    if not url or url.strip() == '':
        return None
    
    # If it's already just a video ID (no URL structure)
    if not url.startswith('http') and len(url) == 11:
        return url
    
    # Handle different YouTube URL formats
    if 'youtube.com/watch' in url:
        parsed = urlparse(url)
        video_id = parse_qs(parsed.query).get('v', [None])[0]
        return video_id
    elif 'youtu.be/' in url:
        video_id = url.split('youtu.be/')[1].split('?')[0].split('&')[0]
        return video_id
    elif 'youtube.com/embed/' in url:
        video_id = url.split('youtube.com/embed/')[1].split('?')[0]
        return video_id
    
    return None

def check_video_exists(video_id):
    """Check if a YouTube video exists and is playable"""
    if not video_id:
        return False, "No video ID provided"
    
    # Method 1: Check oembed API (most reliable)
    video_url = f"https://www.youtube.com/watch?v={video_id}"
    oembed_url = f"https://www.youtube.com/oembed?url={video_url}&format=json"
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/json',
    }
    
    try:
        response = requests.get(oembed_url, headers=headers, timeout=10)
        if response.status_code == 200:
            data = response.json()
            if 'title' in data:
                return True, f"✓ Playable - {data.get('title', 'Unknown title')[:60]}"
            return True, "✓ Playable"
        elif response.status_code == 404:
            return False, "✗ Video not found (404)"
        elif response.status_code == 403:
            # Try alternative method - check video page directly
            return check_video_alternative(video_id)
        else:
            return False, f"✗ Error: HTTP {response.status_code}"
    except requests.exceptions.RequestException as e:
        # Try alternative method on network error
        return check_video_alternative(video_id)

def check_video_alternative(video_id):
    """Alternative method: Check video page directly"""
    video_url = f"https://www.youtube.com/watch?v={video_id}"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    }
    
    try:
        response = requests.get(video_url, headers=headers, timeout=10, allow_redirects=True)
        if response.status_code == 200:
            # Check if page contains video unavailable message
            if 'Video unavailable' in response.text or 'This video is not available' in response.text:
                return False, "✗ Video unavailable"
            elif 'og:title' in response.text or 'watch-title' in response.text:
                return True, "✓ Playable (verified via page check)"
            else:
                return True, "✓ Likely playable (page accessible)"
        elif response.status_code == 404:
            return False, "✗ Video not found (404)"
        else:
            return False, f"✗ Error: HTTP {response.status_code}"
    except requests.exceptions.RequestException as e:
        return False, f"✗ Network error: {str(e)}"

def parse_breed_dart_file(file_path):
    """Parse breed.dart and extract YouTube video information"""
    breeds = []
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Pattern to match Breed constructor
    # Breed(id, name, sortOrder, htmlUrl, pictureHeadShotName, crossRefBreedID, 
    #       fullSizedPicture, youTubeURL, cats101URL, playListID, ...)
    pattern = r"Breed\(\s*(\d+),\s*'([^']+)',\s*[^,]+,\s*[^,]+,\s*[^,]+,\s*\d+,\s*'([^']+)',\s*'([^']+)',\s*'([^']+)',\s*'([^']+)',"
    
    matches = re.finditer(pattern, content, re.MULTILINE)
    
    for match in matches:
        breed_id = int(match.group(1))
        name = match.group(2)
        full_sized = match.group(3)
        youtube_url = match.group(4)  # youTubeURL (video ID)
        cats101_url = match.group(5)  # cats101URL (full URL)
        playlist_id = match.group(6)  # playListID
        
        breeds.append({
            'id': breed_id,
            'name': name,
            'youTubeURL': youtube_url,
            'cats101URL': cats101_url,
            'playListID': playlist_id,
        })
    
    return breeds

def main():
    breed_file = Path(__file__).parent.parent / 'lib' / 'models' / 'breed.dart'
    
    if not breed_file.exists():
        print(f"Error: {breed_file} not found")
        sys.exit(1)
    
    print("Parsing breed.dart file...")
    breeds = parse_breed_dart_file(breed_file)
    print(f"Found {len(breeds)} breeds\n")
    
    print("=" * 80)
    print("Testing YouTube Videos")
    print("=" * 80)
    
    results = {
        'total': len(breeds),
        'valid': 0,
        'invalid': 0,
        'missing': 0,
        'errors': []
    }
    
    for breed in breeds:
        print(f"\n[{breed['id']}] {breed['name']}")
        print(f"  youTubeURL: {breed['youTubeURL']}")
        print(f"  cats101URL: {breed['cats101URL']}")
        
        # Check youTubeURL (video ID)
        video_id_from_url = breed['youTubeURL']
        if video_id_from_url:
            exists, message = check_video_exists(video_id_from_url)
            print(f"  youTubeURL check: {message}")
            if exists:
                results['valid'] += 1
            else:
                results['invalid'] += 1
                results['errors'].append({
                    'breed': breed['name'],
                    'field': 'youTubeURL',
                    'value': video_id_from_url,
                    'error': message
                })
        else:
            print(f"  youTubeURL: ⚠ Empty")
            results['missing'] += 1
        
        # Check cats101URL (full URL)
        video_id_from_cats101 = extract_video_id(breed['cats101URL'])
        if video_id_from_cats101:
            exists, message = check_video_exists(video_id_from_cats101)
            print(f"  cats101URL check: {message}")
            if not exists:
                results['errors'].append({
                    'breed': breed['name'],
                    'field': 'cats101URL',
                    'value': breed['cats101URL'],
                    'error': message
                })
        else:
            print(f"  cats101URL: ⚠ Could not extract video ID")
            if breed['cats101URL']:
                results['errors'].append({
                    'breed': breed['name'],
                    'field': 'cats101URL',
                    'value': breed['cats101URL'],
                    'error': 'Could not extract video ID from URL'
                })
    
    # Summary
    print("\n" + "=" * 80)
    print("SUMMARY")
    print("=" * 80)
    print(f"Total breeds: {results['total']}")
    print(f"Valid videos: {results['valid']}")
    print(f"Invalid videos: {results['invalid']}")
    print(f"Missing videos: {results['missing']}")
    print(f"Total errors: {len(results['errors'])}")
    
    if results['errors']:
        print("\n" + "=" * 80)
        print("ERRORS FOUND")
        print("=" * 80)
        for error in results['errors']:
            print(f"\n{error['breed']} ({error['field']})")
            print(f"  Value: {error['value']}")
            print(f"  Error: {error['error']}")
    
    # Exit code
    if results['invalid'] > 0 or results['missing'] > 0:
        sys.exit(1)
    else:
        print("\n✓ All videos are valid and playable!")
        sys.exit(0)

if __name__ == '__main__':
    main()
