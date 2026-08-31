import Foundation
import SwiftUI

/// Persistent counters that aren't derived from trip/place/tracker data.
enum AchievementCounters {
    static let aiDaysPlannedKey = "achievements.aiDaysPlanned"
    
    static var aiDaysPlanned: Int {
        UserDefaults.standard.integer(forKey: aiDaysPlannedKey)
    }
    
    static func recordAIDaysPlanned(_ count: Int) {
        guard count > 0 else { return }
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: aiDaysPlannedKey) + count, forKey: aiDaysPlannedKey)
    }
}

/// Persists when each badge was first observed as unlocked (for “latest unlocked” sorting).
enum AchievementUnlockStore {
    private static let defaultsKey = "achievements.unlockDates"
    
    static func unlockDate(for id: String) -> Date? {
        load()[id]
    }
    
    /// Records unlock timestamps for newly unlocked badges. Existing unlocks keep their dates.
    static func sync(unlockedIDs: Set<String>) {
        var map = load()
        let missing = unlockedIDs.filter { map[$0] == nil }.sorted()
        guard !missing.isEmpty else { return }
        
        let now = Date()
        if missing.count == 1, let id = missing.first {
            // A single new unlock — treat as just earned.
            map[id] = now
        } else {
            // Bulk backfill (first launch / migration): stable older dates so real new unlocks sort first.
            for (index, id) in missing.enumerated() {
                map[id] = Date(timeIntervalSince1970: TimeInterval(index + 1))
            }
        }
        save(map)
    }
    
    /// Unlocked badges newest-first, then locked milestones in catalog order.
    static func sorted(
        _ definitions: [AchievementDefinition],
        progress: AchievementProgress
    ) -> [AchievementDefinition] {
        let unlockedIDs = Set(definitions.filter { progress.isUnlocked($0) }.map(\.id))
        sync(unlockedIDs: unlockedIDs)
        
        let unlocked = definitions
            .filter { progress.isUnlocked($0) }
            .sorted { lhs, rhs in
                let left = unlockDate(for: lhs.id) ?? .distantPast
                let right = unlockDate(for: rhs.id) ?? .distantPast
                if left != right { return left > right }
                return lhs.id < rhs.id
            }
        let locked = definitions.filter { !progress.isUnlocked($0) }
        return unlocked + locked
    }
    
    private static func load() -> [String: Date] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: Date].self, from: data)
        else { return [:] }
        return decoded
    }
    
    private static func save(_ map: [String: Date]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

enum AchievementCategory: String, CaseIterable, Identifiable, Hashable {
    case tripLogging
    case countries
    case continents
    case daysTraveled
    case flights
    case drives
    case placesSaved
    case restaurantsTried
    case nationalParks
    case cities
    case aiTripPlanning
    case checklistsCompleted
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .tripLogging: return "Trip logging"
        case .countries: return "Countries"
        case .continents: return "Continents"
        case .daysTraveled: return "Days traveled"
        case .flights: return "Flights"
        case .drives: return "Drives"
        case .placesSaved: return "Places saved"
        case .restaurantsTried: return "Restaurants tried"
        case .nationalParks: return "National Parks"
        case .cities: return "Cities"
        case .aiTripPlanning: return "AI trip planning"
        case .checklistsCompleted: return "Checklists completed"
        }
    }
    
    var systemImage: String {
        switch self {
        case .tripLogging: return "luggage"
        case .countries: return "globe"
        case .continents: return "earth"
        case .daysTraveled: return "calendar"
        case .flights: return "plane"
        case .drives: return "car"
        case .placesSaved: return "map-pinned"
        case .restaurantsTried: return "utensils"
        case .nationalParks: return "mountain"
        case .cities: return "building-2"
        case .aiTripPlanning: return "sparkles"
        case .checklistsCompleted: return "list-checks"
        }
    }
    
    /// Shared badge art for milestone tiers (not used for per-park badges).
    func illustrationName(forTier tier: Int) -> String? {
        switch tier {
        case 1: return "illustrations/achievement-level-1"
        case 2: return "illustrations/achievement-level-2"
        case 3: return "illustrations/achievement-level-3"
        default: return nil
        }
    }
}

struct AchievementDefinition: Identifiable, Hashable {
    let id: String
    let category: AchievementCategory
    let tier: Int
    let threshold: Int
    let title: String
    let description: String
    /// When set, overrides the category tier illustration (e.g. national park badge).
    var customIllustrationName: String? = nil
    /// Park badges are omitted from the grid until earned.
    var hidesWhenLocked: Bool = false
    
    var systemImage: String { category.systemImage }
    
    var illustrationName: String? {
        customIllustrationName ?? category.illustrationName(forTier: tier)
    }
}

enum AchievementsCatalog {
    static let nationalParkBadgeAsset = "illustrations/badge-national-park"
    static let cityStampAsset = "illustrations/stamp-city"
    static let lockedBadgeAsset = "illustrations/badge-locked"
    
