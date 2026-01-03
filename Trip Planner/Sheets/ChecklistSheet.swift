import SwiftUI
import UIKit

struct ChecklistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var accentColor
    
    @Binding var title: String
    @Binding var items: [ChecklistEntry]
    @Binding var selectedDayID: UUID?
    let dayOptions: [DayOption]
    var isEditing: Bool = false
    var onSave: () -> Void
    
    @State private var newItemText: String = ""
    @FocusState private var focusedItemID: UUID?
    @State private var pendingDeleteItemID: UUID?
    @State private var didCopyItems: Bool = false
    
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
                                        .foregroundStyle(isDone ? accentColor : .secondary)
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
                                .focused($focusedItemID, equals: itemID)
                                
                                if focusedItemID == itemID {
                                    Button {
                                        pendingDeleteItemID = itemID
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .id(itemID)
                        }
                        .onDelete { offsets in
                            for offset in offsets.sorted(by: >) where offset < items.count {
                                items.remove(at: offset)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.secondary)
                            TextField("Add item", text: $newItemText)
                            Button("Add") {
                                let t = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !t.isEmpty else { return }
                                let newID = UUID()
                                items.append(ChecklistEntry(id: newID, text: t, isDone: false))
                                newItemText = ""
                                DispatchQueue.main.async {
                                    focusedItemID = newID
                                }
                            }
                            .disabled(newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
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
                                Label(didCopyItems ? "Copied" : "Copy Items", systemImage: "doc.on.doc")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .disabled(didCopyItems || items.isEmpty)
                    }
                }
                .onChange(of: focusedItemID) { _, newValue in
                    guard let id = newValue else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        guard items.contains(where: { $0.id == id }) else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
                .onChange(of: pendingDeleteItemID) { _, newValue in
                    guard let id = newValue else { return }
                    DispatchQueue.main.async {
                        if focusedItemID == id { focusedItemID = nil }
                        withAnimation(.easeInOut(duration: 0.15)) {
                            items.removeAll(where: { $0.id == id })
                        }
                        pendingDeleteItemID = nil
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
}

