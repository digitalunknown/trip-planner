import SwiftUI
import UIKit

struct NewChecklistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    
    @Binding var title: String
    @Binding var items: [ChecklistEntry]
    @Binding var selectedDayID: UUID?
    let dayOptions: [DayOption]
    var isEditing: Bool = false
    var onSave: () -> Void
    var onDelete: (() -> Void)? = nil
    
    @State private var newItemText: String = ""
    @State private var isAddFieldFocused: Bool = false
    @State private var didCopyItems: Bool = false
    @FocusState private var isTitleFocused: Bool
    @FocusState private var focusedItemID: UUID?
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var pillBackground: Color { colorScheme == .dark ? Color(hex: 0x2C2C2E) : Color(hex: 0xE5E5EA) }
    private var pillHighlight: Color { colorScheme == .dark ? Color(hex: 0x3A3A3C) : Color(hex: 0xD1D1D6) }
    
    private let maxChecklistItemLength = 40
    private let addRowID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollViewReader { proxy in
                    Form {
                        Section {
                            VStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                                        .fill(Color(hex: 0xF9C842).opacity(0.18))
                                    AppIcon(
                                        lucide: "list-checks",
                                        size: 52,
                                        color: Color(hex: 0xF9C842)
                                    )
                                }
                                .frame(width: 112, height: 112)
                                
                                TextField(
                                    "",
                                    text: $title,
                                    prompt: Text("Checklist")
                                        .font(.app(40, weight: .semibold))
                                        .foregroundStyle(.secondary),
                                    axis: .vertical
                                )
                                .font(.app(40, weight: .semibold))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.primary)
                                .tint(appAccentColor)
                                .focused($isTitleFocused)
                                .padding(.horizontal, 18)
                                .frame(minHeight: 72, maxHeight: 120)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 6)
                            .padding(.bottom, 10)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        
                        Section {
                            Picker(selection: $selectedDayID) {
                                ForEach(dayOptions) { option in
                                    Text(option.title)
                                        .tag(Optional(option.id))
                                }
                            } label: {
                                Label("Day", appIcon: "calendar", color: .primary)
                            }
                        }
                        
                        Section {
                            ForEach(items) { item in
                                let itemID = item.id
                                let isDone = items.first(where: { $0.id == itemID })?.isDone ?? false
                                let isFocused = focusedItemID == itemID
                                
                                Button {
                                    guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
                                    let wasDone = items[idx].isDone
                                    items[idx].isDone.toggle()
                                    if !wasDone, items[idx].isDone { Haptics.bump() }
                                } label: {
                                    HStack(spacing: 12) {
                                        AppIcon(
                                            lucide: isDone ? "circle-check-big" : "circle",
                                            size: 20,
                                            color: textPrimary
                                        )
                                        
                                        HStack(spacing: 0) {
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
                                                prompt: Text("Item").foregroundStyle(.secondary)
                                            )
                                            .foregroundStyle(textPrimary)
                                            .focused($focusedItemID, equals: itemID)
                                            .strikethrough(isDone, color: textPrimary.opacity(0.6))
                                            .lineLimit(1)
                                            .onTapGesture {
                                                focusedItemID = itemID
                                            }
                                            
                                            Spacer(minLength: 0)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        Capsule()
                                            .fill(isDone || isFocused ? pillHighlight : pillBackground)
                                    )
                                    .contentShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .id(itemID)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
                                        let wasDone = items[idx].isDone
                                        items[idx].isDone = !wasDone
                                        if !wasDone, items[idx].isDone { Haptics.bump() }
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(Color.orange)
                                            AppIcon(
                                                lucide: isDone ? "undo-2" : "check",
                                                size: 18,
                                                color: .white
                                            )
                                        }
                                        .frame(width: 44, height: 44)
                                    }
                                    .tint(.clear)
                                    
                                    Button {
                                        items.removeAll(where: { $0.id == itemID })
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(Color.red)
                                            AppIcon(lucide: "trash-2", size: 18, color: .white)
                                        }
                                        .frame(width: 44, height: 44)
                                    }
                                    .tint(.clear)
                                }
                            }
                            .onDelete { offsets in
                                for offset in offsets.sorted(by: >) where offset < items.count {
                                    items.remove(at: offset)
                                }
                            }
                            
                            Button {
                                // No-op — only the text field / Add control focus & commit.
                            } label: {
                                HStack(spacing: 12) {
                                    AppIcon(
                                        lucide: "circle-plus",
                                        size: 20,
                                        color: textPrimary
                                    )
                                    
                                    HStack(spacing: 0) {
                                        ReturnKeyTextField(
                                            placeholder: "Add item",
                                            text: $newItemText,
                                            isFirstResponder: $isAddFieldFocused,
                                            autocapitalization: .sentences,
                                            maxLength: maxChecklistItemLength
                                        ) {
                                            addNewChecklistItem(proxy: proxy)
                                        }
                                        .foregroundStyle(textPrimary)
                                        .onTapGesture {
                                            isAddFieldFocused = true
                                        }
                                        
                                        Spacer(minLength: 0)
                                            .allowsHitTesting(false)
                                        
                                        Button("Add") {
                                            addNewChecklistItem(proxy: proxy)
                                        }
                                        .font(.appCaption)
                                        .foregroundStyle(textPrimary)
                                        .disabled(newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(pillBackground)
                                )
                                .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .id(addRowID)
                        }
                        .listRowSpacing(1)
                        
                        DetailActionButtonStack {
                            Button {
                                let lines = items
                                    .map { entry -> String in
                                        let t = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
                                        guard !t.isEmpty else { return "" }
                                        return entry.isDone ? "✓ \(t)" : t
                                    }
                                    .filter { !$0.isEmpty }
                                
                                let payload = lines.joined(separator: "\n")
                                UIPasteboard.general.string = payload
                                Haptics.bump()
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    didCopyItems = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        didCopyItems = false
                                    }
                                }
                            } label: {
                                Label(
                                    didCopyItems ? "Copied" : "Copy Items",
                                    appIcon: didCopyItems ? "checkmark" : "doc.on.doc"
                                )
                            }
                            .buttonStyle(.secondaryCapsuleBlock)
                            .disabled(didCopyItems || items.isEmpty)
                            .detailActionRow()
                            
                            if isEditing {
                                Button {
                                    onDelete?()
                                    dismiss()
                                } label: {
                                    Label("Delete Checklist", appIcon: "trash")
                                }
                                .buttonStyle(.destructiveCapsuleBlock)
                                .detailActionRow()
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listRowSpacing(1)
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
                        isEnabled: !(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedDayID == nil)
                    ) {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
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

