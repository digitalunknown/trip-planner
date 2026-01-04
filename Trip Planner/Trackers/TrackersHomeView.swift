import SwiftUI

struct TrackersHomeView: View {
    @StateObject private var store = TrackerStore()
    @State private var showComingSoon = false
    @Environment(\.appAccentColor) private var appAccentColor

    var body: some View {
        SwiftUI.ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 12) {
                NavigationLink {
                    PassportView()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [appAccentColor.opacity(0.22), appAccentColor.opacity(0.10)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Image(systemName: "passport")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [appAccentColor, appAccentColor.opacity(0.75)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .frame(width: 44, height: 44)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Passport")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("Stamps from completed trips")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer(minLength: 0)
                        
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                
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
                    ToolbarItem(placement: .topBarLeading) {
                        LiquidGlassIconButton(systemName: "xmark") { showComingSoon = false }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        LiquidGlassIconButton(systemName: "checkmark") { showComingSoon = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

