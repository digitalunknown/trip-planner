import Foundation
import MapKit
import UIKit

/// Cover imagery for places.
///
/// Apple Maps Place Card gallery photos are not available to third-party apps —
/// only Apple’s Place Card UI can show them. We instead resolve the same `MKMapItem`
/// the in-app Maps preview uses, then prefer Look Around for that place and fall
/// back to a standard Maps-style snapshot with a pin.
enum PlaceAppleImagery {
    /// Keep snapshots modest — full-res Look Around for every place OOM'd the app.
    private static let coverSize = CGSize(width: 480, height: 360)
    private static let cache = NSCache<NSString, NSData>()
    
    /// JPEG cover for a known MapKit place.
    static func coverJPEG(for mapItem: MKMapItem) async -> Data? {
        guard let coordinate = mapItemCoordinate(mapItem),
              CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        
        let key = cacheKey(for: coordinate, mapItem: mapItem)
        if let cached = cache.object(forKey: key) {
            return cached as Data
        }
        
        let data: Data?
        if let lookAround = await lookAroundImage(for: mapItem, coordinate: coordinate),
           let jpeg = lookAround.jpegData(compressionQuality: 0.72) {
            data = jpeg
        } else if let map = await mapSnapshotImage(at: coordinate),
                  let jpeg = map.jpegData(compressionQuality: 0.72) {
            data = jpeg
        } else {
            data = nil
        }
        
        if let data {
            store(data, key: key)
        }
        return data
    }
    
    /// JPEG cover for a coordinate, or nil if nothing could be captured.
    static func coverJPEG(at coordinate: CLLocationCoordinate2D) async -> Data? {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        let key = cacheKey(for: coordinate, mapItem: nil)
        if let cached = cache.object(forKey: key) {
            return cached as Data
        }
        
        let data: Data?
        if let lookAround = await lookAroundImage(for: nil, coordinate: coordinate),
           let jpeg = lookAround.jpegData(compressionQuality: 0.72) {
            data = jpeg
        } else if let map = await mapSnapshotImage(at: coordinate),
                  let jpeg = map.jpegData(compressionQuality: 0.72) {
            data = jpeg
        } else {
            data = nil
        }
        
        if let data {
            store(data, key: key)
        }
        return data
    }
    
    /// Resolves the MapKit place (same matcher as Apple Maps preview), then returns a cover JPEG.
    static func coverJPEG(
        name: String,
        location: String,
        latitude: Double?,
        longitude: Double?,
        regionHint: MKCoordinateRegion? = nil,
        destinationHint: String? = nil
    ) async -> Data? {
        if let mapItem = await ApplePlaceLookup.mapItem(
            name: name,
            location: location,
            latitude: latitude,
            longitude: longitude,
            regionHint: regionHint,
            destinationHint: destinationHint
        ) {
            return await coverJPEG(for: mapItem)
        }
        
        if let latitude, let longitude {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            if CLLocationCoordinate2DIsValid(coordinate) {
                return await coverJPEG(at: coordinate)
            }
        }
        return nil
    }
    
    // MARK: - Private
    
    private static func store(_ data: Data, key: NSString) {
        cache.setObject(data as NSData, forKey: key, cost: data.count)
        cache.totalCostLimit = 8 * 1024 * 1024
        cache.countLimit = 40
    }
    
    private static func cacheKey(for coordinate: CLLocationCoordinate2D, mapItem: MKMapItem?) -> NSString {
        let lat = (coordinate.latitude * 10_000).rounded() / 10_000
        let lon = (coordinate.longitude * 10_000).rounded() / 10_000
        if #available(iOS 18.0, *), let id = mapItem?.identifier?.rawValue, !id.isEmpty {
            return "id:\(id)" as NSString
        }
        let name = (mapItem?.name ?? "").lowercased()
        return "\(lat),\(lon),\(name)" as NSString
    }
    
    private static func lookAroundImage(
        for mapItem: MKMapItem?,
        coordinate: CLLocationCoordinate2D
    ) async -> UIImage? {
        let request: MKLookAroundSceneRequest
        if let mapItem {
            request = MKLookAroundSceneRequest(mapItem: mapItem)
        } else {
            request = MKLookAroundSceneRequest(coordinate: coordinate)
        }
        guard let scene = try? await request.scene else {
            // mapItem Look Around can fail even when coordinate works.
            if mapItem != nil {
                let fallback = MKLookAroundSceneRequest(coordinate: coordinate)
                guard let scene = try? await fallback.scene else { return nil }
                return await snapshot(scene: scene)
            }
            return nil
        }
        return await snapshot(scene: scene)
    }
    
    private static func snapshot(scene: MKLookAroundScene) async -> UIImage? {
        let options = MKLookAroundSnapshotter.Options()
        options.size = coverSize
        let snapshotter = MKLookAroundSnapshotter(scene: scene, options: options)
        guard let snapshot = try? await snapshotter.snapshot else { return nil }
        return snapshot.image
    }
    
    /// Standard map (not satellite) with a pin — closer to the Maps place preview map.
    private static func mapSnapshotImage(at coordinate: CLLocationCoordinate2D) async -> UIImage? {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 450,
            longitudinalMeters: 450
        )
        options.size = coverSize
        options.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic)
        
        let snapshotter = MKMapSnapshotter(options: options)
        return await withCheckedContinuation { continuation in
            snapshotter.start { snapshot, _ in
                guard let snapshot else {
                    continuation.resume(returning: nil)
                    return
                }
                let point = snapshot.point(for: coordinate)
                let rendered = UIGraphicsImageRenderer(size: snapshot.image.size).image { _ in
                    snapshot.image.draw(at: .zero)
                    drawMapsStylePin(at: point)
                }
                continuation.resume(returning: rendered)
            }
        }
    }
    
    private static func drawMapsStylePin(at point: CGPoint) {
        let pinHeight: CGFloat = 36
        let pinWidth: CGFloat = 24
        let rect = CGRect(
            x: point.x - pinWidth / 2,
            y: point.y - pinHeight,
            width: pinWidth,
            height: pinHeight
        )
        
        let color = UIColor.systemRed
        color.setFill()
        
        let path = UIBezierPath()
        let head = CGRect(
            x: rect.midX - 10,
            y: rect.minY,
            width: 20,
            height: 20
        )
        path.append(UIBezierPath(ovalIn: head))
        path.move(to: CGPoint(x: rect.midX - 7, y: head.maxY - 4))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX + 7, y: head.maxY - 4))
        path.close()
        path.fill()
        
        UIColor.white.setFill()
        let dot = CGRect(x: rect.midX - 4, y: head.minY + 6, width: 8, height: 8)
        UIBezierPath(ovalIn: dot).fill()
    }
}
