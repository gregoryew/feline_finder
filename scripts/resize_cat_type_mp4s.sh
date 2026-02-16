#!/usr/bin/env bash
# Resize each MP4 in assets/cat_types/544/ to 298×220 (proportional to 736×544 at 220 height).
# Reads from and writes to assets/cat_types/544/ as {name}_resized.mp4
# Requires: ffmpeg (e.g. brew install ffmpeg)
# Run from repo root: ./scripts/resize_cat_type_mp4s.sh

set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$DIR/assets/cat_types/544"
mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

for f in *.mp4; do
  [ -f "$f" ] || continue
  [[ "$f" == *"_resized.mp4" ]] && continue
  base="${f%.mp4}"
  out="${base}_resized.mp4"
  echo "Resizing $f -> $out"
  ffmpeg -y -i "$f" \
    -vf "scale=297:219:force_original_aspect_ratio=decrease,pad=298:220:(ow-iw)/2:(oh-ih)/2" \
    -c:v libx264 -crf 23 -preset medium \
    -c:a aac -b:a 128k \
    "$out"
done

echo "Done. Resized files are in $SRC_DIR"
