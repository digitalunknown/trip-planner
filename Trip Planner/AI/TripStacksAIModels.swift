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
    
    init(name: String, destination: String, startDate: String? = nil, endDate: String? = nil) {
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
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
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server."
        case .http(let status, let body):
            if body.isEmpty {
                return "Server error (\(status))."
            }
            return "Server error (\(status)): \(body)"
        }
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
