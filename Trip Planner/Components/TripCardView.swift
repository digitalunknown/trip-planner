//
//  TripCardView.swift
//  Trip Planner
//
//  Created by Piotr Osmenda on 12/18/25.
//

import SwiftUI
import MapKit

private enum TripStatus: Equatable {
    case upcoming(daysUntilStart: Int)
    case inProgress
    case ended
}

struct TripCardView: View {
    @Environment(\.appAccentColor) private var accentColor
    
    let trip: Trip
    
    private static let animationStart = Date()
    
    private let cardHeight: CGFloat = 280
    private let blurHeight: CGFloat = 220
    private let blurRadius: CGFloat = 60
    
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
    
    private var countdownText: String {
        guard trip.isDatesSet else { return "Unscheduled" }
        switch tripStatus {
        case .upcoming(let daysUntilStart):
            if daysUntilStart == 0 { return "Today!" }
            if daysUntilStart == 1 { return "Tomorrow" }
            return "In \(max(daysUntilStart, 0)) days"
        case .inProgress:
            return "In progress"
        case .ended:
            return "Ended"
        }
    }
    
    var body: some View {
        ZStack {
            backgroundLayer
            
            backgroundLayer
                .blur(radius: blurRadius)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .clear, location: 0.12),
                            .init(color: .black.opacity(0.35), location: 0.38),
                            .init(color: .black.opacity(0.85), location: 0.72),
                            .init(color: .black, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: blurHeight)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                )
            
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 140)
            }
            
            VStack {
                if trip.isDatesSet {
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            if trip.daysUntilTrip == 0 {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                            }
                            Text(countdownText)
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            isUrgent ? AnyShapeStyle(accentColor) : AnyShapeStyle(.ultraThinMaterial)
                        )
                        .clipShape(Capsule())
                    }
                    .padding(12)
                }
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                
                Text(trip.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                
                Text(trip.destination)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                
                Text(trip.isDatesSet ? trip.formattedDateRange : "Unscheduled")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
    }
    
    @ViewBuilder
    private var backgroundLayer: some View {
        if let imageData = trip.coverImageData, let uiImage = UIImage(data: imageData) {
            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSince(Self.animationStart)
                let phase = elapsed.truncatingRemainder(dividingBy: 24)
                let normalizedPhase = phase < 12 ? phase / 12 : (24 - phase) / 12
                let scale = 1.0 + (0.15 * normalizedPhase)
                
                GeometryReader { geo in
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(scale)
                        .frame(width: geo.size.width, height: cardHeight)
                        .clipped()
                }
                .frame(height: cardHeight)
            }
        } else {
            MapSnapshotView(region: mapRegion)
                .frame(height: cardHeight)
                .clipped()
        }
    }
}

struct MapSnapshotView: View {
    let region: MKCoordinateRegion
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
        options.size = CGSize(width: 400, height: 300)
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

