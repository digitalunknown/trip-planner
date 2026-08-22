import Foundation
import UIKit

enum PlaceNaming {
    /// Prefer an explicit place name; otherwise derive from location.
    static func displayTitle(name: String, location: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return title(location: location, fallback: "Place")
    }
    
    /// Prefer MapKit / address-derived title (first comma segment) over activity titles.
    static func title(location: String, fallback: String = "Place") -> String {
        let loc = location.trimmingCharacters(in: .whitespacesAndNewlines)
        if loc.isEmpty {
            let fb = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
            return fb.isEmpty ? "Place" : fb
        }
        if let comma = loc.firstIndex(of: ",") {
            let head = String(loc[..<comma]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !head.isEmpty { return head }
        }
        return loc
    }
    
    /// Remaining address after the title, if any — avoids duplicating the title line.
    static func subtitle(location: String, title: String) -> String? {
        let loc = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !loc.isEmpty else { return nil }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if loc.compare(trimmedTitle, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
            return nil
        }
        
        if loc.lowercased().hasPrefix(trimmedTitle.lowercased()) {
            var rest = String(loc.dropFirst(trimmedTitle.count))
            while rest.hasPrefix(",") || rest.hasPrefix(" ") {
                rest = String(rest.dropFirst())
            }
            let cleaned = rest.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned
        }
        
        return loc
    }
    
    static func normalizedLocationKey(_ location: String) -> String {
        location
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}

enum PlaceImageResolver {
    /// Prefer activity photo, then first image document (thumbnail or file).
    static func imageData(from event: EventItem) -> Data? {
        if let photo = event.photoData, UIImage(data: photo) != nil {
            return photo
        }
        
        for document in event.documents {
            if let thumb = document.thumbnailData, UIImage(data: thumb) != nil {
                return compressedJPEG(from: thumb) ?? thumb
            }
            
            let ext = document.fileExtension.lowercased()
            let isImageExt = ["jpg", "jpeg", "png", "heic", "heif", "webp", "gif"].contains(ext)
            let mimeLooksImage = document.mimeType?.hasPrefix("image/") == true
            guard isImageExt || mimeLooksImage || document.source == .photoLibrary else {
                continue
            }
            
            let url = ActivityDocumentStore.fileURL(for: document.localRelativePath)
            guard let data = try? Data(contentsOf: url), UIImage(data: data) != nil else { continue }
            return compressedJPEG(from: data) ?? data
        }
        
        return nil
    }
    
    /// Downscale cover photos before persisting on activities (avoids OOM on big trips).
    static func compressedCoverData(_ data: Data?, maxPixelSize: CGFloat = 480) -> Data? {
        guard let data, !data.isEmpty else { return nil }
        guard let image = UIImage(data: data) else { return data }
        let maxSide = max(image.size.width, image.size.height)
        guard maxSide > maxPixelSize else {
            return image.jpegData(compressionQuality: 0.72) ?? data
        }
        let scale = maxPixelSize / maxSide
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return scaled.jpegData(compressionQuality: 0.72) ?? data
    }
    
    private static func compressedJPEG(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return image.jpegData(compressionQuality: 0.8)
    }
}

enum PlaceTripMembership {
    /// Trips that contain a matching activity for this place (or the place’s source trip).
    static func trips(for place: Place, in trips: [Trip]) -> [Trip] {
        let key = PlaceNaming.normalizedLocationKey(place.location)
        var matched: [Trip] = []
        
        for trip in trips {
            let events = trip.days.flatMap(\.events) + trip.parkedIdeas
            let matches = events.contains { event in
                if let sourceEventID = place.sourceEventID, event.id == sourceEventID {
                    return true
                }
                let eventKey = PlaceNaming.normalizedLocationKey(event.location)
                if !key.isEmpty, !eventKey.isEmpty, key == eventKey {
                    return true
                }
                if let plat = place.latitude, let plon = place.longitude,
                   let elat = event.latitude, let elon = event.longitude {
                    return abs(plat - elat) < 0.002 && abs(plon - elon) < 0.002
                }
                return false
            }
            if matches {
                matched.append(trip)
            }
        }
        
        if let sourceID = place.sourceTripID,
           !matched.contains(where: { $0.id == sourceID }),
           let sourceTrip = trips.first(where: { $0.id == sourceID }) {
            matched.append(sourceTrip)
        }
        
        return matched.sorted { a, b in
            if a.isDatesSet != b.isDatesSet { return a.isDatesSet && !b.isDatesSet }
            if a.isDatesSet, b.isDatesSet {
                return a.startDate > b.startDate
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
    
    /// How many trips contain a matching activity for this place.
    static func tripCount(for place: Place, in trips: [Trip]) -> Int {
        Self.trips(for: place, in: trips).count
    }
    
    static func badgeText(tripCount: Int) -> String? {
        guard tripCount > 0 else { return nil }
        return tripCount == 1 ? "in 1 trip" : "in \(tripCount) trips"
    }
}
