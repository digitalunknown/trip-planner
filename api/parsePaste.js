/**
 * Vercel Serverless Function: POST /api/parsePaste
 *
 * Proxies Plan Day prompts to Gemini and returns itinerary items JSON.
 *
 * Env:
 * - GEMINI_API_KEY (required)
 * - GEMINI_MODEL (optional, default gemini-3.6-flash)
 */

const DEFAULT_MODEL = "gemini-3.6-flash";

const ITEM_SCHEMA = {
  type: "object",
  properties: {
    items: {
      type: "array",
      items: {
        type: "object",
        properties: {
          id: { type: "string" },
          kind: { type: "string", enum: ["activity", "reminder", "checklist", "flight"] },
          include: { type: "boolean" },
          dayID: { type: "string", nullable: true },
          title: { type: "string" },
          subtitle: { type: "string" },
          location: { type: "string" },
          notes: { type: "string" },
          startTime: { type: "string", nullable: true },
          endTime: { type: "string", nullable: true },
          checklistItemsText: {
            anyOf: [{ type: "string" }, { type: "array", items: { type: "string" } }],
          },
          flightFromCode: { type: "string" },
          flightToCode: { type: "string" },
          flightNumber: { type: "string" },
          confidence: { type: "number", nullable: true },
          sourceSnippet: { type: "string" },
        },
        required: ["kind", "title", "include"],
      },
    },
  },
  required: ["items"],
};

function buildSystemPrompt() {
  return `You are a trip-planning assistant for a mobile app.
Return ONLY valid JSON matching the provided schema.
Generate concrete, place-specific itinerary items for ONE day.
Prefer real venues in the destination.

Location field rules (important):
- If an activity is a specific establishment (restaurant, cafe, museum, shop, hotel, landmark building, attraction with a fixed address), set location to that place's street address, including street number when known. Do NOT use only a neighborhood, district, borough, or city.
- Example good location: "172 Boulevard Saint-Germain, 75006 Paris, France"
- Example bad location for a restaurant: "Saint-Germain-des-Prés" or "6th Arrondissement"
- If an activity is intentionally a general area (neighborhood stroll, beach day, explore a district), a neighborhood/area name is fine.
- Never invent a vague area when the venue has a known address.

Use kind values: activity, reminder, checklist, flight.
For times, prefer HH:mm (24h) or ISO-8601; use null when unknown.
For checklists, put checklist items in checklistItemsText as a newline-separated string or string array.
Set dayID to null unless a specific day UUID is provided in context.
Set include to true for every item.
Keep titles short; put detail in subtitle/notes/location.`;
}

function buildUserPrompt(body) {
  const text = (body?.text ?? "").toString().trim();
  const tripContext = body?.tripContext ?? {};
  const preferences = body?.preferences ?? null;
  const facts = body?.facts ?? null;
  const existingItems = Array.isArray(body?.existingItems) ? body.existingItems : [];

  const parts = [text || "Plan a balanced sightseeing day."];

  parts.push(
    "",
    "Trip context JSON:",
    JSON.stringify(tripContext),
    "",
    "User preferences JSON:",
    JSON.stringify(preferences),
    "",
    "Extracted facts JSON:",
    JSON.stringify(facts),
    "",
    "Existing items JSON (refine/extend; do not blindly duplicate):",
    JSON.stringify(existingItems)
  );

  return parts.join("\n");
}

function extractJSON(text) {
  const trimmed = (text ?? "").trim();
  if (!trimmed) return null;

  try {
    return JSON.parse(trimmed);
  } catch {
    // Fall through and try to salvage a JSON object from markdown fences / prose.
  }

  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenced?.[1]) {
    try {
      return JSON.parse(fenced[1].trim());
    } catch {
      // continue
    }
  }

  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start >= 0 && end > start) {
    try {
      return JSON.parse(trimmed.slice(start, end + 1));
    } catch {
      return null;
    }
  }
  return null;
}

export default async function handler(req, res) {
  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return res.status(405).json({ error: "Method not allowed" });
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: "Missing GEMINI_API_KEY" });
  }

  const model = (process.env.GEMINI_MODEL || DEFAULT_MODEL).toString().trim() || DEFAULT_MODEL;
  const body = typeof req.body === "string" ? JSON.parse(req.body || "{}") : req.body ?? {};

  const url = new URL(
    `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`
  );
  url.searchParams.set("key", apiKey);

  const payload = {
    systemInstruction: {
      parts: [{ text: buildSystemPrompt() }],
    },
    contents: [
      {
        role: "user",
        parts: [{ text: buildUserPrompt(body) }],
      },
    ],
    generationConfig: {
      temperature: 0.7,
      responseMimeType: "application/json",
      responseSchema: ITEM_SCHEMA,
    },
  };

  const upstream = await fetch(url.toString(), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });

  const upstreamText = await upstream.text();
  if (!upstream.ok) {
    return res.status(upstream.status).send(upstreamText || `Upstream error (${upstream.status})`);
  }

  let geminiJSON;
  try {
    geminiJSON = JSON.parse(upstreamText);
  } catch {
    return res.status(502).json({ error: "Invalid JSON from Gemini", body: upstreamText });
  }

  const candidateText =
    geminiJSON?.candidates?.[0]?.content?.parts?.map((p) => p?.text ?? "").join("") ?? "";

  const parsed = extractJSON(candidateText);
  if (!parsed || !Array.isArray(parsed.items)) {
    return res.status(502).json({
      error: "Gemini returned no usable items",
      body: candidateText,
    });
  }

  const items = parsed.items.map((item) => ({
    id: item.id || crypto.randomUUID(),
    kind: item.kind || "activity",
    include: item.include !== false,
    dayID: item.dayID ?? null,
    title: item.title ?? "",
    subtitle: item.subtitle ?? "",
    location: item.location ?? "",
    notes: item.notes ?? "",
    startTime: item.startTime ?? null,
    endTime: item.endTime ?? null,
    checklistItemsText: item.checklistItemsText ?? "",
    flightFromCode: item.flightFromCode ?? "",
    flightToCode: item.flightToCode ?? "",
    flightNumber: item.flightNumber ?? "",
    confidence: typeof item.confidence === "number" ? item.confidence : null,
    sourceSnippet: item.sourceSnippet ?? item.title ?? "",
  }));

  return res.status(200).json({ items });
}
