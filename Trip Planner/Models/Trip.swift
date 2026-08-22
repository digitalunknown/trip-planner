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
    
    var isDatesSet: Bool
    var unscheduledDaysCount: Int
    
    var days: [TripDay]
    var coverImageData: Data?
    
    var showParkedIdeas: Bool
    var parkedIdeas: [EventItem]
    
    enum CodingKeys: String, CodingKey {
        case id, name, destination, startDate, endDate
        case latitude, longitude, mapSpan
        case isDatesSet, unscheduledDaysCount
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
        isDatesSet: Bool = true,
        unscheduledDaysCount: Int = 5,
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
        self.isDatesSet = isDatesSet
        self.unscheduledDaysCount = max(1, unscheduledDaysCount)
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
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        mapSpan = try c.decodeIfPresent(Double.self, forKey: .mapSpan)
        
        isDatesSet = try c.decodeIfPresent(Bool.self, forKey: .isDatesSet) ?? true
        unscheduledDaysCount = max(1, try c.decodeIfPresent(Int.self, forKey: .unscheduledDaysCount) ?? 5)
        
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
        try c.encodeIfPresent(latitude, forKey: .latitude)
        try c.encodeIfPresent(longitude, forKey: .longitude)
        try c.encodeIfPresent(mapSpan, forKey: .mapSpan)
        
        try c.encode(isDatesSet, forKey: .isDatesSet)
        try c.encode(unscheduledDaysCount, forKey: .unscheduledDaysCount)
        
        try c.encode(days, forKey: .days)
        try c.encodeIfPresent(coverImageData, forKey: .coverImageData)
        try c.encode(showParkedIdeas, forKey: .showParkedIdeas)
        try c.encode(parkedIdeas, forKey: .parkedIdeas)
    }
    
    var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
    
    /// Card-friendly range without year (e.g. "Mar 12 - Mar 18").
    var formattedDateRangeWithoutYear: String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
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
                    accent: .mustard,
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

extension Trip {
    func duplicatedTrip() -> Trip {
        let duplicatedDays: [TripDay] = days.map { day in
            TripDay(
                id: UUID(),
                date: day.date,
                events: day.events.map { $0.duplicatedItem() },
                reminders: day.reminders.map { ReminderItem(id: UUID(), text: $0.text, createdAt: $0.createdAt) },
                checklists: day.checklists.map { checklist in
                    ChecklistItem(
                        id: UUID(),
                        title: checklist.title,
                        items: checklist.items.map { ChecklistEntry(id: UUID(), text: $0.text, isDone: $0.isDone) },
                        createdAt: checklist.createdAt
                    )
                },
                flights: day.flights.map { $0.duplicatedItem() },
                label: day.label,
                order: day.order,
                weatherIcon: day.weatherIcon,
                temperatureF: day.temperatureF
            )
        }
        
        let duplicatedParkedIdeas: [EventItem] = parkedIdeas.map { $0.duplicatedItem() }
        
        return Trip(
            id: UUID(),
            name: "Copy of \(name)",
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            latitude: latitude,
            longitude: longitude,
            mapSpan: mapSpan,
            isDatesSet: isDatesSet,
            unscheduledDaysCount: unscheduledDaysCount,
            days: duplicatedDays,
            coverImageData: coverImageData,
            showParkedIdeas: showParkedIdeas,
            parkedIdeas: duplicatedParkedIdeas
        )
    }
}

private extension EventItem {
    func duplicatedItem() -> EventItem {
        EventItem(
            id: UUID(),
            title: title,
            description: description,
            time: time,
            location: location,
            latitude: latitude,
            longitude: longitude,
            icon: icon,
            accent: accent,
            photoData: photoData,
            documents: documents,
            rating: rating,
            cost: cost,
            costCurrencyCode: costCurrencyCode
        )
    }
}

private extension FlightItem {
    func duplicatedItem() -> FlightItem {
        FlightItem(
            id: UUID(),
            fromName: fromName,
            fromCode: fromCode,
            fromCity: fromCity,
            fromLatitude: fromLatitude,
            fromLongitude: fromLongitude,
            fromTerminal: fromTerminal,
            fromGate: fromGate,
            toName: toName,
            toCode: toCode,
            toCity: toCity,
            toLatitude: toLatitude,
            toLongitude: toLongitude,
            toTerminal: toTerminal,
            toGate: toGate,
            travelMode: travelMode,
            flightNumber: flightNumber,
            notes: notes,
            documents: documents,
            accent: accent,
            startTime: startTime,
            endTime: endTime,
            cost: cost,
            costCurrencyCode: costCurrencyCode
        )
    }
}
