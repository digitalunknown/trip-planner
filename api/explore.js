/**
 * TripStacks Explore feed — GET /api/explore
 *
 * Serves staff-pick / editorial content from api/content/explore.json so the
 * iOS app can refresh Explore without an App Store update.
 *
 * Edit api/content/explore.json and redeploy to publish new picks.
 * Prefer coverImageURL for new entries; coverImageName only works for assets
 * already bundled in the app.
 */

import { readFileSync, statSync } from "fs";
import { join } from "path";

const CONTENT_PATH = join(process.cwd(), "api", "content", "explore.json");

let cachedParsed = null;
let cachedMtimeMs = null;

function loadContent() {
  try {
    const { mtimeMs } = statSync(CONTENT_PATH);
    if (cachedParsed && cachedMtimeMs === mtimeMs) {
      return { ok: true, data: cachedParsed };
    }

    const raw = readFileSync(CONTENT_PATH, "utf8");
    const parsed = JSON.parse(raw);
    if (!parsed || !Array.isArray(parsed.picks)) {
      return { ok: false, status: 500, error: "Invalid explore content shape" };
    }
    cachedParsed = parsed;
    cachedMtimeMs = mtimeMs;
    return { ok: true, data: parsed };
  } catch (err) {
    return {
      ok: false,
      status: 500,
      error: "Failed to load explore content",
      detail: err?.message ?? String(err),
    };
  }
}

export default async function handler(req, res) {
  if (req.method !== "GET") {
    res.setHeader("Allow", "GET");
    return res.status(405).json({ error: "Method not allowed" });
  }

  const loaded = loadContent();
  if (!loaded.ok) {
    return res.status(loaded.status || 500).json({
      error: loaded.error || "Unknown error",
      ...(loaded.detail ? { detail: loaded.detail } : {}),
    });
  }

  // Short CDN cache — content edits should show up quickly after deploy.
  res.setHeader("Cache-Control", "public, s-maxage=60, stale-while-revalidate=300");
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  return res.status(200).json(loaded.data);
}
