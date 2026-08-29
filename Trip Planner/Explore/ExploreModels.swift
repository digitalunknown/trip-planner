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
    /// Bundled asset name (e.g. `explore-content/paris-museums`) — only works for assets already in the app.
    let coverImageName: String?
    /// Remote cover URL — preferred for content published without an app update.
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

extension ExploreStaffPick {
    /// Offline fallback when the remote feed is unreachable.
    static var bundledFallback: [ExploreStaffPick] { hardcodedFallback }
    
    /// Last-resort hardcoded picks — keep in sync with `api/content/explore.json`.
    static let hardcodedFallback: [ExploreStaffPick] = [
        ExploreStaffPick(
            id: "paris-museums-kids",
            title: "The best Paris museums to visit with kids",
            destination: "Paris, France",
            publisher: "Cara Willenbrock",
            badge: "Staff Pick",
            coverImageName: "explore-content/paris-museums",
            latitude: 48.8606,
            longitude: 2.3376,
            mapSpan: 0.08,
            paragraphs: [
                "Parisian art museums are very welcoming to kids — but what does one actually think of these world-class cultural institutions when you’re touring with a little one in tow?",
                "This shortlist mixes headline collections with spaces that invite sketching, wandering, and hands-on moments. Use it as a flexible route: pair Orsay with Rodin on a dual ticket, leave room for a garden break, and treat fog sculptures and medieval moats as the real souvenirs.",
            ],
            activities: [
                EventItem(title: "Bourse de Commerce", description: "A former government building turned private art collection — ornate interiors colliding with contemporary work. Don’t miss Fujiko Nakaya’s Fog Sculpture when it’s on view.", time: "10:00 AM", location: "2 Rue de Viarmes, Paris", latitude: 48.8628, longitude: 2.3426, icon: "building.columns.fill", accent: .forest, photoData: nil),
                EventItem(title: "Musée d'Orsay", description: "A former train station turned Impressionist temple, crowned by the famous gold clock. Book a dual Orsay + Rodin ticket to skip lines and keep the day flexible.", time: "11:30 AM", location: "1 Rue de la Légion d'Honneur, Paris", latitude: 48.8600, longitude: 2.3266, icon: "clock.fill", accent: .tangerine, photoData: nil),
                EventItem(title: "Musée Rodin", description: "Hit The Atelier first — interactive, air-conditioned, and packed with activities — then wander the sculpture garden before and after.", time: "1:30 PM", location: "77 Rue de Varenne, Paris", latitude: 48.8553, longitude: 2.3158, icon: "leaf.fill", accent: .lime, photoData: nil),
                EventItem(title: "Grand Palais — Matisse", description: "A Matisse exhibit where the artist’s sketchbook can spark kids to open their own. Worth the stop if the current show is running.", time: "3:30 PM", location: "3 Avenue du Général Eisenhower, Paris", latitude: 48.8660, longitude: 2.3126, icon: "paintpalette.fill", accent: .blush, photoData: nil),
                EventItem(title: "Musée du Louvre", description: "Start at Le Studio for model sand, sketching, and books, then walk the Medieval Louvre — the empty former moat of the fortress, surprisingly peaceful with kids.", time: "5:00 PM", location: "Rue de Rivoli, Paris", latitude: 48.8606, longitude: 2.3376, icon: "building.2.fill", accent: .mustard, photoData: nil),
            ]
        ),
        ExploreStaffPick(
            id: "toronto-designer",
            title: "A designer's curated Toronto itinerary",
            destination: "Toronto, Canada",
            publisher: "Peter Osmenda",
            badge: "Staff Pick",
            coverImageName: "explore-content/toronto",
            latitude: 43.6532,
            longitude: -79.3832,
            mapSpan: 0.12,
            paragraphs: [
                "This is a design-forward day through Toronto — the kind of route a creative director would sketch for a short visit. Expect sharp architecture, thoughtful retail, and neighborhood texture instead of a checklist of tourist checkboxes.",
                "Walk between stops when you can. The point is noticing materials, storefronts, and street rhythm as much as the destinations themselves. Keep the afternoon flexible so coffee can turn into a longer linger.",
            ],
            activities: [
                EventItem(title: "Art Gallery of Ontario", description: "Gehry’s light-filled galleries and Canadian collections.", time: "10:00 AM", location: "317 Dundas St W, Toronto", latitude: 43.6536, longitude: -79.3925, icon: "building.columns.fill", accent: .forest, photoData: nil),
                EventItem(title: "Grainge", description: "Curated design objects and quiet browsing energy.", time: "12:00 PM", location: "Ossington Avenue, Toronto", latitude: 43.6475, longitude: -79.4200, icon: "bag.fill", accent: .lime, photoData: nil),
                EventItem(title: "Lunch at Quetzal", description: "Wood-fired Mexican with a refined room.", time: "1:00 PM", location: "419 College St, Toronto", latitude: 43.6560, longitude: -79.4075, icon: "fork.knife", accent: .tangerine, photoData: nil),
                EventItem(title: "Distillery District walk", description: "Brick lanes, galleries, and slow window-shopping.", time: "3:00 PM", location: "Distillery District, Toronto", latitude: 43.6503, longitude: -79.3595, icon: "figure.walk", accent: .mustard, photoData: nil),
                EventItem(title: "Evergreen Brick Works", description: "Adaptive reuse, trails, and golden-hour light.", time: "5:00 PM", location: "550 Bayview Ave, Toronto", latitude: 43.6846, longitude: -79.3656, icon: "leaf.fill", accent: .blush, photoData: nil),
            ]
        ),
        ExploreStaffPick(
            id: "nyc-foodies",
            title: "New York foodies",
            destination: "New York, USA",
            publisher: "Peter Osmenda",
            badge: "Staff Pick",
            coverImageName: "explore-content/new-york",
            latitude: 40.7128,
            longitude: -74.0060,
            mapSpan: 0.12,
            paragraphs: [
                "New York eats are endless, so this list stays opinionated: a tight set of places that reward appetite, patience, and a little neighborhood hopping. Think classics with staying power alongside rooms that still feel current.",
                "Don’t try to do every meal back-to-back. Pick two anchors for the day, leave space to wander into a bakery or market, and let the city’s pace decide whether dessert happens at the table or on the sidewalk.",
            ],
            activities: [
                EventItem(title: "Russ & Daughters Cafe", description: "Appetizing-counter legends with a sit-down ritual.", time: "9:30 AM", location: "127 Orchard St, New York", latitude: 40.7195, longitude: -73.9885, icon: "cup.and.saucer.fill", accent: .tangerine, photoData: nil),
                EventItem(title: "Xi'an Famous Foods", description: "Hand-pulled noodles and cumin heat.", time: "12:30 PM", location: "81 St Marks Pl, New York", latitude: 40.7282, longitude: -73.9857, icon: "fork.knife", accent: .plum, photoData: nil),
                EventItem(title: "Chelsea Market graze", description: "A walkable circuit of stalls and small bites.", time: "2:30 PM", location: "75 9th Ave, New York", latitude: 40.7424, longitude: -74.0061, icon: "cart.fill", accent: .lime, photoData: nil),
                EventItem(title: "Lucali", description: "Cash-only pizza worth the Brooklyn pilgrimage.", time: "6:30 PM", location: "575 Henry St, Brooklyn", latitude: 40.6818, longitude: -74.0003, icon: "flame.fill", accent: .mustard, photoData: nil),
                EventItem(title: "Uncle Boons Sister", description: "Thai flavors in a lively late-night room.", time: "9:00 PM", location: "231 Eldridge St, New York", latitude: 40.7214, longitude: -73.9908, icon: "wineglass.fill", accent: .blush, photoData: nil),
            ]
        ),
    ]
}
