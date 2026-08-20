import Foundation
import MapKit
import UIKit

enum TripMapSupport {
    /// True when the trip has a cover photo we can render.
    static func hasCoverImage(_ trip: Trip) -> Bool {
        trip.coverImageData.flatMap(UIImage.init(data:)) != nil
    }
    
    /// Best-effort center for the trip-card map inset.
    static func mapRegion(for trip: Trip) -> MKCoordinateRegion? {
        if let lat = trip.latitude, let lon = trip.longitude {
            let span = trip.mapSpan ?? 0.1
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            )
        }
        
        let coords = eventCoordinates(in: trip)
        guard !coords.isEmpty else { return nil }
        
        let minLat = coords.map(\.latitude).min() ?? 0
        let maxLat = coords.map(\.latitude).max() ?? 0
        let minLon = coords.map(\.longitude).min() ?? 0
        let maxLon = coords.map(\.longitude).max() ?? 0
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let latSpread = max(maxLat - minLat, 0.02)
        let lonSpread = max(maxLon - minLon, 0.02)
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: latSpread * 1.6,
                longitudeDelta: lonSpread * 1.6
            )
        )
    }
    
    static func needsDestinationGeocode(_ trip: Trip) -> Bool {
        guard trip.latitude == nil || trip.longitude == nil else { return false }
        if !eventCoordinates(in: trip).isEmpty { return false }
        return !trip.destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !trip.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    static func eventCoordinates(in trip: Trip) -> [CLLocationCoordinate2D] {
        let fromDays = trip.days.flatMap(\.events).compactMap { event -> CLLocationCoordinate2D? in
            guard let lat = event.latitude, let lon = event.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        let fromParked = trip.parkedIdeas.compactMap { event -> CLLocationCoordinate2D? in
            guard let lat = event.latitude, let lon = event.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return fromDays + fromParked
    }
    
    static func geocodeQuery(for trip: Trip) -> String {
        let destination = trip.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        if !destination.isEmpty { return destination }
        return trip.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func geocodeDestination(_ query: String) async -> (latitude: Double, longitude: Double, mapSpan: Double)? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.address, .pointOfInterest]
        
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first,
                  let coordinate = mapItemCoordinate(item) else { return nil }
            let span = max(
                response.boundingRegion.span.latitudeDelta,
                response.boundingRegion.span.longitudeDelta,
                0.08
            )
            return (coordinate.latitude, coordinate.longitude, min(span, 0.35))
        } catch {
            return nil
        }
    }
    
    /// Fetches a single Unsplash cover for `query` when possible.
    static func fetchUnsplashCover(query: String) async -> (data: Data, photographerName: String?)? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let client = UnsplashAPIClient()
        guard let response = try? await client.searchPhotos(query: trimmed, page: 1, perPage: 1),
              let photo = response.results.first,
              let urlString = photo.urls.regular ?? photo.urls.small,
              let url = URL(string: urlString) else { return nil }
        
        if let dl = photo.download_location {
            try? await client.trackDownload(downloadLocation: dl)
        }
        
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return (data, photo.user.name)
    }
}
