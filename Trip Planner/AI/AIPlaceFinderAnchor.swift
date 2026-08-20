import CoreLocation
import Foundation
import MapKit

/// Resolves the geographic anchor for Find Places so prompts like
/// "Best of Toronto" aren't overridden by an unrelated tripContext (e.g. Chicago).
enum AIPlaceFinderAnchor {
    struct Resolved {
        /// Short label for reply copy ("Toronto", "Chicago, IL").
        var label: String?
        /// MapKit bias region for refining venues.
        var region: MKCoordinateRegion?
        /// tripContext sent to the API — nil when the prompt names a conflicting city.
        var tripContextForAPI: PlanDayTripContext?
        /// Prompt text, possibly strengthened with an explicit city lock.
        var promptText: String
    }
    
    static func resolve(
        prompt: String,
        tripContext: PlanDayTripContext?,
        nearYouLabel: String?,
        nearYouCoordinate: CLLocationCoordinate2D?
    ) async -> Resolved {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let nearYouLabel, !nearYouLabel.isEmpty, let nearYouCoordinate {
            return Resolved(
                label: nearYouLabel,
                region: MKCoordinateRegion(
                    center: nearYouCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
                ),
                tripContextForAPI: nil,
                promptText: trimmed
            )
        }
        
        let promptDestination = extractDestination(from: trimmed)
        let tripDestination = tripContext?.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let tripLabel = (tripDestination?.isEmpty == false) ? tripDestination : nil
        
        let usePromptOverTrip: Bool = {
            guard let promptDestination else { return false }
            guard let tripLabel else { return true }
            return !labelsAlign(promptDestination, tripLabel)
        }()
        
        let anchorLabel = usePromptOverTrip ? promptDestination : (promptDestination ?? tripLabel)
        var region: MKCoordinateRegion?
        var tripContextForAPI = tripContext
        var promptText = trimmed
        
        if usePromptOverTrip, let promptDestination {
            tripContextForAPI = nil
            promptText = """
            Anchor ALL suggestions to \(promptDestination). Every item location MUST include "\(promptDestination)". Ignore any other city.
            
            \(trimmed)
            """
            if let geocoded = await TripMapSupport.geocodeDestination(promptDestination) {
                let span = max(0.18, min(geocoded.mapSpan * 1.4, 0.55))
                region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: geocoded.latitude, longitude: geocoded.longitude),
                    span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
                )
            }
        } else if let tripContext,
                  let lat = tripContext.latitude,
                  let lon = tripContext.longitude {
            let span = max(0.12, min((tripContext.mapSpan ?? 0.25) * 1.25, 0.55))
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            )
        } else if let promptDestination,
                  let geocoded = await TripMapSupport.geocodeDestination(promptDestination) {
            let span = max(0.18, min(geocoded.mapSpan * 1.4, 0.55))
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: geocoded.latitude, longitude: geocoded.longitude),
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            )
        }
        
        return Resolved(
            label: shortLabel(anchorLabel),
            region: region,
            tripContextForAPI: tripContextForAPI,
            promptText: promptText
        )
    }
    
    /// Pulls an explicit city/region from place-finder prompts and chips.
    static func extractDestination(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let lower = trimmed.lowercased()
        if lower.hasPrefix("best of ") {
            return cleanDestinationCandidate(String(trimmed.dropFirst("Best of ".count)))
        }
        
        let patterns: [String] = [
            #"(?i)places?\s+to\s+save\s+in\s+(.+?)(?:\s*[—\-]|\s+mix\b|\s+each\b|\.|$)"#,
            #"(?i)\b(?:best|top)\s+(?:\w+\s+){0,4}(?:in|near|around)\s+(.+?)(?:\s*[—\-]|\s+mix\b|\.|$)"#,
            #"(?i)\b(?:restaurants?|cafes?|hotels?|stays?|attractions?|activities|places?|venues?|spots?)\s+(?:in|near|around)\s+(.+?)(?:\s*[—\-]|\.|$)"#,
            #"(?i)\b(?:in|near|around)\s+([A-Z][\w'.\-]+(?:[\s,]+[A-Z][\w'.\-]*){0,3})(?:\s*[—\-.,]|\s+within\b|\s+mix\b|$)"#,
        ]
        
        for pattern in patterns {
            guard let match = trimmed.range(of: pattern, options: .regularExpression) else { continue }
            let matched = String(trimmed[match])
            guard let group = firstCapture(in: matched, pattern: pattern)
                    ?? firstCapture(in: trimmed, pattern: pattern) else { continue }
            if let cleaned = cleanDestinationCandidate(group) {
                return cleaned
            }
        }
        return nil
    }
    
    static func labelsAlign(_ a: String, _ b: String) -> Bool {
        let left = normalizeLabel(a)
        let right = normalizeLabel(b)
        guard !left.isEmpty, !right.isEmpty else { return false }
        if left == right { return true }
        if left.contains(right) || right.contains(left) { return true }
        
        let leftTokens = Set(left.split(separator: " ").map(String.init).filter { $0.count > 2 })
        let rightTokens = Set(right.split(separator: " ").map(String.init).filter { $0.count > 2 })
        return !leftTokens.isEmpty && !rightTokens.isEmpty && !leftTokens.isDisjoint(with: rightTokens)
    }
    
    // MARK: - Private
    
    private static func shortLabel(_ value: String?) -> String? {
        guard let value else { return nil }
        let first = value
            .split(separator: ",")
            .first
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            ?? value
        return first.isEmpty ? nil : first
    }
    
    private static func normalizeLabel(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .split(separator: ",")
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            ?? ""
    }
    
    private static func cleanDestinationCandidate(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cut = value.range(of: #"\s*[—\-]\s*"#, options: .regularExpression) {
            value = String(value[..<cut.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let cut = value.range(
            of: #"\s+(?:mix|each|within|return|suggest|including)\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            value = String(value[..<cut.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
        
        let rejected: Set<String> = [
            "you", "me", "here", "there", "home", "current location",
            "my location", "this area", "the area"
        ]
        let lower = value.lowercased()
        guard !rejected.contains(lower) else { return nil }
        guard value.count >= 2, value.count <= 64 else { return nil }
        guard value.range(of: #"\p{L}"#, options: .regularExpression) != nil else { return nil }
        return value
    }
    
    private static func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
              let swiftRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[swiftRange])
    }
}
