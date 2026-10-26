import Foundation
import SwiftUI

@Observable
class TripStore {
    var trips: [Trip] = []
    var isLoadingTrips: Bool = true
    private let ioQueue = DispatchQueue(label: "TripStore.ioQueue", qos: .utility)
    private var presenter: ICloudFilePresenter?
    private var hasCompletedInitialLoad: Bool = false
    // When true, allows saves before the first successful load because no backing file exists anywhere.
    private var canSaveBeforeInitialLoad: Bool = false
    // Captures user-initiated changes while waiting for the first successful load.
    private var pendingSaveSnapshot: [Trip]?
    private var lastTouchedTripID: UUID?
    
    private var urls: (active: URL, local: URL, iCloud: URL?) { CloudSyncPaths.tripsURL() }
    
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
    
    func save() {
        let snapshot = trips
        
        // Guard: Never persist before we know the true initial state of storage.
        // Brand-new users (no file anywhere) are allowed to save immediately.
        if !(hasCompletedInitialLoad || canSaveBeforeInitialLoad) {
            // Queue the snapshot to be merged after the first successful load.
            pendingSaveSnapshot = snapshot
            print("TripStore.save(): Skipping save until first successful load; queued snapshot.")
            // Widget snapshot can still reflect in-memory state.
            publishWidgetSnapshot(trips: snapshot)
            return
        }
        
        let urlSet = urls
        let url = urlSet.active
        
        ioQueue.async {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(snapshot)
                
                try CoordinatedFileIO.writeData(data, to: url)
                
                // Keep a local cache even when writing to iCloud.
                if urlSet.iCloud != nil {
                    try CoordinatedFileIO.writeData(data, to: urlSet.local)
                }
                
                ActivityDocumentStore.pruneUnreferencedFiles(in: snapshot)
            } catch {
                print("Failed to save trips: \(error)")
            }
        }
        publishWidgetSnapshot(trips: snapshot)
    }
    
    func load() {
        // If the user is signed in, wait for the iCloud container lookup to complete
        // before deciding we have "no trips" (prevents empty-state flash).
        if CloudSyncPaths.isSignedInToApple(), !CloudSyncPaths.hasAttemptedICloudContainerLookup() {
            isLoadingTrips = true
            return
        }

        let urlSet = urls
        configurePresenterIfNeeded(for: urlSet)

        ioQueue.async {
            // One-time migration: if iCloud is enabled but empty, seed it from local.
            if let iCloud = urlSet.iCloud {
                do {
                    try CoordinatedFileIO.coordinatedCopyIfMissing(from: urlSet.local, to: iCloud)
                } catch {
                    print("Failed to seed iCloud trips file: \(error)")
                }
            }
            
            let fm = FileManager.default
            let activeURL = urlSet.active
            let localExists = fm.fileExists(atPath: urlSet.local.path)
            var iCloudExists = false
            var iCloudIsDownloaded = false
            
            if let iCloudURL = urlSet.iCloud {
                iCloudExists = fm.fileExists(atPath: iCloudURL.path)
                if iCloudExists {
                    let keys: Set<URLResourceKey> = [
                        .ubiquitousItemDownloadingStatusKey,
                        .isUbiquitousItemKey,
                        .ubiquitousItemIsDownloadingKey
                    ]
                    if let vals = try? iCloudURL.resourceValues(forKeys: keys) {
                        if vals.ubiquitousItemDownloadingStatus == .current {
                            iCloudIsDownloaded = true
                        } else if let status = vals.ubiquitousItemDownloadingStatus,
                                  status == .downloaded {
                            iCloudIsDownloaded = true
                        }
                    }
                }
                
                // If the iCloud file exists but isn't downloaded yet, start download and wait briefly.
                if iCloudExists && !iCloudIsDownloaded {
                    _ = try? fm.startDownloadingUbiquitousItem(at: iCloudURL)
                    var attempts = 0
                    while attempts < 20 && !iCloudIsDownloaded {
                        if let vals = try? iCloudURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]) {
                            if vals.ubiquitousItemDownloadingStatus == .current ||
                                vals.ubiquitousItemDownloadingStatus == .downloaded {
                                iCloudIsDownloaded = true
                                break
                            }
                        }
                        Thread.sleep(forTimeInterval: 0.25)
                        attempts += 1
                    }
                }
            }
            
            // Try to read whatever is active (iCloud when available, otherwise local).
            do {
                let data = try CoordinatedFileIO.readData(from: activeURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let decoded = try decoder.decode([Trip].self, from: data)
                
                // Merge any pending, user-edited snapshot created before the first successful load.
                let finalTrips: [Trip] = {
                    guard let pending = self.pendingSaveSnapshot, !pending.isEmpty else { return decoded }
                    var map: [UUID: Trip] = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
                    for t in pending { map[t.id] = t }
                    return Array(map.values)
                }()
                let hadPendingBeforeMerge: Bool = (self.pendingSaveSnapshot != nil && !(self.pendingSaveSnapshot?.isEmpty ?? true))
                
                DispatchQueue.main.async {
                    self.trips = finalTrips
                    self.isLoadingTrips = false
                    self.hasCompletedInitialLoad = true
                    self.canSaveBeforeInitialLoad = false
                    self.pendingSaveSnapshot = nil
                    self.publishWidgetSnapshot(trips: finalTrips)
                }
                
                // If we merged any pending local edits into loaded trips, persist them now.
                if hadPendingBeforeMerge && finalTrips != decoded {
                    self.save()
                }
                return
            } catch {
                // Read failed. Decide whether this is "no file anywhere" vs. "waiting for iCloud download".
                let iCloudPathExists = (urlSet.iCloud != nil) ? fm.fileExists(atPath: urlSet.iCloud!.path) : false
                let noBackingFile = (!localExists && !iCloudPathExists)
                
                if noBackingFile {
                    // Treat as a clean slate — allow immediate saves.
                    let pending = self.pendingSaveSnapshot
                    DispatchQueue.main.async {
                        self.trips = pending ?? []
                        self.isLoadingTrips = false
                        self.hasCompletedInitialLoad = true
                        self.canSaveBeforeInitialLoad = true
                        self.publishWidgetSnapshot(trips: self.trips)
                    }
                    if let _ = pending {
                        // Persist the queued snapshot now that it's safe.
                        self.save()
                        self.pendingSaveSnapshot = nil
                    }
                    return
                }
                
                // Backing file exists (likely in iCloud) but couldn't be read — keep loading
                // and try again when the file presenter fires or after a short delay.
                print("TripStore.load(): Backing file exists but initial read failed. Waiting for download or change notification.")
                DispatchQueue.main.async {
                    self.isLoadingTrips = true
                }
                // Retry in the background after a short delay as a simple backoff.
                self.ioQueue.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.load()
                }
            }
        }
    }
    
    @objc
    private func handleSignInStateChanged() {
        CloudSyncPaths.primeICloudContainerIfNeeded()
        isLoadingTrips = true
        // Tear down any presenter and rebuild based on current storage location.
        if let presenter {
            NSFileCoordinator.removeFilePresenter(presenter)
            self.presenter = nil
        }
        load()
    }
    
    @objc
    private func handleICloudContainerPrimed() {
        // Only keep showing loading until the first load after iCloud priming.
        if !hasCompletedInitialLoad {
            isLoadingTrips = true
        }
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
    
    func addTrip(_ trip: Trip) {
        lastTouchedTripID = trip.id
        trips.append(trip)
        save()
    }
    
    func updateTrip(_ trip: Trip) {
        lastTouchedTripID = trip.id
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
            save()
        }
    }
    
    func deleteTrip(_ trip: Trip) {
        trips.removeAll { $0.id == trip.id }
        save()
    }
    
    func deleteTrip(at offsets: IndexSet) {
        trips.remove(atOffsets: offsets)
        save()
    }
    
    func publishWidgetSnapshot() {
        publishWidgetSnapshot(trips: trips)
    }
    
    private func publishWidgetSnapshot(trips: [Trip]) {
        WidgetSnapshotPublisher.publish(trips: trips, lastTouchedID: lastTouchedTripID)
    }
}

