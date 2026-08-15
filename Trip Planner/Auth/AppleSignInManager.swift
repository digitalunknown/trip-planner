import Foundation
import AuthenticationServices
import Combine

@MainActor
final class AppleSignInManager: NSObject, ObservableObject {
    static let userIdentifierKeychainKey = "appleUserIdentifier"
    static let displayNameKeychainKey = "appleDisplayName"

    @Published private(set) var isSignedIn: Bool = false
    @Published private(set) var userIdentifier: String?
    @Published private(set) var displayName: String?
    @Published private(set) var lastErrorDescription: String?
    /// Becomes true after the cached Keychain session has been applied (sync on init).
    /// Used so the sign-in gate never flashes before we know if a session exists.
    @Published private(set) var hasResolvedInitialAuthState: Bool = false

    override init() {
        super.init()
        // Restore synchronously so the first frame already knows signed-in state.
        // Async Apple credential verification still runs afterward.
        restoreCachedSession()
        Task { await refreshCredentialState() }
    }

    private func restoreCachedSession() {
        let cached = KeychainHelper.getString(forKey: Self.userIdentifierKeychainKey)
        userIdentifier = cached
        displayName = Self.resolvedDisplayName(forUserID: cached)
        isSignedIn = (cached != nil)
        hasResolvedInitialAuthState = true
    }

    func refreshCredentialState() async {
        let cached = KeychainHelper.getString(forKey: Self.userIdentifierKeychainKey)
        let cachedName = Self.resolvedDisplayName(forUserID: cached)
        await MainActor.run {
            self.userIdentifier = cached
            self.displayName = cachedName
            self.isSignedIn = (cached != nil)
            self.hasResolvedInitialAuthState = true
        }

        guard let cached else {
            NotificationCenter.default.post(name: .appleSignInStateChanged, object: nil)
            return
        }

        let provider = ASAuthorizationAppleIDProvider()
        do {
            let state = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<ASAuthorizationAppleIDProvider.CredentialState, Error>) in
                provider.getCredentialState(forUserID: cached) { state, error in
                    if let error {
                        cont.resume(throwing: error)
                    } else {
                        cont.resume(returning: state)
                    }
                }
            }

            switch state {
            case .authorized:
                await MainActor.run {
                    self.lastErrorDescription = nil
                    self.userIdentifier = cached
                    self.displayName = Self.resolvedDisplayName(forUserID: cached)
                    self.isSignedIn = true
                }
            case .revoked, .notFound:
                // Keep the per-user name cache so a later re-auth can restore it.
                KeychainHelper.delete(forKey: Self.userIdentifierKeychainKey)
                KeychainHelper.delete(forKey: Self.displayNameKeychainKey)
                await MainActor.run {
                    self.userIdentifier = nil
                    self.displayName = nil
                    self.isSignedIn = false
                }
            case .transferred:
                // Treat as signed-in; iOS may require re-auth later.
                await MainActor.run {
                    self.userIdentifier = cached
                    self.displayName = Self.resolvedDisplayName(forUserID: cached)
                    self.isSignedIn = true
                }
            @unknown default:
                await MainActor.run {
                    self.userIdentifier = cached
                    self.displayName = Self.resolvedDisplayName(forUserID: cached)
                    self.isSignedIn = true
                }
            }
        } catch {
            await MainActor.run {
                self.lastErrorDescription = error.localizedDescription
                self.userIdentifier = cached
                self.displayName = Self.resolvedDisplayName(forUserID: cached)
                self.isSignedIn = true
            }
        }

        NotificationCenter.default.post(name: .appleSignInStateChanged, object: nil)
    }

    func handleAuthorizationResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            let userID = credential.user
            // Apple only provides name/email on the *first* authorization for this app.
            // Always fall back to any name we already stored for this user.
            let name = Self.bestDisplayName(from: credential)
                ?? Self.storedDisplayName(forUserID: userID)
                ?? KeychainHelper.getString(forKey: Self.displayNameKeychainKey)

            do {
                try KeychainHelper.setString(userID, forKey: Self.userIdentifierKeychainKey)
                if let name, !name.isEmpty {
                    try KeychainHelper.setString(name, forKey: Self.displayNameKeychainKey)
                    try KeychainHelper.setString(name, forKey: Self.perUserDisplayNameKey(userID))
                }
                userIdentifier = userID
                displayName = name
                isSignedIn = true
                lastErrorDescription = nil
            } catch {
                lastErrorDescription = error.localizedDescription
            }
            NotificationCenter.default.post(name: .appleSignInStateChanged, object: nil)
        case .failure(let error):
            lastErrorDescription = error.localizedDescription
        }
    }

    func signOut() {
        // Keep the per-user name so Sign in with Apple can restore it on the next login
        // (Apple will not send fullName again after the first authorization).
        KeychainHelper.delete(forKey: Self.userIdentifierKeychainKey)
        KeychainHelper.delete(forKey: Self.displayNameKeychainKey)
        userIdentifier = nil
        displayName = nil
        isSignedIn = false
        NotificationCenter.default.post(name: .appleSignInStateChanged, object: nil)
    }

    /// Updates the profile display name (Settings → Personal). Persists for this Apple user when signed in.
    func updateDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? nil : trimmed
        displayName = value

        if let value {
            try? KeychainHelper.setString(value, forKey: Self.displayNameKeychainKey)
            if let userID = userIdentifier {
                try? KeychainHelper.setString(value, forKey: Self.perUserDisplayNameKey(userID))
            }
        } else {
            KeychainHelper.delete(forKey: Self.displayNameKeychainKey)
            if let userID = userIdentifier {
                KeychainHelper.delete(forKey: Self.perUserDisplayNameKey(userID))
            }
        }
    }
}

private extension AppleSignInManager {
    static func perUserDisplayNameKey(_ userID: String) -> String {
        "appleDisplayName.\(userID)"
    }

    static func storedDisplayName(forUserID userID: String) -> String? {
        let value = KeychainHelper.getString(forKey: perUserDisplayNameKey(userID))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false) ? value : nil
    }

    static func resolvedDisplayName(forUserID userID: String?) -> String? {
        if let userID, let perUser = storedDisplayName(forUserID: userID) {
            return perUser
        }
        let legacy = KeychainHelper.getString(forKey: displayNameKeychainKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (legacy?.isEmpty == false) ? legacy : nil
    }

    static func bestDisplayName(from credential: ASAuthorizationAppleIDCredential) -> String? {
        if let fullName = credential.fullName {
            let given = fullName.givenName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let family = fullName.familyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let parts = [given, family].filter { !$0.isEmpty }
            if !parts.isEmpty {
                return parts.joined(separator: " ")
            }

            let formatter = PersonNameComponentsFormatter()
            let formatted = formatter.string(from: fullName).trimmingCharacters(in: .whitespacesAndNewlines)
            if !formatted.isEmpty { return formatted }
        }

        let email = (credential.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return email.isEmpty ? nil : email
    }
}

extension Notification.Name {
    static let appleSignInStateChanged = Notification.Name("appleSignInStateChanged")
}
