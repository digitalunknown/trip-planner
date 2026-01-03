//
//  TripStore.swift
//  Trip Planner
//
//  Created by Piotr Osmenda on 12/18/25.
//

import Foundation
import SwiftUI

@Observable
class TripStore {
    var trips: [Trip] = []
    private let ioQueue = DispatchQueue(label: "TripStore.ioQueue", qos: .utility)
    
    private var saveURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("TripPlanner", isDirectory: true)
        return dir.appendingPathComponent("SavedTrips.json")
    }
    
    init() {
        load()
    }
    
    func save() {
        let snapshot = trips
        let url = saveURL
        
        ioQueue.async {
            do {
                let dir = url.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(snapshot)
                
                try data.write(to: url, options: [.atomic])
            } catch {
                print("Failed to save trips: \(error)")
            }
        }
    }
    
    func load() {
        let url = saveURL
        guard let data = try? Data(contentsOf: url) else {
            trips = []
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            trips = try decoder.decode([Trip].self, from: data)
        } catch {
            print("Failed to load trips: \(error)")
            trips = []
        }
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

