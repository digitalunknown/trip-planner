import SwiftUI

struct AIPlacesReviewView: View {
    @Binding var items: [PlanDayItem]
    var onConfirm: ([PlanDayItem]) -> Void
    
    @Environment(\.appAccentColor) private var appAccentColor
    
    private var includedCount: Int {
        items.filter(\.include).count
    }
    
    var body: some View {
        List {
            ForEach($items) { $item in
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
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
                        }
                        Spacer(minLength: 0)
                        Toggle("", isOn: $item.include)
                            .labelsHidden()
                            .tint(appAccentColor)
                    }
                }
            }
        }
        .navigationTitle("Places")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save \(includedCount)") {
                    onConfirm(items.filter(\.include))
                }
                .disabled(includedCount == 0)
            }
        }
    }
}

struct AICreateTripReviewView: View {
    @State private var selectedTrip: AITripDraft
    let alternatives: [AITripDraft]
    let seedItems: [PlanDayItem]
    var onConfirm: (AITripDraft, [PlanDayItem]) -> Void
    
    init(
        trip: AITripDraft,
        alternatives: [AITripDraft],
        seedItems: [PlanDayItem],
        onConfirm: @escaping (AITripDraft, [PlanDayItem]) -> Void
    ) {
        self._selectedTrip = State(initialValue: trip)
        self.alternatives = alternatives
        self.seedItems = seedItems
        self.onConfirm = onConfirm
    }
    
    private var allOptions: [AITripDraft] {
        var seen = Set<String>()
        var result: [AITripDraft] = []
        for draft in [selectedTrip] + alternatives {
            let key = draft.id
            if seen.insert(key).inserted {
                result.append(draft)
            }
        }
        return result
    }
    
    var body: some View {
        List {
            if allOptions.count > 1 {
                Section("Choose a trip") {
                    ForEach(allOptions) { option in
                        Button {
                            selectedTrip = option
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: option.id == selectedTrip.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(option.id == selectedTrip.id ? Color.accentColor : .secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(option.name.isEmpty ? "Untitled trip" : option.name)
                                        .font(.appHeadline)
                                        .foregroundStyle(.primary)
                                    Text(option.destination)
                                        .font(.appCaption)
                                        .foregroundStyle(.secondary)
                                    if !option.summary.isEmpty {
                                        Text(option.summary)
                                            .font(.appCaption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Section("Trip") {
                LabeledContent("Name", value: selectedTrip.name.isEmpty ? "—" : selectedTrip.name)
                LabeledContent("Destination", value: selectedTrip.destination.isEmpty ? "—" : selectedTrip.destination)
                if selectedTrip.isDatesSet {
                    LabeledContent("Dates", value: dateRangeText)
                } else {
                    LabeledContent("Days", value: "\(max(1, selectedTrip.unscheduledDaysCount)) unscheduled")
                }
                if !selectedTrip.summary.isEmpty {
                    Text(selectedTrip.summary)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if !seedItems.isEmpty {
                Section("Starter ideas (\(seedItems.count))") {
                    ForEach(seedItems.prefix(8)) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.app(14, weight: .semibold))
                            if !item.dayLabel.isEmpty {
                                Text(item.dayLabel)
                                    .font(.appCaption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("New Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Create") {
                    onConfirm(selectedTrip, seedItems)
                }
                .disabled(selectedTrip.destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          && selectedTrip.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    private var dateRangeText: String {
        let start = selectedTrip.startDate ?? "—"
        let end = selectedTrip.endDate ?? "—"
        return "\(start) → \(end)"
    }
}
