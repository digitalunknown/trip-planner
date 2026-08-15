/**
 * TripStacks AI backend — POST /api/ai
 *
 * Modes:
 * - plan_day     – itinerary / options inside a trip (LIVE)
 * - place_finder – Places-tab discovery
 * - create_trip  – draft a new trip (+ optional seed items)
 *
 * Env: GEMINI_API_KEY (required), GEMINI_MODEL (optional, default gemini-3.6-flash)
 */

const DEFAULT_MODEL = "gemini-3.6-flash";

const PLAN_DAY_KINDS = ["activity", "reminder", "checklist", "flight"];
const PLAN_DAY_INTENTS = [
  "day_plan",
  "multi_day_plan",
  "options_list",
  "checklist",
  "reminder",
  "flight",
  "clarification_needed",
];

const PLACE_FINDER_CATEGORIES = [
  "restaurant",
  "cafe",
  "bar",
  "hotel",
  "attraction",
  "museum",
  "park",
  "beach",
  "hike",
  "shopping",
  "nightlife",
  "viewpoint",
  "kids",
  "other",
];
const PLACE_FINDER_INTENTS = ["place_discovery", "clarification_needed"];

const CREATE_TRIP_INTENTS = ["create_trip", "trip_options", "clarification_needed"];

function baseItemProperties() {
  return {
    id: { type: "string" },
    include: { type: "boolean" },
    dayID: { type: "string", nullable: true },
    dayIndex: { type: "integer", nullable: true },
    dayLabel: { type: "string" },
    title: { type: "string" },
    subtitle: { type: "string" },
    location: { type: "string" },
    notes: { type: "string" },
    startTime: { type: "string", nullable: true },
    endTime: { type: "string", nullable: true },
    checklistItemsText: { type: "string" },
    flightFromCode: { type: "string" },
    flightToCode: { type: "string" },
    flightNumber: { type: "string" },
    confidence: { type: "number" },
    sourceSnippet: { type: "string" },
  };
}

const BASE_REQUIRED = [
  "id",
  "include",
  "dayIndex",
  "dayLabel",
  "title",
  "subtitle",
  "location",
  "notes",
  "checklistItemsText",
  "flightFromCode",
  "flightToCode",
  "flightNumber",
  "confidence",
  "sourceSnippet",
];

const PLAN_DAY_SCHEMA = {
  type: "object",
  properties: {
    intent: { type: "string", enum: PLAN_DAY_INTENTS },
    clarificationNeeded: { type: "boolean" },
    clarificationPrompt: { type: "string" },
    items: {
      type: "array",
      items: {
        type: "object",
        properties: {
          kind: { type: "string", enum: PLAN_DAY_KINDS },
          ...baseItemProperties(),
        },
        required: ["kind", ...BASE_REQUIRED],
      },
    },
  },
  required: ["intent", "clarificationNeeded", "clarificationPrompt", "items"],
};

const PLACE_FINDER_SCHEMA = {
  type: "object",
  properties: {
    intent: { type: "string", enum: PLACE_FINDER_INTENTS },
    clarificationNeeded: { type: "boolean" },
    clarificationPrompt: { type: "string" },
    items: {
      type: "array",
      items: {
        type: "object",
        properties: {
          kind: { type: "string", enum: ["place"] },
          category: { type: "string", enum: PLACE_FINDER_CATEGORIES },
          ...baseItemProperties(),
        },
        required: ["kind", "category", ...BASE_REQUIRED],
      },
    },
  },
  required: ["intent", "clarificationNeeded", "clarificationPrompt", "items"],
};

const TRIP_DRAFT_PROPERTIES = {
  name: { type: "string" },
  destination: { type: "string" },
  isDatesSet: { type: "boolean" },
  startDate: { type: "string", nullable: true },
  endDate: { type: "string", nullable: true },
  unscheduledDaysCount: { type: "integer" },
  summary: { type: "string" },
  confidence: { type: "number" },
};

const TRIP_DRAFT_REQUIRED = [
  "name",
  "destination",
  "isDatesSet",
  "startDate",
  "endDate",
  "unscheduledDaysCount",
  "summary",
  "confidence",
];

const CREATE_TRIP_SCHEMA = {
  type: "object",
  properties: {
    intent: { type: "string", enum: CREATE_TRIP_INTENTS },
    clarificationNeeded: { type: "boolean" },
    clarificationPrompt: { type: "string" },
    trip: {
      type: "object",
      properties: TRIP_DRAFT_PROPERTIES,
      required: TRIP_DRAFT_REQUIRED,
    },
    items: {
      type: "array",
      items: {
        type: "object",
        properties: {
          kind: { type: "string", enum: PLAN_DAY_KINDS },
          ...baseItemProperties(),
        },
        required: ["kind", ...BASE_REQUIRED],
      },
    },
    alternatives: {
      type: "array",
      items: {
        type: "object",
        properties: TRIP_DRAFT_PROPERTIES,
        required: TRIP_DRAFT_REQUIRED,
      },
    },
  },
  required: [
    "intent",
    "clarificationNeeded",
    "clarificationPrompt",
    "trip",
    "items",
    "alternatives",
  ],
};

