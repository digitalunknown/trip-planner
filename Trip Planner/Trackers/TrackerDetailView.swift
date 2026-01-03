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
                    totalCount: TrackerData.items(for: type).count
                )
                .padding(.top, 6)
                .padding(.bottom, 10)
                
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.bottom, 2)

                ForEach(items) { item in
                    TrackerItemCard(
                        title: item.name,
                        subtitle: item.subtitle,
                        isVisited: store.isVisited(item.id, in: type),
                        iconSystemName: icon(for: type)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let wasVisited = store.isVisited(item.id, in: type)
                        withAnimation(.easeInOut(duration: 0.12)) {
                            store.toggleVisited(item.id, in: type)
                        }
                        if !wasVisited {
                            Haptics.bump()
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

