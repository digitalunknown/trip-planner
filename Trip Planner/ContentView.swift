//
//  ContentView.swift
//  Trip Planner
//
//  Created by Piotr Osmenda on 12/16/25.
//

import SwiftUI

struct ContentView: View {
    private enum RootTab: Hashable {
        case myTrips
        case trackers
    }
    
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("accentColor") private var accentColorRaw: String = AccentColorOption.orange.rawValue
    @State private var selectedTab: RootTab = .myTrips
    @State private var tripStore = TripStore()
    
    private var accentColor: Color {
        AccentColorOption(rawValue: accentColorRaw)?.color ?? .orange
    }
    
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
    }
}

#Preview {
    ContentView()
}
