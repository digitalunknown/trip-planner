import SwiftUI

struct TrackersHomeView: View {
    @StateObject private var store = TrackerStore()
    @State private var showComingSoon = false

    var body: some View {
        SwiftUI.ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 12) {
                ForEach(TrackerType.allCases) { type in
                    NavigationLink(value: type) {
                        TrackerRowCard(
                            type: type,
                            visitedCount: store.visitedCount(in: type),
                            totalCount: TrackerData.items(for: type).count
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Trackers")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showComingSoon = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.medium)
                }
            }
        }
        .navigationDestination(for: TrackerType.self) { type in
            TrackerDetailView(type: type, store: store)
        }
        .sheet(isPresented: $showComingSoon) {
            NavigationStack {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Coming Soon")
                        .font(.title2.weight(.bold))
                    Text("Custom trackers are coming soon.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
                .navigationTitle("Add Tracker")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showComingSoon = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

