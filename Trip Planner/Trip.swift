//
//  Trip.swift
//  Trip Planner
//
//  Created by Piotr Osmenda on 12/18/25.
//

import Foundation

struct Trip: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date
    
    var latitude: Double?
    var longitude: Double?
    var mapSpan: Double?
    
    var days: [TripDay]
    var coverImageData: Data?
    
    var showParkedIdeas: Bool
    var parkedIdeas: [EventItem]
    
    enum CodingKeys: String, CodingKey {
        case id, name, destination, startDate, endDate
        case latitude, longitude, mapSpan
        case days, coverImageData
        case showParkedIdeas, parkedIdeas
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        destination: String,
        startDate: Date,
        endDate: Date,
        latitude: Double? = nil,
        longitude: Double? = nil,
        mapSpan: Double? = nil,
        days: [TripDay] = [],
        coverImageData: Data? = nil,
        showParkedIdeas: Bool = false,
        parkedIdeas: [EventItem] = []
    ) {
        self.id = id
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.latitude = latitude
        self.longitude = longitude
        self.mapSpan = mapSpan
        self.days = days
        self.coverImageData = coverImageData
        self.showParkedIdeas = showParkedIdeas
        self.parkedIdeas = parkedIdeas
    }
    
    var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
    
    var daysUntilTrip: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: startDate)
        let components = calendar.dateComponents([.day], from: today, to: start)
        return components.day ?? 0
    }
    
    var tripDuration: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return (components.day ?? 0) + 1
    }
    
    static var sampleTrips: [Trip] {
        let baseDate = Date()
        let day1 = TripDay(
            id: UUID(),
            date: baseDate,
            events: [
                EventItem(
                    id: UUID(),
                    title: "Brunch",
                    description: "",
                    time: "9:30 AM",
                    location: "Alfama",
                    latitude: nil,
                    longitude: nil,
                    icon: "fork.knife",
                    accent: .gold,
                    photoData: nil
                )
            ],
            reminders: [],
            checklists: [],
            flights: [],
            label: "Arrival",
            order: 1,
            weatherIcon: "cloud.sun.fill",
            temperatureF: 72
        )
        
        return [
            Trip(
                name: "Portugal Adventure",
                destination: "Lisbon",
                startDate: baseDate,
                endDate: Calendar.current.date(byAdding: .day, value: 2, to: baseDate) ?? baseDate,
                latitude: 38.7223,
                longitude: -9.1393,
                mapSpan: 0.14,
                days: [day1],
                coverImageData: nil,
                showParkedIdeas: true,
                parkedIdeas: []
            )
        ]
    }
}

