import SwiftUI
import MapKit
import PhotosUI
import UIKit

struct PlaceDetailView: View {
    let placeID: UUID
    
    @Environment(PlaceStore.self) private var placeStore
    @Environment(TripStore.self) private var tripStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var appleMapItem: MKMapItem?
    @State private var isLoadingApplePlace = false
    @State private var selectedAppleMapItem: MKMapItem?
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
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                showEdit = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            if place.hasAppleMapsMatch {
                                Button {
                                    placeStore.unlinkAppleMapsMatch(for: place.id)
                                    appleMapItem = nil
                                    selectedAppleMapItem = nil
                                } label: {
                                    Label("Unlink Apple Maps place", systemImage: "link.badge.minus")
                                }
                            } else if #available(iOS 18.0, *) {
                                Button {
                                    placeStore.scheduleMapKitMatch(for: place.id, force: true)
                                } label: {
                                    Label("Find on Apple Maps", systemImage: "map")
                                }
                            }
                            
                            if place.photoData != nil {
                                Button(role: .destructive) {
                                    clearPlaceImage(on: place)
                                } label: {
                                    Label("Remove image", systemImage: "photo.badge.minus")
                                }
                            }
                            
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                                .contentShape(Rectangle())
                        }
                        .tint(.primary)
                        .buttonStyle(.plain)
                    }
                }
                .sheet(isPresented: $showEdit) {
                    AddEditPlaceSheet(mode: .edit(place)) { updated in
                        placeStore.update(updated)
                        syncDrafts(from: updated)
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
                .confirmationDialog("Delete this place?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        placeStore.delete(place)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                }
                .modifier(ApplePlaceCardSheetModifier(item: $selectedAppleMapItem))
                .task(id: place.mapKitIdentifier) {
                    await loadApplePlaceIfNeeded(for: place)
                }
                .onAppear {
                    syncDrafts(from: place)
                    placeStore.scheduleMapKitMatch(for: place.id)
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
                        Text("Looking up Apple Maps…")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let appleMapItem {
                Section("Apple Maps") {
                    Button {
                        selectedAppleMapItem = appleMapItem
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(appleMapItem.name ?? placeTitle(for: place))
                                    .foregroundStyle(.primary)
                                Text("Photos, hours, ratings & more")
                                    .font(.appCaption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
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
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundStyle(.secondary)
                    }
                }
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
}

private struct ApplePlaceCardSheetModifier: ViewModifier {
    @Binding var item: MKMapItem?
    
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.mapItemDetailSheet(item: $item, displaysMap: true)
        } else {
            content
        }
    }
}