const SHARED_BRAIN = `
You are TripStacks AI — the planning brain for an iOS trip app.

You help with exactly three jobs, one per call mode:
1) plan_day — organize itineraries / options inside an existing trip
2) place_finder — discover places worth saving to the user's Places library
3) create_trip — draft a new trip the user can create and refine

General rules (all modes):
- Be specific, real-world, and "best of the best." No generic filler.
- Never invent venues, airports, or addresses you are not confident about.
- Prefer asking one clarifying question over a wild guess when destination/dates are missing and cannot be inferred.
- Obey the JSON schema for this mode exactly. No markdown, no code fences, no extra keys.
- Personalization fields (preferences, existingPlaces, existingTrips, existingItems) are signals — never mention them by name in titles/notes.
`;

const SHARED_OUTPUT_CONTRACT = `
Output requirements (STRICT):
Return ONLY valid JSON matching the schema for this mode.

PlanItem fields (ALWAYS include every field; use "" or null if not applicable):
- id: UUID string
- kind: see mode-specific kind list
- include: true
- dayID: always null (app owns UUIDs)
- dayIndex: integer or null (0-based day offset when multi-day / scoped)
- dayLabel: short label or ""
- title, subtitle, location, notes: strings
- startTime / endTime: HH:mm, ISO-8601, or null
- checklistItemsText: newline-separated string (checklists)
- flightFromCode / flightToCode / flightNumber: flight only; else ""
- confidence: 0.0–1.0
- sourceSnippet: key phrase from the user prompt that caused the item

Rules:
- Set dayID to null for ALL items.
- Do not output markdown, code fences, or extra keys.
- If too ambiguous: clarificationNeeded=true, clarificationPrompt=one short question, items=[] (and alternatives=[] for create_trip).

## Location precision
- location must be maps-searchable: specific venue + city (e.g. "Tartine Bakery, San Francisco, CA"), not a vague neighborhood when a venue is intended.
- Area categories (park, hike, beach, viewpoint): use a named feature still geocodable.
- Never invent a fictional venue; lower confidence and note uncertainty instead.

## Counting discipline (HARD)
- If the user specifies a number, return EXACTLY that many matching items — no padding with unrelated kinds.
- If no number: typically 3–8 items scaled to breadth of the ask.

## Dedup
- Do not suggest the same title+location as existingItems / existingPlaces / existingTrips (or duplicates within your own output).
- Food-related: vary cuisine, meal type, vibe, neighborhood, or price across suggestions.

## Mode awareness
- plan_day: kinds activity|reminder|checklist|flight only. No kind=place.
- place_finder: every item kind=place with a valid category; startTime/endTime null.
- create_trip: primary payload is trip (+ alternatives / seed items). Seed items use plan_day kinds only.

## Self-check
1. Does intent match the ask (not a habit default)?
2. Exact count if requested?
3. Locations specific and real?
4. Deduped against existing context and self?
5. All required fields present?
`;

function buildPlanDayPrompt() {
  return `${SHARED_BRAIN}

You are generating itinerary content inside an existing trip.

There is no discrete field for which day is in scope — that signal lives in the user's prompt text (the app may bake a selected day title into the prompt, e.g. "For Mon, Oct 5: ..."). Read carefully; do not assume every request is a full day_plan.

## Intent (pick exactly one first)
- day_plan: full scheduled day (only if a day is in scope/implied AND they want a full day)
- multi_day_plan: multiple days when trip-scoped
- options_list: N options (hotels, dinners, museums) WITHOUT full-day scheduling — even if opened from a day sheet
- checklist / reminder / flight: only that kind
- clarification_needed: too vague

CRITICAL: Opening from "Plan Day" does NOT mean every ask is day_plan. "Find me 10 hotels" → options_list with kind=activity (no place kind in this mode).

## Kinds
1) activity — places/things to do; also hotels/venues in options_list
2) checklist — checklistItemsText 5–12 lines
3) reminder — short actionable task; not a duplicate activity
4) flight — only with real/strongly implied flight details; blank IATA rather than guess
Ground transport: kind=activity (e.g. title="Drive to Fort Wayne"), not a new kind.

## Personalization
favoriteFoodCSV / drinksAlcohol / interestsCSV silently bias choices.

## Day structure (day_plan / multi_day_plan only)
Morning→night, 2–3 proximity clusters, default windows (breakfast/lunch/dinner, etc.), 15–30 min transit gaps.

## Day binding
- dayID always null.
- day_plan: dayIndex 0 (or scoped day), dayLabel if known from prompt.
- multi_day_plan: every item MUST set dayIndex (0 = first day) and dayLabel ("Day 1", …).
- options_list / checklist / reminder / flight: dayIndex null, dayLabel "" unless user tied ask to a day.

## Options-list
No extra checklists/reminders. Exact count. Times null unless inherent (e.g. dinner).

${SHARED_OUTPUT_CONTRACT}
`;
}

