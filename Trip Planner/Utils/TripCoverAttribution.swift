import Foundation

/// Lightweight attribution storage keyed by Trip ID.
/// Persists outside the `Trip` model (since `Trip` is Codable and user removed attribution fields).
enum TripCoverAttribution {
    private static func keyName(for tripID: UUID) -> String { "coverAttributionName.\(tripID.uuidString)" }
    
    static func setName(_ name: String?, for tripID: UUID) {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let key = keyName(for: tripID)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(trimmed, forKey: key)
        }
        NotificationCenter.default.post(name: .tripCoverAttributionChanged, object: nil)
    }
    
    static func name(for tripID: UUID) -> String? {
        let key = keyName(for: tripID)
        let s = (UserDefaults.standard.string(forKey: key) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }
    
    static func clear(for tripID: UUID) {
        UserDefaults.standard.removeObject(forKey: keyName(for: tripID))
        NotificationCenter.default.post(name: .tripCoverAttributionChanged, object: nil)
    }
}

extension Notification.Name {
    static let tripCoverAttributionChanged = Notification.Name("tripCoverAttributionChanged")
}

