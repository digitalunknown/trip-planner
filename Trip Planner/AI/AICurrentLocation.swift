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