function buildPlaceFinderPrompt() {
  return `${SHARED_BRAIN}

You are a local discovery guide for the Places library. You are NOT planning a day or schedule. No morning/afternoon pacing. startTime/endTime must be null. Every item kind="place".

## Intent
Almost always place_discovery. clarification_needed only with zero destination in prompt, tripContext, or inferable existingPlaces.

## Anchoring
Prefer tripContext.destination, else a destination named in text, else a strong regional signal from existingPlaces.

## Personalization from existingPlaces
Treat saved places as taste (categories/notes) — silent influence. Dedup against them strictly.

## Categories (exact)
restaurant, cafe, bar, hotel, attraction, museum, park, beach, hike, shopping, nightlife, viewpoint, kids, other.
Match what was asked ("hotels" → every category=hotel).

## Good suggestions
Renowned real venues; notes explain why worth saving. No proximity clustering for a schedule.

${SHARED_OUTPUT_CONTRACT}
`;
}

function buildCreateTripPrompt() {
  return `${SHARED_BRAIN}

You draft a NEW trip for the Trips tab — not filling an existing day board, not Places cards.

## Intent
- create_trip: one concrete draft (default)
- trip_options: several ideas; best in trip, 2–4 more in alternatives; items usually empty
- clarification_needed: missing destination AND dates/duration with nothing inferable

## trip fields
- name: short title
- destination: geocodeable city/region
- isDatesSet true → startDate/endDate YYYY-MM-DD, unscheduledDaysCount 0
- isDatesSet false → dates null, unscheduledDaysCount = day count (default 3)
- summary: 1–2 sentence pitch
- confidence 0–1

## items (optional seed)
plan_day kinds only. dayID null; use dayIndex/dayLabel across days.
Light seed (3–6 highlights or Day 1) unless user wants empty ("I'll plan later" → items=[]).
Never kind=place.

## alternatives
Only for trip_options; else [].

## Dedup / taste from existingTrips
Avoid cloning same destination+timing unless asked. Bias style silently.

${SHARED_OUTPUT_CONTRACT}

Also return trip, alternatives, and items as required by the create_trip schema.
`;
}

function safeString(v) {
  return typeof v === "string" ? v : "";
}

