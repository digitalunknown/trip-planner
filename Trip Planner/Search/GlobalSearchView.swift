import SwiftUI
import UIKit

struct GlobalSearchView: View {
    @Binding var searchText: String
    
    @Environment(TripStore.self) private var tripStore
    @Environment(PlaceStore.self) private var placeStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appAccentColor) private var appAccentColor
    
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var textSecondary: Color { textPrimary.opacity(colorScheme == .dark ? 0.72 : 0.62) }
    private var rowBackground: Color { colorScheme == .dark ? Color(hex: 0x171717) : Color(hex: 0xF0F0F0) }
    
    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var matchedTrips: [Trip] {
        let q = query.lowercased()
        guard !q.isEmpty else { return [] }
        return tripStore.trips.filter { trip in
            trip.name.lowercased().contains(q)
                || trip.destination.lowercased().contains(q)
                || trip.days.contains { day in
                    day.events.contains { event in
                        event.title.lowercased().contains(q)
                            || event.location.lowercased().contains(q)
                    }
                }
                || trip.parkedIdeas.contains { event in
                    event.title.lowercased().contains(q)
                        || event.location.lowercased().contains(q)
                }
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var matchedPlaces: [Place] {
        let q = query.lowercased()
        guard !q.isEmpty else { return [] }
        return placeStore.places.filter { place in
            let title = PlaceNaming.title(location: place.location, fallback: place.name)
            return title.lowercased().contains(q)
                || place.name.lowercased().contains(q)
                || place.location.lowercased().contains(q)
                || place.note.lowercased().contains(q)
                || (place.placeType != .unspecified && place.placeType.title.lowercased().contains(q))
        }
        .sorted {
            PlaceNaming.title(location: $0.location, fallback: $0.name)
                .localizedCaseInsensitiveCompare(PlaceNaming.title(location: $1.location, fallback: $1.name))
                == .orderedAscending
        }
    }
    
    var body: some View {
        Group {
            if query.isEmpty {
                SearchGlobeIllustration()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if matchedTrips.isEmpty && matchedPlaces.isEmpty {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !matchedTrips.isEmpty {
                        Section {
                            ForEach(matchedTrips) { trip in
                                NavigationLink(value: SearchDestination.trip(trip.id)) {
                                    tripRow(trip)
                                }
                            }
                        }
                    }
                    
                    if !matchedPlaces.isEmpty {
                        Section {
                            ForEach(matchedPlaces) { place in
                                NavigationLink(value: SearchDestination.place(place.id)) {
                                    placeRow(place)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            query.isEmpty || (matchedTrips.isEmpty && matchedPlaces.isEmpty)
                ? Color(.systemBackground)
                : Color(.systemGroupedBackground)
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: SearchDestination.self) { destination in
            switch destination {
            case .trip(let tripID):
                if let index = tripStore.trips.firstIndex(where: { $0.id == tripID }) {
                    TripDetailView(trip: Binding(
                        get: { tripStore.trips[index] },
                        set: { newValue in
                            tripStore.trips[index] = newValue
                            tripStore.save()
                        }
                    ))
                } else {
                    Color.clear
                }
            case .place(let placeID):
                PlaceDetailView(placeID: placeID)
            }
        }
    }
    
    private func tripRow(_ trip: Trip) -> some View {
        HStack(spacing: 12) {
            tripThumbnail(trip)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.name)
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(2)
                
                if !trip.destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(trip.destination)
                        .font(.appCaption)
                        .foregroundStyle(textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
    
    private func placeRow(_ place: Place) -> some View {
        let title = PlaceNaming.title(location: place.location, fallback: place.name)
        let subtitle = PlaceNaming.subtitle(location: place.location, title: title)
        
        return HStack(spacing: 12) {
            placeThumbnail(place)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(2)
                
                if let subtitle {
                    Text(subtitle)
                        .font(.appCaption)
                        .foregroundStyle(textSecondary)
                        .lineLimit(1)
                }
                
                if place.placeType != .unspecified {
                    HStack(spacing: 4) {
                        Image(systemName: place.placeType.iconSystemName)
                        Text(place.placeType.title)
                    }
                    .font(.app(11, weight: .semibold))
                    .foregroundStyle(textSecondary)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func tripThumbnail(_ trip: Trip) -> some View {
        if let data = trip.coverImageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(appAccentColor.opacity(0.18))
                Image(systemName: "suitcase.fill")
                    .foregroundStyle(appAccentColor)
                    .font(.app(18, weight: .semibold))
            }
            .frame(width: 52, height: 52)
        }
    }
    
    @ViewBuilder
    private func placeThumbnail(_ place: Place) -> some View {
        if let data = place.photoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(rowBackground)
                Image(systemName: place.placeType == .unspecified ? "mappin.and.ellipse" : place.placeType.iconSystemName)
                    .foregroundStyle(textSecondary)
                    .font(.app(18, weight: .semibold))
            }
            .frame(width: 52, height: 52)
        }
    }
}

enum SearchDestination: Hashable {
    case trip(UUID)
    case place(UUID)
}
