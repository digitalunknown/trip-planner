import SwiftUI

struct NewReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var reminderText: String
    @Binding var selectedDayID: UUID?
    let dayOptions: [DayOption]
    var isEditing: Bool = false
    var onAdd: () -> Void
    var onDelete: (() -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Day", selection: $selectedDayID) {
                        ForEach(dayOptions) { option in
                            Text(option.title)
                                .tag(Optional(option.id))
                        }
                    }
                }
                
                Section {
                    HStack {
                        TextField("Add a reminder", text: $reminderText)
                        if !reminderText.isEmpty {
                            Button {
                                reminderText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                if isEditing {
                    DetailActionButtonStack {
                        Button {
                            onDelete?()
                            dismiss()
                        } label: {
                            Label("Delete Reminder", systemImage: "trash")
                        }
                        .buttonStyle(.destructiveCapsuleBlock)
                        .detailActionRow()
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Reminder" : "Add Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    LiquidGlassIconButton(
                        systemName: "checkmark",
                        isEnabled: {
                            let textOK = !reminderText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            return textOK && selectedDayID != nil
                        }()
                    ) {
                        onAdd()
                        dismiss()
                    }
                }
            }
        }
    }
}

