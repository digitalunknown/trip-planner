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
    
    /// Optional cover from Apple Maps Look Around / snapshot (AI + Explore enrichment).
    var photoData: Data?
    
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
        category: String = "",
        photoData: Data? = nil
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
        self.photoData = photoData
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

/// Schedules start/end on AI itinerary activities when the model omits times.
enum PlanDayTiming {
    private static let dayStartMinutes = 9 * 60
    private static let gapMinutes = 30
    private static let latestStartMinutes = 21 * 60
    
    /// Whether we should invent a day schedule (not for options lists / place finder).
    static func shouldAutoSchedule(intent: String?, isCreateTrip: Bool = false) -> Bool {
        if isCreateTrip { return true }
        let i = (intent ?? "").lowercased()
        if i.contains("option") { return false }
        if i == "checklist" || i == "reminder" || i == "flight" { return false }
        if i.contains("place") { return false }
        return true
    }
    
    static func fillMissingActivityTimes(_ items: inout [PlanDayItem]) {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())
        
        var groups: [String: [Int]] = [:]
        for (idx, item) in items.enumerated() {
            guard item.kind == .activity || item.kind == .place else { continue }
            if isHotel(item) { continue }
            let key: String = {
                if let dayID = item.dayID { return "id:\(dayID.uuidString)" }
                if let dayIndex = item.dayIndex { return "idx:\(dayIndex)" }
                let label = item.dayLabel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !label.isEmpty { return "label:\(label)" }
                return "idx:0"
            }()
            groups[key, default: []].append(idx)
        }
        
        for indices in groups.values {
            var cursor = dayStartMinutes
            var occupied: [(Int, Int)] = []
            
            for idx in indices {
                guard let start = items[idx].startTime else { continue }
                let startM = minutes(from: start, calendar: cal)
                let endM: Int = {
                    if let end = items[idx].endTime, end > start {
                        return max(startM + 30, minutes(from: end, calendar: cal))
                    }
                    return startM + defaultDurationMinutes(for: items[idx])
                }()
                occupied.append((startM, endM))
                cursor = max(cursor, endM + gapMinutes)
            }
            occupied.sort { $0.0 < $1.0 }
            
            for idx in indices {
                if items[idx].startTime != nil {
                    if let start = items[idx].startTime {
                        let needsEnd = items[idx].endTime.map { $0 <= start } ?? true
                        if needsEnd {
                            let mins = defaultDurationMinutes(for: items[idx])
                            items[idx].endTime = start.addingTimeInterval(TimeInterval(mins * 60))
                        }
                    }
                    continue
                }
                
                let duration = defaultDurationMinutes(for: items[idx])
                var startM = max(cursor, dayStartMinutes)
                startM = nextFreeStart(from: startM, duration: duration, occupied: occupied)
                if startM > latestStartMinutes {
                    startM = min(latestStartMinutes, dayStartMinutes + occupied.count * 45)
                }
                let endM = startM + duration
                items[idx].startTime = date(minutes: startM, on: base, calendar: cal)
                items[idx].endTime = date(minutes: endM, on: base, calendar: cal)
                occupied.append((startM, endM))
                occupied.sort { $0.0 < $1.0 }
                cursor = endM + gapMinutes
            }
        }
    }
    
    static func timeText(start: Date?, end: Date?) -> String {
        guard let start else { return "" }
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        let s = f.string(from: start)
        if let end, end > start {
            return "\(s) - \(f.string(from: end))"
        }
        return s
    }
    
    private static func isHotel(_ item: PlanDayItem) -> Bool {
        let cat = item.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cat == "hotel" || cat == "lodging" || cat == "stay" { return true }
        let title = item.title.lowercased()
        return title.contains("hotel") || title.contains("check-in") || title.contains("check in")
    }
    
    private static func defaultDurationMinutes(for item: PlanDayItem) -> Int {
        switch item.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "restaurant", "cafe", "coffee", "bar": return 75
        case "museum", "gallery", "attraction", "landmark": return 120
        case "park", "hike", "beach", "viewpoint", "trail": return 150
        case "shopping", "market": return 90
        default: return 90
        }
    }
    
    private static func minutes(from date: Date, calendar: Calendar) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
    
    private static func date(minutes: Int, on day: Date, calendar: Calendar) -> Date {
        let clamped = max(0, min(minutes, 23 * 60 + 59))
        return calendar.date(bySettingHour: clamped / 60, minute: clamped % 60, second: 0, of: day) ?? day
    }
    
    private static func nextFreeStart(from start: Int, duration: Int, occupied: [(Int, Int)]) -> Int {
        var candidate = start
        for _ in 0..<24 {
            let end = candidate + duration
            let clash = occupied.contains { otherStart, otherEnd in
                candidate < otherEnd && end > otherStart
            }
            if !clash { return candidate }
            if let blocker = occupied.first(where: { otherStart, otherEnd in
                candidate < otherEnd && end > otherStart
            }) {
                candidate = blocker.1 + gapMinutes
            } else {
                candidate += gapMinutes
            }
        }
        return candidate
    }
}


