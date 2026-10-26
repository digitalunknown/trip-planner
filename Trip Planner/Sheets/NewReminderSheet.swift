import SwiftUI

struct NewReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Binding var reminderText: String
    @Binding var selectedDayID: UUID?
    let dayOptions: [DayOption]
    var isEditing: Bool = false
    var onAdd: () -> Void
    var onDelete: (() -> Void)? = nil
    
    @State private var showDeleteConfirm = false
    @FocusState private var isReminderFocused: Bool
    
    private var selectedDayTitle: String {
        dayOptions.first(where: { $0.id == selectedDayID })?.title ?? ""
    }
    
    private var canSave: Bool {
        let textOK = !reminderText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return textOK && selectedDayID != nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppDetailSurface.page(for: colorScheme)
                    .ignoresSafeArea()
                
                LinearGradient(
                    colors: [
                        ReminderDetailPalette.cream.opacity(0.28),
                        ReminderDetailPalette.cream.opacity(0.12),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 260)
                .ignoresSafeArea(edges: [.top, .horizontal])
                .allowsHitTesting(false)
                
                Form {
                    reminderSection
                    daySection
                    if isEditing {
                        actionsSection
                    }
                }
                .scrollContentBackground(.hidden)
                .appFormPageSpacing()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    LiquidGlassIconButton(
                        systemName: "checkmark",
                        isEnabled: canSave
                    ) {
                        onAdd()
                        dismiss()
                    }
                }
            }
            .alert("Delete Reminder", isPresented: $showDeleteConfirm) {
                Button("Delete Reminder", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this reminder? This action cannot be undone.")
            }
        }
        .sheetAccentDragIndicator(ReminderDetailPalette.cream)
    }
    
    private var reminderSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                AppSectionHeader("Reminder")
                    .padding(.leading, 20)
                
                TextField("", text: $reminderText, axis: .vertical)
                    .font(.app(15, weight: .medium))
                    .foregroundStyle(AppColor.textStrong)
                    .lineLimit(3...12)
                    .textInputAutocapitalization(.sentences)
                    .focused($isReminderFocused)
                    .padding(AppSpacing.cardPadding)
                    .frame(minHeight: 100, alignment: .topLeading)
                    .background(
                        AppColor.card,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    private var daySection: some View {
        Section {
            Menu {
                ForEach(dayOptions) { option in
                    Button {
                        selectedDayID = option.id
                    } label: {
                        if option.id == selectedDayID {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    AppIcon(lucide: "calendar-1", size: AppLucide.fieldSize, color: AppColor.textStrong)
                    Text("Day")
                        .font(.app(15, weight: .medium))
                        .foregroundStyle(AppColor.textStrong)
                    Spacer(minLength: 8)
                    HStack(spacing: 5) {
                        Text(selectedDayTitle)
                            .font(.app(15, weight: .medium))
                            .foregroundStyle(AppColor.textStrong)
                            .lineLimit(1)
                        AppIcon(lucide: "chevrons-up-down", size: AppLucide.fieldSize, color: AppColor.textWeak)
                    }
                }
                .padding(AppSpacing.fieldPadding)
                .background(AppColor.card, in: Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }
    
    private var actionsSection: some View {
        Section {
            HStack(spacing: AppSpacing.xs) {
                DetailIconPillButton(
                    lucide: "trash-2",
                    iconColor: AppColor.destructive,
                    fill: AppColor.destructive.opacity(colorScheme == .dark ? 0.25 : 0.14),
                    accessibilityLabel: "Delete Reminder"
                ) {
                    showDeleteConfirm = true
                }
            }
            .frame(maxWidth: .infinity)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }
}

private enum ReminderDetailPalette {
    static let cream = EventAccent.cream.background
}
