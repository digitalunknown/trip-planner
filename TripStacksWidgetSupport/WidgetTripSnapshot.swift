import Foundation

enum WidgetKindID {
    /// Bump when Home Screen keeps a stale WidgetKit binary.
    static let trip = "digitalunknown.TripStacks.trip.v4"
}

enum WidgetKnownTripID {
    /// Seeded onboarding Tokyo trip — never preferred over a real trip.
    static let onboardingSample = UUID(uuidString: "00000000-0000-0000-0000-000000000777")!
}

enum WidgetDateMode: String, Codable, Sendable {
    case dated
    case undated
}

enum WidgetTripSelection: String, Codable, Sendable {
    case inProgress
    case upcoming
    case unscheduled
    case past
}

enum WidgetItemKind: String, Codable, Sendable {
    case flight
    case activity
    case hotel
    case checklist
    case reminder
    
    var systemImage: String {
        switch self {
        case .flight: return "airplane"
        case .activity: return "mappin"
        case .hotel: return "bed.double.fill"
        case .checklist: return "checklist"
        case .reminder: return "bell"
        }
    }
}

struct WidgetTripItem: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var kind: WidgetItemKind
    var title: String
    var startTime: String?
    var startMinutes: Int?
    var icon: String? = nil
    var accentHex: UInt32? = nil
    var accentForegroundHex: UInt32? = nil
    var iconPNG: Data? = nil
    
    enum CodingKeys: String, CodingKey {
        case id, kind, title, startTime, startMinutes, icon, accentHex, accentForegroundHex
    }
    
    var resolvedIcon: String {
        if let icon, !icon.isEmpty { return icon }
        return kind.systemImage
    }
}

struct WidgetDayPeek: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var label: String
    var detail: String
    var itemCount: Int
}

struct WidgetTripSnapshot: Codable, Equatable, Sendable {
    var tripID: UUID
    var tripName: String
    var destination: String
    var coverFileName: String?
    var tintHex: UInt32
    var dateMode: WidgetDateMode
    var selection: WidgetTripSelection
    var statusLine: String
    var dayID: UUID?
    var dayLabel: String
    var dayDate: Date?
    var items: [WidgetTripItem]
    var ideaCount: Int
    var lastUpdated: Date
    var dayNumber: Int?
    var dateSpanText: String?
    var followingDays: [WidgetDayPeek]?
    
    var nextItem: WidgetTripItem? { items.first }
    var resolvedDayNumber: Int { dayNumber ?? 1 }
    var resolvedFollowingDays: [WidgetDayPeek] { followingDays ?? [] }
    
    var isOnboardingSample: Bool { tripID == WidgetKnownTripID.onboardingSample }
    
    var isCanvasPreview: Bool {
        let previewIDs: [UUID] = [
            UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!,
            UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        ]
        return previewIDs.contains(tripID)
    }
    
    /// Upcoming trips include countdown so “Mon, Oct 5” isn’t mistaken for today.
    var richStatus: String {
        let dayPart = "Day \(resolvedDayNumber)"
        switch selection {
        case .upcoming:
            return [dayPart, dayLabel, statusLine]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        case .inProgress:
            if statusLine.localizedCaseInsensitiveContains("day") {
                if !dayLabel.isEmpty, !statusLine.localizedCaseInsensitiveContains(dayLabel) {
                    return "\(statusLine) · \(dayLabel)"
                }
                return statusLine
            }
            return [statusLine, dayPart, dayLabel]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        case .unscheduled:
            return [dayPart, statusLine]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        case .past:
            return [dayLabel, statusLine]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        }
    }
    
    var emptyDayPrompt: String {
        switch selection {
        case .upcoming:
            return "Day \(resolvedDayNumber) is open"
        case .unscheduled:
            return "Nothing on the stack yet"
        default:
            return "Nothing on this day’s stack"
        }
    }
}

struct WidgetSnapshotEnvelope: Codable, Equatable, Sendable {
    var trip: WidgetTripSnapshot?
    var lastUpdated: Date
}

