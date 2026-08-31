import MapKit
import SwiftUI

struct PlanDayPreviewView: View {
    @State private var draft: PlanDayDraft
    let dayOptions: [DayOption]
    var intent: String = ""
    var replyText: String = ""
    var destination: String = ""
    let onCancel: () -> Void
    let onConfirm: ([PlanDayItem]) -> Void
    
    @Environment(ExpertTipsStore.self) private var expertTips
    @State private var selectedAppleMapItem: MKMapItem?
    @State private var loadingMapsID: UUID?
    
    init(
        draft: PlanDayDraft,
        dayOptions: [DayOption],
        intent: String = "",
        replyText: String = "",
        destination: String = "",
        onCancel: @escaping () -> Void,
        onConfirm: @escaping ([PlanDayItem]) -> Void
    ) {
        var d = draft
        let defaultAssignID = dayOptions.first(where: { !$0.isParkedIdeas })?.id ?? dayOptions.first?.id
        if let defaultAssignID {
            for idx in d.items.indices {
                if d.items[idx].dayID == nil {
                    d.items[idx].dayID = defaultAssignID
                }
            }
        }
        for idx in d.items.indices {
            d.items[idx].include = true
        }
        self._draft = State(initialValue: d)
        self.dayOptions = dayOptions
        self.intent = intent
        self.replyText = replyText
        self.destination = destination
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }
    
    private var includedItems: [PlanDayItem] {
        draft.items.filter(\.include)
    }
    
    private var includedCount: Int { includedItems.count }
    
    private var canConfirm: Bool {
        !includedItems.isEmpty && !includedItems.contains(where: { $0.dayID == nil })
    }
    
    private var resolvedReply: String {
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return AIReplyCopy.planDay(
            intent: intent,
            itemCount: draft.items.count,
            destination: destination
        )
    }
    
    private var confirmTitle: String {
        if includedCount == 0 { return "Add" }
        if includedCount == draft.items.count { return "Add All" }
        return "Add \(includedCount)"
    }
    
    var body: some View {
        List {
            Section {
                AIResultReplyText(text: resolvedReply)
                    .aiResultReplyRowBackground()
            }
            
            ForEach($draft.items) { $item in
                Section {
                    let matchedTips = expertTips.tips(
                        title: item.title,
                        location: item.location,
                        latitude: item.latitude,
                        longitude: item.longitude
                    )
                    AIResultItemCard(
                        title: item.title,
                        subtitle: item.aiResultSubtitle,
                        photoData: item.canSaveToPlaces ? item.photoData : nil,
                        primaryAction: .include(isOn: $item.include),
                        showsMapButton: item.canOpenInMaps,
                        isMapLoading: loadingMapsID == item.id,
                        showsPhotoPlaceholder: item.canSaveToPlaces,
                        onMapTap: {
                            Task {
                                loadingMapsID = item.id
                                defer { loadingMapsID = nil }
                                await AIResultMaps.openListing(
                                    for: item,
                                    selectedMapItem: $selectedAppleMapItem
                                )
                            }
                        }
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            if dayOptions.count > 1 {
                                dayPicker(for: $item)
                            }
                            if let tip = matchedTips.first {
                                ExpertTipInlineCallout(tip: tip)
                            }
                        }
                    }
                    .aiResultItemRowBackground(isIncluded: item.include)
                    .task(id: item.id) {
                        await expertTips.refresh()
                        await AIResultMaps.loadCoverIfNeeded(into: $draft.items, id: item.id)
                    }
                }
            }
        }
        .aiResultsListChrome()
        .navigationTitle("Plan Day")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AIResultToolbarPill(title: confirmTitle, isEnabled: canConfirm) {
                    onConfirm(includedItems.map { item in
                        var copy = item
                        copy.include = true
                        return copy
                    })
                }
            }
        }
        .modifier(AIAppleMapsDetailSheetModifier(item: $selectedAppleMapItem))
    }
    
    private func dayPicker(for item: Binding<PlanDayItem>) -> some View {
        let fallback = dayOptions.first(where: { !$0.isParkedIdeas })?.id ?? dayOptions.first?.id ?? UUID()
        return Picker("Day", selection: Binding(
            get: { item.wrappedValue.dayID ?? fallback },
            set: { item.wrappedValue.dayID = $0 }
        )) {
            ForEach(dayOptions) { opt in
                Text(opt.title).tag(opt.id)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .tint(.primary)
    }
}