    /// Park-specific badge art keyed by tracker item id (`nps-…`).
    private static let nationalParkBadgeAssetsByID: [String: String] = [
        "nps-arches": "illustrations/badge-arches-np",
        "nps-bryce": "illustrations/badge-bryce-canyon-np",
        "nps-canyonlands": "illustrations/badge-canyonlands-np",
        "nps-gatewayarch": "illustrations/badge-gateway-np",
        "nps-joshua": "illustrations/badge-joshua-tree-np"
    ]
    
    /// City-specific stamp art keyed by lowercase city name (first segment of destination).
    private static let cityStampAssetsByName: [String: String] = [
        "toronto": "illustrations/stamps-toronto"
    ]
    
    private static func badgeAsset(forParkID id: String) -> String {
        nationalParkBadgeAssetsByID[id] ?? nationalParkBadgeAsset
    }
    
    /// Prefer a city-specific stamp when we have art; otherwise the shared city stamp.
    static func stampAsset(forCityName name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let head: String = {
            if let comma = trimmed.firstIndex(of: ",") {
                return String(trimmed[..<comma]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return trimmed
        }()
        let key = head.lowercased()
        if let asset = cityStampAssetsByName[key] {
            return asset
        }
        // Fallback: destination string contains a known city name (e.g. "Downtown Toronto").
        for (city, asset) in cityStampAssetsByName where key.contains(city) {
            return asset
        }
        return cityStampAsset
    }
    
    private static func cityBadgeID(forName name: String) -> String {
        let slug = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        return "city-\(slug)"
    }
    
    /// Milestone badges (locked ones still appear in the sheet).
    static let milestones: [AchievementDefinition] = [
        // Trip logging
        make(.tripLogging, tier: 1, threshold: 5, title: "5 Trips", description: "Log 5 trips"),
        make(.tripLogging, tier: 2, threshold: 15, title: "15 Trips", description: "Log 15 trips"),
        make(.tripLogging, tier: 3, threshold: 30, title: "30 Trips", description: "Log 30 trips"),
        
        // Countries
        make(.countries, tier: 1, threshold: 5, title: "5 Countries", description: "Visit 5 countries"),
        make(.countries, tier: 2, threshold: 15, title: "15 Countries", description: "Visit 15 countries"),
        make(.countries, tier: 3, threshold: 30, title: "30 Countries", description: "Visit 30 countries"),
        
        // Continents
        make(.continents, tier: 1, threshold: 3, title: "3 Continents", description: "Visit 3 continents"),
        make(.continents, tier: 2, threshold: 5, title: "5 Continents", description: "Visit 5 continents"),
        make(.continents, tier: 3, threshold: 7, title: "7 Continents", description: "Visit 7 continents"),
        
        // Days traveled
        make(.daysTraveled, tier: 1, threshold: 25, title: "25 Days", description: "Travel 25 days"),
        make(.daysTraveled, tier: 2, threshold: 75, title: "75 Days", description: "Travel 75 days"),
        make(.daysTraveled, tier: 3, threshold: 150, title: "150 Days", description: "Travel 150 days"),
        
        // Flights
        make(.flights, tier: 1, threshold: 5, title: "5 Flights", description: "Log 5 flights"),
        make(.flights, tier: 2, threshold: 15, title: "15 Flights", description: "Log 15 flights"),
        make(.flights, tier: 3, threshold: 30, title: "30 Flights", description: "Log 30 flights"),
        
        // Drives
        make(.drives, tier: 1, threshold: 5, title: "5 Drives", description: "Log 5 drives"),
        make(.drives, tier: 2, threshold: 15, title: "15 Drives", description: "Log 15 drives"),
        make(.drives, tier: 3, threshold: 30, title: "30 Drives", description: "Log 30 drives"),
        
        // Places saved
        make(.placesSaved, tier: 1, threshold: 10, title: "10 Places", description: "Save 10 places"),
        make(.placesSaved, tier: 2, threshold: 50, title: "50 Places", description: "Save 50 places"),
        make(.placesSaved, tier: 3, threshold: 150, title: "150 Places", description: "Save 150 places"),
        
        // Restaurants tried
        make(.restaurantsTried, tier: 1, threshold: 10, title: "10 Restaurants", description: "Save 10 restaurants"),
        make(.restaurantsTried, tier: 2, threshold: 25, title: "25 Restaurants", description: "Save 25 restaurants"),
        make(.restaurantsTried, tier: 3, threshold: 50, title: "50 Restaurants", description: "Save 50 restaurants"),
        
        // AI trip planning
        make(.aiTripPlanning, tier: 1, threshold: 5, title: "5 AI Days", description: "Plan 5 days with AI"),
        make(.aiTripPlanning, tier: 2, threshold: 25, title: "25 AI Days", description: "Plan 25 days with AI"),
        make(.aiTripPlanning, tier: 3, threshold: 100, title: "100 AI Days", description: "Plan 100 days with AI"),
        
        // Checklists completed
        make(.checklistsCompleted, tier: 1, threshold: 5, title: "5 Checklists", description: "Complete 5 checklists"),
        make(.checklistsCompleted, tier: 2, threshold: 25, title: "25 Checklists", description: "Complete 25 checklists"),
        make(.checklistsCompleted, tier: 3, threshold: 50, title: "50 Checklists", description: "Complete 50 checklists"),
    ]
    
    static var totalNationalParkCount: Int {
        TrackerData.usNationalParks.count
    }
    
    static var totalAchievableCount: Int {
        milestones.count + totalNationalParkCount
    }
    
    /// One badge per visited U.S. national park (locked parks are omitted).
    static func unlockedNationalParkBadges(visitedIDs: Set<String>) -> [AchievementDefinition] {
        TrackerData.usNationalParks
            .filter { visitedIDs.contains($0.id) }
            .map { park in
                AchievementDefinition(
                    id: "park-\(park.id)",
                    category: .nationalParks,
                    tier: 1,
                    threshold: 1,
                    title: park.name,
                    description: park.name,
                    customIllustrationName: badgeAsset(forParkID: park.id),
                    hidesWhenLocked: true
                )
            }
    }
    
    /// One stamp badge per logged city (from completed trip destinations).
    static func unlockedCityBadges(cityNames: [String]) -> [AchievementDefinition] {
        cityNames.map { name in
            AchievementDefinition(
                id: cityBadgeID(forName: name),
                category: .cities,
                tier: 1,
                threshold: 1,
                title: name,
                description: name,
                customIllustrationName: stampAsset(forCityName: name),
                hidesWhenLocked: true
            )
        }
    }
    
    /// Unique non-empty destinations from completed / past trips, newest first.
    static func loggedCities(from trips: [Trip], calendar: Calendar = .current) -> [String] {
        let today = calendar.startOfDay(for: Date())
        let completed = trips
            .filter { trip in
                guard trip.isDatesSet else { return false }
                return calendar.startOfDay(for: trip.endDate) < today
            }
            .sorted { $0.endDate > $1.endDate }
        
        var seen = Set<String>()
        var cities: [String] = []
        for trip in completed {
            let name = trip.destination.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let key = name.lowercased()
            if seen.insert(key).inserted {
                cities.append(name)
            }
        }
        return cities
    }
    
    /// Milestones plus earned park / city badges, unlocked newest-first, then locked milestones.
    static func visibleAchievements(
        progress: AchievementProgress,
        visitedParkIDs: Set<String>,
        loggedCities: [String] = []
    ) -> [AchievementDefinition] {
        let combined = milestones
            + unlockedNationalParkBadges(visitedIDs: visitedParkIDs)
            + unlockedCityBadges(cityNames: loggedCities)
        return AchievementUnlockStore.sorted(combined, progress: progress)
    }
    
    static func unlockedCount(
        progress: AchievementProgress,
        visitedParkIDs: Set<String>,
        loggedCities: [String] = []
    ) -> Int {
        let milestoneUnlocked = milestones.filter { progress.isUnlocked($0) }.count
        return milestoneUnlocked + visitedParkIDs.count + loggedCities.count
    }
    
    private static func make(
        _ category: AchievementCategory,
        tier: Int,
        threshold: Int,
        title: String,
        description: String
    ) -> AchievementDefinition {
        AchievementDefinition(
            id: "\(category.rawValue)-\(tier)",
            category: category,
            tier: tier,
            threshold: threshold,
            title: title,
            description: description
        )
    }
}

struct AchievementProgress {
    var tripsLogged: Int
    var countries: Int
    var continents: Int
    var daysTraveled: Int
    var flights: Int
    var drives: Int
    var placesSaved: Int
    var restaurantsTried: Int
    var aiDaysPlanned: Int
    var checklistsCompleted: Int
    
    func count(for category: AchievementCategory) -> Int {
        switch category {
        case .tripLogging: return tripsLogged
        case .countries: return countries
        case .continents: return continents
        case .daysTraveled: return daysTraveled
        case .flights: return flights
        case .drives: return drives
        case .placesSaved: return placesSaved
        case .restaurantsTried: return restaurantsTried
        case .nationalParks: return 0 // per-park badges are handled separately
        case .cities: return 0 // per-city stamps are handled separately
        case .aiTripPlanning: return aiDaysPlanned
        case .checklistsCompleted: return checklistsCompleted
        }
    }
    
    func isUnlocked(_ definition: AchievementDefinition) -> Bool {
        if definition.hidesWhenLocked {
            return true
        }
        return count(for: definition.category) >= definition.threshold
    }
    
    static func totalTravelDays(trips: [Trip], calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: Date())
        var days = Set<Date>()
        
        for trip in trips where trip.isDatesSet {
            let start = calendar.startOfDay(for: trip.startDate)
            let end = min(calendar.startOfDay(for: trip.endDate), today)
            guard end >= start else { continue }
            
            var cursor = start
            while cursor <= end {
                days.insert(cursor)
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
        }
        return days.count
    }
    
    static func completedChecklists(in trips: [Trip]) -> Int {
        trips
            .flatMap(\.days)
            .flatMap(\.checklists)
            .filter { checklist in
                !checklist.items.isEmpty && checklist.items.allSatisfy(\.isDone)
            }
            .count
    }
}
