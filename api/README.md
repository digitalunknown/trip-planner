# Backend API — not in this repo

Production is deployed from:

**https://github.com/digitalunknown/trip-planner-ai-proxy**

Vercel project → `https://trip-planner-ai-proxy.vercel.app`

| Endpoint | Purpose |
|----------|---------|
| `POST /api/ai` | TripStacks AI |
| `GET /api/explore` | Explore staff-pick feed (`api/content/explore.json`) |
| Unsplash routes | Cover photo search / download tracking |

## Editing Explore content

1. Edit `api/content/explore.json` in **trip-planner-ai-proxy**
2. Push to `main`
3. Wait for Vercel deploy — no App Store update

Prefer `coverImageURL` for new picks. Secrets (`GEMINI_API_KEY`, etc.) stay in Vercel env settings only.
