import Foundation

enum CloudSyncPaths {
    static let iCloudContainerIdentifier = "iCloud.digitalunknown.Trip-Planner"
    
    private static let cacheQueue = DispatchQueue(label: "CloudSyncPaths.cacheQueue")
    private static var didAttemptContainerLookup: Bool = false
    private static var cachedUbiquityBaseURL: URL?
    
    static func isSignedInToApple() -> Bool {
        KeychainHelper.getString(forKey: AppleSignInManager.userIdentifierKeychainKey) != nil
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
}

extension Notification.Name {
    static let iCloudContainerPrimed = Notification.Name("iCloudContainerPrimed")
}

