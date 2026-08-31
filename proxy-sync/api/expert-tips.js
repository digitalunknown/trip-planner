/**
 * TripStacks Expert Tips — GET /api/expert-tips
 *
 * Serves place-tied curated tips from api/content/expert-tips.json so the
 * iOS app can show Expert Tips on activities, Places, and AI results without
 * an App Store update.
 *
 * Copy this file to trip-planner-ai-proxy as api/expert-tips.js and place the
 * JSON at api/content/expert-tips.json, then push to main.
 */

import { readFileSync, statSync } from "fs";
import { join } from "path";

const CONTENT_PATH = join(process.cwd(), "api", "content", "expert-tips.json");

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
    if (!parsed || !Array.isArray(parsed.tips)) {
      return { ok: false, status: 500, error: "Invalid expert-tips content shape" };
    }
    cachedParsed = parsed;
    cachedMtimeMs = mtimeMs;
    return { ok: true, data: parsed };
  } catch (err) {
    return {
      ok: false,
      status: 500,
      error: "Failed to load expert-tips content",
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

  res.setHeader("Cache-Control", "public, s-maxage=60, stale-while-revalidate=300");
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  return res.status(200).json(loaded.data);
}
