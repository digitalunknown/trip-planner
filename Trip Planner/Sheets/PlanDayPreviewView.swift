import SwiftUI

struct PlanDayPreviewView: View {
    @State private var draft: PlanDayDraft
    let dayOptions: [DayOption]
    let onCancel: () -> Void
    let onConfirm: ([PlanDayItem]) -> Void
    
    init(
        draft: PlanDayDraft,
        dayOptions: [DayOption],
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
        self._draft = State(initialValue: d)
        self.dayOptions = dayOptions
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }
    
    var body: some View {
        List {
            ForEach(draft.items) { item in
                Section {
                    PlanDayItemEditor(
                        item: binding(for: item.id),
                        dayOptions: dayOptions
                    )
                }
            }
        }
        .listSectionSpacing(16)
        .navigationTitle("Suggestions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add \(includedCount)") { onConfirm(draft.items.filter(\.include)) }
                    .disabled(!canConfirm)
            }
        }
    }
    
    private var canConfirm: Bool {
        !draft.items.filter(\.include).contains(where: { $0.dayID == nil })
    }
    
    private var includedCount: Int {
        draft.items.filter(\.include).count
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
    @Environment(\.appAccentColor) private var appAccentColor
    @Binding var item: PlanDayItem
    let dayOptions: [DayOption]
    
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
                
                Toggle("", isOn: $item.include)
                    .labelsHidden()
                    .tint(appAccentColor)
            }
            
            Text(item.title.isEmpty ? "Untitled" : item.title)
                .font(.appHeadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            
            if item.kind == .activity {
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
            
            if item.include {
                if item.kind == .activity {
                    let hasContext = !item.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    let hasLocation = !item.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    if hasContext || hasLocation {
                        Divider()
                    }
                } else if item.kind == .flight {
                    Divider()
                } else if item.kind == .checklist {
                    if !item.checklistItemsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !item.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Divider()
                    }
                } else if item.kind == .reminder {
                    if !item.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Divider()
                    }
                }
                
                dayPicker
            }
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
        }
    }
    
    private func iconName(for kind: PlanDayItemKind) -> String {
        switch kind {
        case .activity: return "calendar"
        case .reminder: return "pin.fill"
        case .checklist: return "checklist.checked"
        case .flight: return "airplane"
        }
    }
}

