import Foundation

/// Remote Expert Tips feed payload (`GET /api/expert-tips`).
struct ExpertTipsFeedResponse: Codable, Hashable {
    var version: Int?
    var updatedAt: String?
    var tips: [ExpertTip]
    
    enum CodingKeys: String, CodingKey {
        case version, updatedAt, tips
    }
    
    init(version: Int? = nil, updatedAt: String? = nil, tips: [ExpertTip]) {
        self.version = version
        self.updatedAt = updatedAt
        self.tips = tips
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
        var tipsOut: [ExpertTip] = []
        if var unkeyed = try? c.nestedUnkeyedContainer(forKey: .tips) {
            while !unkeyed.isAtEnd {
                if let tip = try? unkeyed.decode(ExpertTip.self) {
                    tipsOut.append(tip)
                } else {
                    _ = try? unkeyed.decode(ExpertTipDiscardedJSONValue.self)
                }
            }
        }
        tips = tipsOut
    }
}

private struct ExpertTipDiscardedJSONValue: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { return }
        if (try? container.decode(Bool.self)) != nil { return }
        if (try? container.decode(Int.self)) != nil { return }
        if (try? container.decode(Double.self)) != nil { return }
        if (try? container.decode(String.self)) != nil { return }
        if (try? container.decode([ExpertTipDiscardedJSONValue].self)) != nil { return }
        if (try? container.decode([String: ExpertTipDiscardedJSONValue].self)) != nil { return }
    }
}

struct ExpertTip: Identifiable, Hashable, Codable {
    let id: String
    let placeName: String
    let aliases: [String]
    let latitude: Double?
    let longitude: Double?
    let mapKitIdentifier: String?
    let tip: String
    let author: String
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, placeName, aliases, latitude, longitude
        case mapKitIdentifier, tip, author, updatedAt
    }
    
    init(
        id: String,
        placeName: String,
        aliases: [String] = [],
        latitude: Double? = nil,
        longitude: Double? = nil,
        mapKitIdentifier: String? = nil,
        tip: String,
        author: String,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.placeName = placeName
        self.aliases = aliases
        self.latitude = latitude
        self.longitude = longitude
        self.mapKitIdentifier = mapKitIdentifier
        self.tip = tip
        self.author = author
        self.updatedAt = updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        placeName = try c.decode(String.self, forKey: .placeName)
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        mapKitIdentifier = try c.decodeIfPresent(String.self, forKey: .mapKitIdentifier)
        tip = try c.decode(String.self, forKey: .tip)
        author = try c.decodeIfPresent(String.self, forKey: .author) ?? ""
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

/// Inputs used to match a curated tip to an activity, Place, or AI result.
struct ExpertTipQuery: Hashable {
    var title: String = ""
    var location: String = ""
    var latitude: Double? = nil
    var longitude: Double? = nil
    var mapKitIdentifier: String? = nil
    
    static func place(_ place: Place) -> ExpertTipQuery {
        ExpertTipQuery(
            title: place.name,
            location: place.location,
            latitude: place.latitude,
            longitude: place.longitude,
            mapKitIdentifier: place.mapKitIdentifier
        )
    }
}
