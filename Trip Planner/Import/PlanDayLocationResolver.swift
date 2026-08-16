import Foundation
import MapKit

enum PlanDayLocationResolver {
    /// Resolve activity locations to street-level MapKit places when the item is a specific establishment.
    /// Always stores coordinates when MapKit finds a match so trip map pins can plot.
    /// General-area activities keep the AI location text as-is when no POI match is found.
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
            
            for query in queries {
                if Task.isCancelled { break }
                guard let mapItem = await searchMapItem(query: query, region: biasRegion) else { continue }
                guard let coordinate = mapItemCoordinate(mapItem) else { continue }
                
                let isPOI = isSpecificEstablishment(mapItem)
                let aligned = namesAlign(title: title, mapItem: mapItem)
                
                // Prefer upgrading location text for named establishments.
                if isPOI, aligned, !alreadyStreetLevel,
                   let refined = refinedLocationString(for: mapItem, fallbackTitle: title) {
                    updated.items[idx].location = refined
                    updated.items[idx].latitude = coordinate.latitude
                    updated.items[idx].longitude = coordinate.longitude
                    break
                }
                
                // Street-level (or loose) match: keep location text, still capture coordinates for the map.
                if alreadyStreetLevel || (isPOI && aligned) {
                    updated.items[idx].latitude = coordinate.latitude
                    updated.items[idx].longitude = coordinate.longitude
                    break
                }
            }
            
            try? await Task.sleep(nanoseconds: 160_000_000)
        }
        
        return updated
    }
    
    // MARK: - Search
    
    private static func searchQueries(title: String, location: String, destination: String) -> [String] {
        var queries: [String] = []
        let destSuffix = destination.isEmpty ? "" : ", \(destination)"
        
        if !location.isEmpty {
            queries.append(location)
            if !location.localizedCaseInsensitiveContains(title), !title.isEmpty {
                queries.append("\(title), \(location)")
            }
        }
        queries.append("\(title)\(destSuffix)")
        if !location.isEmpty, location.caseInsensitiveCompare(destination) != .orderedSame {
            queries.append("\(title), \(location)\(destSuffix)")
        }
        
        var seen = Set<String>()
        return queries.filter { seen.insert($0.lowercased()).inserted }
    }
    
    private static func searchMapItem(query: String, region: MKCoordinateRegion?) async -> MKMapItem? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        if let region {
            request.region = region
        }
        
        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.first
        } catch {
            return nil
        }
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
        guard !mapName.isEmpty else { return true }
        
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
    func ranges(of pattern: String, options: String.CompareOptions = []) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var searchStart = startIndex
        while searchStart < endIndex,
              let range = range(of: pattern, options: options.union(.regularExpression), range: searchStart..<endIndex) {
            result.append(range)
            searchStart = range.upperBound
        }
        return result
    }
}
