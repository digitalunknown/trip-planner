import SwiftUI

struct ContentView: View {
    private enum RootTab: Hashable {
        case myTrips
        case trackers
    }
    
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @State private var selectedTab: RootTab = .myTrips
    @State private var tripStore = TripStore()
    
    private let accentColor: Color = .orange
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MyTripsView()
                .tint(.primary)
                .tabItem {
                Label("Trips", systemImage: "suitcase.fill")
            }
            .tag(RootTab.myTrips)

            NavigationStack {
                TrackersHomeView()
                    .tint(.primary)
            }
            .tabItem {
                Label("Stats", systemImage: "checkmark.seal.fill")
            }
            .tag(RootTab.trackers)
        }
        .environment(tripStore)
        .tint(accentColor)
        .environment(\.appAccentColor, accentColor)
        .preferredColorScheme(appearanceMode.preferredColorScheme)
        .onChange(of: selectedTab) { _, _ in
            Haptics.tabSelectionChanged()
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickActionCreateNewTrip)) { _ in
            selectedTab = .myTrips
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                NotificationCenter.default.post(name: .openNewTripSheet, object: nil)
            }
        }
    }
}

#Preview {
    ContentView()
}
