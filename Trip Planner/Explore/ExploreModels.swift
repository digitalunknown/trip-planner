import Foundation
import MapKit

/// Remote Explore feed payload (`GET /api/explore`).
struct ExploreFeedResponse: Codable, Hashable {
    var version: Int?
    var updatedAt: String?
    var picks: [ExploreStaffPick]
    
    enum CodingKeys: String, CodingKey {
        case version, updatedAt, picks
    }
    
    init(version: Int? = nil, updatedAt: String? = nil, picks: [ExploreStaffPick]) {
        self.version = version
        self.updatedAt = updatedAt
        self.picks = picks
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
        // Decode picks one-by-one so a single bad entry can't wipe the whole feed.
        var picksOut: [ExploreStaffPick] = []
        if var unkeyed = try? c.nestedUnkeyedContainer(forKey: .picks) {
            while !unkeyed.isAtEnd {
                if let pick = try? unkeyed.decode(ExploreStaffPick.self) {
                    picksOut.append(pick)
                } else {
                    _ = try? unkeyed.decode(DiscardedJSONValue.self)
                }
            }
        }
        picks = picksOut
    }
}

/// Skips one JSON value when an Explore pick fails to decode.
private struct DiscardedJSONValue: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { return }
        if (try? container.decode(Bool.self)) != nil { return }
        if (try? container.decode(Int.self)) != nil { return }
        if (try? container.decode(Double.self)) != nil { return }
        if (try? container.decode(String.self)) != nil { return }
        if (try? container.decode([DiscardedJSONValue].self)) != nil { return }
        if (try? container.decode([String: DiscardedJSONValue].self)) != nil { return }
    }
}

struct ExploreStaffPick: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let destination: String
    let publisher: String
    let badge: String
    /// Unused legacy field. Covers come from `coverImageURL`.
    let coverImageName: String?
    /// Remote cover URL (Unsplash for now).
    let coverImageURL: String?
    let latitude: Double
    let longitude: Double
    let mapSpan: Double
    let paragraphs: [String]
    let activities: [EventItem]
    
    var mapRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: mapSpan, longitudeDelta: mapSpan)
        )
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, destination, publisher, badge
        case coverImageName, coverImageURL
        case latitude, longitude, mapSpan, paragraphs, activities
    }
    
    init(
        id: String,
        title: String,
        destination: String,
        publisher: String,
        badge: String,
        coverImageName: String? = nil,
        coverImageURL: String? = nil,
        latitude: Double,
        longitude: Double,
        mapSpan: Double,
        paragraphs: [String],
        activities: [EventItem]
    ) {
        self.id = id
        self.title = title
        self.destination = destination
        self.publisher = publisher
        self.badge = badge
        self.coverImageName = coverImageName
        self.coverImageURL = coverImageURL
        self.latitude = latitude
        self.longitude = longitude
        self.mapSpan = mapSpan
        self.paragraphs = paragraphs
        self.activities = activities
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        destination = try c.decode(String.self, forKey: .destination)
        publisher = try c.decode(String.self, forKey: .publisher)
        badge = try c.decodeIfPresent(String.self, forKey: .badge) ?? "Staff Pick"
        coverImageName = try c.decodeIfPresent(String.self, forKey: .coverImageName)
        coverImageURL = try c.decodeIfPresent(String.self, forKey: .coverImageURL)
        latitude = try c.decode(Double.self, forKey: .latitude)
        longitude = try c.decode(Double.self, forKey: .longitude)
        mapSpan = try c.decodeIfPresent(Double.self, forKey: .mapSpan) ?? 0.1
        paragraphs = try c.decodeIfPresent([String].self, forKey: .paragraphs) ?? []
        let payloads = try c.decodeIfPresent([ExploreActivityPayload].self, forKey: .activities) ?? []
        activities = payloads.map { $0.toEventItem() }
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(destination, forKey: .destination)
        try c.encode(publisher, forKey: .publisher)
        try c.encode(badge, forKey: .badge)
        try c.encodeIfPresent(coverImageName, forKey: .coverImageName)
        try c.encodeIfPresent(coverImageURL, forKey: .coverImageURL)
        try c.encode(latitude, forKey: .latitude)
        try c.encode(longitude, forKey: .longitude)
        try c.encode(mapSpan, forKey: .mapSpan)
        try c.encode(paragraphs, forKey: .paragraphs)
        try c.encode(activities.map(ExploreActivityPayload.init(event:)), forKey: .activities)
    }
}

/// Feed activity DTO — content JSON omits `id` / `photoData`; we mint EventItems locally.
struct ExploreActivityPayload: Codable, Hashable {
    var title: String
    var description: String
    var time: String
    var location: String
    var latitude: Double?
    var longitude: Double?
    var icon: String
    var accent: String
    
    init(event: EventItem) {
        title = event.title
        description = event.description
        time = event.time
        location = event.location
        latitude = event.latitude
        longitude = event.longitude
        icon = event.icon
        accent = event.accent.rawValue
    }
    
    func toEventItem() -> EventItem {
        EventItem(
            title: title,
            description: description,
            time: time,
            location: location,
            latitude: latitude,
            longitude: longitude,
            icon: icon.isEmpty ? "mappin" : icon,
            accent: EventAccent(rawValue: accent) ?? .cream,
            photoData: nil
        )
    }
}
