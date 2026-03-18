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

    override init() {
        super.init()
        Task { await refreshCredentialState() }
    }

    func refreshCredentialState() async {
        let cached = KeychainHelper.getString(forKey: Self.userIdentifierKeychainKey)
        let cachedName = KeychainHelper.getString(forKey: Self.displayNameKeychainKey)
        await MainActor.run {
            self.userIdentifier = cached
            self.displayName = cachedName
            self.isSignedIn = (cached != nil)
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
                    self.isSignedIn = true
                }
            case .revoked, .notFound:
                KeychainHelper.delete(forKey: Self.userIdentifierKeychainKey)
                await MainActor.run {
                    self.userIdentifier = nil
                    self.isSignedIn = false
                }
            case .transferred:
                // Treat as signed-in; iOS may require re-auth later.
                await MainActor.run {
                    self.userIdentifier = cached
                    self.isSignedIn = true
                }
            @unknown default:
                await MainActor.run {
                    self.userIdentifier = cached
                    self.isSignedIn = true
                }
            }
        } catch {
            await MainActor.run {
                self.lastErrorDescription = error.localizedDescription
                self.userIdentifier = cached
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
            let name = Self.bestDisplayName(from: credential)
            do {
                try KeychainHelper.setString(userID, forKey: Self.userIdentifierKeychainKey)
                if let name {
                    try KeychainHelper.setString(name, forKey: Self.displayNameKeychainKey)
                }
                userIdentifier = userID
                displayName = name ?? displayName
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
        KeychainHelper.delete(forKey: Self.userIdentifierKeychainKey)
        KeychainHelper.delete(forKey: Self.displayNameKeychainKey)
        userIdentifier = nil
        displayName = nil
        isSignedIn = false
        NotificationCenter.default.post(name: .appleSignInStateChanged, object: nil)
    }
}

private extension AppleSignInManager {
    static func bestDisplayName(from credential: ASAuthorizationAppleIDCredential) -> String? {
        if let fullName = credential.fullName {
            let formatter = PersonNameComponentsFormatter()
            let s = formatter.string(from: fullName).trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { return s }
        }
        let email = (credential.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return email.isEmpty ? nil : email
    }
}

extension Notification.Name {
    static let appleSignInStateChanged = Notification.Name("appleSignInStateChanged")
}

