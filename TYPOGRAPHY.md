# Typography System

## Font Family
**Inter** (Variable Font)

## Font Weights
- **Regular**: 400
- **Semibold**: 600

## Type Styles

### Semantic Styles
Predefined semantic styles with specific size and weight combinations:

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| `.appLargeTitle` | 34pt | Semibold | Large titles, sign-in headline |
| `.appTitle` | 28pt | Semibold | Primary titles, large icons |
| `.appTitle2` | 22pt | Semibold | Secondary titles, activity detail names |
| `.appHeadline` | 17pt | Semibold | Headlines, section headers, trip names, primary buttons |
| `.appBody` | 17pt | Regular | Body text, descriptions |
| `.appCallout` | 16pt | Regular | Preview text, callout information |
| `.appSubheadline` | 15pt | Regular | Subheadings, secondary labels, helper text |
| `.appFootnote` | 13pt | Regular | Footnotes, explanatory text, error messages |
| `.appCaption` | 12pt | Regular | Captions, small labels, metadata |

### Custom Sizes
Using `.app(size, weight:)` for specific use cases:

#### Large Display
- **60pt Regular** - Empty state icon
- **56pt Semibold** - Cost entry display
- **52pt Semibold** - Activity icon picker
- **40pt Semibold** - Activity/checklist name input fields
- **34pt Semibold** - Sign-in page headline (via `.appLargeTitle`)

#### Medium Sizes
- **24pt Semibold** - Empty state tracker icons
- **22pt Semibold** - Activity detail titles, plus icons
- **20pt Semibold** - Airport codes, tracker icons, checklist icons
- **20pt Regular** - Flight icon, icon buttons

#### Small Sizes
- **18pt Regular** - Icon selector icons
- **16pt Semibold** - Map annotations, flight info
- **15pt Semibold** - Section titles, card titles, stats titles, plan day loader, date picker labels, calendar month titles
- **14pt Semibold** - Icon buttons, trip settings icons
- **13pt Semibold** - Chevron icons, small UI elements
- **12pt Semibold** - Weather data, sunrise/sunset times
- **11pt Semibold** - Sort indicators, weekday labels

## Usage Guidelines

### When to Use Semantic Styles
Use predefined semantic styles (`.appLargeTitle`, `.appHeadline`, etc.) for standard UI text like:
- Screen titles and headers
- Body copy and descriptions
- Captions and metadata
- Helper text and labels

### When to Use Custom Sizes
Use `.app(size, weight:)` for:
- Unique display elements (large inputs, cost displays)
- Icons and symbols
- Special emphasis or visual hierarchy needs
- Components requiring precise sizing

## Implementation

```swift
// Semantic styles
Text("Welcome")
    .font(.appLargeTitle)

Text("Trip Details")
    .font(.appHeadline)

Text("Description text")
    .font(.appBody)

// Custom sizes
Text("$1,234")
    .font(.app(56, weight: .semibold))

Image(systemName: "airplane")
    .font(.app(20, weight: .regular))
```

## Key Components Using Typography

### Headers & Navigation
- **Trip name in top bar**: 17pt Semibold
- **Day column dates**: 17pt Semibold
- **Day count**: 12pt Regular (caption)

### Cards & Content
- **Activity names**: 40pt Semibold (input), 22pt Semibold (detail)
- **Airport codes**: 20pt Semibold
- **Flight numbers**: 15pt Semibold
- **Stats card titles**: 15pt Semibold
- **Tracker titles**: 15pt Semibold

### Interactive Elements
- **Button labels**: 17pt Semibold (headline)
- **Icon buttons**: 14pt Semibold
- **Chevrons**: 13pt Semibold

### Specialty
- **Cost display**: 56pt Semibold
- **Passport stamp text**: Dynamic size Semibold
- **Empty state icon**: 60pt Regular
- **Large title overlays**: 34pt Semibold

---

*Last updated: January 2026*
