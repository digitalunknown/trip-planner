import Foundation
import Combine

final class TrackerStore: ObservableObject {
    @Published var state = TrackerVisitedState()

    private let ioQueue = DispatchQueue(label: "TrackerStore.ioQueue", qos: .utility)
    private var presenter: ICloudFilePresenter?

    private var urls: (active: URL, local: URL, iCloud: URL?) { CloudSyncPaths.trackersURL() }

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
    
    private func validIDs(in tracker: TrackerType) -> Set<String> {
        Set(TrackerData.items(for: tracker).map(\.id))
    }
    
    private func pruneInvalidVisitedIDs() {
        var updated = state
        for tracker in TrackerType.allCases {
            let current = updated.visitedIDsByTracker[tracker, default: []]
            updated.visitedIDsByTracker[tracker] = current.intersection(validIDs(in: tracker))
        }
        state = updated
    }

    func isVisited(_ itemID: String, in tracker: TrackerType) -> Bool {
        state.visitedIDsByTracker[tracker, default: []].contains(itemID)
    }

    func toggleVisited(_ itemID: String, in tracker: TrackerType) {
        var set = state.visitedIDsByTracker[tracker, default: []]
        if set.contains(itemID) {
            set.remove(itemID)
        } else {
            set.insert(itemID)
        }
        state.visitedIDsByTracker[tracker] = set
        save()
    }

    func visitedCount(in tracker: TrackerType) -> Int {
        visitedIDs(in: tracker).count
    }
    
    func visitedIDs(in tracker: TrackerType) -> Set<String> {
        state.visitedIDsByTracker[tracker, default: []]
            .intersection(validIDs(in: tracker))
    }

    func save() {
        let snapshot = state
        let urlSet = urls
        let url = urlSet.active
        
        let data: Data
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            data = try encoder.encode(snapshot)
        } catch {
            print("Failed to encode trackers: \(error)")
            return
        }

        ioQueue.async {
            do {
                try CoordinatedFileIO.writeData(data, to: url)
                
                // Keep a local cache even when writing to iCloud.
                if urlSet.iCloud != nil {
                    try CoordinatedFileIO.writeData(data, to: urlSet.local)
                }
            } catch {
                print("Failed to save trackers: \(error)")
            }
        }
    }

    func load() {
        let urlSet = urls
        configurePresenterIfNeeded(for: urlSet)

        ioQueue.async {
            // One-time migration: if iCloud is enabled but empty, seed it from local.
            if let iCloud = urlSet.iCloud {
                do {
                    try CoordinatedFileIO.coordinatedCopyIfMissing(from: urlSet.local, to: iCloud)
                } catch {
                    print("Failed to seed iCloud trackers file: \(error)")
                }
            }
            
            let data: Data
            do {
                data = try CoordinatedFileIO.readData(from: urlSet.active)
            } catch {
                DispatchQueue.main.async { self.state = TrackerVisitedState() }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(TrackerVisitedState.self, from: data)
                DispatchQueue.main.async {
                    self.state = decoded
                    self.pruneInvalidVisitedIDs()
                }
            } catch {
                print("Failed to load trackers: \(error)")
                DispatchQueue.main.async { self.state = TrackerVisitedState() }
            }
        }
    }
    
    @objc
    private func handleSignInStateChanged() {
        CloudSyncPaths.primeICloudContainerIfNeeded()
        if let presenter {
            NSFileCoordinator.removeFilePresenter(presenter)
            self.presenter = nil
        }
        load()
    }
    
    @objc
    private func handleICloudContainerPrimed() {
        load()
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
        self.presenter = newPresenter
        NSFileCoordinator.addFilePresenter(newPresenter)
    }
}

