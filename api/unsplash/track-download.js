/**
 * Vercel Serverless Function: POST /api/unsplash/track-download
 *
 * Env:
 * - UNSPLASH_ACCESS_KEY (required)
 *
 * Body (JSON):
 * - download_location: string (required)  // value from Unsplash `photo.links.download_location`
 */

export default async function handler(req, res) {
  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return res.status(405).json({ error: "Method not allowed" });
  }

  const accessKey = process.env.UNSPLASH_ACCESS_KEY;
  if (!accessKey) {
    return res.status(500).json({ error: "Missing UNSPLASH_ACCESS_KEY" });
  }

  let body = req.body;
  if (!body || typeof body !== "object") {
    try {
      body = JSON.parse(req.body ?? "{}");
    } catch {
      body = {};
    }
  }

  const downloadLocation = (body.download_location ?? "").toString().trim();
  if (!downloadLocation) {
    return res.status(400).json({ error: "Missing download_location" });
  }

  // Unsplash requires triggering `download_location` (not `download`) to credit downloads.
  const url = new URL(downloadLocation);
  url.searchParams.set("client_id", accessKey);

  const upstream = await fetch(url.toString(), {
    method: "GET",
    headers: { "Accept-Version": "v1" },
  });

  if (!upstream.ok) {
    const text = await upstream.text();
    return res.status(upstream.status).json({ error: "Unsplash error", body: text });
  }

  // We don't need the response body; success indicates tracking recorded.
  return res.status(204).end();
}

