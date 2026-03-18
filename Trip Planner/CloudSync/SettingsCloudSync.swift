import Foundation

struct SettingsSnapshot: Codable {
    var appearanceModeRaw: String
    var hapticsEnabled: Bool
    var parallaxEffectsEnabled: Bool
    var prefFood: String
    var prefInterests: String
    var currencyCode: String
}

@MainActor
final class SettingsCloudSync {
    static let shared = SettingsCloudSync()

    private let ioQueue = DispatchQueue(label: "SettingsCloudSync.ioQueue", qos: .utility)
    private var pendingSaveWorkItem: DispatchWorkItem?
    private var presenter: ICloudFilePresenter?
    private var onRemoteUpdate: ((SettingsSnapshot) -> Void)?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSignInStateChanged),
            name: .appleSignInStateChanged,
            object: nil
        )
    }

    func start(onRemoteUpdate: @escaping (SettingsSnapshot) -> Void) {
        self.onRemoteUpdate = onRemoteUpdate
        handleSignInStateChanged()
    }

    @objc
    private func handleSignInStateChanged() {
        configurePresenterIfNeeded()
        loadAndNotify()
    }

    func scheduleSave(_ snapshot: SettingsSnapshot) {
        guard CloudSyncPaths.isSignedInToApple() else { return }
        pendingSaveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.save(snapshot)
        }
        pendingSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func save(_ snapshot: SettingsSnapshot) {
        let urlSet = CloudSyncPaths.settingsURL()
        let url = urlSet.active

        ioQueue.async {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                let data = try encoder.encode(snapshot)
                try CoordinatedFileIO.writeData(data, to: url)

                if urlSet.iCloud != nil {
                    try CoordinatedFileIO.writeData(data, to: urlSet.local)
                }
            } catch {
                print("Failed to save settings: \(error)")
            }
        }
    }

    private func loadAndNotify() {
        let urlSet = CloudSyncPaths.settingsURL()

        if let iCloud = urlSet.iCloud {
            do {
                try CoordinatedFileIO.coordinatedCopyIfMissing(from: urlSet.local, to: iCloud)
            } catch {
                print("Failed to seed iCloud settings file: \(error)")
            }
        }

        ioQueue.async { [weak self] in
            guard let self else { return }
            do {
                let data = try CoordinatedFileIO.readData(from: urlSet.active)
                guard !data.isEmpty else { return }
                let decoded = try JSONDecoder().decode(SettingsSnapshot.self, from: data)
                DispatchQueue.main.async {
                    self.onRemoteUpdate?(decoded)
                }
            } catch {
                // ignore
            }
        }
    }

    private func configurePresenterIfNeeded() {
        let urlSet = CloudSyncPaths.settingsURL()
        guard let iCloudURL = urlSet.iCloud else {
            if let presenter {
                NSFileCoordinator.removeFilePresenter(presenter)
                self.presenter = nil
            }
            return
        }

        if let presenter, presenter.presentedItemURL == iCloudURL { return }
        if let presenter {
            NSFileCoordinator.removeFilePresenter(presenter)
            self.presenter = nil
        }

        let newPresenter = ICloudFilePresenter(url: iCloudURL) { [weak self] in
            self?.loadAndNotify()
        }
        self.presenter = newPresenter
        NSFileCoordinator.addFilePresenter(newPresenter)
    }
}

