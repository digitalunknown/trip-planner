import SwiftUI
import UIKit

struct GlobalSearchView: View {
    @Binding var searchText: String
    
    @Environment(TripStore.self) private var tripStore
    @Environment(PlaceStore.self) private var placeStore
    
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
                Text("No results")
                    .font(.app(15, weight: .medium))
                    .foregroundStyle(AppColor.textWeak)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                        if !matchedTrips.isEmpty {
                            resultSection(title: "Trips") {
                                ForEach(matchedTrips) { trip in
                                    NavigationLink(value: SearchDestination.trip(trip.id)) {
                                        TripResultRow(trip: trip)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        if !matchedPlaces.isEmpty {
                            resultSection(title: "Places") {
                                ForEach(matchedPlaces) { place in
                                    NavigationLink(value: SearchDestination.place(place.id)) {
                                        placeRow(place)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, RootHomeMetrics.horizontalInset)
                    .padding(.top, RootHomeMetrics.topInset)
                    .padding(.bottom, RootHomeMetrics.bottomInset)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppDetailSurface.page)
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
    
    private func resultSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            AppSectionHeader(title)
            VStack(spacing: AppSpacing.xs) {
                content()
            }
        }
    }
    
    private func placeRow(_ place: Place) -> some View {
        let title = PlaceNaming.title(location: place.location, fallback: place.name)
        let subtitle = PlaceNaming.subtitle(location: place.location, title: title)
        
        return HStack(spacing: AppSpacing.sm) {
            placeThumbnail(place)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.app(15, weight: .medium))
                    .foregroundStyle(AppColor.textStrong)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let subtitle {
                    Text(subtitle)
                        .font(.app(13, weight: .medium))
                        .foregroundStyle(AppColor.textWeak)
                        .lineLimit(1)
                }
                
                if place.placeType != .unspecified {
                    HStack(spacing: AppSpacing.xxs) {
                        AppIcon(systemName: place.placeType.iconSystemName, size: 16, color: AppColor.textWeak)
                        Text(place.placeType.title)
                            .font(.app(13, weight: .medium))
                            .foregroundStyle(AppColor.textWeak)
                    }
                }
            }
            
            AppIcon(lucide: "chevron-right", size: AppLucide.fieldSize, color: AppColor.textWeak)
        }
        .padding(AppSpacing.fieldPadding)
        .background(AppColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                    .fill(AppColor.elevated)
                AppIcon(
                    systemName: place.placeType.mapIconName,
                    size: 18,
                    color: AppColor.textWeak
                )
            }
            .frame(width: 52, height: 52)
        }
    }
}

enum SearchDestination: Hashable {
    case trip(UUID)
    case place(UUID)
}
