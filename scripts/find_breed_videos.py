#!/usr/bin/env python3
"""
Script to find YouTube videos for cat breeds.
Searches for "Cats 101" videos first, then alternative breed explanation videos.
"""

import json
import sys
import os

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

def generate_search_queries(breed):
    """Generate search queries for a breed, prioritizing Cats 101."""
    queries = [
        f"Cats 101 {breed}",
        f"{breed} cat breed information",
        f"{breed} cat breed facts",
        f"{breed} cat characteristics",
        f"{breed} cat breed guide"
    ]
    return queries

def generate_youtube_urls(breed):
    """Generate YouTube search URLs for manual searching."""
    queries = generate_search_queries(breed)
    urls = []
    for query in queries:
        # URL encode the query
        encoded_query = query.replace(' ', '+').replace('-', '+')
        url = f"https://www.youtube.com/results?search_query={encoded_query}"
        urls.append((query, url))
    return urls

def main():
    print("=" * 80)
    print("YouTube Video Finder for Cat Breeds")
    print("=" * 80)
    print("\nThis script helps you find YouTube videos for cat breeds.")
    print("For each breed, search YouTube using the queries below.")
    print("Prioritize 'Cats 101' videos, then look for popular breed explanation videos.\n")
    
    results = {}
    
    for breed in BREEDS:
        print(f"\n{'='*80}")
        print(f"BREED: {breed}")
        print(f"{'='*80}")
        
        queries = generate_search_queries(breed)
        urls = generate_youtube_urls(breed)
        
        print("\nSearch Queries (in order of priority):")
        for i, (query, url) in enumerate(urls, 1):
            print(f"  {i}. {query}")
            print(f"     URL: {url}")
        
        print("\nManual Steps:")
        print("  1. Open the first search URL (Cats 101)")
        print("  2. Look for videos with:")
        print("     - 'Cats 101' in the title (preferred)")
        print("     - High view count (popular)")
        print("     - Breed explanation/education content")
        print("     - Embedding enabled (check Share > Embed)")
        print("  3. Copy the video URL (watch?v=VIDEO_ID)")
        print("  4. Repeat for 2-3 videos per breed")
        
        # Store for output
        results[breed] = {
            "queries": queries,
            "urls": [url for _, url in urls]
        }
    
    # Save results to JSON file
    output_file = "breed_video_search_results.json"
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\n\n{'='*80}")
    print(f"Search URLs saved to: {output_file}")
    print(f"{'='*80}")
    print("\nNext Steps:")
    print("1. Use the search URLs above to find videos on YouTube")
    print("2. For each breed, find 1-3 videos that:")
    print("   - Are embeddable (check Share > Embed option)")
    print("   - Have high view counts (popular)")
    print("   - Explain the breed (like Cats 101)")
    print("3. Copy the full YouTube URL (e.g., https://www.youtube.com/watch?v=VIDEO_ID)")
    print("4. Update the breed.dart file with the cats101URL field")
    
    return results

if __name__ == "__main__":
    main()



