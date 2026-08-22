import Foundation
import MapKit
import CoreLocation

enum PlanDayLocationResolver {
    /// Resolve activity locations to street-level MapKit places when the item is a specific establishment.
    /// Always stores coordinates when MapKit finds a match so trip map pins can plot.
    /// Unresolved venues get confidence crushed so callers can treat them as a negative signal.
    static func refineLocations(
        in draft: PlanDayDraft,
        destination: String,
        biasRegion: MKCoordinateRegion?
    ) async -> PlanDayDraft {
        var updated = draft
        let destination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        
        for idx in updated.items.indices {
            if Task.isCancelled { break }
            guard updated.items[idx].kind == .activity || updated.items[idx].kind == .place else { continue }
            
            let item = updated.items[idx]
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            
            let currentLocation = item.location.trimmingCharacters(in: .whitespacesAndNewlines)
            let alreadyStreetLevel = isAlreadyStreetLevel(currentLocation)
            let queries = searchQueries(
                title: title,
                location: currentLocation,
                destination: destination
            )
            
            var resolved = false
            for query in queries {
                if Task.isCancelled { break }
                guard let mapItem = await searchMapItem(
                    query: query,
                    expectedTitle: title,
                    region: biasRegion,
                    destination: destination
                ) else { continue }
                guard let coordinate = mapItemCoordinate(mapItem) else { continue }
                
                let isPOI = isSpecificEstablishment(mapItem)
                let aligned = namesAlign(title: title, mapItem: mapItem)
                
                // Prefer upgrading location text for named establishments.
                if isPOI, aligned, !alreadyStreetLevel,
                   let refined = refinedLocationString(for: mapItem, fallbackTitle: title) {
                    updated.items[idx].location = refined
                    updated.items[idx].latitude = coordinate.latitude
                    updated.items[idx].longitude = coordinate.longitude
                    resolved = true
                    break
                }
                
                // Street-level (or loose) match: keep location text, still capture coordinates for the map.
                if alreadyStreetLevel || (isPOI && aligned) {
                    updated.items[idx].latitude = coordinate.latitude
                    updated.items[idx].longitude = coordinate.longitude
                    if !destination.isEmpty,
                       !currentLocation.localizedCaseInsensitiveContains(destination.split(separator: ",").first.map(String.init) ?? destination),
                       let refined = refinedLocationString(for: mapItem, fallbackTitle: title) {
                        updated.items[idx].location = refined
                    }
                    resolved = true
                    break
                }
            }
            
            // MapKit found nothing usable — treat as a real negative, not a silent pass-through.
            if !resolved, shouldRequireMapVerification(item) {
                let prior = updated.items[idx].confidence ?? 0.7
                updated.items[idx].confidence = min(prior, 0.15)
                if updated.items[idx].notes.range(
                    of: #"unverified"#,
                    options: [.caseInsensitive, .regularExpression]
                ) == nil {
                    let note = updated.items[idx].notes.trimmingCharacters(in: .whitespacesAndNewlines)
                    updated.items[idx].notes = note.isEmpty
                        ? "Unverified location"
                        : "\(note) · Unverified location"
                }
            }
            
            try? await Task.sleep(nanoseconds: 120_000_000)
        }
        
        return updated
    }
    
