import Foundation

enum AIMode: String, Codable, Hashable {
    case planDay = "plan_day"
    case placeFinder = "place_finder"
    case createTrip = "create_trip"
}

struct AITripSummary: Hashable, Codable {
    var name: String
    var destination: String
    var startDate: String?
    var endDate: String?
    var isDatesSet: Bool
    
    init(
        name: String,
        destination: String,
        startDate: String? = nil,
        endDate: String? = nil,
        isDatesSet: Bool = false
    ) {
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.isDatesSet = isDatesSet
    }
}

struct AIPlaceSummary: Hashable, Codable {
    var name: String
    var location: String
    var category: String
    var note: String
    
    init(name: String, location: String, category: String = "", note: String = "") {
        self.name = name
        self.location = location
        self.category = category
        self.note = note
    }
}

struct AITripDraft: Hashable, Codable, Identifiable {
    var id: String { "\(name)|\(destination)|\(startDate ?? "")|\(endDate ?? "")" }
    var name: String
    var destination: String
    var isDatesSet: Bool
    var startDate: String?
    var endDate: String?
    var unscheduledDaysCount: Int
    var summary: String
    var confidence: Double
    
    init(
        name: String = "",
        destination: String = "",
        isDatesSet: Bool = false,
        startDate: String? = nil,
        endDate: String? = nil,
        unscheduledDaysCount: Int = 3,
        summary: String = "",
        confidence: Double = 0.5
    ) {
        self.name = name
        self.destination = destination
        self.isDatesSet = isDatesSet
        self.startDate = startDate
        self.endDate = endDate
        self.unscheduledDaysCount = unscheduledDaysCount
        self.summary = summary
        self.confidence = confidence
    }
}

extension AITripDraft {
    /// Calendar-date math for YYYY-MM-DD strings (never local startOfDay on UTC midnight).
    fileprivate static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }
    
    /// Roll past-year AI dates forward to the next upcoming occurrence.
    mutating func normalizeUpcomingDates(reference: Date = Date()) {
        guard isDatesSet else { return }
        guard var start = Self.parseDraftISODate(startDate),
              var end = Self.parseDraftISODate(endDate) else { return }
        
        let calendar = Self.utcCalendar
        start = calendar.startOfDay(for: start)
        end = calendar.startOfDay(for: end)
        let today = calendar.startOfDay(for: reference)
        
        while end < start {
            end = calendar.date(byAdding: .year, value: 1, to: end) ?? end
        }
        var guardCount = 0
        while end < today, guardCount < 10 {
            start = calendar.date(byAdding: .year, value: 1, to: start) ?? start
            end = calendar.date(byAdding: .year, value: 1, to: end) ?? end
            guardCount += 1
        }
        
        startDate = Self.formatDraftISODate(start)
        endDate = Self.formatDraftISODate(end)
        unscheduledDaysCount = 0
    }
    
    private static func parseDraftISODate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: raw)
    }
    
    private static func formatDraftISODate(_ date: Date) -> String {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }
}

struct AIRequest: Codable {
    var mode: AIMode
    var text: String
    var scopeHint: String
    var tripContext: PlanDayTripContext?
    var preferences: PlanDayUserPreferences?
    var existingItems: [PlanDayItem]
    var existingPlaces: [AIPlaceSummary]
    var existingTrips: [AITripSummary]
    var facts: PlanDayFacts
    
    init(
        mode: AIMode,
        text: String,
        scopeHint: String = "",
        tripContext: PlanDayTripContext? = nil,
        preferences: PlanDayUserPreferences? = nil,
        existingItems: [PlanDayItem] = [],
        existingPlaces: [AIPlaceSummary] = [],
        existingTrips: [AITripSummary] = [],
        facts: PlanDayFacts = PlanDayFacts()
    ) {
        self.mode = mode
        self.text = text
        self.scopeHint = scopeHint
        self.tripContext = tripContext
        self.preferences = preferences
        self.existingItems = existingItems
        self.existingPlaces = existingPlaces
        self.existingTrips = existingTrips
        self.facts = facts
    }
}

struct AIResponse: Codable {
    var intent: String
    var clarificationNeeded: Bool
    var clarificationPrompt: String
    var items: [PlanDayItem]
    var trip: AITripDraft?
    var alternatives: [AITripDraft]
    
    init(
        intent: String = "",
        clarificationNeeded: Bool = false,
        clarificationPrompt: String = "",
        items: [PlanDayItem] = [],
        trip: AITripDraft? = nil,
        alternatives: [AITripDraft] = []
    ) {
        self.intent = intent
        self.clarificationNeeded = clarificationNeeded
        self.clarificationPrompt = clarificationPrompt
        self.items = items
        self.trip = trip
        self.alternatives = alternatives
    }
}

