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

const CREATE_TRIP_INTENTS = [
  "get_started",
  "full_itinerary",
  "create_trip",
  "clarification_needed",
];

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
    category: { type: "string" },
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
  "category",
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
          ...baseItemProperties(),
          category: { type: "string", enum: PLACE_FINDER_CATEGORIES },
        },
        required: ["kind", "category", ...BASE_REQUIRED.filter((k) => k !== "category")],
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
- If the user specifies an explicit count (e.g. "top 5", "3 restaurants"), return EXACTLY that many matching items — no padding with unrelated kinds.
- If no explicit count: return 6–8 items for plan_day day plans / discovery asks; for place_finder always default to exactly 10.
- Never return only 1–2 items for a broad place_finder or options-style ask.
- Digits in coordinates, dates, addresses, or names do NOT count as an item count.
- create_trip counting is mode-specific (see create_trip prompt) — full itineraries are MUCH larger than 3–8.

## Dedup
- Do not suggest the same title+location as existingItems / existingPlaces / existingTrips (or duplicates within your own output).
- Food-related: vary cuisine, meal type, vibe, neighborhood, or price across suggestions.

## Mode awareness
- plan_day: kinds activity|reminder|checklist|flight only. No kind=place. Set category on venue activities (hotel/restaurant/…).
- place_finder: every item kind=place with a valid category; startTime/endTime null.
- create_trip: primary payload is trip (+ alternatives / seed items). Seed items use plan_day kinds only; every venue activity MUST set category.

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
CRITICAL for day_plan: return MULTIPLE separate activity items (typically 6–8) — one venue/stop per item with its own title/location/startTime.
NEVER collapse a whole day into a single combined "itinerary" / "sightseeing day" item.
Reminders/checklists are optional extras (0–2), not a substitute for the activity list.

## Day binding
- dayID always null.
- day_plan: dayIndex 0 (or scoped day), dayLabel if known from prompt.
- multi_day_plan: every item MUST set dayIndex (0 = first day) and dayLabel ("Day 1", …).
- options_list / checklist / reminder / flight: dayIndex null, dayLabel "" unless user tied ask to a day.

## Options-list
No extra checklists/reminders. Exact count (default 8 if unspecified). Times null unless inherent (e.g. dinner).
Never return only 1 option for a list-style ask.

## Count (HARD) for day_plan / options_list / multi_day_plan
Unless clarificationNeeded or the ask is clearly a single checklist/reminder/flight:
- day_plan → 6–8 distinct activity items (plus optional 0–2 reminders/checklists)
- options_list → 8 options (or exact N if stated)
- multi_day_plan → several items per day across the scoped days
Keep notes to one short sentence. Self-check: if items.length < 4 for day_plan/options_list, keep adding real venues before responding.

${SHARED_OUTPUT_CONTRACT}
`;
}

function buildPlaceFinderPrompt() {
  return `${SHARED_BRAIN}

You are a local discovery guide for the Places library. You are NOT planning a day or schedule. No morning/afternoon pacing. startTime/endTime must be null. Every item kind="place".

## Intent
Almost always place_discovery. clarification_needed only with zero destination in prompt, tripContext, or inferable existingPlaces — and no coordinates / "near {city}" signal.

## Anchoring (priority order)
1. Explicit current-location / "near {city}" / lat,long / "Best of {city}" / "in {city}" in the user text — this WINS over tripContext.
2. Else tripContext.destination
3. Else a destination named in text
4. Else a strong regional signal from existingPlaces

When (1) applies, ignore a conflicting tripContext.destination completely. Suggest real venues in that city only (roughly within ~15–25 km unless the ask implies a city-wide "best of").
CRITICAL: Every item.location MUST include the anchor city (e.g. "CN Tower, Toronto, ON"). Never invent or reuse a street from a different city that shares a name (e.g. do not use Chicago addresses for a Toronto ask).
CRITICAL: Prefer well-known official venue names that MapKit can resolve uniquely in the anchor city.

