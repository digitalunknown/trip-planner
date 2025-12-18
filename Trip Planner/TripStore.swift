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
    
    private static let saveKey = "SavedTrips"
    
    init() {
        load()
    }
    
    func save() {
        do {
            let data = try JSONEncoder().encode(trips)
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        } catch {
            print("Failed to save trips: \(error)")
        }
    }
    
    func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.saveKey) else {
            trips = []
            return
        }
        
        do {
            trips = try JSONDecoder().decode([Trip].self, from: data)
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

