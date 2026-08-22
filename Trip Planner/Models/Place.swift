import Foundation

enum PlaceType: String, Codable, CaseIterable, Identifiable, Hashable {
    case unspecified
    case restaurant
    case cafe
    case bar
    case hotel
    case attraction
    case museum
    case park
    case beach
    case hike
    case shopping
    case nightlife
    case viewpoint
    case kids
    case other
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .unspecified: return "Select type"
        case .restaurant: return "Restaurant"
        case .cafe: return "Cafe"
        case .bar: return "Bar"
        case .hotel: return "Hotel"
        case .attraction: return "Attraction"
        case .museum: return "Museum"
        case .park: return "Park"
        case .beach: return "Beach"
        case .hike: return "Hike"
        case .shopping: return "Shopping"
        case .nightlife: return "Nightlife"
        case .viewpoint: return "Viewpoint"
        case .kids: return "Kids"
        case .other: return "Other"
        }
    }
    
    var iconSystemName: String {
        switch self {
        case .unspecified: return "tag"
        case .restaurant: return "utensils"
        case .cafe: return "coffee"
        case .bar: return "beer"
        case .hotel: return "hotel"
        case .attraction: return "ferris-wheel"
        case .museum: return "landmark"
        case .park: return "tree-palm"
        case .beach: return "umbrella"
        case .hike: return "mountain"
        case .shopping: return "shopping-bag"
        case .nightlife: return "moon-star"
        case .viewpoint: return "binoculars"
        case .kids: return "baby"
        case .other: return "map-pin"
        }
    }
    
    /// Icon used on map pins when this place has no photo.
    var mapIconName: String {
        self == .unspecified ? "map-pinned" : iconSystemName
    }
    
    /// Best-effort type from an activity SF Symbol.
    static func inferred(fromActivityIcon icon: String) -> PlaceType {
        switch icon {
        case "fork.knife", "carrot.fill", "takeoutbag.and.cup.and.straw.fill", "birthday.cake.fill",
             "apple", "beef", "cake", "chef-hat", "cooking-pot", "croissant", "donut",
             "egg-fried", "hamburger", "ice-cream-cone", "pizza", "popcorn":
            return .restaurant
        case "cup.and.saucer.fill", "mug.fill", "coffee", "cup-soda":
            return .cafe
        case "wineglass.fill", "beer", "bottle-wine":
            return .bar
        case "bed.double.fill", "house.fill":
            return .hotel
        case "bag.fill", "cart.fill", "tag.fill", "gift.fill", "creditcard.fill", "duffle.bag.fill":
            return .shopping
        case "leaf.fill", "tree.fill", "flower", "tree-palm", "tent-tree":
            return .park
        case "beach.umbrella.fill", "water.waves":
            return .beach
        case "figure.hiking", "figure.walk", "mountain.2.fill":
            return .hike
        case "building.columns.fill", "atom", "paintpalette.fill", "sparkles", "palette", "pencil-ruler":
            return .museum
        case "binoculars.fill":
            return .viewpoint
        case "moon.stars.fill":
            return .nightlife
        case "figure.and.child.holdinghands":
            return .kids
        case "star.fill", "ticket.fill", "camera.fill", "photo.fill", "theatermasks.fill", "building.2.fill":
            return .attraction
        default:
            return .unspecified
        }
    }
}

/// First-class saved place — can exist with or without a trip link.
struct Place: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var location: String
    var note: String
    var photoData: Data?
    var latitude: Double?
    var longitude: Double?
    var createdAt: Date
    var updatedAt: Date
    var placeType: PlaceType
    
    /// Apple Maps place identifier (`MKMapItem.Identifier.rawValue`) when confidently matched.
    var mapKitIdentifier: String?
    var mapKitMatchStatus: PlaceMapKitMatchStatus
    
    /// Provenance when saved from / linked to a trip activity.
    var sourceTripID: UUID?
    var sourceTripName: String?
    var sourceEventID: UUID?
    
    /// Reserved for future user tags/collections (many-to-many).
    var tagIDs: [UUID]
    
    init(
        id: UUID = UUID(),
        name: String,
        location: String = "",
        note: String = "",
        photoData: Data? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        placeType: PlaceType = .unspecified,
        mapKitIdentifier: String? = nil,
        mapKitMatchStatus: PlaceMapKitMatchStatus = .notAttempted,
        sourceTripID: UUID? = nil,
        sourceTripName: String? = nil,
        sourceEventID: UUID? = nil,
        tagIDs: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.note = note
        self.photoData = photoData
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.placeType = placeType
        self.mapKitIdentifier = mapKitIdentifier
        self.mapKitMatchStatus = mapKitMatchStatus
        self.sourceTripID = sourceTripID
        self.sourceTripName = sourceTripName
        self.sourceEventID = sourceEventID
        self.tagIDs = tagIDs
    }
    
    var hasPhoto: Bool { photoData != nil }
    
    var isLinkedToTrip: Bool { sourceTripID != nil }
    
    var hasAppleMapsMatch: Bool {
        mapKitMatchStatus == .matched && !(mapKitIdentifier?.isEmpty ?? true)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, location, note, photoData, latitude, longitude
        case createdAt, updatedAt, placeType
        case mapKitIdentifier, mapKitMatchStatus
        case sourceTripID, sourceTripName, sourceEventID, tagIDs
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        photoData = try container.decodeIfPresent(Data.self, forKey: .photoData)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        placeType = try container.decodeIfPresent(PlaceType.self, forKey: .placeType) ?? .unspecified
        mapKitIdentifier = try container.decodeIfPresent(String.self, forKey: .mapKitIdentifier)
        mapKitMatchStatus = try container.decodeIfPresent(PlaceMapKitMatchStatus.self, forKey: .mapKitMatchStatus) ?? .notAttempted
        sourceTripID = try container.decodeIfPresent(UUID.self, forKey: .sourceTripID)
        sourceTripName = try container.decodeIfPresent(String.self, forKey: .sourceTripName)
        sourceEventID = try container.decodeIfPresent(UUID.self, forKey: .sourceEventID)
        tagIDs = try container.decodeIfPresent([UUID].self, forKey: .tagIDs) ?? []
    }
}
