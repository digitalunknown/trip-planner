import Foundation

enum CloudSyncPaths {
    static let iCloudContainerIdentifier = "iCloud.digitalunknown.Trip-Planner"
    
    private static let cacheQueue = DispatchQueue(label: "CloudSyncPaths.cacheQueue")
    private static var didAttemptContainerLookup: Bool = false
    private static var cachedUbiquityBaseURL: URL?
    
    private static let legacyPlacesMigrationKey = "legacySavedPlacesMigratedToUser"
    
    static func isSignedInToApple() -> Bool {
        currentAppleUserIdentifier() != nil
    }
    
    static func currentAppleUserIdentifier() -> String? {
        KeychainHelper.getString(forKey: AppleSignInManager.userIdentifierKeychainKey)
    }

    /// Call this on app start / after sign-in to avoid blocking the main thread later.
    static func primeICloudContainerIfNeeded() {
        cacheQueue.async {
            guard !didAttemptContainerLookup else { return }
            didAttemptContainerLookup = true
            cachedUbiquityBaseURL = FileManager.default.url(forUbiquityContainerIdentifier: iCloudContainerIdentifier)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .iCloudContainerPrimed, object: nil)
            }
        }
    }

    static func hasAttemptedICloudContainerLookup() -> Bool {
        cacheQueue.sync { didAttemptContainerLookup }
    }
    
    static func iCloudDocumentsRootIfAvailable() -> URL? {
        guard isSignedInToApple() else { return nil }
        let base: URL? = cacheQueue.sync { cachedUbiquityBaseURL }
        guard let base else { return nil }
        return base.appendingPathComponent("Documents", isDirectory: true)
    }

    static func localAppSupportRoot() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("TripPlanner", isDirectory: true)
    }
    
    /// Stable filesystem folder for a Sign in with Apple user identifier.
    static func sanitizedAccountFolderName(for userIdentifier: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let scalars = userIdentifier.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let cleaned = String(scalars)
        return cleaned.isEmpty ? "unknown" : cleaned
    }
    
    static func accountLocalRoot(for userIdentifier: String) -> URL {
        localAppSupportRoot()
            .appendingPathComponent("Accounts", isDirectory: true)
            .appendingPathComponent(sanitizedAccountFolderName(for: userIdentifier), isDirectory: true)
    }
    
    static func accountICloudRoot(for userIdentifier: String) -> URL? {
        iCloudDocumentsRootIfAvailable()?
            .appendingPathComponent("Accounts", isDirectory: true)
            .appendingPathComponent(sanitizedAccountFolderName(for: userIdentifier), isDirectory: true)
    }

    static func tripsURL() -> (active: URL, local: URL, iCloud: URL?) {
        let local = localAppSupportRoot().appendingPathComponent("SavedTrips.json")
        let iCloud = iCloudDocumentsRootIfAvailable()?.appendingPathComponent("SavedTrips.json")
        return (active: iCloud ?? local, local: local, iCloud: iCloud)
    }

    static func trackersURL() -> (active: URL, local: URL, iCloud: URL?) {
        let local = localAppSupportRoot().appendingPathComponent("SavedTrackers.json")
        let iCloud = iCloudDocumentsRootIfAvailable()?.appendingPathComponent("SavedTrackers.json")
        return (active: iCloud ?? local, local: local, iCloud: iCloud)
    }

    static func coverAttributionURL() -> (active: URL, local: URL, iCloud: URL?) {
        let local = localAppSupportRoot().appendingPathComponent("CoverAttribution.json")
        let iCloud = iCloudDocumentsRootIfAvailable()?.appendingPathComponent("CoverAttribution.json")
        return (active: iCloud ?? local, local: local, iCloud: iCloud)
    }
    
    static func settingsURL() -> (active: URL, local: URL, iCloud: URL?) {
        let local = localAppSupportRoot().appendingPathComponent("SavedSettings.json")
        let iCloud = iCloudDocumentsRootIfAvailable()?.appendingPathComponent("SavedSettings.json")
        return (active: iCloud ?? local, local: local, iCloud: iCloud)
    }
    
    /// Places are scoped to the Sign in with Apple user (local + iCloud Accounts folders).
    /// When signed out, returns a non-shared placeholder path — callers must not load/save.
    static func placesURL() -> (active: URL, local: URL, iCloud: URL?) {
        guard let userID = currentAppleUserIdentifier() else {
            let local = localAppSupportRoot()
                .appendingPathComponent("SignedOut", isDirectory: true)
                .appendingPathComponent("SavedPlaces.json")
            return (active: local, local: local, iCloud: nil)
        }
        
        let local = accountLocalRoot(for: userID).appendingPathComponent("SavedPlaces.json")
        let iCloud = accountICloudRoot(for: userID)?.appendingPathComponent("SavedPlaces.json")
        return (active: iCloud ?? local, local: local, iCloud: iCloud)
    }
    
    /// One-time move of pre-account-scoped `SavedPlaces.json` into the current user's folder.
    /// Only the first signed-in user after upgrade receives the legacy file; then it is removed
    /// so a later account on the same device cannot inherit it.
    static func migrateLegacyPlacesIfNeeded(for userIdentifier: String) {
        let defaults = UserDefaults.standard
        let migratedTo = defaults.string(forKey: legacyPlacesMigrationKey)
        if let migratedTo, migratedTo != userIdentifier {
            // Already claimed by another account — remove leftover legacy without attaching it here.
            removeLegacyPlacesFilesIfPresent()
            return
        }
        
        let fm = FileManager.default
        let localRoot = accountLocalRoot(for: userIdentifier)
        let localDest = localRoot.appendingPathComponent("SavedPlaces.json")
        let legacyLocal = localAppSupportRoot().appendingPathComponent("SavedPlaces.json")
        
        do {
            try fm.createDirectory(at: localRoot, withIntermediateDirectories: true)
        } catch {
            print("Failed to create places account directory: \(error)")
        }
        
        copyLegacyPlacesFileIfNeeded(from: legacyLocal, to: localDest)
        
        if let iCloudRoot = accountICloudRoot(for: userIdentifier) {
            let iCloudDest = iCloudRoot.appendingPathComponent("SavedPlaces.json")
            let legacyICloud = iCloudDocumentsRootIfAvailable()?.appendingPathComponent("SavedPlaces.json")
            do {
                try fm.createDirectory(at: iCloudRoot, withIntermediateDirectories: true)
            } catch {
                print("Failed to create iCloud places account directory: \(error)")
            }
            if let legacyICloud {
                copyLegacyPlacesFileIfNeeded(from: legacyICloud, to: iCloudDest)
            }
        }
        
        defaults.set(userIdentifier, forKey: legacyPlacesMigrationKey)
        removeLegacyPlacesFilesIfPresent()
    }
    
    private static func copyLegacyPlacesFileIfNeeded(from source: URL, to destination: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path) else { return }
        guard !fm.fileExists(atPath: destination.path) else { return }
        do {
            try fm.copyItem(at: source, to: destination)
        } catch {
            print("Failed to migrate legacy places file: \(error)")
        }
    }
    
    private static func removeLegacyPlacesFilesIfPresent() {
        let fm = FileManager.default
        let legacyLocal = localAppSupportRoot().appendingPathComponent("SavedPlaces.json")
        if fm.fileExists(atPath: legacyLocal.path) {
            try? fm.removeItem(at: legacyLocal)
        }
        if let legacyICloud = iCloudDocumentsRootIfAvailable()?.appendingPathComponent("SavedPlaces.json"),
           fm.fileExists(atPath: legacyICloud.path) {
            // Only remove the legacy root file — never Accounts/… paths.
            let name = legacyICloud.lastPathComponent
            let parentName = legacyICloud.deletingLastPathComponent().lastPathComponent
            if name == "SavedPlaces.json", parentName == "Documents" {
                try? fm.removeItem(at: legacyICloud)
            }
        }
    }
}

extension Notification.Name {
    static let iCloudContainerPrimed = Notification.Name("iCloudContainerPrimed")
}
