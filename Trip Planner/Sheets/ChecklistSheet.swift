import SwiftUI
import UIKit

struct ChecklistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    
    @Binding var title: String
    @Binding var items: [ChecklistEntry]
    @Binding var selectedDayID: UUID?
    let dayOptions: [DayOption]
    var isEditing: Bool = false
    var onSave: () -> Void
    
    @State private var newItemText: String = ""
    @State private var isAddFieldFocused: Bool = false
    @State private var didCopyItems: Bool = false
    
    private let addRowID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    Section {
                        Picker("Day", selection: $selectedDayID) {
                            ForEach(dayOptions) { option in
                                Text(option.title)
                                    .tag(Optional(option.id))
                            }
                        }
                    }
                    
                    Section("Checklist") {
                        HStack {
                            TextField("Title", text: $title)
                            if !title.isEmpty {
                                Button {
                                    title = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Section("Items") {
                        ForEach(items) { item in
                            let itemID = item.id
                            HStack(spacing: 12) {
                                Button {
                                    guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
                                    let wasDone = items[idx].isDone
                                    items[idx].isDone.toggle()
                                    if !wasDone, items[idx].isDone { Haptics.bump() }
                                } label: {
                                    let isDone = items.first(where: { $0.id == itemID })?.isDone ?? false
                                    Image(systemName: isDone ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                
                                TextField(
                                    "Item",
                                    text: Binding(
                                        get: { items.first(where: { $0.id == itemID })?.text ?? "" },
                                        set: { newValue in
                                            guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
                                            items[idx].text = newValue
                                        }
                                    )
                                )
                            }
                            .id(itemID)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                let isDone = items.first(where: { $0.id == itemID })?.isDone ?? false
                                Button {
                                    guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
                                    let wasDone = items[idx].isDone
                                    items[idx].isDone = !wasDone
                                    if !wasDone, items[idx].isDone { Haptics.bump() }
                                } label: {
                                    Label(isDone ? "Undone" : "Done", systemImage: isDone ? "arrow.uturn.left" : "checkmark")
                                }
                                .tint(isDone ? Color.secondary : appAccentColor)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    items.removeAll(where: { $0.id == itemID })
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete { offsets in
                            for offset in offsets.sorted(by: >) where offset < items.count {
                                items.remove(at: offset)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.secondary)
                            ReturnKeyTextField(
                                placeholder: "Add item",
                                text: $newItemText,
                                isFirstResponder: $isAddFieldFocused,
                                autocapitalization: .sentences
                            ) {
                                addNewChecklistItem(proxy: proxy)
                            }
                            Button("Add") {
                                addNewChecklistItem(proxy: proxy)
                            }
                            .disabled(newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .id(addRowID)
                    }
                    
                    Section {
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
                            HStack {
                                Spacer()
                                Text(didCopyItems ? "Copied" : "Copy Items")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .disabled(didCopyItems || items.isEmpty)
                    }
                }
                .onChange(of: isAddFieldFocused) { _, newValue in
                    guard newValue else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withTransaction(Transaction(animation: nil)) {
                            proxy.scrollTo(addRowID, anchor: .bottom)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Checklist" : "New Checklist")
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
        let t = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
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
}

