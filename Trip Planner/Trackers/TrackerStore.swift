import Foundation
import Combine

final class TrackerStore: ObservableObject {
    @Published var state = TrackerVisitedState()

    private let ioQueue = DispatchQueue(label: "TrackerStore.ioQueue", qos: .utility)

    private var saveURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("TripPlanner", isDirectory: true)
        return dir.appendingPathComponent("SavedTrackers.json")
    }

    init() {
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
        state.visitedIDsByTracker[tracker, default: []]
            .intersection(validIDs(in: tracker))
            .count
    }

    func save() {
        let snapshot = state
        let url = saveURL
        
        // Encode on the main actor (TrackerVisitedState is main-actor isolated under
        // SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor). Only do file IO off-thread.
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
                let dir = url.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                try data.write(to: url, options: [.atomic])
            } catch {
                print("Failed to save trackers: \(error)")
            }
        }
    }

    func load() {
        let url = saveURL
        guard let data = try? Data(contentsOf: url) else {
            state = TrackerVisitedState()
            return
        }

        do {
            let decoded = try JSONDecoder().decode(TrackerVisitedState.self, from: data)
            state = decoded
            pruneInvalidVisitedIDs()
        } catch {
            print("Failed to load trackers: \(error)")
            state = TrackerVisitedState()
        }
    }
}

