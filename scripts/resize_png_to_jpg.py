#!/usr/bin/env python3
"""
Resize all PNG images in a folder to 512 × 374 and save as JPG.

Usage:
  python scripts/resize_png_to_jpg.py [input_folder] [output_folder]

  input_folder  Directory containing .png files (default: assets/cat_types).
  output_folder Where to write .jpg files (default: same as input_folder).

Example:
  python scripts/resize_png_to_jpg.py ./my_images
  python scripts/resize_png_to_jpg.py ./source_pngs ./output_jpgs
"""

import sys
from pathlib import Path

from PIL import Image

# Project root (parent of scripts/)
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent

TARGET_SIZE = (512, 374)
JPG_QUALITY = 90


def resize_png_to_jpg(input_dir: Path, output_dir: Path) -> None:
    input_dir = input_dir.resolve()
    output_dir = output_dir.resolve()
    if not input_dir.is_dir():
        print(f"Error: input folder does not exist: {input_dir}")
        sys.exit(1)
    output_dir.mkdir(parents=True, exist_ok=True)

    pngs = sorted(input_dir.glob("*.png"))
    if not pngs:
        print(f"No .png files found in {input_dir}")
        return

    print(f"Resizing {len(pngs)} PNG(s) to {TARGET_SIZE[0]}×{TARGET_SIZE[1]} JPG in {output_dir}")
    for png_path in pngs:
        jpg_name = png_path.stem + ".jpg"
        jpg_path = output_dir / jpg_name
        try:
            with Image.open(png_path) as im:
                # Handle RGBA: paste onto white background before converting to RGB
                if im.mode in ("RGBA", "P"):
                    background = Image.new("RGB", im.size, (255, 255, 255))
                    if im.mode == "P":
                        im = im.convert("RGBA")
                    background.paste(im, mask=im.split()[-1] if im.mode == "RGBA" else None)
                    im = background
                elif im.mode != "RGB":
                    im = im.convert("RGB")
                im = im.resize(TARGET_SIZE, Image.Resampling.LANCZOS)
                im.save(jpg_path, "JPEG", quality=JPG_QUALITY, optimize=True)
            print(f"  {png_path.name} -> {jpg_path.name}")
        except Exception as e:
            print(f"  Skip {png_path.name}: {e}")


def main() -> None:
    if len(sys.argv) > 2:
        input_folder = Path(sys.argv[1])
        output_folder = Path(sys.argv[2])
    elif len(sys.argv) > 1:
        input_folder = Path(sys.argv[1])
        output_folder = input_folder
    else:
        input_folder = PROJECT_ROOT / "assets" / "cat_types"
        output_folder = input_folder

    resize_png_to_jpg(input_folder, output_folder)


if __name__ == "__main__":
    main()
