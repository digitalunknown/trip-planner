import Foundation
import MapKit
import SwiftUI

@Observable
class PlaceStore {
    var places: [Place] = []
    var isLoading: Bool = true
    
    private let ioQueue = DispatchQueue(label: "PlaceStore.ioQueue", qos: .utility)
    private var presenter: ICloudFilePresenter?
    private var hasCompletedInitialLoad: Bool = false
    /// Apple user id the in-memory `places` array currently belongs to (nil when signed out / cleared).
    private var loadedForUserID: String?
    
    private var urls: (active: URL, local: URL, iCloud: URL?) { CloudSyncPaths.placesURL() }
    
    /// Most recently saved first.
    var placesNewestFirst: [Place] {
        places.sorted { $0.updatedAt > $1.updatedAt }
    }
    
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
        guard CloudSyncPaths.isSignedInToApple() else { return }
        
        let snapshot = places
        let urlSet = urls
        let url = urlSet.active
        
        ioQueue.async {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(snapshot)
                try CoordinatedFileIO.writeData(data, to: url)
                if urlSet.iCloud != nil {
                    try CoordinatedFileIO.writeData(data, to: urlSet.local)
                }
            } catch {
                print("Failed to save places: \(error)")
            }
        }
    }
    
    func load() {
        guard let userID = CloudSyncPaths.currentAppleUserIdentifier() else {
            clearAccountData(isLoading: false)
            return
        }
        
        if !CloudSyncPaths.hasAttemptedICloudContainerLookup() {
            isLoading = true
            return
        }
        
        // Drop previous account's in-memory data before touching disk.
        if loadedForUserID != userID {
            places = []
            loadedForUserID = userID
        }
        
        let urlSet = urls
        configurePresenterIfNeeded(for: urlSet)
        isLoading = true
        
        ioQueue.async {
            CloudSyncPaths.migrateLegacyPlacesIfNeeded(for: userID)
            
            // Seed iCloud from this account's local cache only (never from another user).
            if let iCloud = urlSet.iCloud {
                do {
                    try CoordinatedFileIO.coordinatedCopyIfMissing(from: urlSet.local, to: iCloud)
                } catch {
                    print("Failed to seed iCloud places file: \(error)")
                }
            }
            
            // Bail if the user changed while we were on the background queue.
            guard CloudSyncPaths.currentAppleUserIdentifier() == userID else { return }
            
            let data: Data
            do {
                data = try CoordinatedFileIO.readData(from: urlSet.active)
            } catch {
                DispatchQueue.main.async {
                    guard CloudSyncPaths.currentAppleUserIdentifier() == userID else { return }
                    self.places = []
                    self.loadedForUserID = userID
                    self.isLoading = false
                    self.hasCompletedInitialLoad = true
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let decoded = try decoder.decode([Place].self, from: data)
                DispatchQueue.main.async {
                    guard CloudSyncPaths.currentAppleUserIdentifier() == userID else { return }
                    self.places = decoded
                    self.loadedForUserID = userID
                    self.isLoading = false
                    self.hasCompletedInitialLoad = true
                }
            } catch {
                print("Failed to load places: \(error)")
                DispatchQueue.main.async {
                    guard CloudSyncPaths.currentAppleUserIdentifier() == userID else { return }
                    self.places = []
                    self.loadedForUserID = userID
                    self.isLoading = false
                    self.hasCompletedInitialLoad = true
                }
            }
        }
    }
    
    @objc
    private func handleSignInStateChanged() {
        CloudSyncPaths.primeICloudContainerIfNeeded()
        // Immediately hide the previous account's places.
        clearAccountData(isLoading: CloudSyncPaths.isSignedInToApple())
        load()
    }
    
    @objc
    private func handleICloudContainerPrimed() {
        if !hasCompletedInitialLoad {
            isLoading = true
        }
        load()
    }
    
    private func clearAccountData(isLoading: Bool) {
        places = []
        loadedForUserID = nil
        self.isLoading = isLoading
        hasCompletedInitialLoad = !isLoading
        if let presenter {
            NSFileCoordinator.removeFilePresenter(presenter)
            self.presenter = nil
        }
    }
    
    private func configurePresenterIfNeeded(for urlSet: (active: URL, local: URL, iCloud: URL?)) {
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
            self?.load()
        }
        self.presenter = newPresenter
        NSFileCoordinator.addFilePresenter(newPresenter)
    }
    
    func add(_ place: Place) {
        guard CloudSyncPaths.isSignedInToApple() else { return }
        places.insert(place, at: 0)
        save()
        scheduleMapKitMatch(for: place.id)
    }
    
    func update(_ place: Place, rematchMapKitIfNeeded: Bool = true) {
        guard CloudSyncPaths.isSignedInToApple() else { return }
        guard let index = places.firstIndex(where: { $0.id == place.id }) else { return }
        let previous = places[index]
        var updated = place
        updated.updatedAt = Date()
        
        if rematchMapKitIfNeeded {
            let locationChanged = PlaceNaming.normalizedLocationKey(previous.location)
                != PlaceNaming.normalizedLocationKey(updated.location)
            let coordsChanged = previous.latitude != updated.latitude || previous.longitude != updated.longitude
            if locationChanged || coordsChanged {
                updated.mapKitIdentifier = nil
                updated.mapKitMatchStatus = .notAttempted
            }
        }
        
        places[index] = updated
        save()
        
        if rematchMapKitIfNeeded, updated.mapKitMatchStatus == .notAttempted {
            scheduleMapKitMatch(for: updated.id)
        }
    }
    
    func delete(_ place: Place) {
        guard CloudSyncPaths.isSignedInToApple() else { return }
        places.removeAll { $0.id == place.id }
        save()
    }
    
    func place(id: UUID) -> Place? {
        places.first { $0.id == id }
    }
    
    func unlinkAppleMapsMatch(for placeID: UUID) {
        guard var place = place(id: placeID) else { return }
        place.mapKitIdentifier = nil
        place.mapKitMatchStatus = .unmatched
        update(place, rematchMapKitIfNeeded: false)
    }
    
    func scheduleMapKitMatch(for placeID: UUID, force: Bool = false) {
        Task { @MainActor in
            await resolveMapKitMatchIfNeeded(placeID: placeID, force: force)
        }
    }
    
    @MainActor
    func resolveMapKitMatchIfNeeded(placeID: UUID, force: Bool = false) async {
        guard #available(iOS 18.0, *) else { return }
        guard CloudSyncPaths.isSignedInToApple() else { return }
        guard var existing = place(id: placeID) else { return }
        
        if !force {
            if existing.hasAppleMapsMatch {
                await enrichCoverImageIfNeeded(for: placeID)
                return
            }
            if existing.mapKitMatchStatus == .unmatched { return }
        }
        
        let identifier = await PlaceMapKitMatcher.resolveIdentifier(for: existing)
        guard placeStoreStillContains(placeID) else { return }
        guard CloudSyncPaths.isSignedInToApple() else { return }
        guard var latest = place(id: placeID) else { return }
        
        if let identifier {
            latest.mapKitIdentifier = identifier
            latest.mapKitMatchStatus = .matched
            await applyMapKitEnrichment(to: &latest, identifier: identifier)
        } else {
            latest.mapKitIdentifier = nil
            latest.mapKitMatchStatus = .unmatched
        }
        
        guard placeStoreStillContains(placeID) else { return }
        if let index = places.firstIndex(where: { $0.id == placeID }) {
            places[index] = latest
            save()
        }
    }
    
    /// Fills missing coordinates / cover from Apple Maps without overwriting user photos.
    @MainActor
    @available(iOS 18.0, *)
    private func applyMapKitEnrichment(to place: inout Place, identifier: String) async {
        guard let mapItem = await PlaceMapKitMatcher.loadMapItem(identifierRawValue: identifier) else {
            await assignCoverIfNeeded(to: &place)
            return
        }
        
        if let coordinate = mapItemCoordinate(mapItem) {
            if place.latitude == nil { place.latitude = coordinate.latitude }
            if place.longitude == nil { place.longitude = coordinate.longitude }
        }
        
        await assignCoverIfNeeded(to: &place)
    }
    
    @MainActor
    @available(iOS 18.0, *)
    private func enrichCoverImageIfNeeded(for placeID: UUID) async {
        guard var existing = place(id: placeID) else { return }
        guard existing.photoData == nil else { return }
        guard existing.hasAppleMapsMatch, let identifier = existing.mapKitIdentifier else { return }
        
        await applyMapKitEnrichment(to: &existing, identifier: identifier)
        guard existing.photoData != nil else { return }
        guard placeStoreStillContains(placeID) else { return }
        if let index = places.firstIndex(where: { $0.id == placeID }) {
            places[index] = existing
            save()
        }
    }
    
    @MainActor
    private func assignCoverIfNeeded(to place: inout Place) async {
        guard place.photoData == nil else { return }
        guard let lat = place.latitude, let lon = place.longitude else { return }
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        guard CLLocationCoordinate2DIsValid(coordinate) else { return }
        
        let placeID = place.id
        let jpeg = await PlaceAppleImagery.coverJPEG(at: coordinate)
        guard placeStoreStillContains(placeID) else { return }
        // Re-read in case the user set a photo while we were fetching.
        if let current = self.place(id: placeID), current.photoData != nil {
            place.photoData = current.photoData
            return
        }
        place.photoData = jpeg
    }
    
    private func placeStoreStillContains(_ placeID: UUID) -> Bool {
        places.contains { $0.id == placeID }
    }
    
    /// Upsert by source event, or merge into an existing place with the same location.
    @discardableResult
    func saveFromActivity(
        name: String,
        location: String,
        note: String,
        photoData: Data?,
        latitude: Double?,
        longitude: Double?,
        tripID: UUID,
        tripName: String,
        eventID: UUID?,
        placeType: PlaceType = .unspecified
    ) -> Place? {
        guard CloudSyncPaths.isSignedInToApple() else { return nil }
        
        let locationKey = PlaceNaming.normalizedLocationKey(location)
        
        // Already linked to this activity — never overwrite on repeat taps.
        if let eventID, let existing = places.first(where: { $0.sourceEventID == eventID }) {
            return existing
        }
        
        if let index = places.firstIndex(where: {
                !locationKey.isEmpty
                    && PlaceNaming.normalizedLocationKey($0.location) == locationKey
            }) {
            var existing = places[index]
            let locationChanged = PlaceNaming.normalizedLocationKey(existing.location) != locationKey
            existing.name = name
            existing.location = location.isEmpty ? existing.location : location
            if !note.isEmpty { existing.note = note }
            if let photoData { existing.photoData = photoData }
            existing.latitude = latitude ?? existing.latitude
            existing.longitude = longitude ?? existing.longitude
            existing.sourceTripID = tripID
            existing.sourceTripName = tripName
            if let eventID { existing.sourceEventID = eventID }
            if placeType != .unspecified {
                existing.placeType = placeType
            }
            existing.updatedAt = Date()
            if locationChanged || existing.mapKitMatchStatus == .notAttempted {
                existing.mapKitIdentifier = locationChanged ? nil : existing.mapKitIdentifier
                existing.mapKitMatchStatus = locationChanged ? .notAttempted : existing.mapKitMatchStatus
            }
            places[index] = existing
            save()
            if existing.mapKitMatchStatus == .notAttempted {
                scheduleMapKitMatch(for: existing.id)
            }
            return existing
        }
        
        let place = Place(
            name: name,
            location: location,
            note: note,
            photoData: photoData,
            latitude: latitude,
            longitude: longitude,
            placeType: placeType,
            sourceTripID: tripID,
            sourceTripName: tripName,
            sourceEventID: eventID
        )
        add(place)
        return place
    }
}
