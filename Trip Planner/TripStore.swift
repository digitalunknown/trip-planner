import Foundation
import SwiftUI

@Observable
class TripStore {
    var trips: [Trip] = []
    var isLoadingTrips: Bool = true
    private let ioQueue = DispatchQueue(label: "TripStore.ioQueue", qos: .utility)
    private var presenter: ICloudFilePresenter?
    private var hasCompletedInitialLoad: Bool = false
    
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
            
            let data: Data
            do {
                data = try CoordinatedFileIO.readData(from: urlSet.active)
            } catch {
                DispatchQueue.main.async {
                    self.trips = []
                    self.isLoadingTrips = false
                    self.hasCompletedInitialLoad = true
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let decoded = try decoder.decode([Trip].self, from: data)
                DispatchQueue.main.async {
                    self.trips = decoded
                    self.isLoadingTrips = false
                    self.hasCompletedInitialLoad = true
                }
            } catch {
                print("Failed to load trips: \(error)")
                DispatchQueue.main.async {
                    self.trips = []
                    self.isLoadingTrips = false
                    self.hasCompletedInitialLoad = true
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
        trips.append(trip)
        save()
    }
    
    func updateTrip(_ trip: Trip) {
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
}