function cryptoRandomId() {
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === "x" ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

function sanitizeItem(item, mode) {
  if (!item || typeof item !== "object") return null;

  const allowedKinds =
    mode === "place_finder" ? ["place"] : PLAN_DAY_KINDS;
  if (!allowedKinds.includes(item.kind)) return null;

  const clean = {
    id: typeof item.id === "string" && item.id.length > 0 ? item.id : cryptoRandomId(),
    kind: item.kind,
    include: item.include !== false,
    dayID: null,
    dayIndex: Number.isInteger(item.dayIndex) ? item.dayIndex : null,
    dayLabel: safeString(item.dayLabel),
    title: safeString(item.title),
    subtitle: safeString(item.subtitle),
    location: safeString(item.location),
    notes: safeString(item.notes),
    startTime: item.startTime ?? null,
    endTime: item.endTime ?? null,
    checklistItemsText: safeString(item.checklistItemsText),
    flightFromCode: safeString(item.flightFromCode),
    flightToCode: safeString(item.flightToCode),
    flightNumber: safeString(item.flightNumber),
    confidence: typeof item.confidence === "number" ? item.confidence : 0.5,
    sourceSnippet: safeString(item.sourceSnippet),
    category: "",
  };

  if (mode === "place_finder") {
    clean.category = PLACE_FINDER_CATEGORIES.includes(item.category)
      ? item.category
      : "other";
    if (!clean.location) return null;
    clean.startTime = null;
    clean.endTime = null;
    clean.dayIndex = null;
    clean.dayLabel = "";
  }

  return clean;
}

function sanitizeTripDraft(trip) {
  if (!trip || typeof trip !== "object") {
    return {
      name: "",
      destination: "",
      isDatesSet: false,
      startDate: null,
      endDate: null,
      unscheduledDaysCount: 3,
      summary: "",
      confidence: 0.5,
    };
  }
  const isDatesSet = trip.isDatesSet === true;
  let unscheduledDaysCount = Number.isInteger(trip.unscheduledDaysCount)
    ? Math.max(1, Math.min(trip.unscheduledDaysCount, 30))
    : 3;
  if (isDatesSet) unscheduledDaysCount = 0;

  return {
    name: safeString(trip.name),
    destination: safeString(trip.destination),
    isDatesSet,
    startDate: isDatesSet ? trip.startDate ?? null : null,
    endDate: isDatesSet ? trip.endDate ?? null : null,
    unscheduledDaysCount,
    summary: safeString(trip.summary),
    confidence: typeof trip.confidence === "number" ? trip.confidence : 0.5,
  };
}

function extractJSON(text) {
  const trimmed = (text ?? "").trim();
  if (!trimmed) return null;
  try {
    return JSON.parse(trimmed);
  } catch {
    // fall through
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

  try {
    const body = typeof req.body === "string" ? JSON.parse(req.body || "{}") : req.body ?? {};

    const mode =
      body?.mode === "place_finder"
        ? "place_finder"
        : body?.mode === "create_trip"
          ? "create_trip"
          : "plan_day";

    const text = body?.text ?? "";
    const facts = body?.facts ?? {};
    const tripContext = body?.tripContext ?? {};
    const preferences = body?.preferences ?? null;
    const existingItems = Array.isArray(body?.existingItems) ? body.existingItems : [];
    const existingPlaces = Array.isArray(body?.existingPlaces) ? body.existingPlaces : [];
    const existingTrips = Array.isArray(body?.existingTrips) ? body.existingTrips : [];
    const scopeHint = body?.scopeHint ?? "";

    const systemInstruction =
      mode === "place_finder"
        ? buildPlaceFinderPrompt()
        : mode === "create_trip"
          ? buildCreateTripPrompt()
          : buildPlanDayPrompt();

    const responseSchema =
      mode === "place_finder"
        ? PLACE_FINDER_SCHEMA
        : mode === "create_trip"
          ? CREATE_TRIP_SCHEMA
          : PLAN_DAY_SCHEMA;

    const userMessage = {
      mode,
      text,
      scopeHint,
      facts,
      tripContext,
      preferences,
      existingItems,
      existingPlaces,
      existingTrips,
    };

    const model =
      (process.env.GEMINI_MODEL || DEFAULT_MODEL).toString().trim() || DEFAULT_MODEL;

    const url = new URL(
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`
    );
    url.searchParams.set("key", apiKey);

    const geminiRes = await fetch(url.toString(), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        systemInstruction: {
          parts: [{ text: systemInstruction }],
        },
        contents: [
          {
            role: "user",
            parts: [{ text: JSON.stringify(userMessage) }],
          },
        ],
        generationConfig: {
          temperature: 0.5,
          responseMimeType: "application/json",
          responseSchema,
        },
      }),
    });

    const upstreamText = await geminiRes.text();
    if (!geminiRes.ok) {
      return res.status(geminiRes.status).send(upstreamText || `Upstream error (${geminiRes.status})`);
    }

    let geminiJSON;
    try {
      geminiJSON = JSON.parse(upstreamText);
    } catch {
      return res.status(502).json({ error: "Invalid JSON from Gemini", body: upstreamText });
    }

    const candidateText =
      geminiJSON?.candidates?.[0]?.content?.parts?.map((p) => p?.text ?? "").join("") ?? "";

    const result = extractJSON(candidateText);
    if (!result || typeof result !== "object") {
      return res.status(502).json({
        error: "Gemini returned no usable JSON",
        body: candidateText,
      });
    }

    if (mode === "create_trip") {
      if (!result.trip || typeof result.trip !== "object") {
        return res.status(502).json({ error: "Invalid Gemini JSON shape (missing trip)" });
      }
      const cleanedItems = Array.isArray(result.items)
        ? result.items.map((item) => sanitizeItem(item, "plan_day")).filter(Boolean)
        : [];
      const alternatives = Array.isArray(result.alternatives)
        ? result.alternatives.map(sanitizeTripDraft)
        : [];
      return res.status(200).json({
        intent: result.intent ?? "unknown",
        clarificationNeeded: Boolean(result.clarificationNeeded),
        clarificationPrompt: result.clarificationPrompt ?? "",
        trip: sanitizeTripDraft(result.trip),
        alternatives,
        items: cleanedItems,
      });
    }

    if (!Array.isArray(result.items)) {
      return res.status(502).json({
        error: "Gemini returned no usable items",
        body: candidateText,
      });
    }

    const cleanedItems = result.items
      .map((item) => sanitizeItem(item, mode))
      .filter(Boolean);

    return res.status(200).json({
      intent: result.intent ?? "unknown",
      clarificationNeeded: Boolean(result.clarificationNeeded),
      clarificationPrompt: result.clarificationPrompt ?? "",
      items: cleanedItems,
    });
  } catch (err) {
    return res.status(500).json({ error: String(err?.message || err) });
  }
}
