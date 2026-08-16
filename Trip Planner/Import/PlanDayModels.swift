import Foundation

enum PlanDayItemKind: String, Codable, CaseIterable, Hashable {
    case activity
    case reminder
    case checklist
    case flight
    /// Place Finder only — never applied via plan-day commit path.
    case place
}

struct PlanDayItem: Identifiable, Hashable, Codable {
    let id: UUID
    var kind: PlanDayItemKind
    var include: Bool
    
    var dayID: UUID?
    /// 0-based day offset from trip start when `dayID` is unknown (AI multi-day).
    var dayIndex: Int?
    var dayLabel: String
    
    var title: String
    var subtitle: String
    
    var location: String
    /// MapKit-resolved coordinates when available (map pins need these, not just location text).
    var latitude: Double?
    var longitude: Double?
    var notes: String
    
    var startTime: Date?
    var endTime: Date?
    
    var checklistItemsText: String
    
    var flightFromCode: String
    var flightToCode: String
    var flightNumber: String
    
    var confidence: Double?
    var sourceSnippet: String
    
    /// Place Finder category (`restaurant`, `hotel`, …). Empty for plan_day items.
    var category: String
    
    init(
        id: UUID = UUID(),
        kind: PlanDayItemKind,
        include: Bool = true,
        dayID: UUID? = nil,
        dayIndex: Int? = nil,
        dayLabel: String = "",
        title: String,
        subtitle: String = "",
        location: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        notes: String = "",
        startTime: Date? = nil,
        endTime: Date? = nil,
        checklistItemsText: String = "",
        flightFromCode: String = "",
        flightToCode: String = "",
        flightNumber: String = "",
        confidence: Double? = nil,
        sourceSnippet: String = "",
        category: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.include = include
        self.dayID = dayID
        self.dayIndex = dayIndex
        self.dayLabel = dayLabel
        self.title = title
        self.subtitle = subtitle
        self.location = location
        self.latitude = latitude
        self.longitude = longitude
        self.notes = notes
        self.startTime = startTime
        self.endTime = endTime
        self.checklistItemsText = checklistItemsText
        self.flightFromCode = flightFromCode
        self.flightToCode = flightToCode
        self.flightNumber = flightNumber
        self.confidence = confidence
        self.sourceSnippet = sourceSnippet
        self.category = category
    }
}

struct PlanDayDraft: Hashable, Codable {
    var items: [PlanDayItem]
    var extractedText: String
    var extractedFacts: PlanDayFacts
    
    init(items: [PlanDayItem], extractedText: String, extractedFacts: PlanDayFacts) {
        self.items = items
        self.extractedText = extractedText
        self.extractedFacts = extractedFacts
    }
}

struct PlanDayFacts: Hashable, Codable {
    var detectedDates: [PlanDayDetectedDate]
    var detectedLinks: [String]
    var detectedAddresses: [String]
    
    init(detectedDates: [PlanDayDetectedDate] = [], detectedLinks: [String] = [], detectedAddresses: [String] = []) {
        self.detectedDates = detectedDates
        self.detectedLinks = detectedLinks
        self.detectedAddresses = detectedAddresses
    }
}

struct PlanDayDetectedDate: Hashable, Codable, Identifiable {
    let id: UUID
    var date: Date
    var hasTime: Bool
    var snippet: String
    
    init(id: UUID = UUID(), date: Date, hasTime: Bool, snippet: String) {
        self.id = id
        self.date = date
        self.hasTime = hasTime
        self.snippet = snippet
    }
}

struct PlanDayTripContext: Hashable, Codable {
    var isDatesSet: Bool
    var startDate: Date
    var endDate: Date
    var unscheduledDaysCount: Int
    var destination: String
    var latitude: Double?
    var longitude: Double?
    var mapSpan: Double?
    
    init(
        isDatesSet: Bool,
        startDate: Date,
        endDate: Date,
        unscheduledDaysCount: Int,
        destination: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        mapSpan: Double? = nil
    ) {
        self.isDatesSet = isDatesSet
        self.startDate = startDate
        self.endDate = endDate
        self.unscheduledDaysCount = unscheduledDaysCount
        self.destination = destination
        self.latitude = latitude
        self.longitude = longitude
        self.mapSpan = mapSpan
    }
}

struct PlanDayUserPreferences: Hashable, Codable {
    var favoriteFoodCSV: String
    var drinksAlcohol: Bool
    var interestsCSV: String
    
    init(favoriteFoodCSV: String, drinksAlcohol: Bool, interestsCSV: String) {
        self.favoriteFoodCSV = favoriteFoodCSV
        self.drinksAlcohol = drinksAlcohol
        self.interestsCSV = interestsCSV
    }
    
    var isEmpty: Bool {
        favoriteFoodCSV.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        interestsCSV.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}


