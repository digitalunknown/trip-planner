import SwiftUI

struct TrackerDetailView: View {
    let type: TrackerType
    @ObservedObject var store: TrackerStore
    @State private var query: String = ""
    @Environment(\.colorScheme) private var colorScheme
    
    private var dayBackground: Color { colorScheme == .dark ? Color(hex: 0x171717) : Color(hex: 0xF0F0F0) }
    private var columnStroke: Color { colorScheme == .dark ? Color(hex: 0x252525) : Color(hex: 0xFFFFFF) }
    private var textSecondary: Color {
        let primary = colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717)
        return primary.opacity(colorScheme == .dark ? 0.72 : 0.62)
    }
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var pillBackground: Color { colorScheme == .dark ? Color(hex: 0x2C2C2E) : Color(hex: 0xE5E5EA) }
    private var pillHighlight: Color { colorScheme == .dark ? Color(hex: 0x3A3A3C) : Color(hex: 0xD1D1D6) }
    
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
        SwiftUI.ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 10) {
                TrackerProgressBar(
                    percent: progress,
                    visitedCount: store.visitedCount(in: type),
                    totalCount: TrackerData.items(for: type).count,
                    barHeight: 40,
                    unfilledColor: columnStroke,
                    useLargeTitle: true
                )
                .padding(.top, 6)
                .padding(.bottom, 10)
                
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(textSecondary)
                    TextField("Search", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(dayBackground, in: Capsule())
                .overlay { Capsule().strokeBorder(columnStroke) }
                .padding(.bottom, 2)

                VStack(spacing: 1) {
                    ForEach(items.indices, id: \.self) { idx in
                        let item = items[idx]
                        TrackerItemRow(
                            title: item.name,
                            subtitle: item.subtitle,
                            isVisited: store.isVisited(item.id, in: type),
                            iconSystemName: icon(for: type),
                            pillBackground: pillBackground,
                            pillHighlight: pillHighlight,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary
                        )
                        .onTapGesture {
                            let wasVisited = store.isVisited(item.id, in: type)
                            withAnimation(.easeInOut(duration: 0.12)) {
                                store.toggleVisited(item.id, in: type)
                            }
                            if !wasVisited {
                                Haptics.bump()
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                let wasVisited = store.isVisited(item.id, in: type)
                                withAnimation(.easeInOut(duration: 0.12)) {
                                    store.toggleVisited(item.id, in: type)
                                }
                                if !wasVisited {
                                    Haptics.bump()
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange)
                                    Image(systemName: store.isVisited(item.id, in: type) ? "arrow.uturn.left" : "checkmark")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                .frame(width: 44, height: 44)
                            }
                            .tint(.clear)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(type.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func icon(for type: TrackerType) -> String {
        switch type {
        case .countries: return "globe.americas.fill"
        case .states: return "map.fill"
        case .continents: return "globe.europe.africa.fill"
        case .subwaySystems: return "tram.fill"
        case .nationalParks: return "mountain.2.fill"
        }
    }
    
}

private struct TrackerItemRow: View {
    @Environment(\.appAccentColor) private var accentColor
    
    let title: String
    let subtitle: String?
    let isVisited: Bool
    let iconSystemName: String
    let pillBackground: Color
    let pillHighlight: Color
    let textPrimary: Color
    let textSecondary: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isVisited ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(textPrimary)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.app(12, weight: .regular))
                    .foregroundStyle(textPrimary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.appCaption)
                        .foregroundStyle(textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(isVisited ? pillHighlight : pillBackground)
        )
        .contentShape(Capsule())
    }
}

