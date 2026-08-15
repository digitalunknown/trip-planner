import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @EnvironmentObject private var auth: AppleSignInManager
    @AppStorage("exploreSampleEnabled") private var exploreSampleEnabled: Bool = false
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("parallaxEffectsEnabled") private var parallaxEffectsEnabled: Bool = true
    @AppStorage("prefFood") private var prefFood: String = ""
    @AppStorage("prefInterests") private var prefInterests: String = ""
    @AppStorage("currencyCode") private var currencyCode: String = "USD"
    @State private var displayNameDraft: String = ""
    
    private struct CurrencyOption: Identifiable {
        let code: String
        let name: String
        var id: String { code }
        var label: String { "\(name) (\(code))" }
    }
    
    private let popularCurrencies: [CurrencyOption] = [
        CurrencyOption(code: "USD", name: "US Dollar"),
        CurrencyOption(code: "EUR", name: "Euro"),
        CurrencyOption(code: "GBP", name: "British Pound"),
        CurrencyOption(code: "JPY", name: "Japanese Yen"),
        CurrencyOption(code: "CAD", name: "Canadian Dollar"),
        CurrencyOption(code: "AUD", name: "Australian Dollar"),
        CurrencyOption(code: "CHF", name: "Swiss Franc"),
        CurrencyOption(code: "CNY", name: "Chinese Yuan"),
        CurrencyOption(code: "INR", name: "Indian Rupee"),
        CurrencyOption(code: "SGD", name: "Singapore Dollar")
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if auth.isSignedIn {
                        HStack {
                            Text("Account")
                            Spacer()
                            Text(auth.displayName ?? "Apple ID")
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        Button(role: .destructive) {
                            auth.signOut()
                        } label: {
                            Text("Sign out")
                        }
                    } else {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            auth.handleAuthorizationResult(result)
                            if auth.isSignedIn {
                                exploreSampleEnabled = false
                            }
                        }
                        .frame(height: 44)
                        .signInWithAppleButtonStyle(.black)
                    }
                    
                    if let err = auth.lastErrorDescription, !err.isEmpty {
                        Text(err)
                            .font(.appFootnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Account")
                } footer: {
                    Text(
                        auth.isSignedIn
                        ? "Your account is only used to store your trips in iCloud."
                        : "Sign in to sync your trips and stats to iCloud. Your account is only used to store your trips in iCloud."
                    )
                    .font(.appFootnote)
                    .foregroundStyle(.secondary)
                }
                
                Section("Personal") {
                    TextField("Display Name", text: $displayNameDraft)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                    
                    Picker("Home Currency", selection: $currencyCode) {
                        ForEach(popularCurrencies) { option in
                            Text(option.label).tag(option.code)
                        }
                    }
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
                    
                    Link(destination: URL(string: "https://apps.apple.com/us/app/tripstacks-travel-organizer/id6757321257?action=write-review")!) {
                        HStack {
                            Text("Review TripStacks")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.2")
                            .foregroundStyle(.secondary)
                    }
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
        .onChange(of: appearanceMode) { _, _ in saveSettingsToICloudIfNeeded() }
        .onChange(of: hapticsEnabled) { _, _ in saveSettingsToICloudIfNeeded() }
        .onChange(of: parallaxEffectsEnabled) { _, _ in saveSettingsToICloudIfNeeded() }
        .onChange(of: prefFood) { _, _ in saveSettingsToICloudIfNeeded() }
        .onChange(of: prefInterests) { _, _ in saveSettingsToICloudIfNeeded() }
        .onChange(of: currencyCode) { _, _ in saveSettingsToICloudIfNeeded() }
        .onChange(of: displayNameDraft) { _, newValue in
            auth.updateDisplayName(newValue)
        }
        .onChange(of: auth.displayName) { _, newValue in
            let incoming = newValue ?? ""
            if displayNameDraft != incoming {
                displayNameDraft = incoming
            }
        }
        .onAppear {
            displayNameDraft = auth.displayName ?? ""
            SettingsCloudSync.shared.start { snapshot in
                applySettingsSnapshot(snapshot)
            }
            if UserDefaults.standard.object(forKey: "hapticsEnabled") == nil {
                hapticsEnabled = true
            }
            if UserDefaults.standard.object(forKey: "parallaxEffectsEnabled") == nil {
                parallaxEffectsEnabled = true
            }
        }
    }
    
    private func currentSnapshot() -> SettingsSnapshot {
        SettingsSnapshot(
            appearanceModeRaw: appearanceMode.rawValue,
            hapticsEnabled: hapticsEnabled,
            parallaxEffectsEnabled: parallaxEffectsEnabled,
            prefFood: prefFood,
            prefInterests: prefInterests,
            currencyCode: currencyCode
        )
    }
    
    private func saveSettingsToICloudIfNeeded() {
        guard auth.isSignedIn else { return }
        SettingsCloudSync.shared.scheduleSave(currentSnapshot())
    }
    
    private func applySettingsSnapshot(_ snapshot: SettingsSnapshot) {
        if let mode = AppearanceMode(rawValue: snapshot.appearanceModeRaw) {
            appearanceMode = mode
        }
        hapticsEnabled = snapshot.hapticsEnabled
        parallaxEffectsEnabled = snapshot.parallaxEffectsEnabled
        prefFood = snapshot.prefFood
        prefInterests = snapshot.prefInterests
        currencyCode = snapshot.currencyCode
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

