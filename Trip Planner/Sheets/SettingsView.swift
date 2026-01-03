//
//  SettingsView.swift
//  Trip Planner
//
//  Created by Piotr Osmenda on 12/18/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("accentColor") private var accentColorRaw: String = AccentColorOption.orange.rawValue
    
    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    Picker("Appearance", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    
                    Picker("Accent Color", selection: $accentColorRaw) {
                        ForEach(AccentColorOption.allCases) { option in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 14, height: 14)
                                Text(option.title)
                            }
                            .tag(option.rawValue)
                        }
                    }
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("Beta")
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Created by Peter Osmenda (@digitalunknown).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Link("Send feedback on X", destination: URL(string: "https://x.com/digitalunknown")!)
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    LiquidGlassIconButton(systemName: "checkmark") { dismiss() }
                }
            }
        }
        .preferredColorScheme(appearanceMode.preferredColorScheme)
        .tint(.primary)
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AccentColorOption: String, CaseIterable, Identifiable {
    case orange
    case purple
    case blue
    case teal
    case pink
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .orange: return "Orange"
        case .purple: return "Purple"
        case .blue: return "Blue"
        case .teal: return "Teal"
        case .pink: return "Pink"
        }
    }
    
    var color: Color {
        switch self {
        case .orange: return .orange
        case .purple: return .purple
        case .blue: return .blue
        case .teal: return .teal
        case .pink: return .pink
        }
    }
}

private struct AppAccentColorKey: EnvironmentKey {
    static let defaultValue: Color = .orange
}

extension EnvironmentValues {
    var appAccentColor: Color {
        get { self[AppAccentColorKey.self] }
        set { self[AppAccentColorKey.self] = newValue }
    }
}

#Preview {
    SettingsView()
}