enum TripStacksAIError: LocalizedError {
    case invalidResponse
    case http(status: Int, body: String)
    
    /// Short code from the API `{ "error": "..." }` payload when present.
    var serverErrorCode: String? {
        guard case let .http(_, body) = self else { return nil }
        return Self.parseServerError(from: body)
    }
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server."
        case .http(let status, let body):
            if let code = Self.parseServerError(from: body) {
                return code
            }
            if body.isEmpty {
                return "Server error (\(status))."
            }
            // Never surface raw upstream payloads (can be huge / escaped JSON).
            return "Server error (\(status))."
        }
    }
    
    private static func parseServerError(from body: String) -> String? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = obj["error"] as? String
        else { return nil }
        let code = error.trimmingCharacters(in: .whitespacesAndNewlines)
        return code.isEmpty ? nil : code
    }
}

enum AIDayMapping {
    /// Maps AI dayIndex / dayLabel onto concrete day UUIDs.
    static func assignDayIDs(
        to items: [PlanDayItem],
        dayOptions: [DayOption],
        defaultDayID: UUID?
    ) -> [PlanDayItem] {
        let nonIdeas = dayOptions.filter { !$0.isParkedIdeas }
        let fallback = defaultDayID ?? nonIdeas.first?.id ?? dayOptions.first?.id
        
        return items.map { item in
            var updated = item
            if updated.dayID != nil { return updated }
            
            if let index = updated.dayIndex, index >= 0, index < nonIdeas.count {
                updated.dayID = nonIdeas[index].id
                return updated
            }
            
            let label = updated.dayLabel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !label.isEmpty,
               let match = nonIdeas.first(where: {
                   $0.title.lowercased().contains(label) || label.contains($0.title.lowercased())
               }) {
                updated.dayID = match.id
                return updated
            }
            
            updated.dayID = fallback
            return updated
        }
    }
    
    static func inferredDayCount(from text: String) -> Int? {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        
        let patterns = [
            #"\b(\d{1,2})\s*-?\s*days?\b"#,
            #"\b(\d{1,2})\s+day\s+trip\b"#,
            #"\bplan\s+a\s+(\d{1,2})\s+day\b"#,
            #"\bfor\s+(\d{1,2})\s+days?\b"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: raw),
               let value = Int(raw[range]),
               (1...30).contains(value) {
                return value
            }
        }
        if raw.range(of: #"\bweekend\b"#, options: .regularExpression) != nil { return 3 }
        if raw.range(of: #"\bweek\b"#, options: .regularExpression) != nil,
           raw.range(of: #"\bweekend\b"#, options: .regularExpression) == nil {
            return 7
        }
        return nil
    }
    
    static func resolvedDayCount(for trip: AITripDraft, promptText: String) -> Int {
        if trip.isDatesSet,
           let start = Self.parseISODate(trip.startDate),
           let end = Self.parseISODate(trip.endDate),
           end >= start {
            let days = (AITripDraft.utcCalendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
            return min(max(days, 1), 30)
        }
        if let extracted = extractTripDateRange(from: promptText) {
            return resolvedDayCount(
                for: AITripDraft(isDatesSet: true, startDate: extracted.start, endDate: extracted.end),
                promptText: promptText
            )
        }
        let inferred = inferredDayCount(from: promptText) ?? 0
        return min(max(max(trip.unscheduledDaysCount, inferred), 1), 30)
    }
    
    /// Item floor that can finish inside one Gemini response (long trips still get 8–12, not 22).
    static func completableItemCount(dayCount: Int) -> Int {
        let days = min(max(dayCount, 1), 30)
        return max(8, min(days + 4, 12))
    }
    
    /// Spread day-scoped activities across 0…dayCount-1 when the model collapsed onto day 0.
    static func spreadCreateTripItems(_ items: [PlanDayItem], dayCount: Int) -> [PlanDayItem] {
        let n = min(max(dayCount, 1), 30)
        guard n >= 2, !items.isEmpty else { return items }
        
        var updated = items.map { item -> PlanDayItem in
            var copy = item
            if copy.dayIndex == nil {
                copy.dayIndex = dayIndex(fromLabel: copy.dayLabel)
            }
            if let index = copy.dayIndex {
                copy.dayIndex = min(max(index, 0), n - 1)
                if copy.dayLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    copy.dayLabel = "Day \((copy.dayIndex ?? 0) + 1)"
                }
            }
            return copy
        }
        
        func isHotel(_ item: PlanDayItem) -> Bool {
            item.kind == .activity && item.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "hotel"
        }
        func isDayScoped(_ item: PlanDayItem) -> Bool {
            item.kind == .activity && !isHotel(item)
        }
        
        let dayScoped = updated.filter(isDayScoped)
        guard !dayScoped.isEmpty else { return updated }
        
        let covered = Set(dayScoped.compactMap { item -> Int? in
            guard let index = item.dayIndex, (0..<n).contains(index) else { return nil }
            return index
        })
        let allOnFirst = dayScoped.allSatisfy { ($0.dayIndex ?? 0) == 0 }
        let minCoverage = min(n, max(2, Int(ceil(Double(n) * 0.6))))
        guard allOnFirst || covered.count < minCoverage else { return updated }
        
        var slot = 0
        for idx in updated.indices {
            let item = updated[idx]
            if item.kind == .checklist || item.kind == .reminder || isHotel(item) {
                updated[idx].dayIndex = 0
                updated[idx].dayLabel = "Day 1"
                continue
            }
            guard isDayScoped(item) else {
                if updated[idx].dayIndex == nil {
                    updated[idx].dayIndex = 0
                    updated[idx].dayLabel = "Day 1"
                }
                continue
            }
            let dayIndex = slot % n
            updated[idx].dayIndex = dayIndex
            updated[idx].dayLabel = "Day \(dayIndex + 1)"
            slot += 1
        }
        return updated
    }
    
    private static func dayIndex(fromLabel label: String) -> Int? {
        let raw = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let regex = try? NSRegularExpression(pattern: #"day\s*(\d+)"#, options: .caseInsensitive),
              let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: raw),
              let value = Int(raw[range]),
              value >= 1 else { return nil }
        return value - 1
    }
    
    private static func parseISODate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: raw)
    }
    
