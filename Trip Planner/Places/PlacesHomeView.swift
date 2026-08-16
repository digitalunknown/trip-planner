import SwiftUI
import PhotosUI
import UIKit

struct PlacesHomeView: View {
    @Environment(PlaceStore.self) private var placeStore
    @Environment(TripStore.self) private var tripStore
    
    @State private var showAddPlace = false
    @State private var showAIFindPlaces = false
    @State private var selectedPlaceID: UUID?
    @State private var selectedPlaceType: PlaceType?
    @State private var placeToEdit: Place?
    @State private var placeForImageUpdate: Place?
    @State private var showUnsplashPicker = false
    @State private var photosPickerPresented = false
    @State private var photoItem: PhotosPickerItem?
    @State private var placePendingDelete: Place?
    
    private var allPlaces: [Place] {
        placeStore.placesNewestFirst
    }
    
    /// Types that currently appear in the library, in canonical enum order.
    private var activePlaceTypes: [PlaceType] {
        let present = Set(allPlaces.map(\.placeType).filter { $0 != .unspecified })
        return PlaceType.allCases.filter { present.contains($0) }
    }
    
    private var places: [Place] {
        guard let selectedPlaceType else { return allPlaces }
        return allPlaces.filter { $0.placeType == selectedPlaceType }
    }
    
