//
//  SettingsView.swift
//  Trip Planner
//
//  Created by Piotr Osmenda on 12/18/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("parallaxEffectsEnabled") private var parallaxEffectsEnabled: Bool = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    Picker("Appearance", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    
                    Toggle("Haptics", isOn: $hapticsEnabled)
                        .tint(appAccentColor)
                    Toggle("Parallax Effects", isOn: $parallaxEffectsEnabled)
                        .tint(appAccentColor)
                    
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
        .onAppear {
            if UserDefaults.standard.object(forKey: "hapticsEnabled") == nil {
                hapticsEnabled = true
            }
            if UserDefaults.standard.object(forKey: "parallaxEffectsEnabled") == nil {
                parallaxEffectsEnabled = true
            }
        }
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

