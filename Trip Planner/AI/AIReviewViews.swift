import MapKit
import SwiftUI
import UIKit

// MARK: - Result sections

enum AIResultSection: String, CaseIterable, Identifiable {
    case accommodations
    case restaurants
    case activities
    case flights
    case checklists
    case reminders
    case other
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .accommodations: return "Accommodations"
        case .restaurants: return "Restaurants"
        case .activities: return "Activities"
        case .flights: return "Flights"
        case .checklists: return "To-do lists"
        case .reminders: return "Reminders"
        case .other: return "Other"
        }
    }
    
    static func section(for item: PlanDayItem) -> AIResultSection {
        switch item.kind {
        case .flight: return .flights
        case .checklist: return .checklists
        case .reminder: return .reminders
        case .activity, .place:
            switch PlaceType.fromAICategory(item.category) {
            case .hotel: return .accommodations
            case .restaurant, .cafe, .bar: return .restaurants
            case .unspecified where item.kind == .place: return .other
            default: return .activities
            }
        }
    }
    
    static func grouped(_ items: [PlanDayItem]) -> [(section: AIResultSection, items: [PlanDayItem])] {
        allCases.map { section in
            (section, items.filter { Self.section(for: $0) == section })
        }
        .filter { !$0.1.isEmpty }
    }
}

extension PlanDayItem {
    var canSaveToPlaces: Bool {
        switch kind {
        case .activity, .place:
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return false
        }
    }
    
    var aiResultSubtitle: String {
        let notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty { return notes }
        if kind == .checklist {
            let checklist = checklistItemsText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !checklist.isEmpty { return checklist }
        }
        if kind == .flight {
            let from = flightFromCode.trimmingCharacters(in: .whitespacesAndNewlines)
            let to = flightToCode.trimmingCharacters(in: .whitespacesAndNewlines)
            let number = flightNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            let route = [from.isEmpty ? nil : from, to.isEmpty ? nil : to]
                .compactMap { $0 }
                .joined(separator: " → ")
            let parts = [route.isEmpty ? nil : route, number.isEmpty ? nil : number].compactMap { $0 }
            if !parts.isEmpty { return parts.joined(separator: "  ") }
        }
        return location.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var canOpenInMaps: Bool {
        switch kind {
        case .activity, .place:
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return false
        }
    }
}

// MARK: - Shared reply + selection chrome

enum AIReplyCopy {
    static func planDay(intent: String, itemCount: Int, destination: String?) -> String {
        let place = destination?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let inPlace = place.isEmpty ? "" : " in \(place)"
        let n = max(itemCount, 1)
        switch intent {
        case "day_plan":
            return "Here’s a full day plan\(inPlace) with \(n) ideas."
        case "multi_day_plan":
            return "Here’s a multi-day plan\(inPlace) with \(n) suggestions."
        case "options_list":
            return "Here are \(n) options\(inPlace)."
        case "checklist":
            return "I put together a checklist for you."
        case "reminder":
            return "Here \(n == 1 ? "is a reminder" : "are \(n) reminders") you can add."
        case "flight":
            return "Here’s travel I found for your trip."
        default:
            return "Here are \(n) suggestions\(inPlace)."
        }
    }
    
    static func places(itemCount: Int, destinationHint: String?, items: [PlanDayItem] = []) -> String {
        let place = destinationHint?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let n = max(itemCount, 1)
        let mix = placesCategoryBlurb(for: items)
        let saveHint = "Tap Save to Places on any you’d like to keep, or Save All to add them to your library."
        
        if place.isEmpty {
            return "I put together \(n) places that felt worth saving\(mix). \(saveHint)"
        }
        return "I put together \(n) highlights around \(place)\(mix). They’re a mix of local favorites and easy-to-revisit spots. \(saveHint)"
    }
    
    private static func placesCategoryBlurb(for items: [PlanDayItem]) -> String {
        let types = items.map { PlaceType.fromAICategory($0.category) }
            .map { $0 == .unspecified ? PlaceType.other : $0 }
        let unique = PlaceType.allCases.filter { type in
            type != .unspecified && types.contains(type)
        }
        guard !unique.isEmpty else { return "" }
        
        let labels = unique.prefix(3).map { type -> String in
            switch type {
            case .restaurant: return "restaurants"
            case .cafe: return "cafés"
            case .bar: return "bars"
            case .hotel: return "stays"
            case .attraction: return "attractions"
            case .museum: return "museums"
            case .park: return "parks"
            case .viewpoint: return "viewpoints"
            default: return type.title.lowercased()
            }
        }
        
        switch labels.count {
        case 1: return " — mostly \(labels[0])"
        case 2: return " — a mix of \(labels[0]) and \(labels[1])"
        default: return " — spanning \(labels[0]), \(labels[1]), and \(labels[2])"
        }
    }
    
