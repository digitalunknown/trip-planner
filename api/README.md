# API handlers — not deployed from this repo

Production Vercel is connected to:

**https://github.com/digitalunknown/trip-planner-ai-proxy**

That repo is the source of truth for `/api/ai`, `/api/explore`, Unsplash, etc.
`GEMINI_API_KEY` and other secrets live in that Vercel project’s env settings (never in git).

## Syncing changes to production

From this iOS repo:

```bash
./scripts/sync-api-to-proxy.sh /path/to/trip-planner-ai-proxy
cd /path/to/trip-planner-ai-proxy
git add -A && git commit -m "Sync API" && git push origin main
```

## Explore content

Edit `api/content/explore.json` here only if you are about to sync; otherwise edit it directly in `trip-planner-ai-proxy` and push.