    private var tripsForAddMenu: [Trip] {
        tripStore.trips.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
    
    private var unsplashQuery: String {
        guard let place = placeForImageUpdate else { return "" }
        let loc = place.location.trimmingCharacters(in: .whitespacesAndNewlines)
        if !loc.isEmpty { return loc }
        return PlaceNaming.title(location: place.location, fallback: place.name)
    }
    
    private var masonryColumns: (left: [Place], right: [Place]) {
        var left: [Place] = []
        var right: [Place] = []
        var leftHeight: CGFloat = 0
        var rightHeight: CGFloat = 0
        
        // Match `.padding(16)` + `HStack` spacing `12` in the grid below.
        let columnWidth = max((UIScreen.main.bounds.width - 32 - 12) / 2, 140)
        
        for place in places {
            let estimate = PlaceCardMetrics.estimatedHeight(for: place, columnWidth: columnWidth)
            if leftHeight <= rightHeight {
                left.append(place)
                leftHeight += estimate + 12
            } else {
                right.append(place)
                rightHeight += estimate + 12
            }
        }
        return (left, right)
    }
    
    var body: some View {
        Group {
            if placeStore.isLoading && placeStore.places.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if allPlaces.isEmpty {
                emptyState
            } else if places.isEmpty {
                VStack(spacing: 0) {
                    if !activePlaceTypes.isEmpty {
                        filterChipsRow
                            .padding(.top, RootHomeMetrics.topInset)
                            .padding(.bottom, RootHomeMetrics.chromeToContent)
                    }
                    ContentUnavailableView(
                        "No places",
                        systemImage: "mappin.slash",
                        description: Text("Nothing matches this filter.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !activePlaceTypes.isEmpty {
                            filterChipsRow
                                .padding(.bottom, RootHomeMetrics.chromeToContent)
                        }
                        
                        let columns = masonryColumns
                        HStack(alignment: .top, spacing: 12) {
                            LazyVStack(spacing: 12) {
                                ForEach(columns.left) { place in
                                    placeButton(place)
                                }
                            }
                            LazyVStack(spacing: 12) {
                                ForEach(columns.right) { place in
                                    placeButton(place)
                                }
                            }
                        }
                        .padding(.horizontal, RootHomeMetrics.horizontalInset)
                    }
                    .padding(.top, RootHomeMetrics.topInset)
                    .padding(.bottom, RootHomeMetrics.bottomInset)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Places")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                LiquidGlassToolbarIconPair {
                    if #unavailable(iOS 26.0) {
                        Button {
                            showAIFindPlaces = true
                        } label: {
                            LiquidGlassToolbarIconLabel(systemName: "sparkles")
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        showAddPlace = true
                    } label: {
                        LiquidGlassToolbarIconLabel(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationDestination(item: $selectedPlaceID) { id in
            PlaceDetailView(placeID: id)
        }
        .sheet(isPresented: $showAddPlace) {
            AddEditPlaceSheet(mode: .add) { place in
                placeStore.add(place)
            }
        }
        .sheet(isPresented: $showAIFindPlaces) {
            TripStacksAISheet(
                mode: .placeFinder,
                tripContext: nearestTripContext,
                existingPlaces: placeStore.places.map {
                    AIPlaceSummary(
                        name: $0.name,
                        location: $0.location,
                        category: $0.placeType == .unspecified ? "" : $0.placeType.rawValue,
                        note: $0.note
                    )
                },
                onCommitPlaces: commitAIPlaces
            )
            .tint(.primary)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAIFindPlaces)) { _ in
            showAIFindPlaces = true
        }
        .sheet(item: $placeToEdit) { place in
            AddEditPlaceSheet(mode: .edit(place)) { updated in
                placeStore.update(updated)
            }
        }
        .sheet(isPresented: $showUnsplashPicker) {
            UnsplashCoverPickerSheet(initialQuery: unsplashQuery) { selection in
                if let place = placeForImageUpdate {
                    setPlaceImage(selection.imageData, on: place)
                }
                placeForImageUpdate = nil
            }
            .presentationDetents([.large])
            .tint(.primary)
        }
        .photosPicker(isPresented: $photosPickerPresented, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item, let place = placeForImageUpdate else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let jpeg = image.jpegData(compressionQuality: 0.8) {
                    await MainActor.run {
                        setPlaceImage(jpeg, on: place)
                        photoItem = nil
                        placeForImageUpdate = nil
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete this place?",
            isPresented: Binding(
                get: { placePendingDelete != nil },
                set: { if !$0 { placePendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: placePendingDelete
        ) { place in
            Button("Delete", role: .destructive) {
                placeStore.delete(place)
                placePendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                placePendingDelete = nil
            }
        } message: { _ in
            Text("This can’t be undone.")
        }
        .onChange(of: activePlaceTypes) { _, types in
            if let selectedPlaceType, !types.contains(selectedPlaceType) {
                self.selectedPlaceType = nil
            }
        }
    }
    
    // MARK: - Filter chips
    
    private var filterChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let selectedPlaceType {
                    PlaceTypeFilterChip(
                        title: selectedPlaceType.title,
                        iconSystemName: selectedPlaceType.iconSystemName,
                        isSelected: true
                    ) {
                        withAnimation(.snappy(duration: 0.22)) {
                            self.selectedPlaceType = nil
                        }
                    }
                } else {
                    ForEach(activePlaceTypes) { type in
                        PlaceTypeFilterChip(
                            title: type.title,
                            iconSystemName: type.iconSystemName,
                            isSelected: false
                        ) {
                            withAnimation(.snappy(duration: 0.22)) {
                                selectedPlaceType = type
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, RootHomeMetrics.horizontalInset)
        }
    }
    
    private func placeButton(_ place: Place) -> some View {
        let tripCount = PlaceTripMembership.tripCount(for: place, in: tripStore.trips)
        return Button {
            selectedPlaceID = place.id
        } label: {
            PlaceCardView(place: place, tripCount: tripCount)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .contextMenu {
            Menu {
                if tripsForAddMenu.isEmpty {
                    Text("No trips yet")
                } else {
                    ForEach(tripsForAddMenu) { trip in
                        Button {
                            addPlace(place, to: trip)
                        } label: {
                            Text(trip.name)
                        }
                    }
                }
            } label: {
                Label("Add to Trip", systemImage: "suitcase")
            }
            
            Menu {
                Button {
                    placeForImageUpdate = place
                    showUnsplashPicker = true
                } label: {
                    Label("Choose from Unsplash", systemImage: "sparkles")
                }
                Button {
                    placeForImageUpdate = place
                    photosPickerPresented = true
                } label: {
                    Label("Upload from Photos", systemImage: "photo.on.rectangle")
                }
            } label: {
                Label(
                    place.hasPhoto ? "Update Image" : "Add Image",
                    systemImage: place.hasPhoto ? "photo" : "photo.badge.plus"
                )
            }
            
            Button {
                placeToEdit = place
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive) {
                placePendingDelete = place
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func addPlace(_ place: Place, to trip: Trip) {
        guard let index = tripStore.trips.firstIndex(where: { $0.id == trip.id }) else { return }
        
        let title = PlaceNaming.title(location: place.location, fallback: place.name)
        let event = EventItem(
            title: title,
            description: place.note,
            time: "",
            location: place.location.isEmpty ? title : place.location,
            latitude: place.latitude,
            longitude: place.longitude,
            icon: place.placeType == .unspecified ? "mappin.and.ellipse" : place.placeType.iconSystemName,
            accent: .neutral,
            photoData: place.photoData
        )
        
        var updatedTrip = tripStore.trips[index]
        updatedTrip.showParkedIdeas = true
        updatedTrip.parkedIdeas.insert(event, at: 0)
        tripStore.trips[index] = updatedTrip
        tripStore.save()
        
        var updatedPlace = place
        updatedPlace.sourceTripID = trip.id
        updatedPlace.sourceTripName = trip.name
        updatedPlace.sourceEventID = event.id
        placeStore.update(updatedPlace, rematchMapKitIfNeeded: false)
    }
    
    private var nearestTripContext: PlanDayTripContext? {
        guard let trip = tripStore.trips.sorted(by: { $0.startDate > $1.startDate }).first else { return nil }
        return PlanDayTripContext(
            isDatesSet: trip.isDatesSet,
            startDate: trip.startDate,
            endDate: trip.endDate,
            unscheduledDaysCount: trip.unscheduledDaysCount,
            destination: trip.destination,
            latitude: trip.latitude,
            longitude: trip.longitude,
            mapSpan: trip.mapSpan
        )
    }
    
    private func commitAIPlaces(_ items: [PlanDayItem]) {
        for item in items where item.include {
            let name = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let place = Place(
                name: name,
                location: item.location,
                note: item.notes,
                latitude: item.latitude,
                longitude: item.longitude,
                placeType: PlaceType.fromAICategory(item.category)
            )
            placeStore.add(place)
        }
    }
    
    private func setPlaceImage(_ data: Data, on place: Place) {
        guard let current = placeStore.place(id: place.id) else { return }
        var updated = current
        updated.photoData = data
        placeStore.update(updated, rematchMapKitIfNeeded: false)
    }
    
    private var emptyState: some View {
        VStack(spacing: 28) {
            Spacer()
            
            SearchGlobeIllustration()
            
            Text("You haven’t added any places yet")
                .font(.appTitle2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showAIFindPlaces = true
            } label: {
                Text("Find Places")
                    .font(.appSubheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(hex: 0x2C2C2E), in: Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            
            Button {
                showAddPlace = true
            } label: {
                Text("New Place")
                    .font(.appSubheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

// MARK: - Chip

private struct PlaceTypeFilterChip: View {
    let title: String
    let iconSystemName: String
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var foreground: Color {
        colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717)
    }
    
    private var fallback: Color {
        colorScheme == .dark ? Color(hex: 0x171717) : Color(hex: 0xF0F0F0)
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                }
                Image(systemName: iconSystemName)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.app(13, weight: .semibold))
            }
            .foregroundStyle(foreground.opacity(isSelected ? 1 : 0.78))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .modifier(PlaceChipGlassBackground(fallback: fallback))
        }
        .buttonStyle(.plain)
    }
}

private struct PlaceChipGlassBackground: ViewModifier {
    let fallback: Color
    private let shape = Capsule(style: .continuous)
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
                .clipShape(shape)
        } else {
            content
                .background(fallback, in: shape)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        }
    }
}
