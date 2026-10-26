import CoreLocation
import Foundation
import SwiftUI

/// Loads the remote Expert Tips feed and matches tips to places / activities / AI items.
@Observable
@MainActor
final class ExpertTipsStore {
    private(set) var tips: [ExpertTip] = []
    private(set) var isLoading = false
    private(set) var hasLoadedOnce = false
    private(set) var lastError: String?
    
    private let client: ExpertTipsClient
    private var inFlight: Task<Void, Never>?
    
    /// ~200 m — geo fallback must also pass a loose name check.
    private static let maxMatchDistanceMeters: CLLocationDistance = 200
    
    init(client: ExpertTipsClient = ExpertTipsClient()) {
        self.client = client
    }
    
    func refresh(force: Bool = false) async {
        if isLoading {
            await inFlight?.value
            return
        }
        if hasLoadedOnce, !force { return }
        
        isLoading = true
        let task = Task { @MainActor in
            defer {
                isLoading = false
                hasLoadedOnce = true
                inFlight = nil
            }
            do {
                let feed = try await client.fetchFeed(forceRefresh: force)
                guard !Task.isCancelled else { return }
                tips = feed.tips
                lastError = nil
            } catch {
                if tips.isEmpty {
                    lastError = "Couldn't load Expert Tips."
                }
                #if DEBUG
                print("Expert Tips refresh failed: \(error)")
                #endif
            }
        }
        inFlight = task
        await task.value
    }
    
    func tips(matching query: ExpertTipQuery) -> [ExpertTip] {
        guard !tips.isEmpty, query.hasMatchableIdentity else { return [] }
        let scored = tips.compactMap { tip -> (ExpertTip, Int)? in
            guard let score = matchScore(tip: tip, query: query) else { return nil }
            return (tip, score)
        }
        return scored
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.placeName.localizedCaseInsensitiveCompare(rhs.0.placeName) == .orderedAscending
            }
            .map(\.0)
    }
    
    func tips(
        title: String = "",
        location: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        mapKitIdentifier: String? = nil
    ) -> [ExpertTip] {
        tips(
            matching: ExpertTipQuery(
                title: title,
                location: location,
                latitude: latitude,
                longitude: longitude,
                mapKitIdentifier: mapKitIdentifier
            )
        )
    }
    
    // MARK: - Matching
    
    /// Higher is better. `nil` = no match.
    private func matchScore(tip: ExpertTip, query: ExpertTipQuery) -> Int? {
        if let tipID = normalizedID(tip.mapKitIdentifier),
           let queryID = normalizedID(query.mapKitIdentifier),
           tipID == queryID {
            return 300
        }
        
        if aliasMatches(tip: tip, query: query) {
            return 200
        }
        
        if geoAndLooseNameMatch(tip: tip, query: query) {
            return 100
        }
        
        return nil
    }
    
    private func aliasMatches(tip: ExpertTip, query: ExpertTipQuery) -> Bool {
        let candidates = queryMatchCandidates(query)
        guard !candidates.isEmpty else { return false }
        
        var aliasKeys: [String] = []
        aliasKeys.append(normalize(tip.placeName))
        aliasKeys.append(contentsOf: tip.aliases.map(normalize))
        aliasKeys = aliasKeys.filter { !$0.isEmpty }
        guard !aliasKeys.isEmpty else { return false }
        
        for candidate in candidates {
            for alias in aliasKeys {
                if namesMatch(candidate, alias) { return true }
            }
        }
        return false
    }
    
    private func geoAndLooseNameMatch(tip: ExpertTip, query: ExpertTipQuery) -> Bool {
        guard
            let tipLat = tip.latitude,
            let tipLon = tip.longitude,
            let qLat = query.latitude,
            let qLon = query.longitude
        else { return false }
        
        let tipLocation = CLLocation(latitude: tipLat, longitude: tipLon)
        let queryLocation = CLLocation(latitude: qLat, longitude: qLon)
        guard tipLocation.distance(from: queryLocation) <= Self.maxMatchDistanceMeters else {
            return false
        }
        
        let tipName = normalize(tip.placeName)
        let candidates = queryMatchCandidates(query)
        guard !tipName.isEmpty, !candidates.isEmpty else { return false }
        
        for candidate in candidates {
            if namesMatch(candidate, tipName) { return true }
        }
        return false
    }
    
    /// Whole-token matching only — substring checks false-positive ("AGO" ⊂ "Chicago").
    private func namesMatch(_ query: String, _ alias: String) -> Bool {
        if query == alias { return true }
        
        let queryTokens = significantTokens(query)
        let aliasTokens = significantTokens(alias)
        guard !queryTokens.isEmpty, !aliasTokens.isEmpty else { return false }
        
        if aliasTokens.count == 1 {
            return queryTokens.contains(aliasTokens[aliasTokens.startIndex])
        }
        if queryTokens.count == 1 {
            return aliasTokens.count == 1
                && aliasTokens.contains(queryTokens[queryTokens.startIndex])
        }
        if aliasTokens.isSubset(of: queryTokens) { return true }
        if queryTokens.isSubset(of: aliasTokens) { return true }
        return false
    }
    
    private func significantTokens(_ value: String) -> Set<String> {
        let stop: Set<String> = ["the", "a", "an", "and", "of", "at", "in", "on", "to", "for"]
        return Set(
            value.split(separator: " ")
                .map(String.init)
                .filter { $0.count > 1 && !stop.contains($0) }
        )
    }
    
    private func queryMatchCandidates(_ query: ExpertTipQuery) -> [String] {
        var values: [String] = []
        let location = query.location.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = query.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !location.isEmpty {
            values.append(normalize(location))
            values.append(normalize(PlaceNaming.title(location: location, fallback: "")))
        }
        if !title.isEmpty {
            values.append(normalize(title))
        }
        return Array(Set(values.filter { !$0.isEmpty }))
    }
    
    private func normalizedID(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: #"['’]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[:\-\|]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
