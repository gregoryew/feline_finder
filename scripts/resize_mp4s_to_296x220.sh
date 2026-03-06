#!/usr/bin/env bash
# Resize all MP4s in a folder to 296×220 (scale to fit, then pad to exact size).
# Requires: ffmpeg (e.g. brew install ffmpeg)
#
# Usage:
#   ./scripts/resize_mp4s_to_296x220.sh [input_folder] [output_folder]
#
#   input_folder   Folder containing .mp4 files (default: assets/cat_types).
#   output_folder  Where to write resized .mp4 files (default: same as input_folder).
#                  Output names: {original_base}_resized.mp4
#
# Example:
#   ./scripts/resize_mp4s_to_296x220.sh
#   ./scripts/resize_mp4s_to_296x220.sh ./my_videos
#   ./scripts/resize_mp4s_to_296x220.sh ./source ./resized

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

W=296
H=220

# scale to fit within 296x220, then pad to exactly 296x220 (letterbox/pillarbox)
VF="scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2"

if [ $# -ge 2 ]; then
  SRC_DIR="$(cd "$1" && pwd)"
  OUT_DIR="$(mkdir -p "$2" && cd "$2" && pwd)"
elif [ $# -eq 1 ]; then
  SRC_DIR="$(cd "$1" && pwd)"
  OUT_DIR="$SRC_DIR"
else
  SRC_DIR="$PROJECT_ROOT/assets/cat_types"
  OUT_DIR="$SRC_DIR"
fi

if [ ! -d "$SRC_DIR" ]; then
  echo "Error: input folder does not exist: $SRC_DIR"
  exit 1
fi

count=0
for f in "$SRC_DIR"/*.mp4; do
  [ -f "$f" ] || continue
  name="$(basename "$f" .mp4)"
  [[ "$name" == *"_resized" ]] && continue
  out="$OUT_DIR/${name}_resized.mp4"
  echo "Resizing $f -> $out"
  ffmpeg -y -i "$f" \
    -vf "$VF" \
    -c:v libx264 -crf 23 -preset medium \
    -c:a aac -b:a 128k \
    "$out"
  count=$((count + 1))
done

if [ $count -eq 0 ]; then
  echo "No .mp4 files found in $SRC_DIR (skipping existing *_resized.mp4)"
else
  echo "Done. Resized $count file(s) to ${W}×${H} in $OUT_DIR"
fi
