import MapKit
import SwiftUI

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
}

struct AIAddActionButton: View {
    let title: String
    let addedTitle: String
    let isAdded: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(isAdded ? addedTitle : title)
                .font(.app(13, weight: .semibold))
                .foregroundStyle(isAdded ? Color.secondary : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(isAdded ? Color(.tertiarySystemFill) : Color(.secondarySystemFill))
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(isAdded ? Color.clear : Color(.separator).opacity(0.45), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(isAdded)
        .accessibilityLabel(isAdded ? addedTitle : title)
    }
}

// MARK: - Places review

struct AIPlacesReviewView: View {
    @Binding var items: [PlanDayItem]
    var onConfirm: ([PlanDayItem]) -> Void
    
    @State private var selectedAppleMapItem: MKMapItem?
    @State private var loadingMapsID: UUID?
    
    private var includedCount: Int {
        items.filter(\.include).count
    }
    
    private var sections: [(section: AIResultSection, items: [PlanDayItem])] {
        AIResultSection.grouped(items)
    }
    
    var body: some View {
        List {
            ForEach(sections, id: \.section.id) { group in
                Section(group.section.title) {
                    ForEach(group.items) { item in
                        placeRow(item)
                    }
                }
            }
        }
        .navigationTitle("Places")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if includedCount > 0 && includedCount < items.count {
                        Button("Done") {
                            onConfirm(items.filter(\.include))
                        }
                    }
                    Button("Add All") {
                        for idx in items.indices { items[idx].include = true }
                        onConfirm(items)
                    }
                    .disabled(items.isEmpty)
                }
            }
        }
        .modifier(AIAppleMapsDetailSheetModifier(item: $selectedAppleMapItem))
    }
    
    @ViewBuilder
    private func placeRow(_ item: PlanDayItem) -> some View {
        let binding = binding(for: item.id)
        VStack(alignment: .leading, spacing: 10) {
            Text(item.title.isEmpty ? "Untitled" : item.title)
                .font(.appHeadline)
            if !item.location.isEmpty {
                Text(item.location)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            if !item.notes.isEmpty {
                Text(item.notes)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            Text(PlaceType.fromAICategory(item.category).title)
                .font(.app(12, weight: .semibold))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                AIAddActionButton(
                    title: "Add to Places",
                    addedTitle: "Added to Places",
                    isAdded: binding.wrappedValue.include
                ) {
                    binding.wrappedValue.include = true
                }
                
                Button {
                    Task { await openAppleMapsListing(for: item) }
                } label: {
                    HStack(spacing: 6) {
                        if loadingMapsID == item.id {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "map")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        Text("Preview in Apple Maps")
                            .font(.app(13, weight: .semibold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(.secondarySystemFill))
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Color(.separator).opacity(0.45), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(loadingMapsID == item.id)
                .accessibilityLabel("Preview in Apple Maps")
            }
        }
        .padding(.vertical, 4)
    }
    
    private func binding(for id: UUID) -> Binding<PlanDayItem> {
        Binding(
            get: { items.first(where: { $0.id == id }) ?? PlanDayItem(kind: .place, title: "") },
            set: { newValue in
                if let idx = items.firstIndex(where: { $0.id == id }) {
                    items[idx] = newValue
                }
            }
        )
    }
    
    @MainActor
    private func openAppleMapsListing(for item: PlanDayItem) async {
        let query = [item.title, item.location]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        guard !query.isEmpty else { return }
        
        loadingMapsID = item.id
        defer { loadingMapsID = nil }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        
        do {
            let response = try await MKLocalSearch(request: request).start()
            if let mapItem = response.mapItems.first {
                if #available(iOS 18.0, *) {
                    selectedAppleMapItem = mapItem
                } else {
                    mapItem.openInMaps()
                }
                return
            }
        } catch {
            // Fall through to URL open.
        }
        
        var comps = URLComponents()
        comps.scheme = "maps"
        comps.host = ""
        comps.queryItems = [URLQueryItem(name: "q", value: query)]
        if let url = comps.url {
            await UIApplication.shared.open(url)
        }
    }
}

private struct AIAppleMapsDetailSheetModifier: ViewModifier {
    @Binding var item: MKMapItem?
    
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.mapItemDetailSheet(item: $item, displaysMap: true)
        } else {
            content
        }
    }
}

// MARK: - Create trip review

