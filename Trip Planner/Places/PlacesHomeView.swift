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
        return PlaceNaming.displayTitle(name: place.name, location: place.location)
    }
    
    private var masonryColumns: (left: [Place], right: [Place]) {
        var left: [Place] = []
        var right: [Place] = []
        var leftHeight: CGFloat = 0
        var rightHeight: CGFloat = 0
        
        // Match page inset + `itemSpacing` between columns in the grid below.
        let columnWidth = max(
            (UIScreen.main.bounds.width - RootHomeMetrics.horizontalInset * 2 - PlaceCardMetrics.itemSpacing) / 2,
            140
        )
        
        for place in places {
            let estimate = PlaceCardMetrics.estimatedHeight(for: place, columnWidth: columnWidth)
            if leftHeight <= rightHeight {
                left.append(place)
                leftHeight += estimate + PlaceCardMetrics.itemSpacing
            } else {
                right.append(place)
                rightHeight += estimate + PlaceCardMetrics.itemSpacing
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
                        HStack(alignment: .top, spacing: PlaceCardMetrics.itemSpacing) {
                            LazyVStack(spacing: PlaceCardMetrics.itemSpacing) {
                                ForEach(columns.left) { place in
                                    placeButton(place)
                                }
                            }
                            LazyVStack(spacing: PlaceCardMetrics.itemSpacing) {
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
        .background(AppDetailSurface.page)
        .appRootNavigationTitle("Places")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                LiquidGlassToolbarIconPair {
                    if #unavailable(iOS 26.0) {
                        Button {
                            showAIFindPlaces = true
                        } label: {
                            LiquidGlassToolbarIconLabel(systemName: "sparkles")
                        }
                        .liquidGlassToolbarControl()
                    }
                    Button {
                        showAddPlace = true
                    } label: {
                        LiquidGlassToolbarIconLabel(systemName: "plus")
                    }
                    .liquidGlassToolbarControl()
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
                existingTrips: tripStore.trips.map { trip in
                    AITripSummary(
                        name: trip.name,
                        destination: trip.destination,
                        startDate: trip.isDatesSet ? isoDateString(trip.startDate) : nil,
                        endDate: trip.isDatesSet ? isoDateString(trip.endDate) : nil,
                        isDatesSet: trip.isDatesSet
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
        .alert(
            "Delete Place",
            isPresented: Binding(
                get: { placePendingDelete != nil },
                set: { if !$0 { placePendingDelete = nil } }
            ),
            presenting: placePendingDelete
        ) { place in
            Button("Delete Place", role: .destructive) {
                placeStore.delete(place)
                placePendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                placePendingDelete = nil
            }
        } message: { _ in
            Text("Are you sure you want to delete this place? This action cannot be undone.")
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
            HStack(spacing: AppSpacing.xs) {
                if let selectedPlaceType {
                    PlaceTypeFilterChip(
                        title: selectedPlaceType.chipTitle,
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
                            title: type.chipTitle,
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
        return Button {
            selectedPlaceID = place.id
        } label: {
            PlaceCardView(place: place)
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
                Label("Add to Trip", menuIcon: "map-plus")
            }
            
            Menu {
                Button {
                    placeForImageUpdate = place
                    showUnsplashPicker = true
                } label: {
                    Label("Choose from Unsplash", menuIcon: "sparkles")
                }
                Button {
                    placeForImageUpdate = place
                    photosPickerPresented = true
                } label: {
                    Label("Upload from Photos", menuIcon: "photo.on.rectangle")
                }
            } label: {
                Label(
                    place.hasPhoto ? "Update Image" : "Add Image",
                    menuIcon: place.hasPhoto ? "photo" : "photo.badge.plus"
                )
            }
            
            Button {
                placeToEdit = place
            } label: {
                Label("Edit Place", menuIcon: "square.and.pencil")
            }
            
            Divider()
            
            Button(role: .destructive) {
                placePendingDelete = place
            } label: {
                Label("Delete Place", menuIcon: "trash")
            }
        }
    }
    
    private func addPlace(_ place: Place, to trip: Trip) {
        guard let index = tripStore.trips.firstIndex(where: { $0.id == trip.id }) else { return }
        
        let title = PlaceNaming.displayTitle(name: place.name, location: place.location)
        let event = EventItem(
            title: title,
            description: place.note,
            time: "",
            location: place.location.isEmpty ? title : place.location,
            latitude: place.latitude,
            longitude: place.longitude,
            icon: place.placeType.mapIconName,
            accent: .cream,
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
        for item in items {
            let name = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let place = Place(
                name: name,
                location: item.location,
                note: item.notes,
                photoData: item.photoData,
                latitude: item.latitude,
                longitude: item.longitude,
                placeType: PlaceType.fromAICategory(item.category)
            )
            placeStore.add(place)
        }
    }
    
    private func isoDateString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
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
    
    private var contentColor: Color { AppColor.textStrong }
    
    private var fillColor: Color {
        isSelected ? AppColor.elevated : AppColor.card
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xxs) {
                AppIcon(
                    systemName: iconSystemName,
                    size: 16,
                    color: contentColor
                )
                Text(title)
                    .font(.app(13, weight: .medium))
                    .foregroundStyle(contentColor)
                if isSelected {
                    AppIcon(lucide: "x", size: 12, color: contentColor)
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(
                fillColor,
                in: Capsule(style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "Clears the filter and shows all places" : "Filters places by this type")
    }
}
