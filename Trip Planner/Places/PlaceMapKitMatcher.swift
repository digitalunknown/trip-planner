import Foundation
import MapKit
import CoreLocation

enum PlaceMapKitMatchStatus: String, Codable, Hashable {
    case notAttempted
    case matched
    case unmatched
}

/// Resolves TripStacks places to Apple Maps identifiers for Place Card display (iOS 18+).
enum PlaceMapKitMatcher {
    /// Max distance for a confident coordinate match (~250 m).
    private static let maxMatchDistanceMeters: CLLocationDistance = 250
    
    @available(iOS 18.0, *)
    static func resolveIdentifier(for place: Place) async -> String? {
        let title = PlaceNaming.title(location: place.location, fallback: place.name)
        let query = bestQuery(for: place, title: title)
        guard !query.isEmpty else { return nil }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        if let lat = place.latitude, let lon = place.longitude {
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                latitudinalMeters: 2_000,
                longitudinalMeters: 2_000
            )
        }
        
        let response: MKLocalSearch.Response
        do {
            response = try await MKLocalSearch(request: request).start()
        } catch {
            return nil
        }
        
        guard let best = response.mapItems.first(where: { isConfidentMatch(place: place, title: title, item: $0) })
                ?? response.mapItems.first(where: { isConfidentMatch(place: place, title: title, item: $0, allowLooseDistance: true) })
                ?? response.mapItems.first(where: { $0.identifier != nil && namesAlign(title: title, mapItem: $0) })
        else {
            return nil
        }
        
        return best.identifier?.rawValue
    }
    
    @available(iOS 18.0, *)
    static func loadMapItem(identifierRawValue: String) async -> MKMapItem? {
        guard let identifier = MKMapItem.Identifier(rawValue: identifierRawValue) else { return nil }
        let request = MKMapItemRequest(mapItemIdentifier: identifier)
        do {
            return try await request.mapItem
        } catch {
            return nil
        }
    }
    
    private static func bestQuery(for place: Place, title: String) -> String {
        let location = place.location.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = place.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !location.isEmpty, !name.isEmpty {
            if location.localizedCaseInsensitiveContains(name) { return location }
            return "\(name), \(location)"
        }
        if !location.isEmpty { return location }
        return name
    }
    
    @available(iOS 18.0, *)
    private static func isConfidentMatch(
        place: Place,
        title: String,
        item: MKMapItem,
        allowLooseDistance: Bool = false
    ) -> Bool {
        guard item.identifier != nil else { return false }
        guard namesAlign(title: title, mapItem: item) else { return false }
        
        // Prefer real establishments / street-level results over vague localities.
        let isPOI = item.pointOfInterestCategory != nil
        let hasStreet = hasStreetAddress(item)
        
        guard let placeLat = place.latitude, let placeLon = place.longitude else {
            // AI-saved places often lack coordinates. Accept strong name matches and
            // named outdoor features (hikes/parks) that may not be street-addressed POIs.
            if strongNameContainment(title: title, mapItem: item) { return true }
            return isPOI || hasStreet
        }
        
        guard isPOI || hasStreet || strongNameContainment(title: title, mapItem: item) else { return false }
        
        let itemCoord = coordinate(of: item)
        let placeLoc = CLLocation(latitude: placeLat, longitude: placeLon)
        let itemLoc = CLLocation(latitude: itemCoord.latitude, longitude: itemCoord.longitude)
        let distance = placeLoc.distance(from: itemLoc)
        let limit = allowLooseDistance ? maxMatchDistanceMeters * 2 : maxMatchDistanceMeters
        return distance <= limit
    }
    
    private static func coordinate(of item: MKMapItem) -> CLLocationCoordinate2D {
        if #available(iOS 26.0, *) {
            return item.location.coordinate
        } else {
            return item.placemark.coordinate
        }
    }
    
    private static func strongNameContainment(title: String, mapItem: MKMapItem) -> Bool {
        let mapName = (mapItem.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mapName.isEmpty else { return false }
        let a = normalize(title)
        let b = normalize(mapName)
        return a.contains(b) || b.contains(a)
    }
    
    private static func namesAlign(title: String, mapItem: MKMapItem) -> Bool {
        let mapName = (mapItem.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mapName.isEmpty else { return false }
        
        let a = normalize(title)
        let b = normalize(mapName)
        if a.isEmpty || b.isEmpty { return false }
        if a.contains(b) || b.contains(a) { return true }
        
        let aTokens = Set(a.split(separator: " ").map(String.init).filter { $0.count > 2 })
        let bTokens = Set(b.split(separator: " ").map(String.init).filter { $0.count > 2 })
        guard !aTokens.isEmpty, !bTokens.isEmpty else { return false }
        let overlap = aTokens.intersection(bTokens).count
        let required = max(1, min(aTokens.count, bTokens.count) / 2)
        return overlap >= required
    }
    
    private static func hasStreetAddress(_ item: MKMapItem) -> Bool {
        if #available(iOS 26.0, *) {
            let full = item.address?.fullAddress ?? item.address?.shortAddress ?? ""
            return full.range(of: #"\d+\s+\p{L}"#, options: .regularExpression) != nil
        } else {
            let placemark = item.placemark
            return placemark.thoroughfare != nil
        }
    }
    
    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: #"[:\-\|]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
