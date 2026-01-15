import SwiftUI

struct AddManySheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let title: String
    let onAdd: ([String]) -> Void
    
    private struct Entry: Identifiable, Hashable {
        let id: UUID
        var text: String
    }
    
    @State private var newItemText: String = ""
    @State private var items: [Entry] = []
    @State private var isAddFieldFocused: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    Section("Items") {
                        ForEach(items) { item in
                            TextField(
                                "Activity",
                                text: Binding(
                                    get: { items.first(where: { $0.id == item.id })?.text ?? "" },
                                    set: { newValue in
                                        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
                                        items[idx].text = newValue
                                    }
                                )
                            )
                            .textInputAutocapitalization(.sentences)
                            .id(item.id)
                        }
                        .onDelete { offsets in
                            items.remove(atOffsets: offsets)
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.secondary)
                            ReturnKeyTextField(
                                placeholder: "Add activity",
                                text: $newItemText,
                                isFirstResponder: $isAddFieldFocused,
                                autocapitalization: .sentences
                            ) {
                                addNewItem(proxy: proxy)
                            }
                            Button("Add") {
                                addNewItem(proxy: proxy)
                            }
                            .disabled(newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .id(addRowID)
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
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isAddFieldFocused = true
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add \(addCount)") {
                        commit()
                    }
                    .disabled(addCount == 0)
                }
            }
        }
    }
    
    private var addRowID: UUID { UUID(uuidString: "00000000-0000-0000-0000-000000000001")! }
    
    private var addCount: Int {
        let cleaned = items.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let draft = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.count + (draft.isEmpty ? 0 : 1)
    }
    
    private func addNewItem(proxy: ScrollViewProxy) {
        let t = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let newID = UUID()
        items.append(Entry(id: newID, text: t))
        newItemText = ""
        isAddFieldFocused = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            withTransaction(Transaction(animation: nil)) {
                proxy.scrollTo(addRowID, anchor: .bottom)
            }
        }
    }
    
    private func commit() {
        var all = items.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let draft = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !draft.isEmpty {
            all.append(draft)
        }
        guard !all.isEmpty else { return }
        onAdd(all)
        dismiss()
    }
}

