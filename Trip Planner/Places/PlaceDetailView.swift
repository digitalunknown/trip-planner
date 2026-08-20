import SwiftUI
import MapKit
import PhotosUI
import UIKit

struct PlaceDetailView: View {
    let placeID: UUID
    
    @Environment(PlaceStore.self) private var placeStore
    @Environment(TripStore.self) private var tripStore
    @Environment(RootTabChrome.self) private var tabChrome
    @Environment(\.dismiss) private var dismiss
    
    @State private var showDeleteConfirm = false
    @State private var appleMapItem: MKMapItem?
    @State private var isLoadingApplePlace = false
    @State private var selectedAppleMapItem: MKMapItem?
    @State private var isPreviewingAppleMaps = false
    @State private var draftNote: String = ""
    @State private var draftLocation: String = ""
    @State private var draftLatitude: Double?
    @State private var draftLongitude: Double?
    @State private var showUnsplashPicker = false
    @State private var photosPickerPresented = false
    @State private var photoItem: PhotosPickerItem?
    @State private var selectedTripID: UUID?
    @FocusState private var isNotesFocused: Bool
    
    private var place: Place? {
        placeStore.place(id: placeID)
    }
    
    private var relatedTrips: [Trip] {
        guard let place else { return [] }
        return PlaceTripMembership.trips(for: place, in: tripStore.trips)
    }
    