    private static func formatISODate(_ date: Date) -> String {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }
    
    /// Deterministic date-range extraction (ISO or month/day phrases like "December 23 – January 1").
    static func extractTripDateRange(from text: String, reference: Date = Date()) -> (start: String, end: String)? {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        let today = calendar.startOfDay(for: reference)
        
        func rollUpcoming(start: Date, end: Date) -> (Date, Date) {
            var s = calendar.startOfDay(for: start)
            var e = calendar.startOfDay(for: end)
            while e < s {
                e = calendar.date(byAdding: .year, value: 1, to: e) ?? e
            }
            var guardCount = 0
            while e < today, guardCount < 10 {
                s = calendar.date(byAdding: .year, value: 1, to: s) ?? s
                e = calendar.date(byAdding: .year, value: 1, to: e) ?? e
                guardCount += 1
            }
            return (s, e)
        }
        
        if let regex = try? NSRegularExpression(
            pattern: #"\b(\d{4}-\d{2}-\d{2})\s*(?:to|through|thru|until|-|–|—)\s*(\d{4}-\d{2}-\d{2})\b"#,
            options: .caseInsensitive
        ),
           let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
           let r1 = Range(match.range(at: 1), in: raw),
           let r2 = Range(match.range(at: 2), in: raw),
           let start = parseISODate(String(raw[r1])),
           let end = parseISODate(String(raw[r2])) {
            let rolled = rollUpcoming(start: start, end: end)
            return (formatISODate(rolled.0), formatISODate(rolled.1))
        }
        
        let months = "january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sep|sept|october|oct|november|nov|december|dec"
        let pattern =
            #"\b("# + months + #")\s+(\d{1,2})(?:st|nd|rd|th)?(?:,?\s*(\d{4}))?"# +
            #"\s*(?:to|through|thru|until|-|–|—)\s*"# +
            #"("# + months + #")\s+(\d{1,2})(?:st|nd|rd|th)?(?:,?\s*(\d{4}))?\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
              match.numberOfRanges >= 6,
              let m1 = Range(match.range(at: 1), in: raw),
              let d1 = Range(match.range(at: 2), in: raw),
              let m2 = Range(match.range(at: 4), in: raw),
              let d2 = Range(match.range(at: 5), in: raw),
              let startDay = Int(raw[d1]),
              let endDay = Int(raw[d2]),
              let startMonth = monthIndex(String(raw[m1])),
              let endMonth = monthIndex(String(raw[m2])) else { return nil }
        
        let y1Range = Range(match.range(at: 3), in: raw)
        let y2Range = Range(match.range(at: 6), in: raw)
        let y1 = y1Range.flatMap { Int(raw[$0]) }
        let y2 = y2Range.flatMap { Int(raw[$0]) }
        let refYear = calendar.component(.year, from: today)
        
        var startYear = y1 ?? refYear
        var endYear = y2 ?? startYear
        if y2 == nil, endMonth < startMonth {
            endYear = startYear + 1
        }
        
        var startComps = DateComponents(year: startYear, month: startMonth, day: startDay)
        var endComps = DateComponents(year: endYear, month: endMonth, day: endDay)
        if y1 == nil, y2 == nil {
            startComps.year = refYear
            endComps.year = endMonth < startMonth ? refYear + 1 : refYear
        }
        guard let start = calendar.date(from: startComps),
              let end = calendar.date(from: endComps) else { return nil }
        let rolled = rollUpcoming(start: start, end: end)
        return (formatISODate(rolled.0), formatISODate(rolled.1))
    }
    
