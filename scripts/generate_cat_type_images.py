#!/usr/bin/env python3
"""
Generate DALL-E 3 images for each cat type in cat_types.json.
Uses the Felix mascot from splash_screen.png for consistency.
Combines overall_prompt + each type's prompt. Output: 512x512 PNG in assets/cat_types/.
"""

import base64
import io
import json
import os
import re
import time
from pathlib import Path

from dotenv import load_dotenv
from openai import OpenAI
from PIL import Image
import requests

# Project root (parent of scripts/)
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
load_dotenv(PROJECT_ROOT / ".env")

API_KEY = os.getenv("OPENAI_API_KEY")
if not API_KEY:
    raise ValueError("OPENAI_API_KEY not set. Add it to .env or environment.")

CAT_TYPES_JSON = PROJECT_ROOT / "test" / "cat_types.json"
OUTPUT_DIR = PROJECT_ROOT / "assets" / "cat_types"
SPLASH_IMAGE = PROJECT_ROOT / "assets" / "splash" / "splash_screen.png"
OUTPUT_SIZE = (512, 512)
DELAY_BETWEEN_REQUESTS = 2  # seconds
MAX_RETRIES = 3
INITIAL_BACKOFF = 5  # seconds
MAX_TYPES = 5  # Generate images for only this many types

# Cached DALL-E–oriented description of Felix from splash image (from vision)
FELIX_DESCRIPTION_CACHE = OUTPUT_DIR / "felix_description.txt"

# Fallback if vision fails or no splash image
CONSISTENCY_FALLBACK = (
    "Felix is a cute cartoon tuxedo cat mascot: cream-and-black fur, big shiny eyes, "
    "soft rounded face, small oversized red nose, Pixar-like warm shading. "
    "The image must show the full type-specific scene with setting and props, not Felix alone. "
)


def get_felix_description_from_image(client, splash_path):
    """
    Use GPT-4o vision to describe the splash image for DALL-E 3 consistency.
    Returns a string suitable for prepending to DALL-E prompts. Caches to file.
    """
    if not splash_path.exists():
        print(f"  Splash image not found, using fallback description.")
        return CONSISTENCY_FALLBACK

    # Use cache if present
    if FELIX_DESCRIPTION_CACHE.exists():
        try:
            text = FELIX_DESCRIPTION_CACHE.read_text(encoding="utf-8").strip()
            if text:
                print(f"  Using cached Felix description ({len(text)} chars)")
                return text
        except Exception as e:
            print(f"  Cache read failed: {e}, calling vision.")

    with open(splash_path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode("utf-8")

    prompt = (
        "Describe this cartoon cat mascot in one detailed paragraph for an image generator. "
        "Include: body shape, fur pattern and colors, face shape, eyes, nose, mouth, ears, "
        "style (e.g. cartoon, Pixar-like), and any props or background. "
        "Write so that another AI (DALL-E 3) could draw this exact same character in different "
        "poses and scenes. Output only the paragraph, no preamble. "
        "Then add one sentence: The image must show the full type-specific scene with setting "
        "and props, not the cat alone; the cat is the main character but the scene should "
        "illustrate the cat type clearly."
    )

    try:
        response = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:image/png;base64,{b64}"},
                        },
                    ],
                }
            ],
            max_tokens=500,
        )
        description = (response.choices[0].message.content or "").strip()
        if not description:
            return CONSISTENCY_FALLBACK
        # Cache it
        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        FELIX_DESCRIPTION_CACHE.write_text(description, encoding="utf-8")
        print(f"  Felix description from vision ({len(description)} chars), cached.")
        return description
    except Exception as e:
        print(f"  Vision failed: {e}, using fallback description.")
        return CONSISTENCY_FALLBACK


def slug(name):
    """Safe filename from cat type name."""
    s = re.sub(r"[^\w\s-]", "", name)
    s = re.sub(r"[-\s]+", "_", s).strip("_")
    return s or "unnamed"


def build_prompt(overall_prompt, cat_type, felix_description):
    """Combine Felix description (from vision), overall_prompt, and this type's scene prompt."""
    type_prompt = cat_type.get("prompt", "")
    combined = f"{overall_prompt.strip()} {type_prompt.strip()}".strip()
    return f"{felix_description.strip()}\n\n{combined}"


def generate_image(client, prompt, out_path):
    """Call DALL-E 3, download image, resize to 512x512, save PNG. Returns True on success."""
    # DALL-E 3 only supports 1024x1024, 1792x1024, 1024x1792; we generate 1024x1024 then resize
    response = client.images.generate(
        model="dall-e-3",
        prompt=prompt,
        size="1024x1024",
        quality="standard",
        n=1,
        response_format="url",  # then we download and resize
    )
    image_url = response.data[0].url
    if not image_url:
        return False
    resp = requests.get(image_url, timeout=60)
    resp.raise_for_status()
    img = Image.open(io.BytesIO(resp.content)).convert("RGB")
    img = img.resize(OUTPUT_SIZE, Image.Resampling.LANCZOS)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    img.save(out_path, "PNG")
    return True


def main():
    with open(CAT_TYPES_JSON, "r", encoding="utf-8") as f:
        data = json.load(f)

    overall_prompt = data.get("overall_prompt", "")
    all_types = data.get("types", [])
    cat_types = all_types[:MAX_TYPES]

    if not overall_prompt:
        raise ValueError("cat_types.json must contain 'overall_prompt'")
    if not cat_types:
        raise ValueError("cat_types.json must contain 'types' (non-empty)")

    if not SPLASH_IMAGE.exists():
        print(f"Warning: Mascot reference not found at {SPLASH_IMAGE}")
    else:
        print(f"Mascot reference: {SPLASH_IMAGE.name} (DALL-E 3 description from vision)")
    print(f"Using overall_prompt (first 80 chars): {overall_prompt[:80]}...")
    print(f"Generating images for {len(cat_types)} types (max {MAX_TYPES}).\n")

    client = OpenAI(api_key=API_KEY)

    # Get Felix description from splash image via GPT-4o vision (cached after first run)
    felix_description = get_felix_description_from_image(client, SPLASH_IMAGE)
    print()

    skipped = []
    succeeded = 0

    for i, cat_type in enumerate(cat_types):
        name = cat_type["name"]
        filename = f"{slug(name)}.png"
        out_path = OUTPUT_DIR / filename
        prompt = build_prompt(overall_prompt, cat_type, felix_description)

        if out_path.exists():
            print(f"[{i+1}/{len(cat_types)}] Skip (exists): {filename}")
            succeeded += 1
            continue

        print(f"[{i+1}/{len(cat_types)}] Generating: {name} -> {filename}")

        for attempt in range(MAX_RETRIES):
            try:
                if generate_image(client, prompt, out_path):
                    succeeded += 1
                    print(f"  -> Saved {out_path}")
                    break
            except Exception as e:
                backoff = INITIAL_BACKOFF * (2 ** attempt)
                if attempt < MAX_RETRIES - 1:
                    print(f"  -> Error: {e}. Retry in {backoff}s ({attempt+1}/{MAX_RETRIES})")
                    time.sleep(backoff)
                else:
                    print(f"  -> Failed after {MAX_RETRIES} attempts: {e}. Skipping.")
                    skipped.append((name, str(e)))
                    break
        else:
            skipped.append((name, "no image data"))

        time.sleep(DELAY_BETWEEN_REQUESTS)

    print(f"\nDone. Generated: {succeeded}/{len(cat_types)}")
    if skipped:
        print("Skipped:")
        for name, reason in skipped:
            print(f"  - {name}: {reason}")


if __name__ == "__main__":
    main()
