import SwiftUI

struct TrackerDetailView: View {
    let type: TrackerType
    @ObservedObject var store: TrackerStore
    @State private var query: String = ""
    
    init(type: TrackerType, store: TrackerStore) {
        self.type = type
        self.store = store
    }

    private var items: [TrackerItem] {
        let all = TrackerData.items(for: type)
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = q.isEmpty ? all : all.filter { item in
            item.name.lowercased().contains(q) || (item.subtitle?.lowercased().contains(q) ?? false)
        }
        if type == .nationalParks {
            return filtered.sorted { $0.name < $1.name }
        }
        return filtered
    }
    
    private var progress: Double {
        let total = TrackerData.items(for: type).count
        guard total > 0 else { return 0 }
        return Double(store.visitedCount(in: type)) / Double(total)
    }

    var body: some View {
        List {
            progressSection
            searchSection
            itemsSection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .listRowSpacing(2)
        .environment(\.defaultMinListRowHeight, 1)
        .contentMargins(.horizontal, AppSpacing.pageInset, for: .scrollContent)
        .contentMargins(.vertical, AppSpacing.pageTop, for: .scrollContent)
        .background(AppDetailSurface.page)
        .navigationTitle(type.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .tint(.primary)
    }
    
    private var progressSection: some View {
        TrackerProgressBar(
            percent: progress,
            visitedCount: store.visitedCount(in: type),
            totalCount: TrackerData.items(for: type).count,
            barHeight: 40,
            unfilledColor: AppColor.elevated,
            useLargeTitle: true
        )
        .padding(.bottom, AppSpacing.sm)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    private var searchSection: some View {
        HStack(spacing: AppSpacing.controlIconGap) {
            AppIcon(lucide: "search", size: AppLucide.fieldSize, color: AppColor.textStrong)
            TextField("Search", text: $query)
                .font(.app(15, weight: .medium))
                .foregroundStyle(AppColor.textStrong)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    AppIcon(lucide: "circle-x", size: AppLucide.fieldSize, color: AppColor.textWeak)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(AppSpacing.fieldPadding)
        .background(AppColor.card, in: Capsule(style: .continuous))
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: AppSpacing.sm, trailing: 0))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    @ViewBuilder
    private var itemsSection: some View {
        if items.isEmpty {
            Text(query.isEmpty ? "No items" : "No matches")
                .font(.app(15, weight: .medium))
                .foregroundStyle(AppColor.textWeak)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.fieldPadding)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        } else {
            ForEach(items) { item in
                let visited = store.isVisited(item.id, in: type)
                Button {
                    toggleVisited(item)
                } label: {
                    TrackerItemRow(
                        title: item.name,
                        subtitle: item.subtitle,
                        isVisited: visited
                    )
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        toggleVisited(item)
                    } label: {
                        swipeActionGlyph(visited ? "circle" : "circle-check-big")
                    }
                    .tint(AppColor.page)
                }
            }
        }
    }
    
    private func toggleVisited(_ item: TrackerItem) {
        let wasVisited = store.isVisited(item.id, in: type)
        withAnimation(.easeInOut(duration: 0.12)) {
            store.toggleVisited(item.id, in: type)
        }
        if !wasVisited {
            Haptics.bump()
        }
    }
    
    @ViewBuilder
    private func swipeActionGlyph(_ lucide: String) -> some View {
        if let image = AppLucide.templateImage(lucide: lucide, pointSize: AppLucide.fieldSize) {
            Image(uiImage: image)
                .renderingMode(.template)
        } else {
            Image(systemName: lucide == "circle-check-big" ? "checkmark.circle" : "circle")
        }
    }
}

private struct TrackerItemRow: View {
    let title: String
    let subtitle: String?
    let isVisited: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            AppIcon(
                lucide: isVisited ? "circle-check-big" : "circle",
                size: AppLucide.fieldSize,
                color: isVisited ? AppColor.textStrong : AppColor.textWeak
            )
            
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.app(15, weight: .medium))
                    .foregroundStyle(isVisited ? AppColor.textStrong : AppColor.textWeak)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.app(13, weight: .medium))
                        .foregroundStyle(AppColor.textWeak)
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.fieldPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (isVisited ? AppColor.elevated : AppColor.card),
            in: Capsule(style: .continuous)
        )
        .contentShape(Capsule(style: .continuous))
    }
}
