#!/usr/bin/env bash
# Sync this repo's api/ into trip-planner-ai-proxy (the Vercel-connected repo).
# Run from a machine that can push to digitalunknown/trip-planner-ai-proxy.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROXY_DIR="${1:-}"

if [[ -z "$PROXY_DIR" ]]; then
  echo "Usage: $0 /path/to/trip-planner-ai-proxy"
  echo "Example:"
  echo "  git clone https://github.com/digitalunknown/trip-planner-ai-proxy.git ~/trip-planner-ai-proxy"
  echo "  $0 ~/trip-planner-ai-proxy"
  exit 1
fi

PROXY_DIR="$(cd "$PROXY_DIR" && pwd)"
mkdir -p "$PROXY_DIR/api/content" "$PROXY_DIR/api/unsplash"

cp "$ROOT/api/ai.js" "$PROXY_DIR/api/ai.js"
cp "$ROOT/api/explore.js" "$PROXY_DIR/api/explore.js"
cp "$ROOT/api/parsePaste.js" "$PROXY_DIR/api/parsePaste.js"
cp "$ROOT/api/content/explore.json" "$PROXY_DIR/api/content/explore.json"
cp "$ROOT/api/unsplash/search.js" "$PROXY_DIR/api/unsplash/search.js"
cp "$ROOT/api/unsplash/track-download.js" "$PROXY_DIR/api/unsplash/track-download.js"
cp "$ROOT/.vercelignore" "$PROXY_DIR/.vercelignore"

cat > "$PROXY_DIR/README.md" <<'README'
# tripstacks-api (trip-planner-ai-proxy)

Vercel backend for the TripStacks iOS app (`digitalunknown/trip-planner`).

This repo is the **only** source of truth for production API code.

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/api/ai` | TripStacks AI (`plan_day`, `place_finder`, `create_trip`) |
| `GET` | `/api/explore` | Explore staff-pick feed |
| `GET` | `/api/unsplash/search` | Unsplash search proxy |
| `POST` | `/api/unsplash/track-download` | Unsplash download tracking |
| `POST` | `/api/parsePaste` | Legacy shim → `/api/ai` |

## Explore content

Edit `api/content/explore.json` and push to `main`. Prefer `coverImageURL` for new covers.

## Env (Vercel — never commit)

- `GEMINI_API_KEY`
- `GEMINI_MODEL` (optional)
- `UNSPLASH_ACCESS_KEY`

Push to `main` → deploy at https://trip-planner-ai-proxy.vercel.app
README

echo "Synced into $PROXY_DIR"
echo "Next:"
echo "  cd \"$PROXY_DIR\""
echo "  git add -A && git status"
echo "  git commit -m \"Sync TripStacks API: ai, explore, unsplash\""
echo "  git push origin main"
echo "Then open https://trip-planner-ai-proxy.vercel.app/api/explore"
