import Foundation

@MainActor
final class CoverAttributionSync {
    static let shared = CoverAttributionSync()

    private let ioQueue = DispatchQueue(label: "CoverAttributionSync.ioQueue", qos: .utility)
    private var pendingSaveWorkItem: DispatchWorkItem?
    private var presenter: ICloudFilePresenter?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSignInStateChanged),
            name: .appleSignInStateChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAttributionChanged),
            name: .tripCoverAttributionChanged,
            object: nil
        )
    }

    func start() {
        // no-op; ensures singleton initializes.
        handleSignInStateChanged()
    }

    @objc
    private func handleSignInStateChanged() {
        configurePresenterIfNeeded()
        loadFromActiveLocation()
    }

    @objc
    private func handleAttributionChanged() {
        scheduleSave()
    }

    private func scheduleSave() {
        pendingSaveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.saveToActiveLocation()
        }
        pendingSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func exportDictionary() -> [String: String] {
        let prefix = "coverAttributionName."
        let dict = UserDefaults.standard.dictionaryRepresentation()
        var out: [String: String] = [:]
        for (k, v) in dict {
            guard k.hasPrefix(prefix) else { continue }
            let tripID = String(k.dropFirst(prefix.count))
            let name = (v as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tripID.isEmpty, !name.isEmpty else { continue }
            out[tripID] = name
        }
        return out
    }

    private func applyDictionary(_ dict: [String: String]) {
        let prefix = "coverAttributionName."
        // Clear existing.
        for k in UserDefaults.standard.dictionaryRepresentation().keys where k.hasPrefix(prefix) {
            UserDefaults.standard.removeObject(forKey: k)
        }
        // Set new.
        for (tripID, name) in dict {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            UserDefaults.standard.set(trimmed, forKey: "\(prefix)\(tripID)")
        }
    }

    private func saveToActiveLocation() {
        let urlSet = CloudSyncPaths.coverAttributionURL()
        let activeURL = urlSet.active
        let snapshot = exportDictionary()

        ioQueue.async {
            do {
                let data = try JSONSerialization.data(withJSONObject: snapshot, options: [.sortedKeys])
                try CoordinatedFileIO.writeData(data, to: activeURL)

                if urlSet.iCloud != nil {
                    try CoordinatedFileIO.writeData(data, to: urlSet.local)
                }
            } catch {
                print("Failed to save cover attribution: \(error)")
            }
        }
    }

    private func loadFromActiveLocation() {
        let urlSet = CloudSyncPaths.coverAttributionURL()

        if let iCloud = urlSet.iCloud {
            do {
                try CoordinatedFileIO.coordinatedCopyIfMissing(from: urlSet.local, to: iCloud)
            } catch {
                print("Failed to seed iCloud cover attribution file: \(error)")
            }
        }

        ioQueue.async {
            do {
                let data = try CoordinatedFileIO.readData(from: urlSet.active)
                guard !data.isEmpty else { return }
                let obj = try JSONSerialization.jsonObject(with: data)
                guard let dict = obj as? [String: String] else { return }
                DispatchQueue.main.async {
                    self.applyDictionary(dict)
                }
            } catch {
                // If missing or invalid, ignore.
            }
        }
    }
    
    private func configurePresenterIfNeeded() {
        let urlSet = CloudSyncPaths.coverAttributionURL()
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
            self?.loadFromActiveLocation()
        }
        self.presenter = newPresenter
        NSFileCoordinator.addFilePresenter(newPresenter)
    }
}

