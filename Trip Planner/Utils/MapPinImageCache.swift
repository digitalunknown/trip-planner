import ImageIO
import UIKit

/// Downsampled map-pin images with an in-memory cache.
/// Avoids decoding full activity photos on every Map annotation re-render.
enum MapPinImageCache {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 200
        cache.totalCostLimit = 12 * 1024 * 1024 // ~12 MB of decoded pin bitmaps
        return cache
    }()
    
    /// Pin image for an activity (photo or first image document), sized for `pointSize` @ screen scale.
    static func image(for event: EventItem, pointSize: CGFloat = 36) -> UIImage? {
        let maxPixels = pixelSize(for: pointSize)
        let key = cacheKey(
            id: event.id.uuidString,
            fingerprint: fingerprint(for: event),
            maxPixels: maxPixels
        )
        if let cached = cache.object(forKey: key) { return cached }
        
        guard let data = sourceData(for: event),
              let image = downsample(data: data, maxPixelSize: maxPixels) else {
            return nil
        }
        cache.setObject(image, forKey: key, cost: cost(for: image))
        return image
    }
    
    /// Pin image from raw image data (e.g. trip cover on the profile globe).
    static func image(data: Data?, id: String, pointSize: CGFloat = 36) -> UIImage? {
        guard let data, !data.isEmpty else { return nil }
        let maxPixels = pixelSize(for: pointSize)
        let key = cacheKey(id: id, fingerprint: data.count, maxPixels: maxPixels)
        if let cached = cache.object(forKey: key) { return cached }
        
        guard let image = downsample(data: data, maxPixelSize: maxPixels) else { return nil }
        cache.setObject(image, forKey: key, cost: cost(for: image))
        return image
    }
    
    // MARK: - Source data (no full UIImage decode)
    
    private static func sourceData(for event: EventItem) -> Data? {
        if let photo = event.photoData, !photo.isEmpty {
            return photo
        }
        
        for document in event.documents {
            if let thumb = document.thumbnailData, !thumb.isEmpty {
                return thumb
            }
            
            let ext = document.fileExtension.lowercased()
            let isImageExt = ["jpg", "jpeg", "png", "heic", "heif", "webp", "gif"].contains(ext)
            let mimeLooksImage = document.mimeType?.hasPrefix("image/") == true
            guard isImageExt || mimeLooksImage || document.source == .photoLibrary else {
                continue
            }
            
            let url = ActivityDocumentStore.fileURL(for: document.localRelativePath)
            if let data = try? Data(contentsOf: url), !data.isEmpty {
                return data
            }
        }
        
        return nil
    }
    
    // MARK: - Downsample
    
    private static func downsample(data: Data, maxPixelSize: Int) -> UIImage? {
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            return nil
        }
        
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
    
    private static func pixelSize(for pointSize: CGFloat) -> Int {
        Int(ceil(max(pointSize, 1) * UIScreen.main.scale))
    }
    
    private static func cacheKey(id: String, fingerprint: Int, maxPixels: Int) -> NSString {
        "\(id)-\(fingerprint)-\(maxPixels)" as NSString
    }
    
    private static func fingerprint(for event: EventItem) -> Int {
        var value = event.photoData?.count ?? 0
        value = value &+ (event.documents.count * 31)
        for document in event.documents {
            value = value &+ (document.thumbnailData?.count ?? 0)
            value = value &+ document.localRelativePath.hashValue
        }
        return value
    }
    
    private static func cost(for image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 32 * 32 * 4 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