struct AICreateTripReviewView: View {
    @State private var trip: AITripDraft
    @State private var items: [PlanDayItem]
    @State private var addedToTripIDs: Set<UUID> = []
    @State private var addedToPlacesIDs: Set<UUID> = []
    
    var onConfirm: (AITripDraft, [PlanDayItem], [PlanDayItem]) -> Void
    
    init(
        trip: AITripDraft,
        alternatives: [AITripDraft] = [],
        seedItems: [PlanDayItem],
        onConfirm: @escaping (AITripDraft, [PlanDayItem], [PlanDayItem]) -> Void
    ) {
        self._trip = State(initialValue: trip)
        self._items = State(initialValue: seedItems.map { item in
            var copy = item
            copy.include = false
            return copy
        })
        self.onConfirm = onConfirm
    }
    
    private var sections: [(section: AIResultSection, items: [PlanDayItem])] {
        AIResultSection.grouped(items)
    }
    
    private var canCreateTrip: Bool {
        !trip.destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !trip.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        List {
            Section("Trip") {
                LabeledContent("Name", value: trip.name.isEmpty ? "—" : trip.name)
                LabeledContent("Destination", value: trip.destination.isEmpty ? "—" : trip.destination)
                if trip.isDatesSet {
                    LabeledContent("Dates", value: dateRangeText)
                } else {
                    LabeledContent("Days", value: "\(max(1, trip.unscheduledDaysCount)) unscheduled")
                }
                if !trip.summary.isEmpty {
                    Text(trip.summary)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            }
            
            ForEach(sections, id: \.section.id) { group in
                Section(group.section.title) {
                    ForEach(group.items) { item in
                        createTripItemRow(item)
                    }
                }
            }
        }
        .navigationTitle("New Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if !addedToTripIDs.isEmpty || !addedToPlacesIDs.isEmpty {
                        Button("Done") { finish() }
                    }
                    Button("Add All") {
                        addAll()
                    }
                    .disabled(!canCreateTrip)
                }
            }
        }
    }
    
    @ViewBuilder
    private func createTripItemRow(_ item: PlanDayItem) -> some View {
        let canSavePlace = itemCanSaveToPlaces(item)
        VStack(alignment: .leading, spacing: 10) {
            Text(item.title.isEmpty ? "Untitled" : item.title)
                .font(.appHeadline)
            
            if !item.dayLabel.isEmpty {
                Text(item.dayLabel)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            if !item.location.isEmpty {
                Text(item.location)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            if item.kind == .checklist, !item.checklistItemsText.isEmpty {
                Text(item.checklistItemsText)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            } else if !item.notes.isEmpty {
                Text(item.notes)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            
            HStack(spacing: 8) {
                AIAddActionButton(
                    title: "Add to Trip",
                    addedTitle: "Added to Trip",
                    isAdded: addedToTripIDs.contains(item.id)
                ) {
                    markAddedToTrip(item.id)
                }
                
                if canSavePlace {
                    AIAddActionButton(
                        title: "Add to Places",
                        addedTitle: "Added to Places",
                        isAdded: addedToPlacesIDs.contains(item.id)
                    ) {
                        markAddedToPlaces(item.id)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func itemCanSaveToPlaces(_ item: PlanDayItem) -> Bool {
        item.canSaveToPlaces
    }
    
    private func markAddedToTrip(_ id: UUID) {
        addedToTripIDs.insert(id)
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items[idx].include = true
        }
    }
    
    private func markAddedToPlaces(_ id: UUID) {
        addedToPlacesIDs.insert(id)
    }
    
    private func addAll() {
        for item in items {
            addedToTripIDs.insert(item.id)
        }
        for idx in items.indices {
            items[idx].include = true
        }
        finish()
    }
    
    private func finish() {
        let tripItems = items.filter { addedToTripIDs.contains($0.id) }.map { item in
            var copy = item
            copy.include = true
            return copy
        }
        let placeItems = items.filter { addedToPlacesIDs.contains($0.id) }.map { item in
            var copy = item
            copy.include = true
            return copy
        }
        // Always create the trip even if no seeds were selected.
        onConfirm(trip, tripItems, placeItems)
    }
    
    private var dateRangeText: String {
        let start = trip.startDate ?? "—"
        let end = trip.endDate ?? "—"
        return "\(start) → \(end)"
    }
}
