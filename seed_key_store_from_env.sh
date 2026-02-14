#!/bin/bash

# Seed Firestore collection `key_store` from `./.env` (one-time).
#
# This script SOURCES `.env` locally, then passes values via --dart-define so
# the app can write them into Firestore using KeyStoreService.seedFromDefinesIfEnabled().
#
# Requirements:
# - Add these to `feline_finder/.env`:
#   GEMINI_API_KEY=...
#   YOUTUBE_API_KEY=...
#   GOOGLE_MAPS_API_KEY=...
#   RESCUE_GROUPS_API_KEY=...
#
# Usage:
#   ./seed_key_store_from_env.sh [-d <device-id>] [any other flutter args]
#
# Example:
#   ./seed_key_store_from_env.sh -d "iPhone 16"

set -euo pipefail

cd "$(dirname "$0")"

if [ ! -f ".env" ]; then
  echo "❌ Missing .env at: $(pwd)/.env"
  exit 1
fi

# Load env vars from .env into this shell.
set -a
source ".env"
set +a

missing=0
for name in GEMINI_API_KEY YOUTUBE_API_KEY GOOGLE_MAPS_API_KEY RESCUE_GROUPS_API_KEY; do
  if [ -z "${!name:-}" ]; then
    echo "❌ Missing $name in .env"
    missing=1
  fi
done

if [ "$missing" -ne 0 ]; then
  echo ""
  echo "Add the missing variables to feline_finder/.env, then re-run."
  exit 1
fi

echo "🔐 Seeding Firestore 'key_store' from .env (values not printed)"

flutter run \
  --dart-define=SEED_KEY_STORE=true \
  --dart-define=GEMINI_API_KEY="${GEMINI_API_KEY}" \
  --dart-define=YOUTUBE_API_KEY="${YOUTUBE_API_KEY}" \
  --dart-define=GOOGLE_MAPS_API_KEY="${GOOGLE_MAPS_API_KEY}" \
  --dart-define=RESCUE_GROUPS_API_KEY="${RESCUE_GROUPS_API_KEY}" \
  "$@"

