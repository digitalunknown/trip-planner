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
    
    private var accentColor: Color {
        AccentColorOption(rawValue: accentColorRaw)?.color ?? .orange
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // MyTripsView already owns its NavigationStack; don't nest another one
            // (nested NavigationStacks can make dismiss/back feel flaky).
            MyTripsView()
                // Keep toolbar icons default (non-accent)
                .tint(.primary)
                .tabItem {
                Label("My Trips", systemImage: "suitcase.fill")
            }
            .tag(RootTab.myTrips)

            NavigationStack {
                TrackersHomeView()
                    // Keep toolbar icons default (non-orange)
                    .tint(.primary)
            }
            .tabItem {
                Label("Trackers", systemImage: "checkmark.seal.fill")
            }
            .tag(RootTab.trackers)
        }
        // User-selected accent for the system tab bar selection.
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
