import SwiftUI
import MapKit

private enum TripStatus: Equatable {
    case upcoming(daysUntilStart: Int)
    case inProgress
    case ended
}

/// Shared cover metrics so trip / explore / activity photos share one fixed frame.
enum TripVisualMetrics {
    /// Width ÷ height for cover images (landscape 4×5 → 5:4).
    static let coverAspectRatio: CGFloat = 5.0 / 4.0
}

/// Fixed-size cover slot. Content is fitted/cropped to the aspect frame and cannot change card height.
struct FixedAspectCover<Content: View>: View {
    var aspectRatio: CGFloat = TripVisualMetrics.coverAspectRatio
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        Color.clear
            .aspectRatio(aspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                content()
            }
            .clipped()
            .contentShape(Rectangle())
    }
}

/// Fills a parent frame with an image (crop as needed). Safe for animated scale effects.
struct FillCroppedImage: View {
    let image: UIImage
    var scale: CGFloat = 1
    
    var body: some View {
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .scaleEffect(scale)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .allowsHitTesting(false)
    }
}

struct TripCardView: View {
    @Environment(\.appAccentColor) private var accentColor
    
    let trip: Trip
    
    private static let animationStart = Date()
    
    private let mapInsetSize: CGFloat = 88
    
    private var hasCoverImage: Bool {
        trip.coverImageData.flatMap(UIImage.init(data:)) != nil
    }
    
    private var mapRegion: MKCoordinateRegion {
        if let lat = trip.latitude, let lon = trip.longitude {
            let span = trip.mapSpan ?? 0.1
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            )
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
        )
    }
    
    private var tripStatus: TripStatus {
        guard trip.isDatesSet else { return .upcoming(daysUntilStart: 0) }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.startOfDay(for: trip.startDate)
        let end = cal.startOfDay(for: trip.endDate)
        
        if today < start { return .upcoming(daysUntilStart: cal.dateComponents([.day], from: today, to: start).day ?? 0) }
        if today > end { return .ended }
        return .inProgress
    }
    
    private var isUrgent: Bool {
        guard trip.isDatesSet else { return false }
        if case let .upcoming(daysUntilStart) = tripStatus {
            return daysUntilStart >= 0 && daysUntilStart < 5
        }
        return false
    }
    
    private var coverAttributionName: String? {
        TripCoverAttribution.name(for: trip.id)
    }
    
    private var countdownText: String {
        guard trip.isDatesSet else { return "Unscheduled" }
        switch tripStatus {
        case .upcoming(let daysUntilStart):
            if daysUntilStart == 0 { return "Today!" }
            if daysUntilStart == 1 { return "Tomorrow" }
            return "In \(max(daysUntilStart, 0)) days"
        case .inProgress:
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            let start = cal.startOfDay(for: trip.startDate)
            let dayIndex = (cal.dateComponents([.day], from: start, to: today).day ?? 0) + 1
            let total = max(1, trip.tripDuration)
            let clampedDay = min(max(dayIndex, 1), total)
            return "Now: Day \(clampedDay) of \(total)"
        case .ended:
            return "Ended"
        }
    }
    
    private var imageShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
    }
    
    private var mapInsetShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            visual
            details
        }
        .contentShape(Rectangle())
    }
    
    private var visual: some View {
        FixedAspectCover {
            ZStack {
                coverOrMapBackground
                
                if trip.isDatesSet {
                    VStack {
                        HStack {
                            Spacer()
                            Text(countdownText)
                                .font(.appCaption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .modifier(TripCountdownGlassBackground(isUrgent: isUrgent, accentColor: accentColor))
                        }
                        .padding(12)
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }
                
                if hasCoverImage, trip.latitude != nil, trip.longitude != nil {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            MapSnapshotView(region: mapRegion, snapshotSize: CGSize(width: 160, height: 160))
                                .frame(width: mapInsetSize, height: mapInsetSize)
                                .clipShape(mapInsetShape)
                                .overlay {
                                    mapInsetShape
                                        .strokeBorder(Color.white.opacity(0.92), lineWidth: 2)
                                }
                                .shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 4)
                                .padding(12)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .clipShape(imageShape)
        .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
    }
    
    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(trip.name)
                .font(.appHeadline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .lineLimit(2)
            
            metadataLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
    }
    
    private var metadataLine: some View {
        let destination = trip.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let dateText = trip.isDatesSet ? trip.formattedDateRange : "Unscheduled"
        
        return HStack(spacing: 0) {
            if !destination.isEmpty {
                Text(destination)
                Text("  ·  ")
            }
            Text(dateText)
            if let coverAttributionName {
                Text("  ·  ")
                Image(systemName: "camera.fill")
                Text(" \(coverAttributionName)")
            }
        }
        .font(.appCaption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    
    @ViewBuilder
    private var coverOrMapBackground: some View {
        if let imageData = trip.coverImageData, let uiImage = UIImage(data: imageData) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                let elapsed = timeline.date.timeIntervalSince(Self.animationStart)
                let phase = elapsed.truncatingRemainder(dividingBy: 24)
                let normalizedPhase = phase < 12 ? phase / 12 : (24 - phase) / 12
                let scale = 1.0 + (0.15 * normalizedPhase)
                
                FillCroppedImage(image: uiImage, scale: scale)
            }
            .allowsHitTesting(false)
        } else {
            MapSnapshotView(region: mapRegion)
                .allowsHitTesting(false)
        }
    }
}

private struct TripCountdownGlassBackground: ViewModifier {
    let isUrgent: Bool
    let accentColor: Color
    
    func body(content: Content) -> some View {
        content
            .background {
                Capsule(style: .continuous)
                    .fill(isUrgent ? accentColor.opacity(0.92) : Color.black.opacity(0.55))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            }
    }
}

struct MapSnapshotView: View {
    let region: MKCoordinateRegion
    var snapshotSize: CGSize = CGSize(width: 400, height: 300)
    
    @State private var snapshot: UIImage?
    
    var body: some View {
        GeometryReader { geo in
            Group {
                if let snapshot = snapshot {
                    Image(uiImage: snapshot)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay {
                            ProgressView()
                        }
                }
            }
        }
        .onAppear {
            generateSnapshot()
        }
    }
    
    private func generateSnapshot() {
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = snapshotSize
        options.mapType = .standard
        
        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { snapshot, error in
            if let snapshot = snapshot {
                self.snapshot = snapshot.image
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(Trip.sampleTrips) { trip in
                TripCardView(trip: trip)
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
