import SwiftUI
import MapKit

private enum TripStatus: Equatable {
    case upcoming(daysUntilStart: Int)
    case inProgress
    case ended
}

/// Shared cover metrics so trip / explore / activity photos share one fixed frame.
enum TripVisualMetrics {
    /// Figma home covers are 370×271.
    static let coverAspectRatio: CGFloat = 370.0 / 271.0
    static let coverRadius: CGFloat = 20
    static let mapInsetSize: CGFloat = 80
    static let mapInsetRadius: CGFloat = 15
    static let overlayInset: CGFloat = 16
    static let imageToTextGap: CGFloat = 8
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
    let trip: Trip
    
    private static let animationStart = Date()
    
    private let mapInsetSize: CGFloat = TripVisualMetrics.mapInsetSize
    
    private var hasCoverImage: Bool {
        TripMapSupport.hasCoverImage(trip)
    }
    
    private var mapRegion: MKCoordinateRegion {
        TripMapSupport.mapRegion(for: trip)
            ?? MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 80, longitudeDelta: 80)
            )
    }
    
    private var showsMapInset: Bool {
        hasCoverImage && TripMapSupport.mapRegion(for: trip) != nil
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
        RoundedRectangle(cornerRadius: TripVisualMetrics.coverRadius, style: .continuous)
    }
    
    private var mapInsetShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: TripVisualMetrics.mapInsetRadius, style: .continuous)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: TripVisualMetrics.imageToTextGap) {
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
                            CoverOverlayBadge(
                                text: countdownText,
                                style: isUrgent ? .accent : .muted
                            )
                        }
                        .padding(TripVisualMetrics.overlayInset)
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }
                
                if showsMapInset {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            MapSnapshotView(region: mapRegion, snapshotSize: CGSize(width: 160, height: 160))
                                .frame(width: mapInsetSize, height: mapInsetSize)
                                .clipShape(mapInsetShape)
                                .overlay {
                                    mapInsetShape
                                        .strokeBorder(AppColor.textStrong, lineWidth: 2)
                                }
                                .padding(TripVisualMetrics.overlayInset)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .clipShape(imageShape)
    }
    
    private var details: some View {
        VStack(alignment: .leading, spacing: AppSpacing.stackMicro) {
            Text(trip.name)
                .font(.app(17, weight: .semibold))
                .foregroundStyle(AppColor.textStrong)
                .lineLimit(2)
            
            destinationMetadataLine
            
            Text(trip.isDatesSet ? trip.formattedDateRangeWithoutYear : "Unscheduled")
                .font(.app(13, weight: .medium))
                .foregroundStyle(AppColor.textWeak)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
    }
    
    private var destinationMetadataLine: some View {
        let destination = trip.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return HStack(spacing: 0) {
            if !destination.isEmpty {
                Text(destination)
            }
            if !destination.isEmpty, coverAttributionName != nil {
                Text(" ⋅ ")
            }
            if let coverAttributionName {
                Text("Photo by \(coverAttributionName)")
            }
        }
        .font(.app(13, weight: .medium))
        .foregroundStyle(AppColor.textWeak)
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

/// Capsule label over cover images (countdown, staff pick).
struct CoverOverlayBadge: View {
    enum Style {
        case accent
        case muted
    }
    
    var lucide: String? = nil
    let text: String
    var style: Style = .muted
    
    var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            if let lucide {
                AppIcon(lucide: lucide, size: 16, color: AppColor.textStrong)
            }
            Text(text)
                .font(.app(13, weight: .medium))
                .foregroundStyle(AppColor.textStrong)
                .lineLimit(1)
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, AppSpacing.xxs)
        .background(fill, in: Capsule(style: .continuous))
    }
    
    private var fill: Color {
        switch style {
        case .accent:
            return AppColor.accent
        case .muted:
            return AppColor.page.opacity(0.75)
        }
    }
}

struct MapSnapshotView: View {
    let region: MKCoordinateRegion
    var snapshotSize: CGSize = CGSize(width: 400, height: 300)
    
    @AppStorage(AppMapStylePreference.storageKey) private var mapStylePreferenceRaw: String = AppMapStylePreference.standard.rawValue
    @State private var snapshot: UIImage?
    @State private var inFlightSnapshotter: MKMapSnapshotter?
    
    private var preferredStyle: AppMapStylePreference {
        AppMapStylePreference.resolved(fromRaw: mapStylePreferenceRaw)
    }
    
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
        .onChange(of: mapStylePreferenceRaw) { _, _ in
            snapshot = nil
            generateSnapshot()
        }
        .onDisappear {
            inFlightSnapshotter?.cancel()
            inFlightSnapshotter = nil
        }
    }
    
    private func generateSnapshot() {
        inFlightSnapshotter?.cancel()
        
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = snapshotSize
        options.preferredConfiguration = preferredStyle.snapshotConfiguration
        
        let snapshotter = MKMapSnapshotter(options: options)
        inFlightSnapshotter = snapshotter
        snapshotter.start { snapshot, _ in
            Task { @MainActor in
                guard snapshotter === self.inFlightSnapshotter else { return }
                self.inFlightSnapshotter = nil
                if let snapshot {
                    self.snapshot = snapshot.image
                }
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
    .background(AppDetailSurface.page)
}
