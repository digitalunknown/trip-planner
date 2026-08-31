# Backend API — not in this repo

Production is deployed from:

**https://github.com/digitalunknown/trip-planner-ai-proxy**

Vercel project → `https://trip-planner-ai-proxy.vercel.app`

| Endpoint | Purpose |
|----------|---------|
| `POST /api/ai` | TripStacks AI |
| `GET /api/explore` | Explore staff-pick feed (`api/content/explore.json`) |
| `GET /api/expert-tips` | Place-tied Expert Tips (`api/content/expert-tips.json`) |
| Unsplash routes | Cover photo search / download tracking |

## Editing Explore content

1. Edit `api/content/explore.json` in **trip-planner-ai-proxy**
2. Push to `main`
3. Wait for Vercel deploy — no App Store update

**Covers must use `coverImageURL` only.** The iOS app does not ship Explore images.

## Editing Expert Tips

1. Copy staged files from this repo into **trip-planner-ai-proxy**:
   - `proxy-sync/expert-tips.json` → `api/content/expert-tips.json`
   - `proxy-sync/api/expert-tips.js` → `api/expert-tips.js`
2. Push to `main` and wait for Vercel
3. Author tips in a Google Doc, then paste into the JSON (one object per tip)

Tip fields: `id`, `placeName`, `aliases[]`, `latitude`, `longitude`, optional `mapKitIdentifier`, `tip`, `author`, `updatedAt`.

Matching in the app: MapKit ID → alias/name → nearby coords (~200 m) + loose name.

Secrets (`GEMINI_API_KEY`, etc.) stay in Vercel env settings only.