    private static func monthIndex(_ name: String) -> Int? {
        let key = name.lowercased()
        let map: [String: Int] = [
            "january": 1, "jan": 1, "february": 2, "feb": 2, "march": 3, "mar": 3,
            "april": 4, "apr": 4, "may": 5, "june": 6, "jun": 6, "july": 7, "jul": 7,
            "august": 8, "aug": 8, "september": 9, "sep": 9, "sept": 9,
            "october": 10, "oct": 10, "november": 11, "nov": 11, "december": 12, "dec": 12,
        ]
        return map[key]
    }
    
    /// Count of venue activities MapKit failed to resolve.
    static func unresolvedVenueCount(_ items: [PlanDayItem]) -> Int {
        items.filter(\.isLocationUnresolved).count
    }
    
    static func needsLocationRefill(_ items: [PlanDayItem]) -> Bool {
        let venues = items.filter {
            $0.kind == .activity || $0.kind == .place
        }
        guard venues.count >= 2 else { return unresolvedVenueCount(items) >= 1 && venues.count == 1 }
        let unresolved = unresolvedVenueCount(items)
        return unresolved >= max(2, Int(ceil(Double(venues.count) * 0.4)))
    }
    
    /// Pull an explicit stay from prompts like "staying at The Plaza".
    static func extractNamedStay(from text: String) -> String? {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let patterns = [
            #"\b(?:staying|stay(?:ing)?|booked|book(?:ed)?|checking\s+in)\s+(?:at|in)\s+((?:the\s+)?[A-Za-z0-9][^.\n,]{2,80})"#,
            #"\b(?:hotel|resort|inn|lodge|suites?)\s*[:\-–]\s+((?:the\s+)?[A-Za-z0-9][^.\n,]{2,80})"#,
            #"\bat\s+((?:the\s+)?[A-Za-z][^.\n,]{2,60}\b(?:Hotel|Resort|Inn|Lodge|Suites?|House|Palace|Ritz|Hyatt|Marriott|Hilton|Fairmont|Four Seasons))\b"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: raw) else { continue }
            let name = String(raw[range])
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'”’")))
            if name.count >= 3 { return name }
        }
        return nil
    }
    
    /// Force the user's named hotel into seed items (replace invented stays).
    static func applyNamedStay(
        _ items: [PlanDayItem],
        fromPrompt text: String,
        destination: String,
        clearCoordinatesWhenRenaming: Bool = true
    ) -> [PlanDayItem] {
        guard let stayName = extractNamedStay(from: text) else { return items }
        let dest = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = dest.isEmpty ? stayName : "\(stayName), \(dest)"
        
        func isHotel(_ item: PlanDayItem) -> Bool {
            item.kind == .activity &&
            item.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "hotel"
        }
        
        let hotels = items.filter(isHotel)
        if !hotels.isEmpty {
            return items.map { item in
                guard isHotel(item) else { return item }
                var copy = item
                let alreadyNamed =
                    copy.title.localizedCaseInsensitiveContains(stayName) ||
                    copy.location.localizedCaseInsensitiveContains(stayName)
                copy.title = stayName
                copy.location = location
                copy.category = "hotel"
                if copy.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    copy.notes = "Your stay"
                }
                if clearCoordinatesWhenRenaming, !alreadyNamed {
                    copy.latitude = nil
                    copy.longitude = nil
                    copy.photoData = nil
                }
                return copy
            }
        }
        
        let hotel = PlanDayItem(
            kind: .activity,
            dayIndex: 0,
            dayLabel: "Day 1",
            title: stayName,
            location: location,
            notes: "Your stay",
            confidence: 0.95,
            sourceSnippet: stayName,
            category: "hotel"
        )
        return [hotel] + items
    }
}

extension PlaceType {
    static func fromAICategory(_ raw: String) -> PlaceType {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return PlaceType(rawValue: key) ?? .other
    }
}

extension PlanDayItem {
    /// Treat API `kind: "place"` as an activity-shaped item carrying `category`.
    static func normalizingPlaceKind(_ item: PlanDayItem) -> PlanDayItem {
        var copy = item
        if copy.kind == .activity, copy.category.isEmpty == false {
            return copy
        }
        return copy
    }
}