    static func createTrip(trip: AITripDraft, itemCount: Int) -> String {
        let summary = trip.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !summary.isEmpty {
            return summary
        }
        let destination = trip.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trip.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = destination.isEmpty ? (name.isEmpty ? "your trip" : name) : destination
        let n = itemCount
        if n == 0 {
            return "I’ve drafted a trip to \(label)."
        }
        return "I’ve drafted a trip to \(label) with \(n) starter ideas."
    }
}

struct AIResultReplyText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.app(15, weight: .regular))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
    }
}

/// Legacy alias used by older call sites.
typealias AIResultReplyCard = AIResultReplyText

enum AIResultPrimaryAction {
    case savePlace(isOn: Binding<Bool>)
    case include(isOn: Binding<Bool>)
}

struct AIResultActionCapsule: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var fill: Color { colorScheme == .dark ? Color(hex: 0x49494C) : Color(hex: 0xD1D1D6) }
    private var foreground: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .medium))
                Text(title)
                    .font(.app(15, weight: .semibold))
            }
            .foregroundStyle(foreground)
            .padding(.leading, 10)
            .padding(.trailing, 15)
            .padding(.vertical, 10)
            .background(Capsule(style: .continuous).fill(fill))
        }
        .buttonStyle(.plain)
    }
}

struct AIResultMapIconButton: View {
    let isLoading: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var fill: Color { colorScheme == .dark ? Color(hex: 0x49494C) : Color(hex: 0xD1D1D6) }
    private var foreground: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "map")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(foreground)
                }
            }
            .frame(width: 40, height: 40)
            .background(Capsule(style: .continuous).fill(fill))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel("Preview in Apple Maps")
    }
}

struct AIResultToolbarPill: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.app(17, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .frame(minHeight: LiquidGlassToolbarMetrics.iconSide)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tint(.primary)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

/// Shared Figma card: title → description → image → action row.
struct AIResultItemCard<Accessory: View>: View {
    let title: String
    let subtitle: String
    let photoData: Data?
    let primaryAction: AIResultPrimaryAction
    var showsMapButton: Bool = true
    var isMapLoading: Bool = false
    /// Reserves the image slot and shows a spinner while the cover loads.
    var showsPhotoPlaceholder: Bool = false
    var onMapTap: (() -> Void)? = nil
    @ViewBuilder var accessory: () -> Accessory
    
    init(
        title: String,
        subtitle: String,
        photoData: Data?,
        primaryAction: AIResultPrimaryAction,
        showsMapButton: Bool = true,
        isMapLoading: Bool = false,
        showsPhotoPlaceholder: Bool = false,
        onMapTap: (() -> Void)? = nil,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.photoData = photoData
        self.primaryAction = primaryAction
        self.showsMapButton = showsMapButton
        self.isMapLoading = isMapLoading
        self.showsPhotoPlaceholder = showsPhotoPlaceholder
        self.onMapTap = onMapTap
        self.accessory = accessory
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title.isEmpty ? "Untitled" : title)
                    .font(.app(17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.app(15, weight: .regular))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            accessory()
            
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 184)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            } else if showsPhotoPlaceholder {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                    ProgressView()
                        .controlSize(.regular)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 184)
                .accessibilityLabel("Loading photo")
            }
            
            HStack(alignment: .center, spacing: 10) {
                primaryActionButton
                Spacer(minLength: 0)
                if showsMapButton, let onMapTap {
                    AIResultMapIconButton(isLoading: isMapLoading, action: onMapTap)
                }
            }
        }
    }
    
    @ViewBuilder
    private var primaryActionButton: some View {
        switch primaryAction {
        case .savePlace(let isOn):
            AIResultActionCapsule(
                title: isOn.wrappedValue ? "Saved to Places" : "Save to Places",
                systemImage: "mappin"
            ) {
                // One-way save — not a checkbox like trip Include.
                guard !isOn.wrappedValue else { return }
                isOn.wrappedValue = true
            }
        case .include(let isOn):
            AIResultActionCapsule(
                title: isOn.wrappedValue ? "Included" : "Include",
                systemImage: isOn.wrappedValue ? "checkmark.circle.fill" : "circle"
            ) {
                isOn.wrappedValue.toggle()
            }
        }
    }
}

