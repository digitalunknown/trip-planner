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
    var notes: String
    var imageName: String
    var latitude: Double?
    var longitude: Double?
    var mapSpan: Double?  // Stores the appropriate zoom level for the destination
    var days: [TripDay]
    var coverImageData: Data?
    
    // Parked Ideas
    var showParkedIdeas: Bool
    var parkedIdeas: [EventItem]
    
    enum CodingKeys: String, CodingKey {
        case id, name, destination, startDate, endDate, notes, imageName, latitude, longitude, mapSpan, days, coverImageData
        case showParkedIdeas, parkedIdeas
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        destination: String,
        startDate: Date,
        endDate: Date,
        notes: String = "",
        imageName: String = "airplane",
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
        self.notes = notes
        self.imageName = imageName
        self.latitude = latitude
        self.longitude = longitude
        self.mapSpan = mapSpan
        self.days = days
        self.coverImageData = coverImageData
        self.showParkedIdeas = showParkedIdeas
        self.parkedIdeas = parkedIdeas
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        destination = try c.decode(String.self, forKey: .destination)
        startDate = try c.decode(Date.self, forKey: .startDate)
        endDate = try c.decode(Date.self, forKey: .endDate)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        imageName = try c.decodeIfPresent(String.self, forKey: .imageName) ?? "airplane"
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        mapSpan = try c.decodeIfPresent(Double.self, forKey: .mapSpan)
        days = try c.decodeIfPresent([TripDay].self, forKey: .days) ?? []
        coverImageData = try c.decodeIfPresent(Data.self, forKey: .coverImageData)
        showParkedIdeas = try c.decodeIfPresent(Bool.self, forKey: .showParkedIdeas) ?? false
        parkedIdeas = try c.decodeIfPresent([EventItem].self, forKey: .parkedIdeas) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(destination, forKey: .destination)
        try c.encode(startDate, forKey: .startDate)
        try c.encode(endDate, forKey: .endDate)
        try c.encode(notes, forKey: .notes)
        try c.encode(imageName, forKey: .imageName)
        try c.encode(latitude, forKey: .latitude)
        try c.encode(longitude, forKey: .longitude)
        try c.encode(mapSpan, forKey: .mapSpan)
        try c.encode(days, forKey: .days)
        try c.encode(coverImageData, forKey: .coverImageData)
        try c.encode(showParkedIdeas, forKey: .showParkedIdeas)
        try c.encode(parkedIdeas, forKey: .parkedIdeas)
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
        return [
            Trip(
                name: "Portugal Adventure",
                destination: "Lisbon • Cascais",
                startDate: baseDate,
                endDate: Calendar.current.date(byAdding: .day, value: 2, to: baseDate) ?? baseDate,
                notes: "Explore the city and coast",
                imageName: "airplane",
                latitude: 38.7223,
                longitude: -9.1393,
                days: [
                    TripDay(
                        id: UUID(),
                        date: baseDate,
                        events: [
                            EventItem(id: UUID(), title: "Brunch at Fauna & Flora", description: "Fresh bowls and coffee with a view of pink buildings.", time: "09:30", location: "Alfama", latitude: nil, longitude: nil, icon: "fork.knife", accent: .lavender, photoData: nil),
                            EventItem(id: UUID(), title: "Castle Walk", description: "Explore Castelo de S. Jorge and the winding streets around it.", time: "11:15", location: "Castelo", latitude: nil, longitude: nil, icon: "building.columns", accent: .burntOrange, photoData: nil),
                            EventItem(id: UUID(), title: "Sunset at Miradouro", description: "Golden hour photos above the river.", time: "18:45", location: "Miradouro da Graça", latitude: nil, longitude: nil, icon: "sunset.fill", accent: .gold, photoData: nil)
                        ],
                        label: "Lisbon Arrival",
                        order: 1,
                        weatherIcon: "cloud.sun.fill",
                        temperatureF: 72
                    ),
                    TripDay(
                        id: UUID(),
                        date: Calendar.current.date(byAdding: .day, value: 1, to: baseDate) ?? baseDate,
                        events: [
                            EventItem(id: UUID(), title: "LX Factory", description: "Design shops and coffee under the bridge.", time: "10:00", location: "Alcântara", latitude: nil, longitude: nil, icon: "bag.fill", accent: .sand, photoData: nil),
                            EventItem(id: UUID(), title: "Bike to Belém", description: "Pastéis de Nata stop and riverside ride.", time: "14:00", location: "Belém", latitude: nil, longitude: nil, icon: "bicycle", accent: .sky, photoData: nil)
                        ],
                        label: "Design Day",
                        order: 2,
                        weatherIcon: "sun.max.fill",
                        temperatureF: 75
                    ),
                    TripDay(
                        id: UUID(),
                        date: Calendar.current.date(byAdding: .day, value: 2, to: baseDate) ?? baseDate,
                        events: [
                            EventItem(id: UUID(), title: "Train to Cascais", description: "Coastal views on the way to the beaches.", time: "09:15", location: "Cais do Sodré", latitude: nil, longitude: nil, icon: "train.side.front.car", accent: .deepNavy, photoData: nil),
                            EventItem(id: UUID(), title: "Beach picnic", description: "Relax on Praia da Rainha with pastel de nata.", time: "12:30", location: "Cascais", latitude: nil, longitude: nil, icon: "beach.umbrella.fill", accent: .mint, photoData: nil),
                            EventItem(id: UUID(), title: "Seafood dinner", description: "Catch of the day at a local marisqueira.", time: "19:00", location: "Cascais Marina", latitude: nil, longitude: nil, icon: "fork.knife.circle.fill", accent: .forest, photoData: nil)
                        ],
                        label: "Coastal Escape",
                        order: 3,
                        weatherIcon: "cloud.sun.rain.fill",
                        temperatureF: 70
                    )
                ]
            ),
            Trip(
                name: "Business Conference",
                destination: "New York, USA",
                startDate: Date().addingTimeInterval(86400 * 14),
                endDate: Date().addingTimeInterval(86400 * 17),
                notes: "Tech conference downtown",
                imageName: "building.2",
                latitude: 40.7128,
                longitude: -74.0060
            ),
            Trip(
                name: "Beach Getaway",
                destination: "Cancun, Mexico",
                startDate: Date().addingTimeInterval(86400 * 60),
                endDate: Date().addingTimeInterval(86400 * 67),
                notes: "Relax and unwind",
                imageName: "sun.max",
                latitude: 21.1619,
                longitude: -86.8515
            )
        ]
    }
}

