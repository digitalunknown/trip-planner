# Trip Planner — Project Context

This document captures the current product/design intent and the technical decisions that shaped the codebase, so someone new can confidently continue work without re-discovering everything.

## What this app is

An iOS SwiftUI trip planning app with:

- A **Trips** area to create and manage trips (timeline by day, map + kanban-like day columns).
- A **Stats** area with “I’ve been” style trackers plus **Stamps** (passport-style stamps for completed trips).

The UX goal is “beautiful but native”: modern, tactile, Apple-like patterns, consistent cards, minimal chrome, and smooth navigation.

## Primary navigation / user flows

### Root navigation

`ContentView` uses a standard Apple `TabView` with two tabs:

- **Trips** (formerly “My Trips”)
- **Stats** (formerly “Trackers”)

Child views (Trip detail, Tracker detail, Stamps page) hide the tab bar for focus.

### Trips flow (Trips tab)

**Trips list (`MyTripsView`)**

- Shows big portrait **Trip cards** (cover image or map snapshot background).
- Long-press context menu on a trip card: add cover image, edit trip, delete trip (with confirmation).
- A segmented control toggles **Upcoming** vs **Past**.
  - Upcoming: chronological.
  - Past: latest first (years also latest→oldest).
- Tapping a trip opens **Trip detail**.

**New Trip (`Sheets/NewTripView`)**

- Name, destination search (MapKit), dates (defaults to 5 total days), cover image, and “Show Parked Ideas”.

**Edit Trip**

- Exists as both:
  - `Sheets/TripSettingsSheet` (used inside trip detail settings)
  - `EditTripView` (declared inside `MyTripsView.swift`)

> Important known issue (needs follow-up): changing trip dates can currently rebuild day arrays; the intended behavior is to confirm and allow **port vs delete** for out-of-range items.

### Trip detail flow (`TripDetailView`)

Trip detail is the “main app” experience:

- Top: **Map** (extends under the notch/top bar).
- Divider: **Resize handle** to resize map vs board with a “zoom in/out” feel.
- Bottom: horizontal board of **Day Columns** (kanban-like).

Key behaviors:

- Day columns can be scrolled horizontally; the app tracks which day is most visible and uses it to drive map markers.
- Map markers only show for the focused day (with cross-fade). If none, show all.
- Tapping `+` defaults the add sheet to the focused day.
- Native swipe-back gesture is preserved; map/board shouldn’t “fight” the edge swipe.

### Items within a day

Four day-based item types exist:

- **Activity** (renamed from “Event” everywhere)
- **Reminder** (one-line)
- **Checklist**
- **Flight**

Plus **Parked Ideas** (a separate column at the end, not a day) when enabled per trip.

All items support:

- Add / Edit via sheets
- Long-press context menus with consistent labels, destructive trash in red
- Quick move options (left/right/park) exist for multiple item types

### Stats flow (Stats tab)

**Stats home (`Trackers/TrackersHomeView`)**

- First: a full-width **Stamps** card (tappable) with a paged stamp carousel + custom pagination.
- Grid of tracker tiles (2-wide) below.
- A non-tappable “Trips Taken” tile appears first in the grid and counts completed trips.

**Tracker detail (`Trackers/TrackerDetailView`)**

- Search field + progress header
- Items are a single list separated by dividers (not per-item cards).
- Tap toggles visited with haptics.

**Stamps page (`Trackers/PassportView`, titled “Stamps”)**

- Shows completed-trip stamps newest-first.
- Background uses the app’s “page background” color scheme (see Theme section).

## Design system (high level)

### Visual language

- “Card-first” UI. Nearly everything is a rounded rectangle card.
- Minimal icon coloration: most toolbars are **primary color**, not accent.
- Accent color is user-selectable (AppStorage) and used for emphasis and selection.
- Trip cards use a “hero image” feel (cover image or map snapshot).

### Theme colors (custom)

These are the current theme colors referenced across cards/columns:

**Activity / Reminder / Flight card base**

- Light background: `#FFFEF9`
- Dark background: `#222222`
- Light primary text: `#171717`
- Dark primary text: `#EFEFF2`

**Day column**

- Light background: `#F0F0F0`
- Dark background: `#171717`
- Light stroke: `#FFFFFF`
- Dark stroke: `#252525`

**Trip detail page background (behind columns / grabber area)**

- Light: `#E0E0E0`
- Dark: `#0A0A0A`

### Interaction + haptics

- Tab selection triggers a selection haptic.
- Checking off tracker items and checklist actions can trigger haptics.

### “Liquid glass” toolbar buttons

Sheets use consistent circular icon buttons via `Components/LiquidGlassIconButton.swift`.

## Data model (overview)

Core models are in:

- `Trip.swift` — `Trip`, `TripDay`, `EventItem` (Activity), `ReminderItem`, `ChecklistItem`, `FlightItem`, `EventAccent`, etc.
- `Trackers/TrackerModels.swift` — tracker types and tracker item identity.

