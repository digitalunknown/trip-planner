import CoreLocation
import Foundation
import MapKit

/// Resolves the same MapKit place Apple Maps preview uses — not just `mapItems.first`.
enum ApplePlaceLookup {
    static func mapItem(
        name: String,
        location: String,
        latitude: Double?,
        longitude: Double?,
        regionHint: MKCoordinateRegion? = nil,
        destinationHint: String? = nil
    ) async -> MKMapItem? {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let destination = (destinationHint ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        let queries = searchQueries(title: title, location: place, destination: destination)
        guard !queries.isEmpty || (latitude != nil && longitude != nil) else { return nil }
        
        let region = searchRegion(
            latitude: latitude,
            longitude: longitude,
            regionHint: regionHint
        )
        
        for query in queries {
            if let item = await searchBest(
                query: query,
                expectedTitle: title.isEmpty ? place : title,
                region: region,
                destination: destination.isEmpty ? placeCityHint(place) : destination
            ) {
                return item
            }
        }
        
        // Coordinate-only fallback when text search misses.
        if let latitude, let longitude {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
            let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            item.name = title.isEmpty ? (place.isEmpty ? "Place" : place) : title
            return item
        }
        return nil
    }
    
    // MARK: - Search
    
    private static func searchQueries(title: String, location: String, destination: String) -> [String] {
        var queries: [String] = []
        let destCity = destination.split(separator: ",").first.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        } ?? destination
        
        if !location.isEmpty {
            if !title.isEmpty, !location.localizedCaseInsensitiveContains(title) {
                queries.append("\(title), \(location)")
            }
            queries.append(location)
            if !destCity.isEmpty, !location.localizedCaseInsensitiveContains(destCity) {
                queries.append("\(location), \(destCity)")
                if !title.isEmpty {
                    queries.append("\(title), \(location), \(destCity)")
                }
            }
        }
        if !title.isEmpty {
            let suffix = destCity.isEmpty ? (location.isEmpty ? "" : ", \(location)") : ", \(destCity)"
            queries.append("\(title)\(suffix)")
        }
        
        var seen = Set<String>()
        return queries.filter { seen.insert($0.lowercased()).inserted }
    }
    
    private static func searchRegion(
        latitude: Double?,
        longitude: Double?,
        regionHint: MKCoordinateRegion?
    ) -> MKCoordinateRegion? {
        if let latitude, let longitude {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            if CLLocationCoordinate2DIsValid(coordinate) {
                return MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: 12_000,
                    longitudinalMeters: 12_000
                )
            }
        }
        return regionHint
    }
    
    private static func searchBest(
        query: String,
        expectedTitle: String,
        region: MKCoordinateRegion?,
        destination: String
    ) async -> MKMapItem? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.pointOfInterest, .address]
        if let region {
            request.region = region
        }
        
        do {
            let response = try await MKLocalSearch(request: request).start()
            return pickBest(
                from: response.mapItems,
                expectedTitle: expectedTitle,
                region: region,
                destination: destination
            )
        } catch {
            return nil
        }
    }
    
    private static func pickBest(
        from items: [MKMapItem],
        expectedTitle: String,
        region: MKCoordinateRegion?,
        destination: String
    ) -> MKMapItem? {
        guard !items.isEmpty else { return nil }
        
        let inRegion = items.filter { isWithinRegion($0, region: region) }
        let pool = inRegion.isEmpty ? items : inRegion
        
        if let hit = pool.first(where: {
            namesAlign(title: expectedTitle, mapItem: $0)
                && isSpecificEstablishment($0)
                && localityMatches($0, destination: destination)
        }) {
            return hit
        }
        if let hit = pool.first(where: {
            namesAlign(title: expectedTitle, mapItem: $0)
                && localityMatches($0, destination: destination)
        }) {
            return hit
        }
        if let hit = pool.first(where: {
            namesAlign(title: expectedTitle, mapItem: $0) && isSpecificEstablishment($0)
        }) {
            return hit
        }
        return pool.first { namesAlign(title: expectedTitle, mapItem: $0) }
            ?? pool.first
    }
    
    // MARK: - Matching helpers
    
    private static func isWithinRegion(_ item: MKMapItem, region: MKCoordinateRegion?) -> Bool {
        guard let region, let coordinate = mapItemCoordinate(item) else { return true }
        let center = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        let point = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let latMeters = region.span.latitudeDelta * 111_000 / 2
        let cosLat = cos(region.center.latitude * .pi / 180)
        let lonMeters = region.span.longitudeDelta * 111_000 * max(cosLat, 0.2) / 2
        let maxDistance = max(max(latMeters, lonMeters), 45_000) * 1.6
        return point.distance(from: center) <= maxDistance
    }
    
    private static func localityMatches(_ item: MKMapItem, destination: String) -> Bool {
        let destination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !destination.isEmpty else { return true }
        
        let destCore = destination
            .split(separator: ",")
            .first
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            ?? destination
        let destNorm = normalize(destCore)
        guard !destNorm.isEmpty else { return true }
        
        let haystack = [
            mapItemCity(item),
            mapItemAddressString(item),
            item.placemark.locality,
            item.placemark.subLocality,
            item.placemark.administrativeArea,
            item.placemark.country,
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        
        let hayNorm = normalize(haystack)
        if hayNorm.contains(destNorm) { return true }
        
        let foreignCities = [
            "chicago", "new york", "los angeles", "miami", "paris", "london",
            "tokyo", "rome", "toronto", "vancouver", "montreal", "boston",
            "san francisco", "seattle", "austin", "denver"
        ]
        let destHit = foreignCities.contains(where: { destNorm.contains($0) })
        if destHit { return hayNorm.contains(destNorm) }
        
        let conflicting = foreignCities.filter { hayNorm.contains($0) && !destNorm.contains($0) }
        return conflicting.isEmpty
    }
    
    private static func isSpecificEstablishment(_ item: MKMapItem) -> Bool {
        if item.pointOfInterestCategory != nil { return true }
        if #available(iOS 26.0, *) {
            let full = item.address?.fullAddress ?? item.address?.shortAddress ?? ""
            return full.range(of: #"\d+\s+\p{L}"#, options: .regularExpression) != nil
        }
        let placemark = item.placemark
        return placemark.thoroughfare != nil || placemark.subThoroughfare != nil
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
    
    private static func placeCityHint(_ location: String) -> String {
        let parts = location
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard parts.count >= 2 else { return "" }
        // "Venue, City, Region" → City
        return parts.count >= 3 ? parts[parts.count - 2] : (parts.last ?? "")
    }
    
    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: #"[:\-\|]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(
                of: #"\b(the|a|an|at|in|near|visit|lunch|dinner|breakfast|coffee|drinks?|check in|check-in)\b"#,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
