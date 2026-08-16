import Combine
import MapKit
import SwiftUI
import UIKit

struct TravelGlobeCard: View {
    let trips: [Trip]
    var onSelectTrip: ((Trip) -> Void)? = nil
    /// Preview cards disable pan so the parent ScrollView stays usable.
    var allowsFullInteraction: Bool = false
    var showsEmptyCopy: Bool = true
    /// When true, frames the whole Earth (good for square preview cards).
    var showsFullGlobe: Bool = false
    /// Soft top scrim for preview cards; full-screen map usually turns this off under chrome.
    var showsTopFade: Bool = true
    
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var position: MapCameraPosition = TravelGlobeCard.makeCamera(heading: -35, fullGlobe: false)
    @State private var heading: Double = -35
    @State private var selectedPinID: UUID?
    @State private var isAutoRotating: Bool = true
    @State private var isProgrammaticCameraUpdate: Bool = false
    @State private var resumeAutoRotateTask: Task<Void, Never>?
    
    private var pins: [TravelDestinationPin] {
        TravelDestinationPin.make(from: trips)
    }
    
    private var mapInteractionModes: MapInteractionModes {
        allowsFullInteraction ? [.pan, .zoom, .rotate, .pitch] : [.zoom, .rotate]
    }
    
    /// Northern-hemisphere framing for interactive / taller previews.
    private static let focusedCenter = CLLocationCoordinate2D(latitude: 48, longitude: -95)
    private static let focusedDistance: CLLocationDistance = 14_500_000
    /// Pull back so the full Earth fits in a square crop.
    private static let fullGlobeCenter = CLLocationCoordinate2D(latitude: 10, longitude: -20)
    private static let fullGlobeDistance: CLLocationDistance = 32_000_000
    private static let rotationDegreesPerTick: Double = 0.08
    
    private static func makeCamera(heading: Double, fullGlobe: Bool) -> MapCameraPosition {
        .camera(
            MapCamera(
                centerCoordinate: fullGlobe ? fullGlobeCenter : focusedCenter,
                distance: fullGlobe ? fullGlobeDistance : focusedDistance,
                heading: heading,
                pitch: 0
            )
        )
    }
    
    var body: some View {
        GeometryReader { geo in
            let height = max(geo.size.height, 1)
            
            ZStack {
                if pins.isEmpty {
                    emptyState
                } else {
                    Map(position: $position, interactionModes: mapInteractionModes) {
                        ForEach(pins) { pin in
                            Annotation(pin.title, coordinate: pin.coordinate, anchor: .center) {
                                Button {
                                    pauseAutoRotateTemporarily()
                                    selectedPinID = pin.id
                                    if let trip = pin.representativeTrip {
                                        onSelectTrip?(trip)
                                    }
                                } label: {
                                    DestinationPinView(
                                        coverImageData: pin.coverImageData,
                                        count: pin.count,
                                        isSelected: selectedPinID == pin.id
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .mapStyle(.imagery(elevation: .realistic))
                    .onMapCameraChange(frequency: .continuous) { _ in
                        guard !isProgrammaticCameraUpdate else { return }
                        pauseAutoRotateTemporarily()
                    }
                }
                
                if showsTopFade {
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [
                                Color.black.opacity(colorScheme == .dark ? 0.28 : 0.16),
                                Color.black.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: min(100, height * 0.22))
                        
                        Spacer(minLength: 0)
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
            applyCamera(heading: heading)
        }
        .onChange(of: showsFullGlobe) { _, _ in
            applyCamera(heading: heading)
        }
        .onReceive(Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()) { _ in
            guard isAutoRotating, !pins.isEmpty else { return }
            heading = (heading + Self.rotationDegreesPerTick).truncatingRemainder(dividingBy: 360)
            if heading < 0 { heading += 360 }
            applyCamera(heading: heading)
        }
        .onDisappear {
            resumeAutoRotateTask?.cancel()
            isAutoRotating = false
        }
    }
    
    private var emptyState: some View {
        ZStack {
            Map(initialPosition: Self.makeCamera(heading: -35, fullGlobe: showsFullGlobe), interactionModes: [])
                .mapStyle(.imagery(elevation: .realistic))
                .allowsHitTesting(false)
                .saturation(0.9)
            
            LinearGradient(
                colors: [
                    Color.black.opacity(0.05),
                    Color.black.opacity(0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            if showsEmptyCopy {
                VStack(spacing: 8) {
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    Text("Complete trips with a destination\nto plot them here.")
                        .font(.appSubheadline)
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                }
                .padding(.bottom, 24)
            }
        }
    }
    
    private func applyCamera(heading: Double) {
        isProgrammaticCameraUpdate = true
        position = Self.makeCamera(heading: heading, fullGlobe: showsFullGlobe)
        DispatchQueue.main.async {
            isProgrammaticCameraUpdate = false
        }
    }
    
    private func pauseAutoRotateTemporarily() {
        isAutoRotating = false
        resumeAutoRotateTask?.cancel()
        resumeAutoRotateTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            isAutoRotating = true
        }
    }
}

// MARK: - Pin model

struct TravelDestinationPin: Identifiable, Hashable {
    let id: UUID
    let title: String
    let coordinate: CLLocationCoordinate2D
    let coverImageData: Data?
    let trips: [Trip]
    
    var count: Int { trips.count }
    var representativeTrip: Trip? { trips.sorted { $0.endDate > $1.endDate }.first }
    
    static func make(from trips: [Trip]) -> [TravelDestinationPin] {
        let mappable = trips.filter { trip in
            guard let lat = trip.latitude, let lon = trip.longitude else { return false }
            return abs(lat) <= 90 && abs(lon) <= 180
        }
        
        let grouped = Dictionary(grouping: mappable) { trip -> String in
            let destinationKey = trip.destination
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if !destinationKey.isEmpty {
                return "dest:\(destinationKey)"
            }
            let lat = trip.latitude ?? 0
            let lon = trip.longitude ?? 0
            return String(format: "coord:%.1f,%.1f", lat, lon)
        }
        
        return grouped.compactMap { _, group in
            guard let first = group.first,
                  first.latitude != nil,
                  first.longitude != nil else { return nil }
            
            let avgLat = group.compactMap(\.latitude).reduce(0, +) / Double(group.count)
            let avgLon = group.compactMap(\.longitude).reduce(0, +) / Double(group.count)
            
            let title = first.destination.trimmingCharacters(in: .whitespacesAndNewlines)
            let cover = group
                .sorted { $0.endDate > $1.endDate }
                .compactMap(\.coverImageData)
                .first
            
            return TravelDestinationPin(
                id: first.id,
                title: title.isEmpty ? "Trip" : title,
                coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                coverImageData: cover,
                trips: group
            )
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
    
    static func == (lhs: TravelDestinationPin, rhs: TravelDestinationPin) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Pin view

private struct DestinationPinView: View {
    let coverImageData: Data?
    let count: Int
    var isSelected: Bool = false
    
    private let size: CGFloat = 36
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            SquareMapPinView(
                size: size,
                image: coverImageData.flatMap(UIImage.init(data:)),
                fallbackColor: Color(hex: 0x4DA1F7),
                fallbackSystemImage: "suitcase.fill",
                isSelected: isSelected
            )
            
            if count > 1 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.82), in: Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(.white.opacity(0.95), lineWidth: 1)
                    }
                    .offset(x: 6, y: -6)
            }
        }
    }
}