    /// Venue-like activities/places that should resolve on Apple Maps.
    private static func shouldRequireMapVerification(_ item: PlanDayItem) -> Bool {
        switch item.kind {
        case .activity, .place:
            let category = item.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            // Skip purely non-venue categories if any appear; default = require verification.
            if category == "other" && item.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }
            return !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return false
        }
    }
    
    // MARK: - Search
    
    private static func searchQueries(title: String, location: String, destination: String) -> [String] {
        var queries: [String] = []
        let destSuffix = destination.isEmpty ? "" : ", \(destination)"
        let destCity = destination.split(separator: ",").first.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        } ?? destination
        
        if !location.isEmpty {
            // Prefer title + location when location lacks the venue name.
            if !location.localizedCaseInsensitiveContains(title), !title.isEmpty {
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
        queries.append("\(title)\(destSuffix)")
        if !location.isEmpty, location.caseInsensitiveCompare(destination) != .orderedSame {
            queries.append("\(title), \(location)\(destSuffix)")
        }
        
        var seen = Set<String>()
        return queries.filter { seen.insert($0.lowercased()).inserted }
    }
    
    private static func searchMapItem(
        query: String,
        expectedTitle: String,
        region: MKCoordinateRegion?,
        destination: String
    ) async -> MKMapItem? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        if let region {
            request.region = region
        }
        
        do {
            let response = try await MKLocalSearch(request: request).start()
            return pickBestMapItem(
                from: response.mapItems,
                expectedTitle: expectedTitle,
                region: region,
                destination: destination
            )
        } catch {
            return nil
        }
    }
    
    /// Prefer name-aligned POIs inside the destination region; never accept a random first hit.
    private static func pickBestMapItem(
        from items: [MKMapItem],
        expectedTitle: String,
        region: MKCoordinateRegion?,
        destination: String
    ) -> MKMapItem? {
        guard !items.isEmpty else { return nil }
        
        let inRegion = items.filter { isWithinBiasRegion($0, region: region) }
        let pool = inRegion.isEmpty && region == nil ? items : (inRegion.isEmpty ? [] : inRegion)
        guard !pool.isEmpty else { return nil }
        
        let alignedPOI = pool.first {
            namesAlign(title: expectedTitle, mapItem: $0)
                && isSpecificEstablishment($0)
                && localityMatches($0, destination: destination)
        }
        if let alignedPOI { return alignedPOI }
        
        let alignedInDest = pool.first {
            namesAlign(title: expectedTitle, mapItem: $0)
                && localityMatches($0, destination: destination)
        }
        if let alignedInDest { return alignedInDest }
        
        let alignedPOIAnywhere = pool.first {
            namesAlign(title: expectedTitle, mapItem: $0) && isSpecificEstablishment($0)
        }
        if let alignedPOIAnywhere { return alignedPOIAnywhere }
        
        // Last resort: name-aligned only (still reject totally unrelated first hits).
        return pool.first { namesAlign(title: expectedTitle, mapItem: $0) }
    }
    
    private static func isWithinBiasRegion(_ item: MKMapItem, region: MKCoordinateRegion?) -> Bool {
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
        
        // Destination "Toronto" should accept "North York, ON" when region filter already passed.
        // Only fail hard when a clearly different major city appears without the destination.
        let foreignCities = ["chicago", "new york", "los angeles", "miami", "paris", "london", "tokyo", "rome"]
        let destHit = foreignCities.contains(where: { destNorm.contains($0) })
        if destHit { return hayNorm.contains(destNorm) }
        
        let conflicting = foreignCities.filter { hayNorm.contains($0) && !destNorm.contains($0) }
        return conflicting.isEmpty
    }
    
    // MARK: - Specificity
    
    private static func isSpecificEstablishment(_ item: MKMapItem) -> Bool {
        if item.pointOfInterestCategory != nil { return true }
        if mapItemHasStreetAddress(item) { return true }
        
        let address = mapItemAddressString(item) ?? ""
        return isAlreadyStreetLevel(address)
    }
    
    private static func mapItemHasStreetAddress(_ item: MKMapItem) -> Bool {
        if #available(iOS 26.0, *) {
            let full = item.address?.fullAddress ?? item.address?.shortAddress ?? ""
            return isAlreadyStreetLevel(full)
        } else {
            let placemark = item.placemark
            return placemark.thoroughfare != nil || placemark.subThoroughfare != nil
        }
    }
    
    private static func isAlreadyStreetLevel(_ location: String) -> Bool {
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        
        // Street number is the strongest signal.
        if trimmed.range(of: #"\b\d+[A-Za-z]?\b"#, options: .regularExpression) != nil {
            // Avoid treating bare postal codes / years as street addresses.
            let digitRuns = trimmed.ranges(of: #"\d+"#, options: .regularExpression)
            if digitRuns.count >= 1, trimmed.contains(",") || trimmed.split(whereSeparator: { $0.isWhitespace }).count >= 3 {
                return true
            }
            if trimmed.range(of: #"\b\d+\s+\p{L}"#, options: .regularExpression) != nil {
                return true
            }
        }
        
        // Common street-type words.
        let streetWords = [
            "street", "st", "avenue", "ave", "road", "rd", "boulevard", "blvd",
            "lane", "ln", "drive", "dr", "way", "court", "ct", "place", "pl",
            "rue", "via", "calle", "straße", "strasse", "ulica", "aleja"
        ]
        let lower = trimmed.lowercased()
        return streetWords.contains { word in
            lower.range(of: "\\b\(word)\\b", options: .regularExpression) != nil
        }
    }
    
    private static func namesAlign(title: String, mapItem: MKMapItem) -> Bool {
        let mapName = (itemName(mapItem) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
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
    
    private static func itemName(_ item: MKMapItem) -> String? {
        if #available(iOS 26.0, *) {
            return item.name
        } else {
            return item.name ?? item.placemark.name
        }
    }
    
    private static func refinedLocationString(for item: MKMapItem, fallbackTitle: String) -> String? {
        let address = mapItemAddressString(item)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = (itemName(item) ?? fallbackTitle).trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !address.isEmpty {
            if !name.isEmpty, !address.localizedCaseInsensitiveContains(name) {
                return "\(name), \(address)"
            }
            return address
        }
        
        if !name.isEmpty, isSpecificEstablishment(item) {
            return name
        }
        return nil
    }
    
    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: #"[:\-\|]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\b(the|a|an|at|in|near|visit|lunch|dinner|breakfast|coffee|drinks?)\b"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    func ranges(of pattern: String, options: NSString.CompareOptions) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var searchStart = startIndex
        while searchStart < endIndex,
              let range = range(of: pattern, options: options, range: searchStart..<endIndex) {
            result.append(range)
            searchStart = range.upperBound
        }
        return result
    }
}
