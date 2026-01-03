import SwiftUI

struct AddReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var reminderText: String
    @Binding var selectedDayID: UUID?
    let dayOptions: [DayOption]
    var isEditing: Bool = false
    var onAdd: () -> Void
    
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
                
                Section("Reminder") {
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