    private var tripsForAddMenu: [Trip] {
        tripStore.trips.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
    
    private func placeTitle(for place: Place) -> String {
        PlaceNaming.title(location: place.location, fallback: place.name)
    }
    
    private var heroImage: UIImage? {
        guard let data = place?.photoData else { return nil }
        return UIImage(data: data)
    }
    
    private var unsplashQuery: String {
        guard let place else { return "" }
        let loc = place.location.trimmingCharacters(in: .whitespacesAndNewlines)
        if !loc.isEmpty { return loc }
        return placeTitle(for: place)
    }
    
    var body: some View {
        Group {
            if let place {
                Form {
                    Section {
                        LocationSearchField(
                            text: $draftLocation,
                            latitude: $draftLatitude,
                            longitude: $draftLongitude,
                            searchRegion: nil
                        )
                        .onChange(of: draftLocation) { _, _ in persistLocation(on: place) }
                        .onChange(of: draftLatitude) { _, _ in persistLocation(on: place) }
                        .onChange(of: draftLongitude) { _, _ in persistLocation(on: place) }
                        
                        placeTypeMenu(for: place)
                    }
                    
                    Section {
                        HStack {
                            Spacer(minLength: 0)
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
                                PrimaryCapsuleLabel(title: "Add to Trip", systemImage: "suitcase.fill")
                            }
                            .buttonStyle(.plain)
                            Spacer(minLength: 0)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                    
                    appleMapsFormSection(for: place)
                    
                    tripsSection
                    
                    imageSection(for: place)
                    
                    Section {
                        TextField("Notes", text: $draftNote, axis: .vertical)
                            .lineLimit(3...12)
                            .textInputAutocapitalization(.sentences)
                            .focused($isNotesFocused)
                            .onChange(of: draftNote) { _, newValue in
                                guard newValue != place.note else { return }
                                var updated = place
                                updated.note = newValue
                                placeStore.update(updated, rematchMapKitIfNeeded: false)
                            }
                    }
                    
                    DetailActionButtonStack {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Place", systemImage: "trash")
                        }
                        .buttonStyle(.destructiveCapsuleBlock)
                        .detailActionRow()
                    }
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .background(Color(.systemGroupedBackground))
                .navigationTitle(placeTitle(for: place))
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(item: $selectedTripID) { tripID in
                    tripDetail(for: tripID)
                }
                .safeAreaInset(edge: .bottom) {
                    if isNotesFocused {
                        Color.clear.frame(height: 36)
                    }
                }
                .sheet(isPresented: $showUnsplashPicker) {
                    UnsplashCoverPickerSheet(initialQuery: unsplashQuery) { selection in
                        setPlaceImage(selection.imageData, on: place)
                    }
                    .presentationDetents([.large])
                    .tint(.primary)
                }
                .photosPicker(isPresented: $photosPickerPresented, selection: $photoItem, matching: .images)
                .onChange(of: photoItem) { _, item in
                    guard let item else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data),
                           let jpeg = image.jpegData(compressionQuality: 0.8) {
                            await MainActor.run {
                                setPlaceImage(jpeg, on: place)
                                photoItem = nil
                            }
                        }
                    }
                }
                .alert("Delete Place", isPresented: $showDeleteConfirm) {
                    Button("Delete Place", role: .destructive) {
                        placeStore.delete(place)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Are you sure you want to delete this place? This action cannot be undone.")
                }
                .applePlaceCardSheet(item: $selectedAppleMapItem)
                .task(id: place.mapKitIdentifier) {
                    await loadApplePlaceIfNeeded(for: place)
                }
                .onAppear {
                    tabChrome.beginSuppressingAIAccessory()
                    syncDrafts(from: place)
                    // Retry unmatched places (common for AI imports without coordinates).
                    placeStore.scheduleMapKitMatch(
                        for: place.id,
                        force: place.mapKitMatchStatus == .unmatched
                    )
                }
                .onDisappear {
                    tabChrome.endSuppressingAIAccessory()
                }
                .onChange(of: place.note) { _, newValue in
                    if !isNotesFocused {
                        draftNote = newValue
                    }
                }
            } else {
                ContentUnavailableView("Place unavailable", systemImage: "mappin.slash")
            }
        }
    }
    
    // MARK: - Form sections
    
    @ViewBuilder
    private var tripsSection: some View {
        if !relatedTrips.isEmpty {
            Section("Trips") {
                ForEach(relatedTrips) { trip in
                    Button {
                        selectedTripID = trip.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(trip.name)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                if let subtitle = tripSubtitle(for: trip) {
                                    Text(subtitle)
                                        .font(.appCaption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.app(13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func tripSubtitle(for trip: Trip) -> String? {
        if trip.isDatesSet {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            if Calendar.current.isDate(trip.startDate, inSameDayAs: trip.endDate) {
                return formatter.string(from: trip.startDate)
            }
            return "\(formatter.string(from: trip.startDate)) – \(formatter.string(from: trip.endDate))"
        }
        let destination = trip.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        return destination.isEmpty ? nil : destination
    }
    
    @ViewBuilder
    private func tripDetail(for tripID: UUID) -> some View {
        if let index = tripStore.trips.firstIndex(where: { $0.id == tripID }) {
            TripDetailView(trip: Binding(
                get: { tripStore.trips[index] },
                set: { newValue in
                    tripStore.trips[index] = newValue
                    tripStore.save()
                }
            ))
        } else {
            ContentUnavailableView("Trip unavailable", systemImage: "airplane.departure")
        }
    }
    
    @ViewBuilder
    private func appleMapsFormSection(for place: Place) -> some View {
        if #available(iOS 18.0, *) {
            if isLoadingApplePlace, place.mapKitMatchStatus == .notAttempted || place.hasAppleMapsMatch {
                Section {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Looking up place info…")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let appleMapItem {
                ApplePlaceContactSection(
                    mapItem: appleMapItem,
                    fallbackTitle: placeTitle(for: place),
                    selectedMapItem: $selectedAppleMapItem
                )
            } else {
                Section {
                    Button {
                        Task { await previewInAppleMaps(for: place) }
                    } label: {
                        appleMapsRow(
                            title: "Look Up Place Info",
                            subtitle: "Address, phone, website & more",
                            showsProgress: isPreviewingAppleMaps
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isPreviewingAppleMaps)
                }
            }
        }
    }
    
    private func appleMapsRow(title: String, subtitle: String, showsProgress: Bool = false) -> some View {
        HStack {
            if showsProgress {
                ProgressView()
                    .padding(.trailing, 4)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.app(13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
    
    private func imageSection(for place: Place) -> some View {
        Section {
            if let heroImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: heroImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipped()
                        .contentShape(Rectangle())
                        .overlay {
                            Menu {
                                Button {
                                    showUnsplashPicker = true
                                } label: {
                                    Label("Choose from Unsplash", systemImage: "sparkles")
                                }
                                Button {
                                    photosPickerPresented = true
                                } label: {
                                    Label("Choose from Photos", systemImage: "photo.on.rectangle")
                                }
                            } label: {
                                Color.clear
                            }
                            .buttonStyle(.plain)
                        }
                    
                    LiquidGlassIconButton(systemName: "xmark", showsGlassBackground: true) {
                        clearPlaceImage(on: place)
                    }
                    .padding(12)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            } else {
                Menu {
                    Button {
                        showUnsplashPicker = true
                    } label: {
                        Label("Choose from Unsplash", systemImage: "sparkles")
                    }
                    Button {
                        photosPickerPresented = true
                    } label: {
                        Label("Choose from Photos", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    HStack {
                        Text("Add Photo")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.primary)
            }
        }
    }
    
    private func placeTypeMenu(for place: Place) -> some View {
        Menu {
            ForEach(PlaceType.allCases) { type in
                Button {
                    setPlaceType(type, on: place)
                } label: {
                    if place.placeType == type {
                        Label(type.title, systemImage: "checkmark")
                    } else {
                        Text(type.title)
                    }
                }
            }
        } label: {
            HStack {
                Text("Type")
                    .foregroundStyle(.primary)
                Spacer()
                Text(place.placeType == .unspecified ? "Select type" : place.placeType.title)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.app(11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tint(.primary)
    }
    
    // MARK: - Persistence helpers
    
    private func syncDrafts(from place: Place) {
        draftNote = place.note
        draftLocation = place.location
        draftLatitude = place.latitude
        draftLongitude = place.longitude
    }
    
    private func persistLocation(on place: Place) {
        guard draftLocation != place.location
                || draftLatitude != place.latitude
                || draftLongitude != place.longitude else { return }
        let coordsChanged = draftLatitude != place.latitude || draftLongitude != place.longitude
        var updated = place
        updated.location = draftLocation
        updated.latitude = draftLatitude
        updated.longitude = draftLongitude
        updated.name = PlaceNaming.title(location: draftLocation, fallback: place.name)
        // Rematch only when MapKit picks coords — avoid clearing the match on every keystroke.
        placeStore.update(updated, rematchMapKitIfNeeded: coordsChanged)
    }
    
    private func setPlaceType(_ type: PlaceType, on place: Place) {
        var updated = place
        updated.placeType = type
        placeStore.update(updated, rematchMapKitIfNeeded: false)
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
        Haptics.bump()
    }
    
    private func setPlaceImage(_ data: Data, on place: Place) {
        var updated = place
        updated.photoData = data
        placeStore.update(updated, rematchMapKitIfNeeded: false)
    }
    
    private func clearPlaceImage(on place: Place) {
        var updated = place
        updated.photoData = nil
        placeStore.update(updated, rematchMapKitIfNeeded: false)
    }
    
    @MainActor
    private func loadApplePlaceIfNeeded(for place: Place) async {
        guard #available(iOS 18.0, *) else {
            appleMapItem = nil
            return
        }
        
        guard let raw = place.mapKitIdentifier, place.mapKitMatchStatus == .matched else {
            appleMapItem = nil
            isLoadingApplePlace = place.mapKitMatchStatus == .notAttempted
            return
        }
        
        isLoadingApplePlace = true
        let item = await PlaceMapKitMatcher.loadMapItem(identifierRawValue: raw)
        appleMapItem = item
        isLoadingApplePlace = false
    }
    
    @MainActor
    private func previewInAppleMaps(for place: Place) async {
        let query = [place.name, place.location]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        guard !query.isEmpty else { return }
        
        isPreviewingAppleMaps = true
        defer { isPreviewingAppleMaps = false }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        if let lat = place.latitude, let lon = place.longitude {
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                latitudinalMeters: 4_000,
                longitudinalMeters: 4_000
            )
        }
        
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let mapItem = response.mapItems.first else { return }
            selectedAppleMapItem = mapItem
            
            // Persist a confident match when possible so the rich row appears next time.
            if #available(iOS 18.0, *), let identifier = mapItem.identifier?.rawValue {
                var updated = place
                updated.mapKitIdentifier = identifier
                updated.mapKitMatchStatus = .matched
                if updated.latitude == nil || updated.longitude == nil {
                    let coordinate = mapItemCoordinate(mapItem)
                    updated.latitude = coordinate?.latitude
                    updated.longitude = coordinate?.longitude
                }
                placeStore.update(updated, rematchMapKitIfNeeded: false)
                appleMapItem = mapItem
            }
        } catch {
            // Keep the preview row available for retry.
        }
    }
}
