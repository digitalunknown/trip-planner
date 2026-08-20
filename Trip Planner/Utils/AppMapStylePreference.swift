import MapKit
import SwiftUI

/// User preference for trip/explore card snapshots and trip detail maps.
/// Profile globe always stays satellite.
enum AppMapStylePreference: String, CaseIterable, Identifiable {
    case standard
    case satellite
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .standard: return "Standard"
        case .satellite: return "Satellite"
        }
    }
    
    /// SwiftUI `Map` style (trip detail).
    var mapStyle: MapStyle {
        switch self {
        case .standard:
            return .standard(elevation: .realistic)
        case .satellite:
            return .imagery(elevation: .realistic)
        }
    }
    
    /// MapKit configuration for `MKMapSnapshotter` (trip/explore cards).
    /// Prefer this over deprecated `mapType` on iOS 17+.
    var snapshotConfiguration: MKMapConfiguration {
        switch self {
        case .standard:
            return MKStandardMapConfiguration(elevationStyle: .realistic)
        case .satellite:
            return MKImageryMapConfiguration(elevationStyle: .realistic)
        }
    }
    
    static let storageKey = "mapStylePreference"
    
    static func resolved(fromRaw raw: String) -> AppMapStylePreference {
        AppMapStylePreference(rawValue: raw) ?? .standard
    }
}
