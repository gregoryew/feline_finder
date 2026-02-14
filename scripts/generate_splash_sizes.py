#!/usr/bin/env python3
"""
Generate iOS launch splash images from assets/splash/splash_screen.png.
Resizes to 1x, 2x, 3x (aspect-fit) and writes to ios/Runner/Assets.xcassets/LaunchImage.imageset/.
Background is black to match LaunchScreen.storyboard.
Requires: pip install Pillow
"""

from pathlib import Path
from PIL import Image

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
SOURCE = PROJECT_ROOT / "assets" / "splash" / "splash_screen.png"
# iOS LaunchImage.imageset (storyboard uses 1125x2436 for 3x)
OUTPUT_DIR = PROJECT_ROOT / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"

# 1x = 375x812, 2x = 750x1624, 3x = 1125x2436 (iPhone X/11/12/13 logical size)
SIZES = [
    (375, 812, "LaunchImage.png"),
    (750, 1624, "LaunchImage@2x.png"),
    (1125, 2436, "LaunchImage@3x.png"),
]

# Match LaunchScreen.storyboard backgroundColor (black)
BG_RGB = (0, 0, 0)

# Purple that was used in the original splash (0.42, 0.30, 0.58 ≈ 107,76,148)
# Pixels within this tolerance are replaced with transparent so black shows through
SPLASH_PURPLE_RGB = (107, 76, 148)
PURPLE_TOLERANCE = 45  # max distance in RGB for a pixel to be considered "background"


def _replace_purple_with_transparent(img: Image.Image) -> Image.Image:
    """Replace splash purple background pixels with transparent (so black shows through)."""
    data = img.getdata()
    pr, pg, pb = SPLASH_PURPLE_RGB
    new_data = []
    for item in data:
        if len(item) == 4:
            r, g, b, a = item
        else:
            r, g, b = item[0], item[1], item[2]
            a = 255
        dist = ((r - pr) ** 2 + (g - pg) ** 2 + (b - pb) ** 2) ** 0.5
        if dist <= PURPLE_TOLERANCE:
            new_data.append((0, 0, 0, 0))
        else:
            new_data.append((r, g, b, a))
    out = Image.new("RGBA", img.size)
    out.putdata(new_data)
    return out


def main():
    if not SOURCE.exists():
        raise SystemExit(f"Source image not found: {SOURCE}")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    img = Image.open(SOURCE).convert("RGBA")
    img = _replace_purple_with_transparent(img)
    for w, h, filename in SIZES:
        out = Image.new("RGBA", (w, h), (*BG_RGB, 255))
        # Scale image to fit inside w x h (aspect fit)
        img_w, img_h = img.size
        scale = min(w / img_w, h / img_h)
        new_w = int(img_w * scale)
        new_h = int(img_h * scale)
        resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
        x = (w - new_w) // 2
        y = (h - new_h) // 2
        out.paste(resized, (x, y), resized)
        out_path = OUTPUT_DIR / filename
        out.convert("RGB").save(out_path, "PNG")
        print(f"Wrote {out_path.relative_to(PROJECT_ROOT)} ({w}x{h})")


if __name__ == "__main__":
    main()
