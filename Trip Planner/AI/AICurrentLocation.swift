import CoreLocation
import Foundation

/// One-shot current location + reverse geocode for AI "near you" chips.
@MainActor
enum AICurrentLocation {
    struct Place {
        let label: String
        let latitude: Double
        let longitude: Double
    }
    
    static func resolve() async -> Place? {
        guard let location = await OneShotLocationFetcher.fetch() else { return nil }
        
        let geocoder = CLGeocoder()
        let placemarks = try? await geocoder.reverseGeocodeLocation(location)
        let placemark = placemarks?.first
        
        let city = placemark?.locality?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let region = placemark?.administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let country = placemark?.country?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        var parts: [String] = []
        if !city.isEmpty { parts.append(city) }
        if !region.isEmpty, region != city { parts.append(region) }
        if parts.isEmpty, !country.isEmpty { parts.append(country) }
        
        let label = parts.isEmpty
            ? String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
            : parts.joined(separator: ", ")
        
        return Place(
            label: label,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }
    
    /// Phrases that make the answer depend on where the user actually is.
    /// Without this the AI has no anchor for "me" and picks a region at random.
    static func promptNeedsOrigin(_ text: String) -> Bool {
        let patterns = [
            #"\bnear\s+(me|my)\b"#,
            #"\bfrom\s+(me|here)\b"#,
            #"\b(of|to|from)\s+me\b"#,
            #"\baround\s+(me|here)\b"#,
            #"\bclose\s+(to|by)\s+(me|here|home)\b"#,
            #"\bmy\s+(area|region|city|town|neighborhood|location|place|home)\b"#,
            #"\bnearby\b"#,
            #"\bwhere\s+i\s+(am|live)\b"#,
            #"\bcurrent\s+location\b"#,
            #"\bdriving\s+distance\b"#,
            #"\bwithin\s+(a\s+|an\s+)?\d{1,2}\s*-?\s*(hours?|hrs?|h)\b"#,
            #"\b\d{1,2}\s*-?\s*(hours?|hrs?)\s+(drive|driving|away)\b"#,
        ]
        return patterns.contains { pattern in
            text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }
    
    /// Resolves the origin only when the prompt needs it and access already exists,
    /// so a typed "near me" doesn't silently fail but ordinary asks stay location-free.
    static func originIfNeeded(for prompt: String) async -> Place? {
        guard promptNeedsOrigin(prompt) else { return nil }
        return await resolve()
    }
}

@MainActor
private final class OneShotLocationFetcher: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?
    
    static func fetch() async -> CLLocation? {
        let fetcher = OneShotLocationFetcher()
        return await fetcher.fetchLocation()
    }
    
    private func fetchLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            default:
                finish(nil)
            }
        }
    }
    
    private func finish(_ location: CLLocation?) {
        continuation?.resume(returning: location)
        continuation = nil
        manager.delegate = nil
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .denied, .restricted:
                finish(nil)
            default:
                break
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            finish(locations.last)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            finish(nil)
        }
    }
}