## Count (HARD)
DEFAULT: return exactly 10 distinct places for every place_discovery ask (hikes, restaurants, stays, activities, "best of", "near me", etc.) unless the user asked for a different specific number — then match that number.
"Best hikes in X" / "cafes in Y" / any list-style ask → 10 named places, never 1.
Each item must be a specific named venue / trail / park — not a neighborhood, region, category, or generic tip.
Vary areas and vibes. No duplicates.
Self-check before responding: count(items) must be 10 (or the user's exact N). If you only have 1 idea, invent more real venues — do not stop early.
clarification_needed → items must be [] (empty array only in that case). Digits in lat/long or street numbers are NOT a requested count.

## Personalization from existingPlaces
Treat saved places as taste (categories/notes) — silent influence. Dedup against them strictly.

## Categories (exact)
restaurant, cafe, bar, hotel, attraction, museum, park, beach, hike, shopping, nightlife, viewpoint, kids, other.
Match what was asked ("hotels" / "stays" → every category=hotel; "restaurants" → restaurant; "activities" → attraction/museum/park/viewpoint/etc. mix).

## Good suggestions
Renowned real venues with maps-searchable location (venue + city). Notes explain why worth saving. No proximity clustering for a schedule.

${SHARED_OUTPUT_CONTRACT}
`;
}

function buildCreateTripPrompt() {
  return `${SHARED_BRAIN}

You draft a NEW trip for the Trips tab — not filling an existing day board, not Places cards.

## Intent (pick ONE — read the ask carefully)
- get_started: user wants a draft / kickoff / "help me start" / light suggestions — NOT a packed schedule
- full_itinerary: user wants a full trip planned / "plan my trip" / "pack the itinerary" / day-by-day / complete stay
- create_trip: only if unclear between get_started and full_itinerary — prefer get_started when vague, full_itinerary when they imply a whole stay ("week in Tokyo", "5 days in Rome", "plan everything")
- clarification_needed: missing destination AND dates/duration with nothing inferable

CRITICAL: Always draft ONE concrete trip. Never offer multiple destination/trip choices.
CRITICAL: "Create a trip to X" with duration/dates often means full_itinerary. "Rough idea for X" / "start a trip" → get_started.

## trip fields
- name: short title
- destination: geocodeable city/region
- isDatesSet true → startDate/endDate YYYY-MM-DD, unscheduledDaysCount 0
- isDatesSet false → dates null, unscheduledDaysCount = day count (default 3; use stated length when given)
- summary: 1–2 sentence pitch
- confidence 0–1

## items — seed itinerary (plan_day kinds only; NEVER kind=place)
dayID always null. Set dayIndex (0-based) + dayLabel ("Day 1", …) for scheduled items.
Every venue activity MUST set category to one of: ${PLACE_FINDER_CATEGORIES.join(", ")}.
Reminders/checklists/flights use category "".

### get_started (light)
Aim for a balanced starter pack across sections (≈8–14 items):
- 1 accommodation (category=hotel)
- 2–3 restaurants/cafes/bars
- 3–5 activities/attractions
- 1 packing or prep checklist
- 1–2 reminders (bookings, docs, etc.)
Do NOT leave items nearly empty unless the user said they'll plan later → items=[].

### full_itinerary (pack it)
Fill the stay for the trip length (use dates or unscheduledDaysCount; default 3–5 days):
- 1 primary hotel (or 1 per city if multi-city) — dayIndex 0, dayLabel "Day 1"
- ~1–2 meals/day as restaurant/cafe/bar activities (vary cuisine/neighborhood)
- ~2–3 activities/attractions per day with dayIndex/dayLabel and rough startTime when natural
- 1 flight item if flights are implied; else skip
- 1 solid packing checklist (8–12 lines in checklistItemsText) — dayIndex 0
- 2–4 reminders (visa/passport, reservations, transit passes, etc.) — dayIndex 0
Target roughly 12–28 items for a 3–5 day trip — never stop at 1–3 filler highlights.

## Day spreading (HARD — full_itinerary and any multi-day ask)
- unscheduledDaysCount (or date span) is the trip length D. Use every day.
- Every day-scoped activity/meal MUST set dayIndex (0…D-1) AND dayLabel ("Day 1"…"Day D").
- Spread venue activities across ALL days: each dayIndex from 0 to D-1 must appear on multiple items.
- NEVER dump the whole itinerary on dayIndex 0 / "Day 1" when D ≥ 2.
- Hotel / packing checklist / prep reminders may stay on dayIndex 0; sightseeing and meals must not.
- Example for a 5-day trip: include activities labeled Day 1, Day 2, Day 3, Day 4, and Day 5.

## alternatives
Always return []. Never invent alternate destinations or competing trip drafts.

## Dedup / taste from existingTrips
Avoid cloning same destination+timing unless asked. Bias style silently.

${SHARED_OUTPUT_CONTRACT}

Also return trip, alternatives, and items as required by the create_trip schema.
`;
}

function safeString(v) {
  return typeof v === "string" ? v : "";
}

/** True only when the user clearly asked for N places/options (not coords/dates/addresses). */
function hasExplicitPlaceCount(text) {
  const raw = safeString(text);
  if (!raw) return false;
  if (/\bexactly\s+([1-9]|1[0-2])\b/i.test(raw)) return true;
  if (
    /\b(?:top|best)\s*([1-9]|1[0-2])\b/i.test(raw) &&
    /\b(places?|restaurants?|cafes?|hotels?|stays?|bars?|hikes?|trails?|spots?|venues?|options?|ideas?|recommendations?|activities|museums?|parks?)\b/i.test(
      raw
    )
  ) {
    return true;
  }
  if (
    /\b([1-9]|1[0-2])\s+(?:places?|restaurants?|cafes?|hotels?|stays?|bars?|hikes?|trails?|spots?|venues?|options?|ideas?|recommendations?|activities|museums?|parks?)\b/i.test(
      raw
    )
  ) {
    return true;
  }
  if (
    /\b(?:find|suggest|give|show|list|return|recommend)\s+(?:me\s+)?([1-9]|1[0-2])\b/i.test(
      raw
    )
  ) {
    return true;
  }
  return false;
}

/** Append an explicit multi-item count for place_finder / plan_day when the user didn't ask for N. */
function enforceItemCount(text, mode) {
  const raw = safeString(text).trim();
  if (!raw) return raw;
  if (hasExplicitPlaceCount(raw)) return raw;

  if (mode === "place_finder") {
    if (/return exactly\s+\d+\s+specific named places/i.test(raw)) return raw;
    return `${raw}\n\nReturn exactly 10 specific named places (trails, venues, or parks — not one summary recommendation).`;
  }

  if (mode === "plan_day") {
    if (/return\s+\d+\s+distinct/i.test(raw)) return raw;
    // Single-kind asks should stay single (or small).
    if (
      /\b(checklist|packing list|remind me|reminder|flight|train|add a flight)\b/i.test(raw) &&
      !/\b(day|sightseeing|food|restaurants?|options?|ideas?|activities|itinerary)\b/i.test(raw)
    ) {
      return raw;
    }
    return (
      `${raw}\n\n` +
      "Return 6–8 distinct itinerary items in the items array " +
      "(one venue/stop per item, short notes). " +
      "Never return a single combined day summary."
    );
  }

  return raw;
}

function isPlanDaySingleKindIntent(intent) {
  return ["checklist", "reminder", "flight", "clarification_needed"].includes(
    String(intent || "")
  );
}

function cryptoRandomId() {
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === "x" ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

function coerceInt(v) {
  if (Number.isInteger(v)) return v;
  if (typeof v === "number" && Number.isFinite(v)) return Math.trunc(v);
  if (typeof v === "string" && /^-?\d+$/.test(v.trim())) return parseInt(v.trim(), 10);
  return null;
}

function parseDayIndexFromLabel(label) {
  const m = /day\s*(\d+)/i.exec(safeString(label));
  if (!m) return null;
  const n = parseInt(m[1], 10);
  return Number.isInteger(n) && n >= 1 ? n - 1 : null;
}

/** Infer trip length from user text like "5 day trip" / "weekend". */
function inferTripDayCountFromText(text) {
  const raw = safeString(text);
  if (!raw) return null;
  const patterns = [
    /\b(\d{1,2})\s*-?\s*days?\b/i,
    /\b(\d{1,2})\s+day\s+trip\b/i,
    /\bplan\s+a\s+(\d{1,2})\s+day\b/i,
    /\bfor\s+(\d{1,2})\s+days?\b/i,
  ];
  for (const re of patterns) {
    const m = raw.match(re);
    if (m) {
      const n = parseInt(m[1], 10);
      if (n >= 1 && n <= 30) return n;
    }
  }
  if (/\bweekend\b/i.test(raw)) return 3;
  if (/\bweek\b/i.test(raw) && !/\bweekend\b/i.test(raw)) return 7;
  return null;
}

/** Append hard day-count + spread requirements for create_trip. */
function enforceCreateTripDays(text) {
  const raw = safeString(text).trim();
  if (!raw) return raw;
  const days = inferTripDayCountFromText(raw);
  if (!days || days < 2) {
    return (
      `${raw}\n\n` +
      "If this is a multi-day trip, set trip.unscheduledDaysCount to the day count and spread " +
      "activity items across every dayIndex (never put the whole itinerary on day 0)."
    );
  }
  return (
    `${raw}\n\n` +
    `This is a ${days}-day trip. Set trip.unscheduledDaysCount=${days} ` +
    `(or dates spanning ${days} days if dates are known). ` +
    `Return a full_itinerary with activities on EVERY dayIndex from 0 to ${days - 1}. ` +
    `Each day-scoped activity must include dayIndex and dayLabel ("Day 1"…"Day ${days}"). ` +
    `Do not place all sightseeing/meals on dayIndex 0.`
  );
}

/** Trip length for seed redistribution. */
function resolveCreateTripDayCount(trip, inferredDays) {
  if (trip?.isDatesSet && trip.startDate && trip.endDate) {
    const start = Date.parse(trip.startDate);
    const end = Date.parse(trip.endDate);
    if (Number.isFinite(start) && Number.isFinite(end) && end >= start) {
      const days = Math.round((end - start) / 86400000) + 1;
      return Math.max(1, Math.min(days, 30));
    }
  }
  const fromTrip = Number.isInteger(trip?.unscheduledDaysCount)
    ? trip.unscheduledDaysCount
    : 0;
  return Math.max(1, Math.min(fromTrip || inferredDays || 3, 30));
}

/**
 * If Gemini collapsed a multi-day itinerary onto day 0, redistribute day-scoped
 * activities across 0…dayCount-1 while keeping hotel/checklist/reminders on day 0.
 */
function redistributeCreateTripItems(items, dayCount) {
  const n = Math.max(1, Math.min(Number(dayCount) || 1, 30));
  if (!Array.isArray(items) || items.length === 0 || n < 2) return items;

  for (const item of items) {
    if (item.dayIndex == null) {
      const fromLabel = parseDayIndexFromLabel(item.dayLabel);
      if (fromLabel != null) item.dayIndex = fromLabel;
    } else {
      item.dayIndex = Math.max(0, Math.min(item.dayIndex, n - 1));
    }
    if (item.dayIndex != null && !safeString(item.dayLabel)) {
      item.dayLabel = `Day ${item.dayIndex + 1}`;
    }
  }

  const isHotel = (item) =>
    item.kind === "activity" && safeString(item.category).toLowerCase() === "hotel";
  const isDayScoped = (item) =>
    item.kind === "activity" && !isHotel(item);

  const dayScoped = items.filter(isDayScoped);
  if (dayScoped.length === 0) return items;

  const covered = new Set(
    dayScoped
      .map((item) => item.dayIndex)
      .filter((d) => Number.isInteger(d) && d >= 0 && d < n)
  );
  const allOnFirst = dayScoped.every((item) => (item.dayIndex ?? 0) === 0);
  const needsRedistribute = allOnFirst || covered.size < Math.min(n, Math.max(2, Math.ceil(n * 0.6)));

  if (!needsRedistribute) return items;

  let slot = 0;
  for (const item of items) {
    if (item.kind === "checklist" || item.kind === "reminder" || isHotel(item)) {
      item.dayIndex = 0;
      item.dayLabel = "Day 1";
      continue;
    }
    if (!isDayScoped(item)) {
      if (item.dayIndex == null) {
        item.dayIndex = 0;
        item.dayLabel = "Day 1";
      }
      continue;
    }
    item.dayIndex = slot % n;
    item.dayLabel = `Day ${item.dayIndex + 1}`;
    slot += 1;
  }
  return items;
}

function sanitizeItem(item, mode) {
  if (!item || typeof item !== "object") return null;

  const allowedKinds =
    mode === "place_finder" ? ["place"] : PLAN_DAY_KINDS;
  if (!allowedKinds.includes(item.kind)) return null;

  let dayIndex = coerceInt(item.dayIndex);
  if (dayIndex == null) {
    dayIndex = parseDayIndexFromLabel(item.dayLabel);
  }

  const clean = {
    id: typeof item.id === "string" && item.id.length > 0 ? item.id : cryptoRandomId(),
    kind: item.kind,
    include: item.include !== false,
    dayID: null,
    dayIndex,
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
    category: PLACE_FINDER_CATEGORIES.includes(item.category)
      ? item.category
      : "",
  };

  if (mode === "place_finder") {
    clean.category = PLACE_FINDER_CATEGORIES.includes(item.category)
      ? item.category
      : "other";
    // Keep title-only rows so the client can MapKit-refine location; drop empties only.
    if (!clean.title.trim()) return null;
    clean.startTime = null;
    clean.endTime = null;
    clean.dayIndex = null;
    clean.dayLabel = "";
  }

  // Venue-like activities should keep a category for UI sectioning.
  if (
    (mode === "create_trip" || mode === "plan_day") &&
    clean.kind === "activity" &&
    !clean.category
  ) {
    clean.category = "attraction";
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

  const tryParse = (raw) => {
    try {
      return JSON.parse(raw);
    } catch {
      return null;
    }
  };

  let parsed = tryParse(trimmed);
  if (parsed) return parsed;

  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenced?.[1]) {
    parsed = tryParse(fenced[1].trim());
    if (parsed) return parsed;
  }

  // Brace-balanced slice from the first `{` (more reliable than lastIndexOf
  // when the model truncates mid-object and an earlier `}` exists).
  const start = trimmed.indexOf("{");
  if (start < 0) return null;

  let depth = 0;
  let inString = false;
  let escape = false;
  for (let i = start; i < trimmed.length; i++) {
    const ch = trimmed[i];
    if (inString) {
      if (escape) {
        escape = false;
      } else if (ch === "\\") {
        escape = true;
      } else if (ch === "\"") {
        inString = false;
      }
      continue;
    }
    if (ch === "\"") {
      inString = true;
      continue;
    }
    if (ch === "{") depth += 1;
    if (ch === "}") {
      depth -= 1;
      if (depth === 0) {
        parsed = tryParse(trimmed.slice(start, i + 1));
        if (parsed) return parsed;
        break;
      }
    }
  }

  // Soft repairs for common model slip-ups / truncated payloads.
  const candidate = trimmed.slice(start);
  const repaired = candidate
    .replace(/,\s*([}\]])/g, "$1") // trailing commas
    .replace(/[\u201C\u201D]/g, '"')
    .replace(/[\u2018\u2019]/g, "'");
  parsed = tryParse(repaired);
  if (parsed) return parsed;

  return tryParse(closeTruncatedJSON(repaired));
}

/** Best-effort close for MAX_TOKENS mid-object / mid-array truncation. */
function closeTruncatedJSON(text) {
  let s = String(text ?? "");
  if (!s) return s;

  let inString = false;
  let escape = false;
  const stack = [];

  for (let i = 0; i < s.length; i++) {
    const ch = s[i];
    if (inString) {
      if (escape) {
        escape = false;
      } else if (ch === "\\") {
        escape = true;
      } else if (ch === "\"") {
        inString = false;
      }
      continue;
    }
    if (ch === "\"") {
      inString = true;
      continue;
    }
    if (ch === "{") stack.push("}");
    else if (ch === "[") stack.push("]");
    else if (ch === "}" || ch === "]") {
      if (stack.length && stack[stack.length - 1] === ch) stack.pop();
    }
  }

  if (inString) s += '"';
  s = s.replace(/,\s*$/, "");
  // Drop a dangling key or colon at the end: `"title":` / `"title"`
  s = s.replace(/,?\s*"[^"]*"\s*:\s*$/, "");
  s = s.replace(/,?\s*"[^"]*"\s*$/, "");
  s = s.replace(/,\s*$/, "");

  while (stack.length) s += stack.pop();
  return s;
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

    const text =
      mode === "create_trip"
        ? enforceCreateTripDays(body?.text ?? "")
        : enforceItemCount(body?.text ?? "", mode);
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

    const outputRequirements =
      mode === "place_finder"
        ? "Unless clarificationNeeded, items MUST contain exactly 10 distinct kind=place venues (or the user's explicit N). Never return a single recommendation for list-style asks like best hikes, restaurants, or stays. Coordinates/addresses with digits are not a count."
        : mode === "plan_day"
          ? "Unless clarificationNeeded or a single checklist/reminder/flight ask: items MUST contain multiple distinct itinerary entries (6–8 activities for day_plan; 8 options for options_list). Keep notes to one short sentence. Never collapse a day into one summary item."
          : mode === "create_trip"
            ? "For multi-day trips: set unscheduledDaysCount (or dates) to the stated length. Spread activity items across EVERY dayIndex — never put the full itinerary on day 0. Each day-scoped activity needs dayIndex + dayLabel."
            : undefined;

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
      ...(outputRequirements ? { outputRequirements } : {}),
    };

    const model =
      (process.env.GEMINI_MODEL || DEFAULT_MODEL).toString().trim() || DEFAULT_MODEL;

    const url = new URL(
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`
    );
    url.searchParams.set("key", apiKey);

    async function callGemini(messagePayload) {
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
              parts: [{ text: JSON.stringify(messagePayload) }],
            },
          ],
          generationConfig: {
            temperature: mode === "place_finder" ? 0.7 : 0.5,
            maxOutputTokens:
              mode === "place_finder"
                ? 8192
                : mode === "create_trip"
                  ? 16384
                  : 8192,
            responseMimeType: "application/json",
            responseSchema,
          },
        }),
      });

      const upstreamText = await geminiRes.text();
      if (!geminiRes.ok) {
        return {
          ok: false,
          status: geminiRes.status,
          body: upstreamText || `Upstream error (${geminiRes.status})`,
        };
      }

      let geminiJSON;
      try {
        geminiJSON = JSON.parse(upstreamText);
      } catch {
        return { ok: false, status: 502, body: upstreamText, error: "Invalid JSON from Gemini" };
      }

      const candidate = geminiJSON?.candidates?.[0];
      const candidateText =
        candidate?.content?.parts?.map((p) => p?.text ?? "").join("") ?? "";
      const finishReason = candidate?.finishReason ?? null;
      const blockReason = geminiJSON?.promptFeedback?.blockReason ?? null;

      const parsed = extractJSON(candidateText);
      if (!parsed || typeof parsed !== "object") {
        // Do not echo the raw model payload to clients (can be huge).
        console.error("Gemini returned no usable JSON", {
          mode,
          finishReason,
          blockReason,
          preview: String(candidateText).slice(0, 400),
          length: String(candidateText).length,
        });
        return {
          ok: false,
          status: 502,
          error: "Gemini returned no usable JSON",
          finishReason,
          blockReason,
        };
      }
      return { ok: true, result: parsed, finishReason };
    }

    let firstCall = await callGemini(userMessage);
    // Parse failure: retry once with a smaller, shorter payload (truncation / empty candidates).
    if (!firstCall.ok && firstCall.error === "Gemini returned no usable JSON") {
      const compactMessage = {
        ...userMessage,
        outputRequirements:
          mode === "place_finder"
            ? "Return exactly 6 distinct kind=place venues. Keep notes under 12 words. Valid complete JSON only."
            : mode === "plan_day"
              ? "Return exactly 6 distinct activity items for this ask. Keep notes under 12 words. One venue per item. Valid complete JSON only."
              : userMessage.outputRequirements,
      };
      const compactRetry = await callGemini(compactMessage);
      if (compactRetry.ok) {
        firstCall = compactRetry;
      }
    }
    if (!firstCall.ok) {
      if (firstCall.error) {
        return res.status(firstCall.status).json({ error: firstCall.error });
      }
      return res.status(firstCall.status).json({
        error: "Upstream AI request failed",
      });
    }

    let result = firstCall.result;

    // place_finder / plan_day often under-deliver (1–3 items). Retry once with a hard recount.
    const underDeliveredList =
      !result.clarificationNeeded &&
      Array.isArray(result.items) &&
      result.items.length > 0 &&
      result.items.length < 5 &&
      !hasExplicitPlaceCount(text);

    if (mode === "place_finder" && underDeliveredList) {
      const retryCall = await callGemini({
        ...userMessage,
        priorItemCount: result.items.length,
        outputRequirements:
          `Your previous answer only returned ${result.items.length} place(s). That is invalid. ` +
          "Return a COMPLETE new JSON response with exactly 8 distinct kind=place venues for the same ask. " +
          "Keep notes under 12 words. Do not apologize; do not return fewer than 8.",
      });
      if (
        retryCall.ok &&
        Array.isArray(retryCall.result.items) &&
        retryCall.result.items.length > result.items.length
      ) {
        result = retryCall.result;
      }
    } else if (
      mode === "plan_day" &&
      underDeliveredList &&
      !isPlanDaySingleKindIntent(result.intent)
    ) {
      const retryCall = await callGemini({
        ...userMessage,
        priorItemCount: result.items.length,
        outputRequirements:
          `Your previous answer only returned ${result.items.length} item(s). That is invalid for this ask. ` +
          "Return a COMPLETE new JSON response with exactly 6 distinct activity items. " +
          "One venue/stop per item, notes under 12 words — never a single combined day summary. Do not apologize.",
      });
      if (
        retryCall.ok &&
        Array.isArray(retryCall.result.items) &&
        retryCall.result.items.length > result.items.length
      ) {
        result = retryCall.result;
      }
      // Keep the short first answer if the recount retry failed to parse.
    }

    if (mode === "create_trip") {
      if (!result.trip || typeof result.trip !== "object") {
        return res.status(502).json({ error: "Invalid Gemini JSON shape (missing trip)" });
      }
      const trip = sanitizeTripDraft(result.trip);
      const inferredDays = inferTripDayCountFromText(text);
      if (
        inferredDays &&
        inferredDays >= 2 &&
        !trip.isDatesSet &&
        (!Number.isInteger(trip.unscheduledDaysCount) || trip.unscheduledDaysCount < inferredDays)
      ) {
        trip.unscheduledDaysCount = inferredDays;
      }
      const dayCount = resolveCreateTripDayCount(trip, inferredDays);
      const cleanedItems = Array.isArray(result.items)
        ? redistributeCreateTripItems(
            result.items.map((item) => sanitizeItem(item, "create_trip")).filter(Boolean),
            dayCount
          )
        : [];
      return res.status(200).json({
        intent: result.intent ?? "unknown",
        clarificationNeeded: Boolean(result.clarificationNeeded),
        clarificationPrompt: result.clarificationPrompt ?? "",
        trip,
        alternatives: [],
        items: cleanedItems,
      });
    }

    if (!Array.isArray(result.items)) {
      return res.status(502).json({
        error: "Gemini returned no usable items",
        body: result,
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