extension AIResultItemCard where Accessory == EmptyView {
    init(
        title: String,
        subtitle: String,
        photoData: Data?,
        primaryAction: AIResultPrimaryAction,
        showsMapButton: Bool = true,
        isMapLoading: Bool = false,
        showsPhotoPlaceholder: Bool = false,
        onMapTap: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            photoData: photoData,
            primaryAction: primaryAction,
            showsMapButton: showsMapButton,
            isMapLoading: isMapLoading,
            showsPhotoPlaceholder: showsPhotoPlaceholder,
            onMapTap: onMapTap,
            accessory: { EmptyView() }
        )
    }
}

struct AITripSummaryCard: View {
    let name: String
    let destination: String
    let datesText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            summaryRow(label: "Name", value: name)
            divider
            summaryRow(label: "Destination", value: destination)
            divider
            summaryRow(label: "Dates", value: datesText)
        }
    }
    
    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.10))
            .frame(height: 1)
    }
    
    private func summaryRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Text(label)
                .font(.app(15, weight: .regular))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Text(value.isEmpty ? "—" : value)
                .font(.app(15, weight: .regular))
                .foregroundStyle(.primary.opacity(0.50))
                .multilineTextAlignment(.trailing)
        }
    }
}

/// Shared list chrome for AI result sheets.
struct AIResultsListChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(.insetGrouped)
            .listSectionSpacing(15)
            .listRowSpacing(12)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
    }
}

extension View {
    func aiResultsListChrome() -> some View {
        modifier(AIResultsListChrome())
    }
    
    func aiResultItemRowBackground(isIncluded: Bool = true) -> some View {
        modifier(AIResultItemRowBackground(isIncluded: isIncluded))
    }
    
    func aiResultReplyRowBackground() -> some View {
        modifier(AIResultReplyRowBackground())
    }
}

private struct AIResultItemRowBackground: ViewModifier {
    var isIncluded: Bool = true
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardFill: Color {
        if colorScheme == .dark {
            return isIncluded ? Color(hex: 0x323234) : Color(hex: 0x252526)
        }
        return isIncluded ? Color(hex: 0xE8E8ED) : Color(hex: 0xF2F2F4).opacity(0.72)
    }
    
    func body(content: Content) -> some View {
        content
            .listRowInsets(EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20))
            .listRowBackground(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(cardFill)
                    .padding(.vertical, 4)
                    .animation(.easeOut(duration: 0.18), value: isIncluded)
            )
            .listRowSeparator(.hidden)
    }
}

private struct AIResultReplyRowBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

// MARK: - Apple Maps helpers

enum AIResultMaps {
    @MainActor
    static func openListing(
        for item: PlanDayItem,
        selectedMapItem: Binding<MKMapItem?>
    ) async {
        await openListing(
            title: item.title,
            location: item.location,
            latitude: item.latitude,
            longitude: item.longitude,
            selectedMapItem: selectedMapItem
        )
    }
    
    /// Resolves a place and presents the in-app Apple Maps preview sheet (never leaves the app).
    @MainActor
    static func openListing(
        title: String,
        location: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        selectedMapItem: Binding<MKMapItem?>
    ) async {
        let query = [title, location]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        guard !query.isEmpty || (latitude != nil && longitude != nil) else { return }
        
        if let mapItem = await searchMapItem(
            query: query,
            latitude: latitude,
            longitude: longitude
        ) {
            selectedMapItem.wrappedValue = mapItem
            return
        }
        
        if let fallback = fallbackMapItem(
            title: title,
            location: location,
            latitude: latitude,
            longitude: longitude
        ) {
            selectedMapItem.wrappedValue = fallback
        }
    }
    
    @MainActor
    private static func searchMapItem(
        query: String,
        latitude: Double?,
        longitude: Double?
    ) async -> MKMapItem? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.pointOfInterest, .address]
        if let latitude, let longitude {
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                latitudinalMeters: 8_000,
                longitudinalMeters: 8_000
            )
        }
        
        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.first
        } catch {
            return nil
        }
    }
    
    private static func fallbackMapItem(
        title: String,
        location: String,
        latitude: Double?,
        longitude: Double?
    ) -> MKMapItem? {
        guard let latitude, let longitude else { return nil }
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = location.trimmingCharacters(in: .whitespacesAndNewlines)
        mapItem.name = name.isEmpty ? (place.isEmpty ? "Place" : place) : name
        return mapItem
    }
    
    @MainActor
    static func loadCoverIfNeeded(into items: Binding<[PlanDayItem]>, id: UUID) async {
        guard let idx = items.wrappedValue.firstIndex(where: { $0.id == id }) else { return }
        guard items.wrappedValue[idx].photoData == nil else { return }
        guard items.wrappedValue[idx].canSaveToPlaces else { return }
        
        let current = items.wrappedValue[idx]
        let data = await PlaceAppleImagery.coverJPEG(
            name: current.title,
            location: current.location,
            latitude: current.latitude,
            longitude: current.longitude
        )
        guard let data,
              let latestIdx = items.wrappedValue.firstIndex(where: { $0.id == id }),
              items.wrappedValue[latestIdx].photoData == nil else { return }
        items.wrappedValue[latestIdx].photoData = data
    }
}

