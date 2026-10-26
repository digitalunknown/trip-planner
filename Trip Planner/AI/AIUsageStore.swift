import Foundation

struct AIUsageSnapshot: Codable, Equatable {
    var weekID: String
    var used: Int
}

/// Per–Sign in with Apple weekly AI credit count. Persists locally and in iCloud.
@Observable
final class AIUsageStore {
    static let weeklyLimit = 15
    
    var usedThisWeek: Int = 0
    
    var progress: Double {
        guard Self.weeklyLimit > 0 else { return 0 }
        return min(1, Double(usedThisWeek) / Double(Self.weeklyLimit))
    }
    
    var remaining: Int {
        max(0, Self.weeklyLimit - usedThisWeek)
    }
    
    var isAtLimit: Bool {
        usedThisWeek >= Self.weeklyLimit
    }
    
    var meterLabel: String {
        "\(usedThisWeek)/\(Self.weeklyLimit) credits used"
    }
    
    func canGenerate(isPremium: Bool) -> Bool {
        if isPremium { return true }
        refreshWeekIfNeeded()
        return !isAtLimit
    }
    
    private var weekID: String = AIUsageStore.currentWeekID()
    private let ioQueue = DispatchQueue(label: "AIUsageStore.ioQueue", qos: .utility)
    private var presenter: ICloudFilePresenter?
    private var loadedForUserID: String?
    
    private var urls: (active: URL, local: URL, iCloud: URL?) { CloudSyncPaths.aiUsageURL() }
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSignInStateChanged),
            name: .appleSignInStateChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleICloudContainerPrimed),
            name: .iCloudContainerPrimed,
            object: nil
        )
        load()
    }
    
    /// One credit per user-started generation (not internal refill calls).
    func consumeCredit(isPremium: Bool = false) {
        guard !isPremium else { return }
        guard CloudSyncPaths.isSignedInToApple() else { return }
        refreshWeekIfNeeded()
        usedThisWeek += 1
        save()
    }
    
    func refreshWeekIfNeeded() {
        let current = Self.currentWeekID()
        guard weekID != current else { return }
        weekID = current
        usedThisWeek = 0
        if CloudSyncPaths.isSignedInToApple() {
            save()
        }
    }
    
    static func currentWeekID(now: Date = Date(), calendar: Calendar = .current) -> String {
        let week = calendar.component(.weekOfYear, from: now)
        let year = calendar.component(.yearForWeekOfYear, from: now)
        return String(format: "%d-W%02d", year, week)
    }
    
    func save() {
        guard CloudSyncPaths.isSignedInToApple() else { return }
        
        let snapshot = AIUsageSnapshot(weekID: weekID, used: usedThisWeek)
        let urlSet = urls
        let url = urlSet.active
        
        let data: Data
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            data = try encoder.encode(snapshot)
        } catch {
            print("Failed to encode AI usage: \(error)")
            return
        }
        
        ioQueue.async {
            do {
                try CoordinatedFileIO.writeData(data, to: url)
                if urlSet.iCloud != nil {
                    try CoordinatedFileIO.writeData(data, to: urlSet.local)
                }
            } catch {
                print("Failed to save AI usage: \(error)")
            }
        }
    }
    
    func load() {
        guard let userID = CloudSyncPaths.currentAppleUserIdentifier() else {
            clearAccountData()
            return
        }
        
        if !CloudSyncPaths.hasAttemptedICloudContainerLookup() {
            return
        }
        
        if loadedForUserID != userID {
            usedThisWeek = 0
            weekID = Self.currentWeekID()
            loadedForUserID = userID
        }
        
        let urlSet = urls
        configurePresenterIfNeeded(for: urlSet)
        
        ioQueue.async {
            if let iCloud = urlSet.iCloud {
                do {
                    try CoordinatedFileIO.coordinatedCopyIfMissing(from: urlSet.local, to: iCloud)
                } catch {
                    print("Failed to seed iCloud AI usage file: \(error)")
                }
            }
            
            guard CloudSyncPaths.currentAppleUserIdentifier() == userID else { return }
            
            let data: Data
            do {
                data = try CoordinatedFileIO.readData(from: urlSet.active)
            } catch {
                DispatchQueue.main.async {
                    guard CloudSyncPaths.currentAppleUserIdentifier() == userID else { return }
                    self.apply(AIUsageSnapshot(weekID: Self.currentWeekID(), used: 0), persistReset: false)
                }
                return
            }
            
            DispatchQueue.main.async {
                guard CloudSyncPaths.currentAppleUserIdentifier() == userID else { return }
                do {
                    let decoded = try JSONDecoder().decode(AIUsageSnapshot.self, from: data)
                    self.apply(decoded, persistReset: true)
                } catch {
                    print("Failed to load AI usage: \(error)")
                    self.apply(AIUsageSnapshot(weekID: Self.currentWeekID(), used: 0), persistReset: false)
                }
            }
        }
    }
    
    private func apply(_ snapshot: AIUsageSnapshot, persistReset: Bool) {
        let current = Self.currentWeekID()
        if snapshot.weekID == current {
            weekID = snapshot.weekID
            usedThisWeek = max(0, snapshot.used)
        } else {
            weekID = current
            usedThisWeek = 0
            if persistReset {
                save()
            }
        }
    }
    
    @objc
    private func handleSignInStateChanged() {
        CloudSyncPaths.primeICloudContainerIfNeeded()
        clearAccountData()
        load()
    }
    
    @objc
    private func handleICloudContainerPrimed() {
        load()
    }
    
    private func clearAccountData() {
        usedThisWeek = 0
        weekID = Self.currentWeekID()
        loadedForUserID = nil
        if let presenter {
            NSFileCoordinator.removeFilePresenter(presenter)
            self.presenter = nil
        }
    }
    
    private func configurePresenterIfNeeded(for urlSet: (active: URL, local: URL, iCloud: URL?)) {
        guard let iCloudURL = urlSet.iCloud else { return }
        if let presenter, presenter.presentedItemURL == iCloudURL { return }
        
        if let presenter {
            NSFileCoordinator.removeFilePresenter(presenter)
            self.presenter = nil
        }
        
        let newPresenter = ICloudFilePresenter(url: iCloudURL) { [weak self] in
            self?.load()
        }
        presenter = newPresenter
        NSFileCoordinator.addFilePresenter(newPresenter)
    }
}