extension WidgetTripSnapshot {
    static let previewInProgress = WidgetTripSnapshot(
        tripID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
        tripName: "Lisbon Long Weekend",
        destination: "Lisbon",
        coverFileName: nil,
        tintHex: 0xFF8B00,
        dateMode: .dated,
        selection: .inProgress,
        statusLine: "Today · Day 2",
        dayID: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
        dayLabel: "Fri, Oct 25",
        dayDate: Date(),
        items: [
            WidgetTripItem(id: UUID(), kind: .flight, title: "SFO → LIS", startTime: "8:10 AM", startMinutes: 490, icon: "plane", accentHex: 0xFF7701, accentForegroundHex: 0x4F0400),
            WidgetTripItem(id: UUID(), kind: .hotel, title: "Bairro Alto Hotel", startTime: "3:00 PM", startMinutes: 900, icon: "bed-double", accentHex: 0x81013A, accentForegroundHex: 0xFBB4D6),
            WidgetTripItem(id: UUID(), kind: .activity, title: "Sunset at Miradouro", startTime: "6:30 PM", startMinutes: 1110, icon: "camera", accentHex: 0xB2A1FF, accentForegroundHex: 0x1A1033)
        ],
        ideaCount: 12,
        lastUpdated: Date(),
        dayNumber: 2,
        dateSpanText: "Oct 24 – Oct 27",
        followingDays: [
            WidgetDayPeek(id: UUID(), label: "Sat, Oct 26", detail: "Alfama walk", itemCount: 3),
            WidgetDayPeek(id: UUID(), label: "Sun, Oct 27", detail: "Open", itemCount: 0)
        ]
    )
    
    static let previewUpcoming = WidgetTripSnapshot(
        tripID: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
        tripName: "Tokyo in November",
        destination: "Tokyo",
        coverFileName: nil,
        tintHex: 0xB2A1FF,
        dateMode: .dated,
        selection: .upcoming,
        statusLine: "in 3 days",
        dayID: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
        dayLabel: "Tue, Nov 12",
        dayDate: Date().addingTimeInterval(3 * 86400),
        items: [
            WidgetTripItem(id: UUID(), kind: .activity, title: "Tsukiji breakfast", startTime: "7:30 AM", startMinutes: 450, icon: "utensils", accentHex: 0xFED130, accentForegroundHex: 0x450700),
            WidgetTripItem(id: UUID(), kind: .checklist, title: "Packing list", startTime: nil, startMinutes: nil, icon: "list-checks", accentHex: 0xFED130, accentForegroundHex: 0x450700)
        ],
        ideaCount: 8,
        lastUpdated: Date(),
        dayNumber: 1,
        dateSpanText: "Nov 12 – Nov 16",
        followingDays: [
            WidgetDayPeek(id: UUID(), label: "Wed, Nov 13", detail: "Meiji Jingu", itemCount: 2),
            WidgetDayPeek(id: UUID(), label: "Thu, Nov 14", detail: "Open", itemCount: 0)
        ]
    )
    
    static let previewUnscheduled = WidgetTripSnapshot(
        tripID: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!,
        tripName: "Mexico City ideas",
        destination: "Mexico City",
        coverFileName: nil,
        tintHex: 0x7EE0B0,
        dateMode: .undated,
        selection: .unscheduled,
        statusLine: "Unscheduled",
        dayID: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!,
        dayLabel: "Day 1",
        dayDate: nil,
        items: [
            WidgetTripItem(id: UUID(), kind: .activity, title: "Roma Norte walk", startTime: nil, startMinutes: nil, icon: "footprints", accentHex: 0xCDF545, accentForegroundHex: 0x025541),
            WidgetTripItem(id: UUID(), kind: .activity, title: "Contramar lunch", startTime: nil, startMinutes: nil, icon: "utensils", accentHex: 0xFF7701, accentForegroundHex: 0x4F0400)
        ],
        ideaCount: 5,
        lastUpdated: Date(),
        dayNumber: 1,
        dateSpanText: nil,
        followingDays: [
            WidgetDayPeek(id: UUID(), label: "Day 2", detail: "Open", itemCount: 0)
        ]
    )
    
    static let previewEmptyDay = WidgetTripSnapshot(
        tripID: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
        tripName: "Design Summit",
        destination: "San Francisco",
        coverFileName: nil,
        tintHex: 0xFF8B00,
        dateMode: .dated,
        selection: .upcoming,
        statusLine: "in 29 days",
        dayID: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
        dayLabel: "Mon, Oct 5",
        dayDate: Date().addingTimeInterval(29 * 86400),
        items: [],
        ideaCount: 2,
        lastUpdated: Date(),
        dayNumber: 1,
        dateSpanText: "Oct 5 – Oct 7",
        followingDays: [
            WidgetDayPeek(id: UUID(), label: "Tue, Oct 6", detail: "Workshops", itemCount: 2),
            WidgetDayPeek(id: UUID(), label: "Wed, Oct 7", detail: "Open", itemCount: 0)
        ]
    )
}
