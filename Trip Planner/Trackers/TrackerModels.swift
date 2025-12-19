import Foundation

enum TrackerType: String, Codable, CaseIterable, Hashable, Identifiable {
    case countries
    case states
    case continents
    case subwaySystems
    case nationalParks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .countries: return "Countries"
        case .states: return "States"
        case .continents: return "Continents"
        case .subwaySystems: return "Subway Systems"
        case .nationalParks: return "U.S. National Parks"
        }
    }

    var subtitle: String {
        switch self {
        case .countries: return "All countries"
        case .states: return "U.S. states"
        case .continents: return "7 continents"
        case .subwaySystems: return "Major systems"
        case .nationalParks: return "US NPS"
        }
    }

    var iconSystemName: String {
        switch self {
        case .countries: return "globe.americas.fill"
        case .states: return "map.fill"
        case .continents: return "globe.europe.africa.fill"
        case .subwaySystems: return "tram.fill"
        case .nationalParks: return "mountain.2.fill"
        }
    }
}

struct TrackerItem: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    var subtitle: String?
}

struct TrackerVisitedState: Codable {
    var visitedIDsByTracker: [TrackerType: Set<String>]

    init(visitedIDsByTracker: [TrackerType: Set<String>] = [:]) {
        self.visitedIDsByTracker = visitedIDsByTracker
    }
}

