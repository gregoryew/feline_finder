#!/usr/bin/env bash
# Strip audio from specified cat type MP4s (video-only, no re-encode).
# Requires: ffmpeg (e.g. brew install ffmpeg)
set -e
cd "$(dirname "$0")/.."
if ! command -v ffmpeg &>/dev/null; then
  echo "ffmpeg not found. Install with: brew install ffmpeg"
  exit 1
fi
for name in Attention_Magnet Social_Learner; do
  f="assets/cat_types/${name}.mp4"
  [ -f "$f" ] || { echo "Skip: $f not found"; continue; }
  echo "Stripping audio: $f"
  ffmpeg -y -i "$f" -an -c:v copy "assets/cat_types/${name}_temp.mp4"
  mv "assets/cat_types/${name}_temp.mp4" "$f"
done
echo "Done."
