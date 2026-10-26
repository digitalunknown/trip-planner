import SwiftUI
import MapKit
import PhotosUI
import UIKit

struct PlaceDetailView: View {
    let placeID: UUID
    
    @Environment(PlaceStore.self) private var placeStore
    @Environment(TripStore.self) private var tripStore
    @Environment(ExpertTipsStore.self) private var expertTips
    @Environment(PremiumStore.self) private var premium
    @Environment(RootTabChrome.self) private var tabChrome
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.openURL) private var openURL
    
    @State private var showDeleteConfirm = false
    @State private var appleMapItem: MKMapItem?
    @State private var isLoadingApplePlace = false
    @State private var selectedAppleMapItem: MKMapItem?
    @State private var isPreviewingAppleMaps = false
    @State private var draftNote: String = ""
    @State private var draftName: String = ""
    @State private var showUnsplashPicker = false
    @State private var photosPickerPresented = false
    @State private var photoItem: PhotosPickerItem?
    @State private var selectedTripDestination: PlaceTripDestination?
    @State private var topSafeArea: CGFloat = 0
    @State private var showAddToTripSheet = false
    @FocusState private var isNotesFocused: Bool
    @FocusState private var isNameFocused: Bool
    
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
    
    private var matchedTips: [ExpertTip] {
        guard let place else { return [] }
        return expertTips.tips(matching: .place(place))
    }
    
    private func placeTitle(for place: Place) -> String {
        PlaceNaming.displayTitle(name: place.name, location: place.location)
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
    
    private var palette: PlaceDetailPalette {
        PlaceDetailPalette(colorScheme: colorScheme)
    }
    
    var body: some View {
        if let place {
            placeDetail(place)
        } else {
            ContentUnavailableView("Place unavailable", systemImage: "mappin.slash")
        }
    }
    
    private func placeDetail(_ place: Place) -> some View {
        applyPlaceLifecycle(to: applyPlaceNavigation(to: placeScroll(place), place: place), place: place)
    }
    
    private func placeScroll(_ place: Place) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if heroImage != nil {
                    heroPhoto(for: place)
                        .padding(.top, -topSafeArea)
                }
                placeFields(place)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .background(palette.page.ignoresSafeArea())
        .background { topSafeAreaReader }
    }
    
    private func placeFields(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: PlaceDetailMetrics.sectionGap) {
            if heroImage == nil {
                heroPhoto(for: place)
            }
            identityCard(for: place)
            if !matchedTips.isEmpty {
                expertTipsCard
            }
            appleMapsCard(for: place)
            tripsSection
            notesSection(for: place)
            actionButtons(for: place)
        }
        .padding(.horizontal, PlaceDetailMetrics.pagePadding)
        .padding(.top, AppSpacing.pageTop)
        .padding(.bottom, AppSpacing.pageBottom)
    }
    
    private var topSafeAreaReader: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { topSafeArea = geo.safeAreaInsets.top }
                .onChange(of: geo.safeAreaInsets.top) { _, value in
                    topSafeArea = value
                }
        }
    }
    
    private func applyPlaceNavigation<Content: View>(to content: Content, place: Place) -> some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .enableSwipeBack()
            .toolbar(.hidden, for: .tabBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(heroImage != nil ? .dark : nil, for: .navigationBar)
            .tint(.primary)
            .toolbar { placeToolbar(for: place) }
            .navigationDestination(item: $selectedTripDestination) { destination in
                tripDetail(for: destination)
            }
            .safeAreaInset(edge: .bottom) {
                if isNotesFocused || isNameFocused {
                    Color.clear.frame(height: 36)
                }
            }
    }
    
    @ToolbarContentBuilder
    private func placeToolbar(for place: Place) -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            LiquidGlassIconButton(systemName: "chevron.left", accessibilityLabelText: "Back") {
                dismiss()
            }
        }
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .principal) {
                placeToolbarTitle(for: place)
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .principal) {
                placeToolbarTitle(for: place)
            }
        }
    }
    
    private func applyPlaceLifecycle<Content: View>(to content: Content, place: Place) -> some View {
        content
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
            .task {
                await expertTips.refresh()
            }
            .onAppear {
                tabChrome.beginSuppressingAIAccessory()
                syncDrafts(from: place)
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
            .onChange(of: place.name) { _, _ in
                guard !isNameFocused else { return }
                draftName = place.name
            }
            .sheet(isPresented: $showAddToTripSheet) {
                PlaceAddToTripSheet(
                    trips: tripsForAddMenu,
                    subtitle: tripSubtitle(for:),
                    onSelect: { trip in
                        addPlace(place, to: trip)
                        showAddToTripSheet = false
                    },
                    onCancel: { showAddToTripSheet = false }
                )
                .tint(.primary)
            }
    }
    
    private func placeToolbarTitle(for place: Place) -> some View {
        Text(placeTitle(for: place))
            .font(.app(17, weight: .semibold))
            .foregroundStyle(heroImage != nil ? Color.white : AppColor.textStrong)
            .lineLimit(1)
            .truncationMode(.tail)
            .multilineTextAlignment(.center)
    }
    
    // MARK: - Hero
    
    @ViewBuilder
    private func heroPhoto(for place: Place) -> some View {
        Menu {
            Button {
                showUnsplashPicker = true
            } label: {
                Label("Choose from Unsplash", menuIcon: "sparkles")
            }
            Button {
                photosPickerPresented = true
            } label: {
                Label("Choose from Photos", menuIcon: "photo.on.rectangle")
            }
            if heroImage != nil {
                Button(role: .destructive) {
                    clearPlaceImage(on: place)
                } label: {
                    Label("Delete Photo", menuIcon: "trash")
                }
            }
        } label: {
            if let heroImage {
                StretchyHero {
                    Image(uiImage: heroImage)
                        .resizable()
                        .scaledToFill()
                }
            } else {
                ZStack {
                    palette.card
                    VStack(spacing: 8) {
                        AppIcon(lucide: "image-plus", size: 24, color: palette.secondary)
                        Text("Add Photo")
                            .font(.app(15, weight: .medium))
                            .foregroundStyle(palette.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: PlaceDetailMetrics.heroHeight)
                .clipShape(RoundedRectangle(cornerRadius: PlaceDetailMetrics.heroRadius, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: PlaceDetailMetrics.heroRadius, style: .continuous))
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    
    private func actionButtons(for place: Place) -> some View {
        HStack(spacing: AppSpacing.xs) {
            DetailIconPillButton(
                lucide: "map-plus",
                accessibilityLabel: "Add to Trip"
            ) {
                showAddToTripSheet = true
            }
            
            DetailIconPillButton(
                lucide: "trash-2",
                iconColor: AppColor.destructive,
                fill: AppColor.destructive.opacity(colorScheme == .dark ? 0.25 : 0.14),
                accessibilityLabel: "Delete Place"
            ) {
                showDeleteConfirm = true
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Identity
    
    private func identityCard(for place: Place) -> some View {
        PlaceDetailCard(palette: palette) {
            HStack(spacing: PlaceDetailMetrics.iconTextGap) {
                AppIcon(lucide: "type", size: PlaceDetailMetrics.iconSize, color: palette.primary)
                TextField("Name", text: $draftName)
                    .font(.app(15, weight: .medium))
                    .foregroundStyle(palette.primary)
                    .textInputAutocapitalization(.words)
                    .focused($isNameFocused)
                    .onChange(of: draftName) { _, newValue in
                        persistName(newValue, on: place)
                    }
            }
            
            PlaceDetailDivider(color: palette.divider)
            
            placeTypeRow(for: place)
        }
    }
    
    private func placeTypeRow(for place: Place) -> some View {
        Menu {
            ForEach(PlaceType.allCases) { type in
                Button {
                    setPlaceType(type, on: place)
                } label: {
                    if type == place.placeType {
                        Label(type.title, menuIcon: "checkmark")
                    } else {
                        Text(type.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 0) {
                HStack(spacing: PlaceDetailMetrics.iconTextGap) {
                    AppIcon(lucide: "tag", size: PlaceDetailMetrics.iconSize, color: palette.primary)
                    Text("Type")
                        .font(.app(15, weight: .medium))
                        .foregroundStyle(palette.primary)
                }
                Spacer(minLength: 8)
                HStack(spacing: 5) {
                    Text(place.placeType.title)
                        .font(.app(15, weight: .medium))
                        .foregroundStyle(palette.primary)
                    AppIcon(lucide: "chevrons-up-down", size: PlaceDetailMetrics.iconSize, color: palette.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .tint(.primary)
    }
    
    // MARK: - Expert tips
    
    @ViewBuilder
    private var expertTipsCard: some View {
        if premium.isPremium {
            PlaceDetailCard(palette: palette, rowSpacing: 10) {
                HStack(spacing: PlaceDetailMetrics.iconTextGap) {
                    AppIcon(lucide: "user-star", size: PlaceDetailMetrics.iconSize, color: palette.expert)
                    Text("Local insights")
                        .font(.app(15, weight: .medium))
                        .foregroundStyle(palette.expert)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(matchedTips) { tip in
                        Text(tip.tip)
                            .font(.app(15, weight: .medium))
                            .foregroundStyle(palette.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .expertTipOutlineShine(cornerRadius: PlaceDetailMetrics.cardRadius)
        } else {
            LockedLocalInsightsCard(
                previewText: matchedTips[0].tip,
                expertColor: palette.expert,
                cardFill: palette.card,
                cornerRadius: PlaceDetailMetrics.cardRadius
            )
        }
    }
    
    // MARK: - Apple Maps
    
    @ViewBuilder
    private func appleMapsCard(for place: Place) -> some View {
        if #available(iOS 18.0, *) {
            if isLoadingApplePlace, place.mapKitMatchStatus == .notAttempted || place.hasAppleMapsMatch {
                PlaceDetailCard(palette: palette) {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Looking up place info…")
                            .font(.app(15, weight: .medium))
                            .foregroundStyle(palette.secondary)
                    }
                }
            } else if let appleMapItem {
                contactCard(mapItem: appleMapItem, fallbackTitle: placeTitle(for: place))
            } else {
                PlaceDetailCard(palette: palette) {
                    Button {
                        Task { await previewInAppleMaps(for: place) }
                    } label: {
                        HStack(spacing: 15) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Look Up Place Info")
                                    .font(.app(15, weight: .medium))
                                    .foregroundStyle(palette.primary)
                                Text("Address, phone, website & more")
                                    .font(.app(13, weight: .medium))
                                    .foregroundStyle(palette.secondary)
                            }
                            Spacer(minLength: 8)
                            if isPreviewingAppleMaps {
                                ProgressView()
                            } else {
                                AppIcon(lucide: "chevron-right", size: PlaceDetailMetrics.iconSize, color: palette.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isPreviewingAppleMaps)
                }
            }
        }
    }
    
    private func contactCard(mapItem: MKMapItem, fallbackTitle: String) -> some View {
        let address = mapItemAddressString(mapItem)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let phone = mapItem.phoneNumber?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let websiteURL = mapItem.url
        let hasContactRows = !address.isEmpty || !phone.isEmpty || websiteURL != nil
        
        return PlaceDetailCard(palette: palette) {
            if !address.isEmpty {
                labeledValue(label: "Address", value: address, valueColor: palette.primary)
                PlaceDetailDivider(color: palette.divider)
            }
            
            if !phone.isEmpty {
                Button {
                    if let url = ApplePlaceContactSection.telephoneURL(from: phone) {
                        openURL(url)
                    }
                } label: {
                    labeledValue(label: "Phone", value: phone, valueColor: appAccentColor)
                }
                .buttonStyle(.plain)
                .disabled(ApplePlaceContactSection.telephoneURL(from: phone) == nil)
                PlaceDetailDivider(color: palette.divider)
            }
            
            if let websiteURL {
                Button {
                    openURL(websiteURL)
                } label: {
                    labeledValue(
                        label: "Website",
                        value: ApplePlaceContactSection.websiteDisplayText(for: websiteURL),
                        valueColor: appAccentColor
                    )
                }
                .buttonStyle(.plain)
                PlaceDetailDivider(color: palette.divider)
            }
            
            Button {
                selectedAppleMapItem = mapItem
            } label: {
                HStack(spacing: 15) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(hasContactRows ? "View More Details" : (mapItem.name ?? fallbackTitle))
                            .font(.app(15, weight: .medium))
                            .foregroundStyle(palette.primary)
                        Text("Photos, hours, ratings & more")
                            .font(.app(13, weight: .medium))
                            .foregroundStyle(palette.secondary)
                    }
                    Spacer(minLength: 8)
                    AppIcon(lucide: "chevron-right", size: PlaceDetailMetrics.iconSize, color: palette.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    private func labeledValue(label: String, value: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.app(13, weight: .medium))
                .foregroundStyle(palette.secondary)
            Text(value)
                .font(.app(15, weight: .medium))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
    
    // MARK: - Trips
    
    @ViewBuilder
    private var tripsSection: some View {
        if !relatedTrips.isEmpty {
            VStack(alignment: .leading, spacing: PlaceDetailMetrics.headerGap) {
                AppSectionHeader("Trips", color: palette.secondary)
                    .padding(.leading, PlaceDetailMetrics.headerIndent)
                
                PlaceDetailCard(palette: palette) {
                    ForEach(Array(relatedTrips.enumerated()), id: \.element.id) { index, trip in
                        Button {
                            guard let place else { return }
                            selectedTripDestination = PlaceTripDestination(
                                tripID: trip.id,
                                eventID: PlaceTripMembership.matchingEvent(for: place, in: trip)?.id
                            )
                        } label: {
                            HStack(spacing: 15) {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(trip.name)
                                        .font(.app(15, weight: .medium))
                                        .foregroundStyle(palette.primary)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    if let subtitle = tripSubtitle(for: trip) {
                                        Text(subtitle)
                                            .font(.app(13, weight: .medium))
                                            .foregroundStyle(palette.secondary)
                                    }
                                }
                                AppIcon(lucide: "chevron-right", size: PlaceDetailMetrics.iconSize, color: palette.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        if index < relatedTrips.count - 1 {
                            PlaceDetailDivider(color: palette.divider)
                        }
                    }
                }
            }
        }
    }
    
    private func tripSubtitle(for trip: Trip) -> String? {
        if trip.isDatesSet {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            formatter.setLocalizedDateFormatFromTemplate("MMMd yyyy")
            if Calendar.current.isDate(trip.startDate, inSameDayAs: trip.endDate) {
                return formatter.string(from: trip.startDate)
            }
            return "\(formatter.string(from: trip.startDate)) - \(formatter.string(from: trip.endDate))"
        }
        let destination = trip.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        return destination.isEmpty ? nil : destination
    }
    
    @ViewBuilder
    private func tripDetail(for destination: PlaceTripDestination) -> some View {
        if let index = tripStore.trips.firstIndex(where: { $0.id == destination.tripID }) {
            TripDetailView(
                trip: Binding(
                    get: { tripStore.trips[index] },
                    set: { newValue in
                        tripStore.trips[index] = newValue
                        tripStore.save()
                    }
                ),
                initialEventID: destination.eventID
            )
        } else {
            ContentUnavailableView("Trip unavailable", systemImage: "airplane.departure")
        }
    }
    
    // MARK: - Notes
    
    private func notesSection(for place: Place) -> some View {
        VStack(alignment: .leading, spacing: PlaceDetailMetrics.headerGap) {
            AppSectionHeader("Notes", color: palette.secondary)
                .padding(.leading, PlaceDetailMetrics.headerIndent)
            
            TextField("", text: $draftNote, axis: .vertical)
                .font(.app(15, weight: .medium))
                .foregroundStyle(palette.primary)
                .lineLimit(3...12)
                .textInputAutocapitalization(.sentences)
                .focused($isNotesFocused)
                .padding(PlaceDetailMetrics.cardPadding)
                .frame(minHeight: PlaceDetailMetrics.notesMinHeight, alignment: .topLeading)
                .background(palette.card, in: RoundedRectangle(cornerRadius: PlaceDetailMetrics.cardRadius, style: .continuous))
                .onChange(of: draftNote) { _, newValue in
                    guard newValue != place.note else { return }
                    var updated = place
                    updated.note = newValue
                    placeStore.update(updated, rematchMapKitIfNeeded: false)
                }
        }
    }
    
    // MARK: - Persistence helpers
    
    private func syncDrafts(from place: Place) {
        draftNote = place.note
        draftName = place.name
    }
    
    private func persistName(_ raw: String, on place: Place) {
        guard raw != place.name else { return }
        var updated = place
        updated.name = raw
        placeStore.update(updated, rematchMapKitIfNeeded: false)
    }
    
    private func setPlaceType(_ type: PlaceType, on place: Place) {
        var updated = place
        updated.placeType = type
        placeStore.update(updated, rematchMapKitIfNeeded: false)
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
        
        guard let mapItem = await ApplePlaceLookup.mapItem(
            name: place.name,
            location: place.location,
            latitude: place.latitude,
            longitude: place.longitude,
            destinationHint: place.location
        ) else { return }
        
        selectedAppleMapItem = mapItem
        
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
    }
}

// MARK: - Layout tokens (Figma 719:8305)

private enum PlaceDetailMetrics {
    static let pagePadding: CGFloat = AppSpacing.pageInset
    static let sectionGap: CGFloat = AppSpacing.sectionGap
    static let headerGap: CGFloat = 8
    /// Matches inset-grouped Form headers, which line up with card content.
    static let headerIndent: CGFloat = 20
    static let cardPadding: CGFloat = AppSpacing.cardPadding
    static let cardRadius: CGFloat = 20
    static let cardRowGap: CGFloat = AppSpacing.pageInset
    static let heroHeight: CGFloat = 200
    static let heroRadius: CGFloat = 16
    static let buttonGap: CGFloat = AppSpacing.xs
    static let buttonRadius: CGFloat = 20
    static let buttonIconTitleGap: CGFloat = AppSpacing.xxs
    static let iconSize: CGFloat = AppLucide.fieldSize
    static let iconTextGap: CGFloat = AppSpacing.sm
    static let notesMinHeight: CGFloat = 100
}

private struct PlaceDetailPalette {
    let page: Color
    let card: Color
    let primary: Color
    let secondary: Color
    let divider: Color
    let expert: Color
    
    init(colorScheme: ColorScheme) {
        expert = AppColor.expert
        page = AppColor.page
        card = AppColor.card
        primary = AppColor.textStrong
        secondary = AppColor.textWeak
        divider = AppColor.divider
    }
}

private struct PlaceDetailCard<Content: View>: View {
    let palette: PlaceDetailPalette
    var rowSpacing: CGFloat = PlaceDetailMetrics.cardRowGap
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            content()
        }
        .padding(PlaceDetailMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.card, in: RoundedRectangle(cornerRadius: PlaceDetailMetrics.cardRadius, style: .continuous))
    }
}

private struct PlaceDetailDivider: View {
    let color: Color
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
    }
}

