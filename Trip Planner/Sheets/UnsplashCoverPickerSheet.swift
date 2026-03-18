import SwiftUI

struct UnsplashCoverPickerSheet: View {
    struct Selection {
        let imageData: Data
        let provider: String
        let photoId: String
        let photographerName: String
        let photographerURL: String
        let sourceURL: String
    }
    
    @Environment(\.dismiss) private var dismiss
    
    let initialQuery: String
    let client: UnsplashAPIClient
    let onSelect: (Selection) -> Void
    
    @State private var query: String = ""
    @State private var isLoading: Bool = false
    @State private var errorText: String?
    @State private var results: [UnsplashPhoto] = []
    @State private var isSelecting: Bool = false
    
    private let masonryColumns: Int = 2
    private let masonrySpacing: CGFloat = 10
    
    init(
        initialQuery: String,
        client: UnsplashAPIClient = UnsplashAPIClient(),
        onSelect: @escaping (Selection) -> Void
    ) {
        self.initialQuery = initialQuery
        self.client = client
        self.onSelect = onSelect
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                
                if let errorText {
                    Text(errorText)
                        .font(.appFootnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                }
                
                ScrollView(.vertical, showsIndicators: true) {
                    MasonryLayout(columns: masonryColumns, spacing: masonrySpacing) {
                        ForEach(results) { photo in
                            UnsplashPhotoTile(photo: photo) {
                                Task { await select(photo) }
                            }
                            .disabled(isSelecting)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .overlay {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.1)
                            .padding(18)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else if results.isEmpty {
                        VStack(spacing: 10) {
                            Text("Search Unsplash")
                                .font(.headline.weight(.semibold))
                            Text("Try a city, landmark, or vibe")
                                .font(.appSubheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            .navigationTitle("Unsplash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
            }
            .onAppear {
                if query.isEmpty {
                    query = initialQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                Task { await runSearchIfNeeded(force: true) }
            }
        }
        .tint(.primary)
    }
    
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search photos", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit {
                    Task { await runSearchIfNeeded(force: true) }
                }
            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                    errorText = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
        .overlay { Capsule().strokeBorder(Color(.separator).opacity(0.35)) }
        .onChange(of: query) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2 else { return }
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                await runSearchIfNeeded(force: false)
            }
        }
    }
    
    @MainActor
    private func runSearchIfNeeded(force: Bool) async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard force || q.count >= 2 else { return }
        guard !isLoading, !isSelecting else { return }
        guard !q.isEmpty else {
            results = []
            errorText = nil
            return
        }
        
        isLoading = true
        errorText = nil
        do {
            let response = try await client.searchPhotos(query: q, page: 1, perPage: 30)
            results = response.results.filter { ($0.urls.small ?? "").hasPrefix("http") && ($0.urls.regular ?? "").hasPrefix("http") }
            isLoading = false
        } catch {
            errorText = error.localizedDescription
            isLoading = false
        }
    }
    
    private func select(_ photo: UnsplashPhoto) async {
        guard !isSelecting else { return }
        guard let regular = photo.urls.regular, let regularURL = URL(string: regular) else { return }
        
        await MainActor.run {
            isSelecting = true
            errorText = nil
        }
        
        // Trigger download tracking (best-effort).
        if let dl = photo.download_location {
            Task.detached {
                try? await client.trackDownload(downloadLocation: dl)
            }
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: regularURL)
            let selection = Selection(
                imageData: data,
                provider: "unsplash",
                photoId: photo.id,
                photographerName: photo.user.name,
                photographerURL: photo.user.profile_url,
                sourceURL: photo.unsplash_url
            )
            await MainActor.run {
                onSelect(selection)
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorText = "Failed to download image.\n\n\(error.localizedDescription)"
                isSelecting = false
            }
        }
    }
}

private struct UnsplashPhotoTile: View {
    let photo: UnsplashPhoto
    let onTap: () -> Void
    
    private var aspectRatio: CGFloat {
        let w = CGFloat(photo.width ?? 1)
        let h = CGFloat(photo.height ?? 1)
        let ratio = (h == 0) ? 1 : (w / h)
        return min(max(ratio, 0.6), 1.8)
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                
                // Reserve height based on aspect ratio (masonry layout depends on this).
                Rectangle()
                    .fill(.clear)
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .overlay {
                        if let urlString = photo.urls.small, let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .scaleEffect(0.9)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure:
                                    Image(systemName: "photo")
                                        .foregroundStyle(.secondary)
                                @unknown default:
                                    Image(systemName: "photo")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .clipped()
                        } else {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color(.separator).opacity(0.35)) }
        }
        .buttonStyle(.plain)
    }
}

private struct MasonryLayout<Content: View>: View {
    let columns: Int
    let spacing: CGFloat
    @ViewBuilder let content: Content
    
    init(columns: Int, spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.columns = max(1, columns)
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        _MasonryLayout(columns: columns, spacing: spacing) {
            content
        }
    }
}

private struct _MasonryLayout: Layout {
    let columns: Int
    let spacing: CGFloat
    
    init(columns: Int, spacing: CGFloat) {
        self.columns = max(1, columns)
        self.spacing = spacing
    }
    
    struct Cache {
        var frames: [CGRect] = []
        var size: CGSize = .zero
    }
    
    func makeCache(subviews: Subviews) -> Cache { Cache(frames: Array(repeating: .zero, count: subviews.count), size: .zero) }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.width ?? 0
        guard width > 0, !subviews.isEmpty else {
            cache.frames = Array(repeating: .zero, count: subviews.count)
            cache.size = CGSize(width: width, height: 0)
            return cache.size
        }
        
        let colCount = columns
        let totalSpacing = spacing * CGFloat(max(0, colCount - 1))
        let colWidth = (width - totalSpacing) / CGFloat(colCount)
        
        var colHeights = Array(repeating: CGFloat(0), count: colCount)
        var frames = Array(repeating: CGRect.zero, count: subviews.count)
        
        for i in subviews.indices {
            let subview = subviews[i]
            let size = subview.sizeThatFits(.init(width: colWidth, height: nil))
            
            // Place in the currently shortest column.
            var targetCol = 0
            var minHeight = colHeights[0]
            for c in 1..<colCount {
                if colHeights[c] < minHeight {
                    minHeight = colHeights[c]
                    targetCol = c
                }
            }
            
            let x = CGFloat(targetCol) * (colWidth + spacing)
            let y = colHeights[targetCol]
            frames[i] = CGRect(x: x, y: y, width: colWidth, height: size.height)
            colHeights[targetCol] = y + size.height + spacing
        }
        
        let height = max(0, (colHeights.max() ?? 0) - spacing)
        cache.frames = frames
        cache.size = CGSize(width: width, height: height)
        return cache.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        if cache.frames.count != subviews.count {
            _ = sizeThatFits(proposal: proposal, subviews: subviews, cache: &cache)
        }
        
        for i in subviews.indices {
            let frame = cache.frames[i].offsetBy(dx: bounds.minX, dy: bounds.minY)
            subviews[i].place(
                at: frame.origin,
                proposal: ProposedViewSize(width: frame.size.width, height: frame.size.height)
            )
        }
    }
}

