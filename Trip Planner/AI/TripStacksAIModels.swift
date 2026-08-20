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
            let days = (Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0) + 1
            return min(max(days, 1), 30)
        }
        let inferred = inferredDayCount(from: promptText) ?? 0
        return min(max(max(trip.unscheduledDaysCount, inferred), 1), 30)
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