struct AIAppleMapsDetailSheetModifier: ViewModifier {
    @Binding var item: MKMapItem?
    
    func body(content: Content) -> some View {
        content.applePlaceCardSheet(item: $item)
    }
}

// MARK: - Places review

struct AIPlacesReviewView: View {
    @Binding var items: [PlanDayItem]
    var replyText: String = ""
    var onSavePlaces: ([PlanDayItem]) -> Void
    var onDone: () -> Void
    
    @State private var selectedAppleMapItem: MKMapItem?
    @State private var loadingMapsID: UUID?
    
    private var unsavedCount: Int {
        items.filter { !$0.include }.count
    }
    
    private var resolvedReply: String {
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return AIReplyCopy.places(itemCount: items.count, destinationHint: nil, items: items)
    }
    
    private var confirmTitle: String {
        unsavedCount == 0 ? "Done" : "Save All"
    }
    
    /// Place-type sections in Places-page order; unspecified maps to Other.
    private var placeTypeSections: [PlaceType] {
        let present = Set(items.map(resolvedPlaceType(for:)))
        return PlaceType.allCases.filter { present.contains($0) }
    }
    
    var body: some View {
        List {
            Section {
                AIResultReplyText(text: resolvedReply)
                    .aiResultReplyRowBackground()
            }
            
            ForEach(placeTypeSections) { type in
                Section {
                    ForEach(itemIndices(for: type), id: \.self) { index in
                        placeCard(at: index)
                    }
                } header: {
                    Text(sectionTitle(for: type))
                        .font(.app(15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.none)
                }
            }
        }
        .aiResultsListChrome()
        .navigationTitle("Places")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AIResultToolbarPill(title: confirmTitle, isEnabled: !items.isEmpty) {
                    saveAllAndFinish()
                }
            }
        }
        .modifier(AIAppleMapsDetailSheetModifier(item: $selectedAppleMapItem))
    }
    
    private func saveAllAndFinish() {
        let unsaved = items.filter { !$0.include }
        if !unsaved.isEmpty {
            for idx in items.indices where !items[idx].include {
                items[idx].include = true
            }
            onSavePlaces(unsaved)
        }
        onDone()
    }
    
    @ViewBuilder
    private func placeCard(at index: Int) -> some View {
        let itemID = items[index].id
        AIResultItemCard(
            title: items[index].title,
            subtitle: items[index].aiResultSubtitle,
            photoData: items[index].photoData,
            primaryAction: .savePlace(isOn: Binding(
                get: {
                    items.first(where: { $0.id == itemID })?.include ?? false
                },
                set: { newValue in
                    guard newValue,
                          let idx = items.firstIndex(where: { $0.id == itemID }),
                          !items[idx].include else { return }
                    items[idx].include = true
                    onSavePlaces([items[idx]])
                    Haptics.bump()
                }
            )),
            showsMapButton: items[index].canOpenInMaps,
            isMapLoading: loadingMapsID == itemID,
            showsPhotoPlaceholder: true,
            onMapTap: {
                Task {
                    loadingMapsID = itemID
                    defer { loadingMapsID = nil }
                    guard let latest = items.first(where: { $0.id == itemID }) else { return }
                    await AIResultMaps.openListing(
                        for: latest,
                        selectedMapItem: $selectedAppleMapItem
                    )
                }
            }
        )
        .aiResultItemRowBackground(isIncluded: true)
        .task(id: itemID) {
            await AIResultMaps.loadCoverIfNeeded(into: $items, id: itemID)
        }
    }
    
    private func resolvedPlaceType(for item: PlanDayItem) -> PlaceType {
        let type = PlaceType.fromAICategory(item.category)
        return type == .unspecified ? .other : type
    }
    
    private func sectionTitle(for type: PlaceType) -> String {
        type == .unspecified ? PlaceType.other.title : type.title
    }
    
    private func itemIndices(for type: PlaceType) -> [Int] {
        items.indices.filter { resolvedPlaceType(for: items[$0]) == type }
    }
}

