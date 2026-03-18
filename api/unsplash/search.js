/**
 * Vercel Serverless Function: GET /api/unsplash/search
 *
 * Env:
 * - UNSPLASH_ACCESS_KEY (required)
 *
 * Query:
 * - query (required)
 * - page (optional, default 1)
 * - per_page (optional, default 30, max 30)
 */

const UTM_SOURCE = "tripstacks";
const UTM_MEDIUM = "referral";

function withUtm(urlString) {
  try {
    const u = new URL(urlString);
    u.searchParams.set("utm_source", UTM_SOURCE);
    u.searchParams.set("utm_medium", UTM_MEDIUM);
    return u.toString();
  } catch {
    return urlString;
  }
}

export default async function handler(req, res) {
  if (req.method !== "GET") {
    res.setHeader("Allow", "GET");
    return res.status(405).json({ error: "Method not allowed" });
  }

  const accessKey = process.env.UNSPLASH_ACCESS_KEY;
  if (!accessKey) {
    return res.status(500).json({ error: "Missing UNSPLASH_ACCESS_KEY" });
  }

  const query = (req.query.query ?? "").toString().trim();
  if (!query) {
    return res.status(400).json({ error: "Missing query" });
  }

  const page = Math.max(1, parseInt(req.query.page ?? "1", 10) || 1);
  const perPage = Math.min(30, Math.max(1, parseInt(req.query.per_page ?? "30", 10) || 30));

  const url = new URL("https://api.unsplash.com/search/photos");
  url.searchParams.set("query", query);
  url.searchParams.set("page", String(page));
  url.searchParams.set("per_page", String(perPage));
  url.searchParams.set("content_filter", "low");

  const upstream = await fetch(url.toString(), {
    headers: {
      Authorization: `Client-ID ${accessKey}`,
      "Accept-Version": "v1",
    },
  });

  const text = await upstream.text();
  if (!upstream.ok) {
    return res.status(upstream.status).json({ error: "Unsplash error", body: text });
  }

  const json = JSON.parse(text);
  const results = (json.results ?? []).map((p) => ({
    id: p.id,
    width: p.width,
    height: p.height,
    color: p.color ?? null,
    blur_hash: p.blur_hash ?? null,
    description: p.description ?? p.alt_description ?? null,
    urls: {
      small: p.urls?.small ?? null,
      regular: p.urls?.regular ?? null,
    },
    user: {
      name: p.user?.name ?? "",
      profile_url: withUtm(p.user?.links?.html ?? ""),
    },
    unsplash_url: withUtm(p.links?.html ?? ""),
    // For server-side tracking. The iOS app should POST this back to /track-download.
    download_location: p.links?.download_location ?? null,
  }));

  res.setHeader("Cache-Control", "s-maxage=60, stale-while-revalidate=300");
  return res.status(200).json({
    query,
    page,
    per_page: perPage,
    total: json.total ?? null,
    total_pages: json.total_pages ?? null,
    results,
  });
}

