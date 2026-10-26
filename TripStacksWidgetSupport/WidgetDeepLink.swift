import Foundation

enum WidgetDeepLink: Equatable, Sendable {
    case trip(UUID)
    case day(trip: UUID, day: UUID)
    case item(trip: UUID, item: UUID, day: UUID?)
    case planDay(trip: UUID, day: UUID?)
    
    static let scheme = "tripstacks"
    
    var tripID: UUID {
        switch self {
        case .trip(let id): return id
        case .day(let trip, _): return trip
        case .item(let trip, _, _): return trip
        case .planDay(let trip, _): return trip
        }
    }
    
    var dayID: UUID? {
        switch self {
        case .trip: return nil
        case .day(_, let day): return day
        case .item(_, _, let day): return day
        case .planDay(_, let day): return day
        }
    }
    
    var itemID: UUID? {
        if case .item(_, let item, _) = self { return item }
        return nil
    }
    
    var opensPlanDay: Bool {
        if case .planDay = self { return true }
        return false
    }
    
    var url: URL {
        switch self {
        case .trip(let id):
            return URL(string: "\(Self.scheme)://trip/\(id.uuidString)")!
        case .day(let trip, let day):
            return URL(string: "\(Self.scheme)://trip/\(trip.uuidString)/day/\(day.uuidString)")!
        case .item(let trip, let item, let day):
            var comps = URLComponents(string: "\(Self.scheme)://trip/\(trip.uuidString)/item/\(item.uuidString)")!
            if let day {
                comps.queryItems = [URLQueryItem(name: "day", value: day.uuidString)]
            }
            return comps.url!
        case .planDay(let trip, let day):
            var comps = URLComponents(string: "\(Self.scheme)://trip/\(trip.uuidString)/plan-day")!
            if let day {
                comps.queryItems = [URLQueryItem(name: "day", value: day.uuidString)]
            }
            return comps.url!
        }
    }
    
    static func parse(_ url: URL) -> WidgetDeepLink? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        let rawParts = ([url.host].compactMap { $0 } + url.pathComponents.filter { $0 != "/" })
        guard rawParts.first?.lowercased() == "trip",
              rawParts.count >= 2,
              let tripID = UUID(uuidString: rawParts[1]) else { return nil }
        
        let dayQuery = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "day" })?
            .value
            .flatMap(UUID.init(uuidString:))
        
        guard rawParts.count >= 3 else { return .trip(tripID) }
        
        switch rawParts[2].lowercased() {
        case "day":
            guard rawParts.count >= 4, let dayID = UUID(uuidString: rawParts[3]) else {
                return .trip(tripID)
            }
            return .day(trip: tripID, day: dayID)
        case "item":
            guard rawParts.count >= 4, let itemID = UUID(uuidString: rawParts[3]) else {
                return .trip(tripID)
            }
            return .item(trip: tripID, item: itemID, day: dayQuery)
        case "plan-day":
            return .planDay(trip: tripID, day: dayQuery)
        default:
            return .trip(tripID)
        }
    }
}
