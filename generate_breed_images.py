#!/usr/bin/env python3
"""
Script to generate breed headshots using DALL-E API
Reads breeds from lib/models/breed.dart and generates images for each breed
"""

import re
import os
import requests
import time
from openai import OpenAI
from PIL import Image
import io

# Configuration
# API key should be set as environment variable: OPENAI_API_KEY
API_KEY = os.getenv("OPENAI_API_KEY")
if not API_KEY:
    raise ValueError("OPENAI_API_KEY environment variable is required")
BREED_FILE = "lib/models/breed.dart"
OUTPUT_DIR = "assets/Cartoon2"
DELAY_BETWEEN_REQUESTS = 2  # seconds (DALL-E 3 has rate limits)
TARGET_SIZE = (512, 512)  # Target image size

def extract_breeds_from_dart(file_path):
    """Extract breed names and pictureHeadShotNames from breed.dart"""
    breeds = []
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Pattern to match Breed constructor: Breed(id, name, sortOrder, htmlUrl, pictureHeadShotName, ...)
    # We need to capture the name (2nd param) and pictureHeadShotName (5th param)
    pattern = r"Breed\(\s*(\d+),\s*'([^']+)',\s*[^,]+,\s*[^,]+,\s*'([^']+)',"
    
    matches = re.finditer(pattern, content)
    for match in matches:
        breed_id = int(match.group(1))
        name = match.group(2)
        picture_headshot_name = match.group(3)
        
        breeds.append({
            'id': breed_id,
            'name': name,
            'pictureHeadShotName': picture_headshot_name
        })
    
    return breeds

def generate_prompt(breed_name):
    """Generate a detailed prompt for DALL-E with solid, realistic style"""
    return f"""A face-forward headshot portrait of a {breed_name} cat in a solid, realistic style. 
Photorealistic rendering with natural fur texture and solid, defined features. 
The cat should look like a real {breed_name} breed with accurate proportions, colors, and markings. 
Natural lighting with soft shadows. 
Expressive, realistic eyes with natural reflections. 
Solid, well-defined form with realistic fur rendering. 
Clean, professional photography style. 
Solid white or neutral background. 
The cat should be definitively recognizable as a {breed_name} breed with realistic breed characteristics. 
High quality, 512x512 pixels, PNG format."""

def generate_image_with_dalle(client, prompt):
    """Call DALL-E 3 API to generate image"""
    try:
        print(f"    Calling DALL-E API...")
        response = client.images.generate(
            model="dall-e-3",
            prompt=prompt,
            size="1024x1024",  # DALL-E 3 outputs 1024x1024, we'll resize
            quality="standard",
            n=1,
        )
        return response.data[0].url
    except Exception as e:
        print(f"    Error generating image: {e}")
        return None

def download_and_resize_image(url, filepath, target_size=(512, 512)):
    """Download image from URL, resize to target size, and save as PNG"""
    try:
        # Download image
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        
        # Open image with PIL
        img = Image.open(io.BytesIO(response.content))
        
        # Convert to RGB if necessary (for PNG with transparency)
        if img.mode in ('RGBA', 'LA', 'P'):
            # Keep transparency if present
            img = img.convert('RGBA')
        else:
            img = img.convert('RGB')
        
        # Resize to target size (512x512)
        img_resized = img.resize(target_size, Image.Resampling.LANCZOS)
        
        # Save as PNG
        img_resized.save(filepath, 'PNG', optimize=True)
        return True
    except Exception as e:
        print(f"    Error downloading/resizing image: {e}")
        return False

def main():
    # Initialize OpenAI client
    print("Initializing OpenAI client...")
    client = OpenAI(api_key=API_KEY)
    
    # Verify output directory exists
    if not os.path.exists(OUTPUT_DIR):
        print(f"Creating output directory: {OUTPUT_DIR}")
        os.makedirs(OUTPUT_DIR, exist_ok=True)
    else:
        print(f"Output directory: {OUTPUT_DIR}")
    
    # Extract breeds
    print(f"\nExtracting breeds from {BREED_FILE}...")
    breeds = extract_breeds_from_dart(BREED_FILE)
    print(f"Found {len(breeds)} breeds\n")
    
    # Track statistics
    successful = 0
    failed = 0
    skipped = 0
    
    # Process each breed
    for i, breed in enumerate(breeds, 1):
        breed_name = breed['name']
        picture_name = breed['pictureHeadShotName']
        # Replace spaces with underscores and ensure .png extension
        filename = picture_name.replace(' ', '_') + '.png'
        filepath = os.path.join(OUTPUT_DIR, filename)
        
        # Skip if already exists
        if os.path.exists(filepath):
            print(f"[{i}/{len(breeds)}] ⏭️  Skipping {breed_name} (already exists: {filename})")
            skipped += 1
            continue
        
        print(f"[{i}/{len(breeds)}] 🐱 Generating {breed_name}...")
        print(f"    Filename: {filename}")
        
        # Generate prompt
        prompt = generate_prompt(breed_name)
        print(f"    Prompt: {prompt[:80]}...")
        
        # Generate image
        image_url = generate_image_with_dalle(client, prompt)
        if not image_url:
            print(f"    ❌ Failed to generate image for {breed_name}")
            failed += 1
            continue
        
        # Download, resize, and save
        print(f"    Downloading and processing...")
        if download_and_resize_image(image_url, filepath, TARGET_SIZE):
            print(f"    ✅ Saved to {filepath}")
            successful += 1
        else:
            print(f"    ❌ Failed to save {breed_name}")
            failed += 1
        
        # Rate limiting delay (except for last item)
        if i < len(breeds):
            print(f"    ⏳ Waiting {DELAY_BETWEEN_REQUESTS} seconds...")
            time.sleep(DELAY_BETWEEN_REQUESTS)
        print()
    
    # Summary
    print("\n" + "="*60)
    print("SUMMARY")
    print("="*60)
    print(f"Total breeds: {len(breeds)}")
    print(f"✅ Successful: {successful}")
    print(f"⏭️  Skipped: {skipped}")
    print(f"❌ Failed: {failed}")
    print(f"\nImages saved to: {OUTPUT_DIR}")

if __name__ == "__main__":
    main()

