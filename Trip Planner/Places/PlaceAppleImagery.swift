import Foundation
import MapKit
import UIKit

/// Generates a cover image for places when Apple Maps Place Card photos
/// aren't available to apps (MapKit only shows those inside system UI).
/// Prefers Look Around, then a satellite map snapshot.
enum PlaceAppleImagery {
    private static let coverSize = CGSize(width: 800, height: 600)
    private static let cache = NSCache<NSString, NSData>()
    
    /// JPEG cover for a coordinate, or nil if nothing could be captured.
    static func coverJPEG(at coordinate: CLLocationCoordinate2D) async -> Data? {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        let key = cacheKey(for: coordinate)
        if let cached = cache.object(forKey: key) {
            return cached as Data
        }
        
        let data: Data?
        if let lookAround = await lookAroundImage(at: coordinate),
           let jpeg = lookAround.jpegData(compressionQuality: 0.82) {
            data = jpeg
        } else if let map = await mapSnapshotImage(at: coordinate),
                  let jpeg = map.jpegData(compressionQuality: 0.82) {
            data = jpeg
        } else {
            data = nil
        }
        
        if let data {
            cache.setObject(data as NSData, forKey: key)
        }
        return data
    }
    
    /// Resolves coordinates when needed, then returns a cover JPEG.
    static func coverJPEG(
        name: String,
        location: String,
        latitude: Double?,
        longitude: Double?,
        regionHint: MKCoordinateRegion? = nil
    ) async -> Data? {
        if let latitude, let longitude {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            if CLLocationCoordinate2DIsValid(coordinate) {
                return await coverJPEG(at: coordinate)
            }
        }
        
        guard let mapItem = await ApplePlaceLookup.mapItem(
            name: name,
            location: location,
            latitude: latitude,
            longitude: longitude,
            regionHint: regionHint
        ), let coordinate = mapItemCoordinate(mapItem) else {
            return nil
        }
        return await coverJPEG(at: coordinate)
    }
    
    private static func cacheKey(for coordinate: CLLocationCoordinate2D) -> NSString {
        // ~11 m precision — enough to reuse covers without over-caching.
        let lat = (coordinate.latitude * 10_000).rounded() / 10_000
        let lon = (coordinate.longitude * 10_000).rounded() / 10_000
        return "\(lat),\(lon)" as NSString
    }
    
    private static func lookAroundImage(at coordinate: CLLocationCoordinate2D) async -> UIImage? {
        let request = MKLookAroundSceneRequest(coordinate: coordinate)
        guard let scene = try? await request.scene else { return nil }
        
        let options = MKLookAroundSnapshotter.Options()
        options.size = coverSize
        let snapshotter = MKLookAroundSnapshotter(scene: scene, options: options)
        guard let snapshot = try? await snapshotter.snapshot else { return nil }
        return snapshot.image
    }
    
    private static func mapSnapshotImage(at coordinate: CLLocationCoordinate2D) async -> UIImage? {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 350,
            longitudinalMeters: 350
        )
        options.size = coverSize
        // Satellite reads more like a place photo in the masonry grid.
        options.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)
        
        let snapshotter = MKMapSnapshotter(options: options)
        return await withCheckedContinuation { continuation in
            snapshotter.start { snapshot, _ in
                continuation.resume(returning: snapshot?.image)
            }
        }
    }
}