Notable model behaviors:

- **Trip days** are normalized with a stable `order` and derived labels like “Day X of Y”.
- **Parked Ideas** are stored separately on `Trip` (`parkedIdeas`) and shown only when `showParkedIdeas` is true.
- Flight stores both “from” and “to” location + manual airport code fields.

## Persistence / state management

### Trip persistence

`TripStore.swift`:

- Uses file-based JSON persistence in **Application Support** (not `UserDefaults`) to avoid size limits/hangs.
- Saves asynchronously on a background queue.

### Tracker persistence

`Trackers/TrackerStore.swift`:

- Similar file-based JSON persistence for visited states.

### Shared `TripStore` across tabs

Important: Trips and Stamps must see the same trip data.

- `ContentView` creates a single `TripStore` and injects it via `.environment(tripStore)`.
- Views read it via `@Environment(TripStore.self)` (not `@EnvironmentObject`).

If Stamps ever fails to update after editing trips, this is the first thing to check.

## Maps & location search

Map features live primarily in:

- `TripDetailView.swift` (map rendering + camera/region behavior + marker filtering)
- `Components/MapSearchFields.swift` and `Components/MapKitHelpers.swift`

Key behaviors:

- Map pins are driven by activities with valid coordinates + non-empty location.
- Map region uses `mapSpan` based on selected place granularity (city/state/country/etc).
- Airport search uses MapKit + filtering and manual code fields for reliability.

## Stamps (passport stamps)

Stamps are rendered by:

- `Components/PassportStampView.swift`

Key design/tech:

- Circular ring text: `LOCATION • YEAR • LOCATION • YEAR`
- The stamp has a **tilt parallax** effect via `CoreMotion`.
- Inner ring is now **radial ticks** (watch-face feel).

## Folder structure

Top-level app code lives under `Trip Planner/`:

- `Trip Planner/Components/`
  - Reusable UI components (cards, controls, helpers)
  - Examples:
    - `TripCardView.swift` (trip list hero card)
    - `EventCard.swift`, `FlightCard.swift`, `ChecklistCard.swift`, `ReminderCard.swift`
    - `TrackerCardView.swift` (grid tiles + progress bar)
    - `PassportStampView.swift` (stamp drawing)
    - `ResizeHandle.swift` (map/board resizer)
    - `MapSearchFields.swift`, `MapKitHelpers.swift`

- `Trip Planner/Sheets/`
  - Modal sheets used across the app
  - Examples:
    - `NewTripView.swift`, `TripSettingsSheet.swift`
    - `AddEventSheet.swift`, `AddReminderSheet.swift`, `ChecklistSheet.swift`, `AddFlightSheet.swift`
    - `SettingsView.swift`

- `Trip Planner/Trackers/`
  - Stats feature area
  - Examples:
    - `TrackersHomeView.swift` (Stats home)
    - `TrackerDetailView.swift` (items list)
    - `PassportView.swift` (Stamps page)
    - `TrackerData.swift` (seed lists), `TrackerStore.swift` (persistence)

- “Core” files:
  - `ContentView.swift` (tabs + global env)
  - `Trip_PlannerApp.swift` (app entry + haptics helper)
  - `TripStore.swift` (trip persistence)
  - `TripDetailView.swift` (largest view; orchestrates map + board)

## Notable UI/UX decisions (quick list)

- Trips are portrait cards with image/map background + progressive blur at bottom for readability.
- Upcoming/Past split via segmented control on Trips list.
- Past trips generate stamps and appear in Stamps newest-first.
- Stats grid is two-wide rectangles; tiles are equal height with truncation.
- Progress bars use “ticks”; grid tiles use fewer ticks so they aren’t hair-thin.
- “Trips Taken” is a special non-tappable tile derived from past trips in `TripStore`.

## Known gotchas / TODOs

- **Trip date change wiping activities**:
  - `TripDetailView.updateTripDaysForDates()` rebuilds the day array by matching dates. If the range shifts, items may be lost.
  - Intended: prompt user with counts and allow **port by delta** vs **delete** for all item types (activities/reminders/checklists/flights + parked ideas).

- **Build environments**:
  - Some Swift macro / plugin steps can fail under sandboxed builds. Local Xcode builds are fine.

## Where to start when making changes

- Trips list UI: `Trip Planner/MyTripsView.swift` + `Components/TripCardView.swift`
- Trip detail UX: `Trip Planner/TripDetailView.swift` + `Components/DayColumn.swift` + `Components/ResizeHandle.swift`
- Stats home tiles: `Trackers/TrackersHomeView.swift` + `Components/TrackerCardView.swift`
- Stamps rendering: `Components/PassportStampView.swift`
- Data/persistence: `TripStore.swift`, `TrackerStore.swift`, `Trip.swift`