// MARK: - Create trip review

struct AICreateTripReviewView: View {
    @State private var trip: AITripDraft
    @State private var items: [PlanDayItem]
    var replyText: String = ""
    
    var onConfirm: (AITripDraft, [PlanDayItem], [PlanDayItem]) -> Void
    
    @State private var selectedAppleMapItem: MKMapItem?
    @State private var loadingMapsID: UUID?
    
    init(
        trip: AITripDraft,
        alternatives: [AITripDraft] = [],
        seedItems: [PlanDayItem],
        replyText: String = "",
        onConfirm: @escaping (AITripDraft, [PlanDayItem], [PlanDayItem]) -> Void
    ) {
        self._trip = State(initialValue: trip)
        self._items = State(initialValue: seedItems.map { item in
            var copy = item
            copy.include = true
            return copy
        })
        self.replyText = replyText
        self.onConfirm = onConfirm
    }
    
    private var includedCount: Int {
        items.filter(\.include).count
    }
    
    private var canCreateTrip: Bool {
        !trip.destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !trip.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var resolvedReply: String {
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return AIReplyCopy.createTrip(trip: trip, itemCount: items.count)
    }
    
    private var datesSummary: String {
        if trip.isDatesSet {
            return dateRangeText
        }
        let days = max(1, trip.unscheduledDaysCount)
        return "\(days) day\(days == 1 ? "" : "s"), unscheduled"
    }
    
    private var resultSections: [AIResultSection] {
        let present = Set(items.map(AIResultSection.section(for:)))
        return AIResultSection.allCases.filter { present.contains($0) }
    }
    
    var body: some View {
        List {
            Section {
                AIResultReplyText(text: resolvedReply)
                    .aiResultReplyRowBackground()
            }
            
            Section {
                AITripSummaryCard(
                    name: trip.name,
                    destination: trip.destination,
                    datesText: datesSummary
                )
                .aiResultItemRowBackground()
            }
            
            ForEach(resultSections) { section in
                Section {
                    ForEach(itemIndices(for: section), id: \.self) { index in
                        tripItemCard(for: $items[index])
                    }
                } header: {
                    Text(section.title)
                        .font(.app(15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.none)
                }
            }
        }
        .aiResultsListChrome()
        .navigationTitle("New Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AIResultToolbarPill(title: "Create", isEnabled: canCreateTrip) {
                    finish()
                }
            }
        }
        .modifier(AIAppleMapsDetailSheetModifier(item: $selectedAppleMapItem))
    }
    
    @ViewBuilder
    private func tripItemCard(for item: Binding<PlanDayItem>) -> some View {
        AIResultItemCard(
            title: item.wrappedValue.title,
            subtitle: itemSubtitle(for: item.wrappedValue),
            photoData: item.wrappedValue.canSaveToPlaces ? item.wrappedValue.photoData : nil,
            primaryAction: .include(isOn: item.include),
            showsMapButton: item.wrappedValue.canOpenInMaps,
            isMapLoading: loadingMapsID == item.wrappedValue.id,
            showsPhotoPlaceholder: item.wrappedValue.canSaveToPlaces,
            onMapTap: {
                Task {
                    loadingMapsID = item.wrappedValue.id
                    defer { loadingMapsID = nil }
                    await AIResultMaps.openListing(
                        for: item.wrappedValue,
                        selectedMapItem: $selectedAppleMapItem
                    )
                }
            }
        )
        .aiResultItemRowBackground(isIncluded: item.wrappedValue.include)
        .task(id: item.wrappedValue.id) {
            await AIResultMaps.loadCoverIfNeeded(into: $items, id: item.wrappedValue.id)
        }
    }
    
    private func itemIndices(for section: AIResultSection) -> [Int] {
        items.indices.filter { AIResultSection.section(for: items[$0]) == section }
    }
    
    private func itemSubtitle(for item: PlanDayItem) -> String {
        let base = item.aiResultSubtitle
        let day = item.dayLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if day.isEmpty || day == base { return base }
        if base.isEmpty { return day }
        return base
    }
    
    private func finish() {
        let tripItems = items.filter(\.include).map { item in
            var copy = item
            copy.include = true
            return copy
        }
        onConfirm(trip, tripItems, [])
    }
    
    private var dateRangeText: String {
        let start = trip.startDate ?? "—"
        let end = trip.endDate ?? "—"
        return "\(start) → \(end)"
    }
}
