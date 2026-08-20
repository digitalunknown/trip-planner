import Foundation
import MapKit
import SwiftUI

/// A travel segment ready to draw on the trip map.
struct TravelMapOverlay: Identifiable, Hashable {
    let id: UUID
    let dayID: UUID
    let flightID: UUID
    let travelMode: TravelMode
    let fromCoordinate: CLLocationCoordinate2D
    let toCoordinate: CLLocationCoordinate2D
    /// Polyline to draw (geodesic or road route). Always includes at least from/to.
    let routeCoordinates: [CLLocationCoordinate2D]
    let isRoadRoute: Bool
    
    var usesDashedStroke: Bool {
        switch travelMode {
        case .flight, .train: return true
        case .drive, .walk: return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TravelMapOverlay, rhs: TravelMapOverlay) -> Bool {
        lhs.id == rhs.id
            && lhs.routeCoordinates.count == rhs.routeCoordinates.count
            && lhs.isRoadRoute == rhs.isRoadRoute
    }
}

enum TravelMapRouting {
    /// Builds overlays from trip days. Uses `resolvedRoadRoutes` when available for drive/walk;
    /// otherwise falls back to a straight segment until directions resolve.
    static func overlays(
        days: [TripDay],
        resolvedRoadRoutes: [UUID: [CLLocationCoordinate2D]]
    ) -> [TravelMapOverlay] {
        days.flatMap { day in
            day.flights.compactMap { flight -> TravelMapOverlay? in
                guard
                    let fromLat = flight.fromLatitude,
                    let fromLon = flight.fromLongitude,
                    let toLat = flight.toLatitude,
                    let toLon = flight.toLongitude
                else { return nil }
                
                let from = CLLocationCoordinate2D(latitude: fromLat, longitude: fromLon)
                let to = CLLocationCoordinate2D(latitude: toLat, longitude: toLon)
                guard CLLocationCoordinate2DIsValid(from), CLLocationCoordinate2DIsValid(to) else { return nil }
                
                let needsRoad = flight.travelMode == .drive || flight.travelMode == .walk
                let route: [CLLocationCoordinate2D]
                let isRoad: Bool
                if needsRoad, let resolved = resolvedRoadRoutes[flight.id], resolved.count >= 2 {
                    route = resolved
                    isRoad = true
                } else if needsRoad {
                    route = [from, to]
                    isRoad = false
                } else {
                    route = geodesicCoordinates(from: from, to: to, samples: 48)
                    isRoad = false
                }
                
                return TravelMapOverlay(
                    id: flight.id,
                    dayID: day.id,
                    flightID: flight.id,
                    travelMode: flight.travelMode,
                    fromCoordinate: from,
                    toCoordinate: to,
                    routeCoordinates: route,
                    isRoadRoute: isRoad
                )
            }
        }
    }
    
    static func coordinates(in overlays: [TravelMapOverlay]) -> [CLLocationCoordinate2D] {
        overlays.flatMap { [$0.fromCoordinate, $0.toCoordinate] + $0.routeCoordinates }
    }
    
    /// Great-circle samples between two points (flight / train arcs).
    static func geodesicCoordinates(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        samples: Int
    ) -> [CLLocationCoordinate2D] {
        let count = max(samples, 2)
        let φ1 = from.latitude * .pi / 180
        let λ1 = from.longitude * .pi / 180
        let φ2 = to.latitude * .pi / 180
        let λ2 = to.longitude * .pi / 180
        
        let sinHalfΔφ = sin((φ2 - φ1) / 2)
        let sinHalfΔλ = sin((λ2 - λ1) / 2)
        let a = sinHalfΔφ * sinHalfΔφ + cos(φ1) * cos(φ2) * sinHalfΔλ * sinHalfΔλ
        let Δ = 2 * asin(min(1, sqrt(a)))
        
        if Δ < 1e-8 {
            return [from, to]
        }
        
        var coords: [CLLocationCoordinate2D] = []
        coords.reserveCapacity(count + 1)
        let sinΔ = sin(Δ)
        
        for i in 0...count {
            let f = Double(i) / Double(count)
            let A = sin((1 - f) * Δ) / sinΔ
            let B = sin(f * Δ) / sinΔ
            let x = A * cos(φ1) * cos(λ1) + B * cos(φ2) * cos(λ2)
            let y = A * cos(φ1) * sin(λ1) + B * cos(φ2) * sin(λ2)
            let z = A * sin(φ1) + B * sin(φ2)
            let φ = atan2(z, sqrt(x * x + y * y))
            let λ = atan2(y, x)
            coords.append(
                CLLocationCoordinate2D(
                    latitude: φ * 180 / .pi,
                    longitude: λ * 180 / .pi
                )
            )
        }
        return coords
    }
    
    static func fetchRoadRoute(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        mode: TravelMode
    ) async -> [CLLocationCoordinate2D]? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        switch mode {
        case .walk:
            request.transportType = .walking
        case .drive:
            request.transportType = .automobile
        default:
            return nil
        }
        request.requestsAlternateRoutes = false
        
        do {
            let response = try await MKDirections(request: request).calculate()
            guard let polyline = response.routes.first?.polyline else { return nil }
            return polyline.tripstacks_coordinates()
        } catch {
            return nil
        }
    }
}

private extension MKPolyline {
    func tripstacks_coordinates() -> [CLLocationCoordinate2D] {
        var coords = Array(
            repeating: kCLLocationCoordinate2DInvalid,
            count: pointCount
        )
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords.filter { CLLocationCoordinate2DIsValid($0) }
    }
}

/// Shared stroke treatment so flight (dashed) and land (solid) routes match:
/// white center line with a black outline. Only dash pattern / weight differs.
enum TravelMapStrokeStyle {
    /// Solid road/walk routes — readable at street scale.
    static let outlineWidth: CGFloat = 3.5
    static let fillWidth: CGFloat = 2
    /// Great-circle / dashed routes span huge distances; keep them finer.
    static let dashedOutlineWidth: CGFloat = 2
    static let dashedFillWidth: CGFloat = 1.15
    static let dashPattern: [CGFloat] = [4, 4]
    static let outlineColor = Color.black
    static let fillColor = Color.white
    
    static func outline(dashed: Bool) -> StrokeStyle {
        StrokeStyle(
            lineWidth: dashed ? dashedOutlineWidth : outlineWidth,
            lineCap: .round,
            lineJoin: .round,
            dash: dashed ? dashPattern : [],
            dashPhase: 0
        )
    }
    
    static func fill(dashed: Bool) -> StrokeStyle {
        StrokeStyle(
            lineWidth: dashed ? dashedFillWidth : fillWidth,
            lineCap: .round,
            lineJoin: .round,
            dash: dashed ? dashPattern : [],
            dashPhase: 0
        )
    }
}
