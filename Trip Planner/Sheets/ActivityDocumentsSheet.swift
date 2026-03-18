import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ActivityDocumentsSheet: View {
    let items: [TripSettingsSheet.DocumentItem]
    
    @State private var selectedDocumentForPreview: EventDocument?
    @State private var selectedImageForPreview: UIImage?
    
    private var groupedItems: [(title: String, subtitle: String, documents: [TripSettingsSheet.DocumentItem])] {
        let grouped = Dictionary(grouping: items) { item in
            "\(item.activityID.uuidString)|\(item.activityTitle)|\(item.dayLabel)"
        }
        return grouped.values
            .map { group in
                let first = group[0]
                let subtitle = first.isIdeas ? "Ideas" : first.dayLabel
                return (first.activityTitle, subtitle, group.sorted { $0.document.createdAt < $1.document.createdAt })
            }
            .sorted { lhs, rhs in
                if lhs.subtitle != rhs.subtitle { return lhs.subtitle < rhs.subtitle }
                return lhs.title < rhs.title
            }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(groupedItems.enumerated()), id: \.offset) { _, group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.title)
                                .font(.appSubheadline)
                                .foregroundStyle(.primary)
                            Text(group.subtitle)
                                .font(.appFootnote)
                                .foregroundStyle(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(group.documents, id: \.id) { item in
                                        Button {
                                            open(item.document)
                                        } label: {
                                            documentCard(item.document)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Documents")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedDocumentForPreview) { document in
                QuickLookPreview(url: ActivityDocumentStore.fileURL(for: document.localRelativePath))
            }
            .sheet(isPresented: Binding(
                get: { selectedImageForPreview != nil },
                set: { if !$0 { selectedImageForPreview = nil } }
            )) {
                if let selectedImageForPreview {
                    NavigationStack {
                        VStack {
                            Spacer(minLength: 0)
                            Image(uiImage: selectedImageForPreview)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            Spacer(minLength: 0)
                        }
                        .padding()
                        .navigationTitle("Preview")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                LiquidGlassIconButton(systemName: "xmark") {
                                    self.selectedImageForPreview = nil
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func isImageDocument(_ document: EventDocument) -> Bool {
        if let mime = document.mimeType?.lowercased(), mime.hasPrefix("image/") {
            return true
        }
        if let type = UTType(filenameExtension: document.fileExtension.lowercased()) {
            return type.conforms(to: .image)
        }
        return false
    }
    
    private func open(_ document: EventDocument) {
        if isImageDocument(document),
           let data = try? Data(contentsOf: ActivityDocumentStore.fileURL(for: document.localRelativePath)),
           let uiImage = UIImage(data: data) {
            selectedImageForPreview = uiImage
            return
        }
        selectedDocumentForPreview = document
    }
    
    private func documentCard(_ document: EventDocument) -> some View {
        let previewSize: CGFloat = 92
        return Group {
            if isImageDocument(document),
               let thumbnail = document.thumbnailData,
               let image = UIImage(data: thumbnail) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .overlay {
                        Image(systemName: "doc.fill")
                            .font(.app(18, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: previewSize, height: previewSize)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
