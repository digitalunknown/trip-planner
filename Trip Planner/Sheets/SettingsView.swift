import SwiftUI
import AuthenticationServices
import StoreKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(PremiumStore.self) private var premium
    @EnvironmentObject private var auth: AppleSignInManager
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("parallaxEffectsEnabled") private var parallaxEffectsEnabled: Bool = true
    @AppStorage(AppMapStylePreference.storageKey) private var mapStylePreferenceRaw: String = AppMapStylePreference.standard.rawValue
    @AppStorage("prefFood") private var prefFood: String = ""
    @AppStorage("prefInterests") private var prefInterests: String = ""
    @AppStorage("currencyCode") private var currencyCode: String = "USD"
    @State private var displayNameDraft: String = ""
    @State private var showPaywall = false
    @State private var showManageSubscriptions = false
    
    private var mapStylePreference: Binding<AppMapStylePreference> {
        Binding(
            get: { AppMapStylePreference(rawValue: mapStylePreferenceRaw) ?? .standard },
            set: { mapStylePreferenceRaw = $0.rawValue }
        )
    }
    
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
                Group {
                Section {
                    if auth.isSignedIn {
                        HStack {
                            Label("Account", appIcon: "user-round", color: .primary)
                            Spacer()
                            Text(auth.displayName ?? "Apple ID")
                                .font(.app(15, weight: .medium))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        Button(role: .destructive) {
                            auth.signOut()
                        } label: {
                            Label("Sign Out", appIcon: "log-out", color: .red)
                        }
                    } else {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            auth.handleAuthorizationResult(result)
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
                    AppSectionHeader("Account")
                } footer: {
                    Text(
                        auth.isSignedIn
                        ? "Your account is only used to store your trips in iCloud."
                        : "Sign in to sync your trips and stats to iCloud. Your account is only used to store your trips in iCloud."
                    )
                    .font(.appFootnote)
                    .foregroundStyle(.secondary)
                }
                
                Section {
                    if premium.isPremium {
                        HStack {
                            Label("TripStacks+", appIcon: "sparkles", color: .primary)
                            Spacer()
                            Text("Active")
                                .font(.app(15, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            showManageSubscriptions = true
                        } label: {
                            HStack {
                                Label("Manage subscription", appIcon: "credit-card", color: .primary)
                                Spacer()
                                AppIcon(lucide: "chevron-right", size: AppLucide.fieldSize, color: AppColor.textWeak)
                            }
                        }
                        .foregroundStyle(.primary)
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Label("Upgrade to TripStacks+", appIcon: "sparkles", color: .primary)
                                Spacer()
                                AppIcon(lucide: "chevron-right", size: AppLucide.fieldSize, color: AppColor.textWeak)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    
                    Button {
                        Task { await premium.restore() }
                    } label: {
                        Label("Restore purchases", appIcon: "rotate-ccw", color: .primary)
                    }
                    .foregroundStyle(.primary)
                    
                    if let error = premium.errorMessage, premium.isPremium || !premium.offeredProducts.isEmpty {
                        Text(error)
                            .font(.appFootnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    AppSectionHeader("TripStacks+")
                } footer: {
                    if premium.isPremium {
                        Text("Unlimited AI and local insights are included with your subscription.")
                            .font(.appFootnote)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section {
                    Label {
                        TextField("Display name", text: $displayNameDraft)
                            .font(.app(15, weight: .medium))
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                    } icon: {
                        AppIcon(lucide: "user-round", size: AppLucide.chromeSize, color: .primary)
                    }
                    
                    Menu {
                        ForEach(popularCurrencies) { option in
                            Button {
                                currencyCode = option.code
                            } label: {
                                if option.code == currencyCode {
                                    Label(option.label, menuIcon: "checkmark")
                                } else {
                                    Text(option.label)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Label("Home currency", appIcon: "circle-dollar-sign", color: .primary)
                            Spacer(minLength: 8)
                            HStack(spacing: 5) {
                                Text(currencyCode)
                                    .font(.app(15, weight: .medium))
                                    .foregroundStyle(.primary)
                                AppIcon(lucide: "chevrons-up-down", size: AppLucide.fieldSize, color: AppColor.textWeak)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    AppSectionHeader("Personal")
                }
                
                Section {
                    Menu {
                        ForEach(AppearanceMode.allCases) { mode in
                            Button {
                                appearanceMode = mode
                            } label: {
                                if mode == appearanceMode {
                                    Label(mode.title, menuIcon: "checkmark")
                                } else {
                                    Text(mode.title)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Label("Appearance", appIcon: "sun-moon", color: .primary)
                            Spacer(minLength: 8)
                            HStack(spacing: 5) {
                                Text(appearanceMode.title)
                                    .font(.app(15, weight: .medium))
                                    .foregroundStyle(.primary)
                                AppIcon(lucide: "chevrons-up-down", size: AppLucide.fieldSize, color: AppColor.textWeak)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Menu {
                        ForEach(AppMapStylePreference.allCases) { style in
                            Button {
                                mapStylePreference.wrappedValue = style
                            } label: {
                                if style == mapStylePreference.wrappedValue {
                                    Label(style.title, menuIcon: "checkmark")
                                } else {
                                    Text(style.title)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Label("Map style", appIcon: "map", color: .primary)
                            Spacer(minLength: 8)
                            HStack(spacing: 5) {
                                Text(mapStylePreference.wrappedValue.title)
                                    .font(.app(15, weight: .medium))
                                    .foregroundStyle(.primary)
                                AppIcon(lucide: "chevrons-up-down", size: AppLucide.fieldSize, color: AppColor.textWeak)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Toggle(isOn: $hapticsEnabled) {
                        Label("Haptics", appIcon: "vibrate", color: .primary)
                    }
                    .tint(appAccentColor)
                    
                    Toggle(isOn: $parallaxEffectsEnabled) {
                        Label("Parallax effects", appIcon: "move-3d", color: .primary)
                    }
                    .tint(appAccentColor)
                    
                    Link(destination: URL(string: "https://apps.apple.com/us/app/tripstacks-travel-organizer/id6757321257?action=write-review")!) {
                        HStack {
                            Label("Review TripStacks", appIcon: "star", color: .primary)
                            Spacer()
                            AppIcon(lucide: "chevron-right", size: AppLucide.fieldSize, color: AppColor.textWeak)
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    HStack {
                        Label("Version", appIcon: "info", color: .primary)
                        Spacer()
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0")
                            .font(.app(15, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    AppSectionHeader("App Settings")
                }
                }
                .appDetailFieldBackground()
            }
            .appFormPageSpacing()
            .appDetailFormChrome()
            .environment(\.font, .app(15, weight: .medium))
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
        .sheet(isPresented: $showPaywall) {
            PaywallSheet()
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        .onChange(of: appearanceMode) { _, _ in saveSettingsToICloudIfNeeded() }
        .onChange(of: hapticsEnabled) { _, _ in saveSettingsToICloudIfNeeded() }
        .onChange(of: parallaxEffectsEnabled) { _, _ in saveSettingsToICloudIfNeeded() }
        .onChange(of: mapStylePreferenceRaw) { _, _ in saveSettingsToICloudIfNeeded() }
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
            mapStyleRaw: mapStylePreferenceRaw,
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
        if let mapStyleRaw = snapshot.mapStyleRaw,
           AppMapStylePreference(rawValue: mapStyleRaw) != nil {
            mapStylePreferenceRaw = mapStyleRaw
        }
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
        .environment(PremiumStore())
        .environmentObject(AppleSignInManager())
}

