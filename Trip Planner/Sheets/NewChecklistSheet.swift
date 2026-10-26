import SwiftUI
import UIKit

struct NewChecklistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @Binding var title: String
    @Binding var items: [ChecklistEntry]
    @Binding var selectedDayID: UUID?
    let dayOptions: [DayOption]
    var isEditing: Bool = false
    var onSave: () -> Void
    var onDelete: (() -> Void)? = nil
    
    @State private var newItemText: String = ""
    @State private var isAddFieldFocused: Bool = false
    @State private var showCopiedToast = false
    @State private var copiedToastHideTask: Task<Void, Never>?
    @State private var showDeleteConfirm = false
    @FocusState private var isTitleFocused: Bool
    @FocusState private var focusedItemID: UUID?
    
    private let maxChecklistItemLength = 40
    private let addRowID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    
    private var selectedDayTitle: String {
        dayOptions.first(where: { $0.id == selectedDayID })?.title ?? ""
    }
    
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedDayID != nil
    }
    
    private var addTextIsEmpty: Bool {
        newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppDetailSurface.page(for: colorScheme)
                    .ignoresSafeArea()
                
                LinearGradient(
                    colors: [
                        ChecklistDetailPalette.gold.opacity(0.28),
                        ChecklistDetailPalette.gold.opacity(0.12),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 260)
                .ignoresSafeArea(edges: [.top, .horizontal])
                .allowsHitTesting(false)
                
                ScrollViewReader { proxy in
                    Form {
                        heroSection
                        daySection
                        itemsSection(proxy: proxy)
                        actionsSection
                    }
                    .scrollContentBackground(.hidden)
                    .appFormPageSpacing()
                    .listRowSpacing(2)
                    .environment(\.defaultMinListRowHeight, 1)
                    .onChange(of: isAddFieldFocused) { _, newValue in
                        guard newValue else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withTransaction(Transaction(animation: nil)) {
                                proxy.scrollTo(addRowID, anchor: .bottom)
                            }
                        }
                    }
                }
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
                        onSave()
                        dismiss()
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if showCopiedToast {
                    DetailToastBanner(text: "Copied to clipboard")
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showCopiedToast)
            .alert("Delete Checklist", isPresented: $showDeleteConfirm) {
                Button("Delete Checklist", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this checklist? This action cannot be undone.")
            }
        }
        .sheetAccentDragIndicator(ChecklistDetailPalette.gold)
    }
    
    private var heroSection: some View {
        Section {
            VStack(spacing: AppSpacing.sectionGap) {
                ZStack {
                    RoundedRectangle(cornerRadius: 35, style: .continuous)
                        .fill(ChecklistDetailPalette.gold)
                    AppIcon(
                        lucide: "list-checks",
                        size: 48,
                        color: ChecklistDetailPalette.ink
                    )
                }
                .frame(width: 120, height: 120)
                
                TextField(
                    "",
                    text: $title,
                    prompt: Text("Checklist")
                        .font(.appDisplay)
                        .foregroundStyle(AppColor.textWeak),
                    axis: .vertical
                )
                .font(.appDisplay)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColor.textStrong)
                .tint(AppColor.textStrong)
                .focused($isTitleFocused)
                .lineLimit(1...3)
                .scrollDisabled(true)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 18)
            }
            .frame(maxWidth: .infinity)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
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
    
    private func itemsSection(proxy: ScrollViewProxy) -> some View {
        Section {
            ForEach(items) { item in
                itemRow(item)
                    .id(item.id)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            toggleDone(itemID: item.id)
                        } label: {
                            swipeActionGlyph("circle-check-big")
                        }
                        .tint(AppColor.page)
                        
                        Button {
                            items.removeAll(where: { $0.id == item.id })
                        } label: {
                            swipeActionGlyph("trash-2")
                        }
                        .tint(AppColor.page)
                    }
                    }
            
            addItemRow(proxy: proxy)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .id(addRowID)
        }
        .listRowSpacing(2)
    }
    
    private func itemRow(_ item: ChecklistEntry) -> some View {
        let itemID = item.id
        let isDone = items.first(where: { $0.id == itemID })?.isDone ?? false
        
        return HStack(spacing: 8) {
            Button {
                toggleDone(itemID: itemID)
            } label: {
                AppIcon(
                    lucide: isDone ? "circle-check-big" : "circle",
                    size: AppLucide.fieldSize,
                    color: isDone ? AppColor.textStrong : AppColor.textWeak
                )
            }
            .buttonStyle(.plain)
            
            TextField(
                "",
                text: Binding(
                    get: { items.first(where: { $0.id == itemID })?.text ?? "" },
                    set: { newValue in
                        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
                        items[idx].text = Self.clampedChecklistItemText(
                            newValue,
                            maxLength: maxChecklistItemLength
                        )
                    }
                ),
                prompt: Text("Item").foregroundStyle(AppColor.textWeak)
            )
            .font(.app(15, weight: .medium))
            .foregroundStyle(isDone ? AppColor.textStrong : AppColor.textWeak)
            .focused($focusedItemID, equals: itemID)
            .lineLimit(1)
            .onTapGesture {
                focusedItemID = itemID
            }
        }
        .padding(AppSpacing.fieldPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (isDone ? AppColor.elevated : AppColor.card),
            in: Capsule(style: .continuous)
        )
        .contentShape(Capsule(style: .continuous))
    }
    
    private func addItemRow(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 8) {
            AppIcon(
                lucide: "circle-plus",
                size: AppLucide.fieldSize,
                color: isAddFieldFocused ? AppColor.textStrong : AppColor.textWeak
            )
            
            ReturnKeyTextField(
                placeholder: "Add item",
                text: $newItemText,
                isFirstResponder: $isAddFieldFocused,
                autocapitalization: .sentences,
                maxLength: maxChecklistItemLength
            ) {
                addNewChecklistItem(proxy: proxy)
            }
            .onTapGesture {
                isAddFieldFocused = true
            }
            
            Spacer(minLength: 0)
                .allowsHitTesting(false)
            
            Button("Add") {
                addNewChecklistItem(proxy: proxy)
            }
            .font(.app(15, weight: .medium))
            .foregroundStyle(addTextIsEmpty ? AppColor.textWeak : AppColor.textStrong)
            .disabled(addTextIsEmpty)
        }
        .padding(AppSpacing.fieldPadding)
        .background(AppColor.card, in: Capsule(style: .continuous))
        .contentShape(Capsule(style: .continuous))
    }
    
    private var actionsSection: some View {
        Section {
            HStack(spacing: AppSpacing.xs) {
                DetailIconPillButton(
                    lucide: "copy",
                    accessibilityLabel: "Copy Checklist"
                ) {
                    copyChecklistToClipboard()
                }
                
                if isEditing {
                    DetailIconPillButton(
                        lucide: "trash-2",
                        iconColor: AppColor.destructive,
                        fill: AppColor.destructive.opacity(colorScheme == .dark ? 0.25 : 0.14),
                        accessibilityLabel: "Delete"
                    ) {
                        showDeleteConfirm = true
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }
    
    private func copyChecklistToClipboard() {
        UIPasteboard.general.string = clipboardText
        Haptics.bump()
        showCopiedToast = true
        copiedToastHideTask?.cancel()
        copiedToastHideTask = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            showCopiedToast = false
        }
    }
    
    private var clipboardText: String {
        var lines: [String] = []
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            lines.append(trimmedTitle)
        }
        if !selectedDayTitle.isEmpty {
            lines.append(selectedDayTitle)
        }
        if !lines.isEmpty {
            lines.append("")
        }
        for item in items {
            let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            lines.append(item.isDone ? "✓ \(text)" : text)
        }
        return lines.joined(separator: "\n")
    }
    
    @ViewBuilder
    private func swipeActionGlyph(_ lucide: String) -> some View {
        if let image = AppLucide.templateImage(lucide: lucide, pointSize: AppLucide.fieldSize) {
            Image(uiImage: image)
                .renderingMode(.template)
        } else {
            Image(systemName: lucide == "trash-2" ? "trash" : "checkmark.circle")
        }
    }
    
    private func toggleDone(itemID: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        let wasDone = items[idx].isDone
        items[idx].isDone.toggle()
        if !wasDone, items[idx].isDone { Haptics.bump() }
    }
    
    private func addNewChecklistItem(proxy: ScrollViewProxy) {
        let t = Self.clampedChecklistItemText(
            newItemText.trimmingCharacters(in: .whitespacesAndNewlines),
            maxLength: maxChecklistItemLength
        )
        guard !t.isEmpty else { return }
        items.append(ChecklistEntry(id: UUID(), text: t, isDone: false))
        newItemText = ""
        isAddFieldFocused = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            withTransaction(Transaction(animation: nil)) {
                proxy.scrollTo(addRowID, anchor: .bottom)
            }
        }
    }
    
    private static func clampedChecklistItemText(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        return String(text.prefix(maxLength))
    }
}

private enum ChecklistDetailPalette {
    static let gold = Color(hex: 0xFED353)
    static let ink = Color(hex: 0x0A0A0A)
}
