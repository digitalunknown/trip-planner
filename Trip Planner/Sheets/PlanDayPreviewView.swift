import SwiftUI

struct PlanDayPreviewView: View {
    @State private var draft: PlanDayDraft
    @State private var addedIDs: Set<UUID> = []
    let dayOptions: [DayOption]
    var intent: String = ""
    let onCancel: () -> Void
    let onConfirm: ([PlanDayItem]) -> Void
    
    init(
        draft: PlanDayDraft,
        dayOptions: [DayOption],
        intent: String = "",
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
            d.items[idx].include = false
        }
        self._draft = State(initialValue: d)
        self.dayOptions = dayOptions
        self.intent = intent
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }
    
    private var sections: [(section: AIResultSection, items: [PlanDayItem])] {
        AIResultSection.grouped(draft.items)
    }
    
    private var canConfirm: Bool {
        !draft.items.filter { addedIDs.contains($0.id) }.contains(where: { $0.dayID == nil })
    }
    
    var body: some View {
        List {
            if !intent.isEmpty {
                Section {
                    Text(intentLabel)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(sections, id: \.section.id) { group in
                Section(group.section.title) {
                    ForEach(group.items) { item in
                        PlanDayItemEditor(
                            item: binding(for: item.id),
                            dayOptions: dayOptions,
                            isAdded: addedIDs.contains(item.id),
                            onAdd: { markAdded(item.id) }
                        )
                    }
                }
            }
        }
        .navigationTitle("Suggestions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if !addedIDs.isEmpty && addedIDs.count < draft.items.count {
                        Button("Done") {
                            onConfirm(draft.items.filter { addedIDs.contains($0.id) }.map { item in
                                var copy = item
                                copy.include = true
                                return copy
                            })
                        }
                        .disabled(!canConfirm)
                    }
                    Button("Add All") {
                        for item in draft.items {
                            markAdded(item.id)
                        }
                        onConfirm(draft.items.map { item in
                            var copy = item
                            copy.include = true
                            return copy
                        })
                    }
                    .disabled(draft.items.isEmpty || !canConfirm)
                }
            }
        }
    }
    
    private var intentLabel: String {
        switch intent {
        case "day_plan": return "Full day plan"
        case "multi_day_plan": return "Multi-day plan"
        case "options_list": return "Options to choose from"
        case "checklist": return "Checklist"
        case "reminder": return "Reminders"
        case "flight": return "Travel"
        case "full_itinerary": return "Full itinerary"
        case "get_started": return "Starter ideas"
        default: return intent.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
    
    private func markAdded(_ id: UUID) {
        addedIDs.insert(id)
        if let idx = draft.items.firstIndex(where: { $0.id == id }) {
            draft.items[idx].include = true
        }
    }
    
    private func binding(for id: UUID) -> Binding<PlanDayItem> {
        Binding(
            get: {
                draft.items.first(where: { $0.id == id }) ?? PlanDayItem(kind: .activity, title: "")
            },
            set: { newValue in
                if let idx = draft.items.firstIndex(where: { $0.id == id }) {
                    draft.items[idx] = newValue
                }
            }
        )
    }
}

private struct PlanDayItemEditor: View {
    @Binding var item: PlanDayItem
    let dayOptions: [DayOption]
    let isAdded: Bool
    let onAdd: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: iconName(for: item.kind))
                    Text(kindTitle(item.kind))
                }
                .font(.appCallout)
                .foregroundStyle(.primary)
                
                Spacer(minLength: 0)
            }
            
            Text(item.title.isEmpty ? "Untitled" : item.title)
                .font(.appHeadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            
            if item.kind == .activity || item.kind == .place {
                if !item.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(item.location)
                        .font(.appCallout)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                
                if !item.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let hasLocation = !item.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    notesBox(item.notes)
                        .padding(.top, hasLocation ? -4 : 0)
                }
            } else if item.kind == .reminder {
                if !item.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    notesBox(item.notes)
                }
            } else if item.kind == .checklist {
                if !item.checklistItemsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(item.checklistItemsText)
                        .font(.appCallout)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                if !item.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    notesBox(item.notes)
                }
            } else if item.kind == .flight {
                flightSummaryRow
            }
            
            dayPicker
            
            AIAddActionButton(
                title: "Add to Trip",
                addedTitle: "Added to Trip",
                isAdded: isAdded,
                action: onAdd
            )
        }
        .padding(.vertical, 10)
    }

    private var dayPicker: some View {
        let fallback = dayOptions.first(where: { !$0.isParkedIdeas })?.id ?? dayOptions.first?.id ?? UUID()
        return Picker("Day", selection: Binding(get: { item.dayID ?? fallback }, set: { item.dayID = $0 })) {
            ForEach(dayOptions) { opt in
                Text(opt.title).tag(opt.id)
            }
        }
        .pickerStyle(.menu)
    }
    
    private var flightSummaryRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            let from = item.flightFromCode.trimmingCharacters(in: .whitespacesAndNewlines)
            let to = item.flightToCode.trimmingCharacters(in: .whitespacesAndNewlines)
            let number = item.flightNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !from.isEmpty || !to.isEmpty || !number.isEmpty {
                Text("\(from.isEmpty ? "—" : from) → \(to.isEmpty ? "—" : to)  \(number)")
                    .font(.app(16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Flight details")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if !item.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                notesBox(item.notes)
            }
        }
    }
    
    private func notesBox(_ text: String) -> some View {
        Text(text)
            .font(.appCallout)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
    }
    
    private func kindTitle(_ kind: PlanDayItemKind) -> String {
        switch kind {
        case .activity: return "Activity"
        case .reminder: return "Reminder"
        case .checklist: return "Checklist"
        case .flight: return "Flight"
        case .place: return "Place"
        }
    }
    
    private func iconName(for kind: PlanDayItemKind) -> String {
        switch kind {
        case .activity: return "calendar"
        case .reminder: return "pin.fill"
        case .checklist: return "checklist.checked"
        case .flight: return "airplane"
        case .place: return "mappin.and.ellipse"
        }
    }
}
