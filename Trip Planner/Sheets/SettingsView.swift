import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("parallaxEffectsEnabled") private var parallaxEffectsEnabled: Bool = true
    @AppStorage("prefFood") private var prefFood: String = ""
    @AppStorage("prefAlcohol") private var prefAlcohol: Bool = false
    @AppStorage("prefInterests") private var prefInterests: String = ""
    
    private var createdByFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Created by Peter Osmenda (@digitalunknown).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Link("Send feedback on X", destination: URL(string: "https://x.com/digitalunknown")!)
                .font(.subheadline.weight(.semibold))
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Favorite food, separated by commas", text: $prefFood, axis: .vertical)
                        .lineLimit(1...3)
                    
                    Picker("Alcohol", selection: $prefAlcohol) {
                        Text("No").tag(false)
                        Text("Yes").tag(true)
                    }
                    
                    TextField("Interests, separated by commas", text: $prefInterests, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("Personal Preferences")
                } footer: {
                    Text("Your preferences will be considered for trip planning and recommendations")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                
                Section("App Settings") {
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
                }
                
                Section {
                    createdByFooter
                        .frame(maxWidth: .infinity, alignment: .leading)
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

