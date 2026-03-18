import SwiftUI

struct ExtractionReviewSheet: View {
    let suggestions: [DocumentTextExtractor.SuggestedField]
    let allowedFieldTypes: Set<DocumentTextExtractor.SuggestedFieldType>?
    let onApplySelected: ([DocumentTextExtractor.SuggestedField]) -> Void
    let onSkip: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs: Set<UUID>

    init(
        suggestions: [DocumentTextExtractor.SuggestedField],
        allowedFieldTypes: Set<DocumentTextExtractor.SuggestedFieldType>? = nil,
        onApplySelected: @escaping ([DocumentTextExtractor.SuggestedField]) -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.suggestions = suggestions
        self.allowedFieldTypes = allowedFieldTypes
        self.onApplySelected = onApplySelected
        self.onSkip = onSkip
        let highConfidence = suggestions.filter { $0.confidence == .high }.map(\.id)
        let initialSelection = highConfidence.isEmpty ? suggestions.map(\.id) : highConfidence
        self._selectedIDs = State(initialValue: Set(initialSelection))
    }

    private var visibleSuggestions: [DocumentTextExtractor.SuggestedField] {
        guard let allowedFieldTypes else { return suggestions }
        return suggestions.filter { allowedFieldTypes.contains($0.type) }
    }

    private var selectedSuggestions: [DocumentTextExtractor.SuggestedField] {
        visibleSuggestions.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                Text("Review extracted fields and choose what to apply.")
                    .font(.appFootnote)
                    .foregroundStyle(.secondary)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)

                if visibleSuggestions.isEmpty {
                    Section {
                        Text("No structured fields found. You can still add leftover notes.")
                            .font(.appFootnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Detected fields") {
                        ForEach(visibleSuggestions) { suggestion in
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle(isOn: Binding(
                                    get: { selectedIDs.contains(suggestion.id) },
                                    set: { enabled in
                                        if enabled {
                                            if shouldAllowOnlyOneSelection(for: suggestion.type) {
                                                let sameTypeIDs = visibleSuggestions
                                                    .filter { $0.type == suggestion.type }
                                                    .map(\.id)
                                                selectedIDs.subtract(sameTypeIDs)
                                            }
                                            selectedIDs.insert(suggestion.id)
                                        } else {
                                            selectedIDs.remove(suggestion.id)
                                        }
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                                            Text(suggestion.title)
                                                .font(.appSubheadline)
                                            confidenceBadge(suggestion.confidence)
                                        }
                                        Text(suggestion.value)
                                            .font(.appBody)
                                            .foregroundStyle(.primary)
                                    }
                                }
                                .toggleStyle(.switch)
                                .tint(.orange)

                                if let source = suggestion.sourceDocumentName, !source.isEmpty {
                                    Text("Source: \(source)")
                                        .font(.appCaption)
                                        .foregroundStyle(.secondary)
                                }
                                if let snippet = suggestion.sourceSnippet,
                                   !snippet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(snippet)
                                        .font(.appCaption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Review extraction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip") {
                        onSkip()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        onApplySelected(selectedSuggestions)
                        dismiss()
                    }
                    .disabled(selectedSuggestions.isEmpty && !visibleSuggestions.isEmpty)
                }
            }
        }
    }

    private func confidenceBadge(_ confidence: DocumentTextExtractor.Confidence) -> some View {
        let color = confidenceColor(confidence)

        return Text(confidence.label)
            .font(.appCaption)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.16))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func confidenceColor(_ confidence: DocumentTextExtractor.Confidence) -> Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .secondary
        }
    }

    private func shouldAllowOnlyOneSelection(for type: DocumentTextExtractor.SuggestedFieldType) -> Bool {
        switch type {
        case .cost, .currencyCode, .startTime, .endTime, .referenceCode:
            return true
        }
    }
}
