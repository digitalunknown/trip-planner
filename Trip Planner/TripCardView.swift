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
    
    // Shared start time for synced animations across all cards
    private static let animationStart = Date()
    
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
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.startOfDay(for: trip.startDate)
        let end = cal.startOfDay(for: trip.endDate)
        
        if today < start { return .upcoming(daysUntilStart: cal.dateComponents([.day], from: today, to: start).day ?? 0) }
        if today > end { return .ended }
        return .inProgress
    }
    
    private var isUrgent: Bool {
        if case let .upcoming(daysUntilStart) = tripStatus {
            return daysUntilStart >= 0 && daysUntilStart < 5
        }
        return false
    }
    
    private var countdownText: String {
        switch tripStatus {
        case .upcoming(let daysUntilStart):
            if daysUntilStart == 0 { return "Today!" }
            if daysUntilStart == 1 { return "Tomorrow" }
            return "\(max(daysUntilStart, 0)) days away"
        case .inProgress:
            return "In progress"
        case .ended:
            return "Ended"
        }
    }
    
    var body: some View {
        ZStack {
            // Background - Image or Map
            if let imageData = trip.coverImageData, let uiImage = UIImage(data: imageData) {
                TimelineView(.animation) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(Self.animationStart)
                    // Create a smooth oscillation: scale from 1.0 to 1.15 over 12 seconds, then back
                    let phase = elapsed.truncatingRemainder(dividingBy: 24) // Full cycle is 24 seconds
                    let normalizedPhase = phase < 12 ? phase / 12 : (24 - phase) / 12
                    let scale = 1.0 + (0.15 * normalizedPhase)
                    
                    GeometryReader { geo in
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(scale)
                            .frame(width: geo.size.width, height: 280)
                            .clipped()
                    }
                    .frame(height: 280)
                }
            } else {
                // Always show map (uses coordinates if available, otherwise world view)
                MapSnapshotView(region: mapRegion)
                    .frame(height: 280)
                    .clipped()
            }
            
            // Gradient overlay for text readability
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 140)
            }
            
            // Countdown badge - top right
            VStack {
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
                Spacer()
            }
            
            // Content overlay - bottom
            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                
                // Trip name
                Text(trip.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                
                // Destination
                Text(trip.destination)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                
                // Date range
                Text(trip.formattedDateRange)
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
}

// Map Snapshot View for static map image
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

