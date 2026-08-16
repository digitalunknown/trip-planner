import SwiftUI

struct ContentView: View {
    fileprivate enum RootTab: Hashable {
        case myTrips
        case explore
        case places
        case trackers
        case search
    }
    
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("exploreSampleEnabled") private var exploreSampleEnabled: Bool = false
    @AppStorage("sampleTripCoverImageData") private var sampleTripCoverImageData: Data = Data()
    @State private var selectedTab: RootTab = .myTrips
    @State private var lastNonSearchTab: RootTab = .myTrips
    @State private var searchText: String = ""
    @State private var isSearchPresented: Bool = false
    @State private var tripStore = TripStore()
    @State private var placeStore = PlaceStore()
    @State private var tabChrome = RootTabChrome()
    @StateObject private var auth = AppleSignInManager()
    @State private var isPresentingSignInGate: Bool = false
    @State private var isFetchingSampleCover: Bool = false
    
    private let accentColor: Color = .orange
    
    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                modernTabView
            } else {
                legacyTabView
            }
        }
        .environment(tripStore)
        .environment(placeStore)
        .environment(tabChrome)
        .environmentObject(auth)
        .tint(accentColor)
        .environment(\.appAccentColor, accentColor)
        .preferredColorScheme(appearanceMode.preferredColorScheme)
        .onAppear {
            CloudSyncPaths.primeICloudContainerIfNeeded()
            CoverAttributionSync.shared.start()
            Task { await auth.refreshCredentialState() }
            updateSignInGatePresentation()
            injectSampleTripIfNeeded()
        }
        .onChange(of: auth.hasResolvedInitialAuthState) { _, _ in
            updateSignInGatePresentation()
        }
        .onChange(of: auth.isSignedIn) { _, newValue in
            if newValue {
                exploreSampleEnabled = false
            }
            updateSignInGatePresentation()
        }
        .onChange(of: exploreSampleEnabled) { _, _ in
            updateSignInGatePresentation()
            injectSampleTripIfNeeded()
        }
        .onChange(of: tripStore.isLoadingTrips) { _, _ in
            injectSampleTripIfNeeded()
        }
        .onChange(of: tripStore.trips.count) { _, _ in
            injectSampleTripIfNeeded()
        }
        .fullScreenCover(isPresented: $isPresentingSignInGate) {
            SignInGateView()
                .environmentObject(auth)
        }
        .onChange(of: selectedTab) { _, newTab in
            Haptics.tabSelectionChanged()
            if newTab == .search {
                isSearchPresented = true
            } else {
                lastNonSearchTab = newTab
                if isSearchPresented {
                    isSearchPresented = false
                }
            }
        }
        .onChange(of: isSearchPresented) { _, presented in
            if !presented {
                searchText = ""
                if selectedTab == .search {
                    selectedTab = lastNonSearchTab
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickActionCreateNewTrip)) { _ in
            selectedTab = .myTrips
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                NotificationCenter.default.post(name: .openNewTripSheet, object: nil)
            }
        }
    }
    
    // MARK: - Tab bars
    
    /// iOS 18+ `Tab` API with `role: .search` — floating magnifying glass beside the tab bar.
    /// `.searchable` lives on the search tab only (not the TabView) so Trips/Places/Profile stay clear.
    /// On iOS 26, that yields the liquid-glass search field above the keyboard.
    /// Trips / Places also show a liquid-glass AI accessory above the tab bar.
    @available(iOS 18.0, *)
    private var modernTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("Trips", systemImage: "suitcase.fill", value: RootTab.myTrips) {
                MyTripsView()
                    .tint(.primary)
            }
            
            Tab("Places", systemImage: "mappin.and.ellipse", value: RootTab.places) {
                NavigationStack {
                    PlacesHomeView()
                        .tint(.primary)
                }
            }
            
            Tab("Explore", systemImage: "safari.fill", value: RootTab.explore) {
                NavigationStack {
                    ExploreHomeView()
                        .tint(.primary)
                }
            }
            
            Tab("Profile", systemImage: "person.fill", value: RootTab.trackers) {
                NavigationStack {
                    TrackersHomeView()
                        .tint(.primary)
                }
            }
            
            Tab("Search", systemImage: "magnifyingglass", value: RootTab.search, role: .search) {
                NavigationStack {
                    GlobalSearchView(searchText: $searchText)
                        .tint(.primary)
                }
                .searchable(
                    text: $searchText,
                    isPresented: $isSearchPresented,
                    prompt: "Search trips and places"
                )
            }
        }
        .modifier(SearchTabActivationModifier())
        .modifier(AITabBarAccessoryModifier(selectedTab: selectedTab))
    }
    
    private var legacyTabView: some View {
        TabView(selection: $selectedTab) {
            MyTripsView()
                .tint(.primary)
                .tabItem {
                    Label("Trips", systemImage: "suitcase.fill")
                }
                .tag(RootTab.myTrips)
            
            NavigationStack {
                PlacesHomeView()
                    .tint(.primary)
            }
            .tabItem {
                Label("Places", systemImage: "mappin.and.ellipse")
            }
            .tag(RootTab.places)
            
            NavigationStack {
                ExploreHomeView()
                    .tint(.primary)
            }
            .tabItem {
                Label("Explore", systemImage: "safari.fill")
            }
            .tag(RootTab.explore)

            NavigationStack {
                TrackersHomeView()
                    .tint(.primary)
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
            .tag(RootTab.trackers)
            
            NavigationStack {
                GlobalSearchView(searchText: $searchText)
                    .tint(.primary)
            }
            .searchable(
                text: $searchText,
                isPresented: $isSearchPresented,
                prompt: "Search trips and places"
            )
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(RootTab.search)
        }
    }
    
    private func updateSignInGatePresentation() {
        // Wait until cached auth is restored so signed-in launches don't flash the gate.
        guard auth.hasResolvedInitialAuthState else {
            isPresentingSignInGate = false
            return
        }
        // If user is signed out and not exploring sample, gate the app.
        isPresentingSignInGate = (!auth.isSignedIn && !exploreSampleEnabled)
    }
    
    private func injectSampleTripIfNeeded() {
        guard exploreSampleEnabled, !auth.isSignedIn else { return }
        guard !tripStore.isLoadingTrips else { return }

        // IMPORTANT: Do not save the sample trip to disk.
        // Explore mode is for browsing; users must sign in to create real trips.
        let sample = makeSampleTripTokyoJuly2026()
        tripStore.trips = [sample]
        
        // Best-effort: fetch a cover image once and cache it.
        Task { await fetchSampleCoverIfNeeded() }
    }
    
    private func isSampleTripList(_ trips: [Trip]) -> Bool {
        guard trips.count == 1 else { return false }
        let t = trips[0]
        if t.id == Self.sampleTripID { return true }
        if t.name == "Sample Trip" { return true }
        // Legacy sample that may have been saved during earlier builds.
        if t.name == "Portugal Adventure", t.destination == "Lisbon" { return true }
        return false
    }
}

// MARK: - Sample trip generation

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    
    mutating func next() -> UInt64 {
        // LCG (good enough for deterministic UI sample content).
        state = 6364136223846793005 &* state &+ 1442695040888963407
        return state
    }
}

private struct SampleCityAirport {
    let city: String
    let airportName: String
    let airportCode: String
    let lat: Double
    let lon: Double
}

private struct SamplePlace {
    let name: String
    let address: String
    let lat: Double
    let lon: Double
    let icon: String
    let accent: EventAccent
    let costUSD: Double?
}

private struct SampleDestination {
    let city: String
    let airport: SampleCityAirport
    let centerLat: Double
    let centerLon: Double
    let places: [SamplePlace]
    let ideas: [SamplePlace]
}

private extension ContentView {
    static let sampleTripID = UUID(uuidString: "00000000-0000-0000-0000-000000000777")!

    func makeSampleTripTokyoJuly2026() -> Trip {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.date(from: DateComponents(year: 2026, month: 7, day: 14)) ?? Date()
        let day1Date = cal.startOfDay(for: start)
        let day2Date = cal.date(byAdding: .day, value: 1, to: day1Date) ?? day1Date
        let day3Date = cal.date(byAdding: .day, value: 2, to: day1Date) ?? day1Date
        let day4Date = cal.date(byAdding: .day, value: 3, to: day1Date) ?? day1Date
        let day5Date = cal.date(byAdding: .day, value: 4, to: day1Date) ?? day1Date
        let end = day5Date

        // Fixed Tokyo trip
        let destination = SampleDestination(
            city: "Tokyo",
            airport: SampleCityAirport(city: "Tokyo", airportName: "Haneda Airport", airportCode: "HND", lat: 35.5494, lon: 139.7798),
            centerLat: 35.6762,
            centerLon: 139.6503,
            places: [
                SamplePlace(name: "Senso-ji Temple", address: "2 Chome-3-1 Asakusa, Taito City", lat: 35.7148, lon: 139.7967, icon: "building.columns.fill", accent: .orange, costUSD: nil),
                SamplePlace(name: "Shibuya Scramble Crossing", address: "Shibuya City", lat: 35.6595, lon: 139.7005, icon: "figure.walk", accent: .mint, costUSD: nil),
                SamplePlace(name: "Meiji Jingu", address: "1-1 Yoyogikamizonocho, Shibuya City", lat: 35.6764, lon: 139.6993, icon: "leaf.fill", accent: .mint, costUSD: nil),
                SamplePlace(name: "Tsukiji Outer Market", address: "Tsukiji, Chuo City", lat: 35.6652, lon: 139.7708, icon: "cart.fill", accent: .yellow, costUSD: 22),
                SamplePlace(name: "Tokyo Skytree", address: "1 Chome-1-2 Oshiage, Sumida City", lat: 35.7101, lon: 139.8107, icon: "mappin.and.ellipse", accent: .blue, costUSD: 22),
                SamplePlace(name: "Ueno Park", address: "Uenokoen, Taito City", lat: 35.7148, lon: 139.7730, icon: "leaf.fill", accent: .mint, costUSD: nil),
                SamplePlace(name: "Tokyo Station", address: "1 Chome Marunouchi, Chiyoda City", lat: 35.6812, lon: 139.7671, icon: "tram.fill", accent: .red, costUSD: nil),
                SamplePlace(name: "teamLab Planets TOKYO", address: "6 Chome-1-16 Toyosu, Koto City", lat: 35.6491, lon: 139.7899, icon: "camera.fill", accent: .purple, costUSD: 30),
                SamplePlace(name: "Imperial Palace East Gardens", address: "Chiyoda City", lat: 35.6852, lon: 139.7528, icon: "leaf.fill", accent: .mint, costUSD: nil),
                SamplePlace(name: "Ichiran Ramen (Shibuya)", address: "Shibuya City", lat: 35.6590, lon: 139.6980, icon: "fork.knife", accent: .orange, costUSD: 18),
                SamplePlace(name: "Shinjuku Gyoen National Garden", address: "11 Naitomachi, Shinjuku City", lat: 35.6852, lon: 139.7100, icon: "leaf.fill", accent: .mint, costUSD: 6),
                SamplePlace(name: "Akihabara Electric Town", address: "Akihabara, Chiyoda City", lat: 35.6984, lon: 139.7730, icon: "bag.fill", accent: .purple, costUSD: 20),
                SamplePlace(name: "Ginza", address: "Ginza, Chuo City", lat: 35.6717, lon: 139.7650, icon: "bag.fill", accent: .yellow, costUSD: nil),
                SamplePlace(name: "Odaiba Seaside Park", address: "Odaiba, Minato City", lat: 35.6280, lon: 139.7765, icon: "water.waves", accent: .blue, costUSD: nil),
                SamplePlace(name: "Asakusa Street Food", address: "Asakusa, Taito City", lat: 35.7145, lon: 139.7960, icon: "takeoutbag.and.cup.and.straw.fill", accent: .orange, costUSD: 15),
                SamplePlace(name: "Tokyo Tower", address: "4 Chome-2-8 Shibakoen, Minato City", lat: 35.6586, lon: 139.7454, icon: "mappin.and.ellipse", accent: .red, costUSD: 15),
                SamplePlace(name: "Shibuya SKY", address: "2 Chome-24-12 Shibuya, Shibuya City", lat: 35.6580, lon: 139.7016, icon: "mappin.and.ellipse", accent: .blue, costUSD: 22),
                SamplePlace(name: "Takeshita Street", address: "1 Chome Jingumae, Shibuya City", lat: 35.6702, lon: 139.7026, icon: "figure.walk", accent: .mint, costUSD: nil),
                SamplePlace(name: "Hamarikyu Gardens", address: "1-1 Hamarikyuteien, Chuo City", lat: 35.6591, lon: 139.7633, icon: "leaf.fill", accent: .mint, costUSD: 4),
                SamplePlace(name: "Kanda Shrine", address: "2 Chome-16-2 Sotokanda, Chiyoda City", lat: 35.7020, lon: 139.7671, icon: "building.columns.fill", accent: .orange, costUSD: nil),
                SamplePlace(name: "Nakamise-dori", address: "1 Chome-36 Asakusa, Taito City", lat: 35.7139, lon: 139.7964, icon: "cart.fill", accent: .yellow, costUSD: 12)
            ],
            ideas: [
                SamplePlace(name: "Ghibli Museum", address: "1 Chome-1-83 Shimorenjaku, Mitaka City, Tokyo", lat: 35.6962, lon: 139.5704, icon: "ticket.fill", accent: .mint, costUSD: 10),
                SamplePlace(name: "Odaiba night photos", address: "1 Chome-4 Daiba, Minato City, Tokyo", lat: 35.6292, lon: 139.7769, icon: "camera.fill", accent: .purple, costUSD: nil),
                SamplePlace(name: "Depachika food hall", address: "4 Chome-6-16 Ginza, Chuo City, Tokyo", lat: 35.6717, lon: 139.7650, icon: "cart.fill", accent: .yellow, costUSD: 25),
                SamplePlace(name: "Sentō / onsen", address: "Thermae-Yu, 1 Chome-1-2 Kabukicho, Shinjuku City, Tokyo", lat: 35.6945, lon: 139.7035, icon: "water.waves", accent: .blue, costUSD: 20)
            ]
        )
        
        let homeAirports: [SampleCityAirport] = [
            SampleCityAirport(city: "San Francisco", airportName: "San Francisco Airport", airportCode: "SFO", lat: 37.6213, lon: -122.3790),
            SampleCityAirport(city: "Seattle", airportName: "Seattle Airport", airportCode: "SEA", lat: 47.4502, lon: -122.3088),
            SampleCityAirport(city: "Los Angeles", airportName: "Los Angeles Airport", airportCode: "LAX", lat: 33.9416, lon: -118.4085),
            SampleCityAirport(city: "Chicago", airportName: "O'Hare Airport", airportCode: "ORD", lat: 41.9742, lon: -87.9073)
        ]
        
        let home = homeAirports.first ?? SampleCityAirport(city: "San Francisco", airportName: "San Francisco Airport", airportCode: "SFO", lat: 37.6213, lon: -122.3790)
        
        let sampleName = "Sample Trip"
        let sampleDestination = destination.city
        
        let hotel = SamplePlace(
            name: "Shinjuku Granbell Hotel",
            address: "2 Chome-14-5 Kabukicho, Shinjuku City, Tokyo",
            lat: 35.6969,
            lon: 139.7057,
            icon: "bed.double.fill",
            accent: .purple,
            costUSD: nil
        )
        
        // Pre-pick places so each day gets real named spots (no vague placeholders).
        let placePool = destination.places
        let day2Places = Array(placePool.prefix(7))
        let day3Places = Array(placePool.dropFirst(7).prefix(7))
        let day4Places = Array(placePool.dropFirst(14).prefix(7))
        let day5Places = Array(placePool.dropFirst(21).prefix(2))
        
        let day1Events: [EventItem] = [
            makeEvent(
                on: day1Date,
                startHour: 14,
                startMinute: 0,
                durationMinutes: 60,
                title: "Hotel check-in",
                notes: "Drop bags, grab a quick shower, and head out when you're ready.",
                location: hotel.address,
                lat: hotel.lat,
                lon: hotel.lon,
                icon: hotel.icon,
                accent: hotel.accent,
                costUSD: nil
            ),
            makeEvent(
                on: day1Date,
                startHour: 16,
                startMinute: 30,
                durationMinutes: 90,
                title: day5Places.first?.name ?? "Neighborhood walk",
                notes: "Keep it light after the flight—stretch your legs and get oriented.",
                location: (day5Places.first?.address ?? "Shinjuku City, Tokyo"),
                lat: day5Places.first?.lat ?? 35.6938,
                lon: day5Places.first?.lon ?? 139.7034,
                icon: day5Places.first?.icon ?? "figure.walk",
                accent: day5Places.first?.accent ?? .mint,
                costUSD: day5Places.first?.costUSD
            ),
            makeEvent(
                on: day1Date,
                startHour: 19,
                startMinute: 0,
                durationMinutes: 90,
                title: "Dinner near Shinjuku",
                notes: "Aim for something easy and close to the hotel.",
                location: "Shinjuku City, Tokyo",
                lat: 35.6938,
                lon: 139.7034,
                icon: "fork.knife",
                accent: .orange,
                costUSD: 32
            )
        ]
        
        let day1 = TripDay(
            id: UUID(),
            date: day1Date,
            events: day1Events,
            reminders: [],
            checklists: [samplePackingChecklist(createdAt: day1Date)],
            flights: [sampleRoundTripFlight(kind: .outbound, day: day1Date, from: home, to: destination.airport)],
            label: "Arrival",
            order: 1,
            weatherIcon: "sun.max.fill",
            temperatureF: 74
        )
        
        let day2 = TripDay(
            id: UUID(),
            date: day2Date,
            events: sampleEvents(baseDate: day2Date, places: day2Places, startHourBase: 9),
            reminders: [
                ReminderItem(id: UUID(), text: "Charge cameras", createdAt: day2Date),
                ReminderItem(id: UUID(), text: "Refill metro pass", createdAt: day2Date)
            ],
            checklists: [],
            flights: [],
            label: "Day 2",
            order: 2,
            weatherIcon: "cloud.sun.fill",
            temperatureF: 70
        )
        
        let day3 = TripDay(
            id: UUID(),
            date: day3Date,
            events: sampleEvents(baseDate: day3Date, places: day3Places, startHourBase: 9),
            reminders: [],
            checklists: [],
            flights: [],
            label: "Day 3",
            order: 3,
            weatherIcon: "cloud.rain.fill",
            temperatureF: 66
        )
        
        let day4 = TripDay(
            id: UUID(),
            date: day4Date,
            events: sampleEvents(baseDate: day4Date, places: day4Places, startHourBase: 9),
            reminders: [],
            checklists: [],
            flights: [],
            label: "Day 4",
            order: 4,
            weatherIcon: "sun.max.fill",
            temperatureF: 73
        )
        
        let day5Events: [EventItem] = [
            makeEvent(
                on: day5Date,
                startHour: 10,
                startMinute: 0,
                durationMinutes: 60,
                title: "Hotel checkout",
                notes: "Leave bags with the front desk if you want to explore a bit more.",
                location: hotel.address,
                lat: hotel.lat,
                lon: hotel.lon,
                icon: hotel.icon,
                accent: hotel.accent,
                costUSD: nil
            ),
            makeEvent(
                on: day5Date,
                startHour: 12,
                startMinute: 0,
                durationMinutes: 90,
                title: day5Places.dropFirst().first?.name ?? "Last-minute souvenirs",
                notes: "Pick up snacks, gifts, and anything you forgot.",
                location: (day5Places.dropFirst().first?.address ?? "Shibuya City, Tokyo"),
                lat: day5Places.dropFirst().first?.lat ?? 35.6595,
                lon: day5Places.dropFirst().first?.lon ?? 139.7005,
                icon: day5Places.dropFirst().first?.icon ?? "bag.fill",
                accent: day5Places.dropFirst().first?.accent ?? .yellow,
                costUSD: day5Places.dropFirst().first?.costUSD
            )
        ]
        
        let day5 = TripDay(
            id: UUID(),
            date: day5Date,
            events: day5Events,
            reminders: [],
            checklists: [],
            flights: [sampleRoundTripFlight(kind: .returning, day: day5Date, from: home, to: destination.airport)],
            label: "Departure",
            order: 5,
            weatherIcon: "cloud.sun.fill",
            temperatureF: 71
        )
        
        return Trip(
            id: Self.sampleTripID,
            name: sampleName,
            destination: sampleDestination,
            startDate: start,
            endDate: end,
            latitude: destination.centerLat,
            longitude: destination.centerLon,
            mapSpan: 0.12,
            isDatesSet: true,
            unscheduledDaysCount: 5,
            days: [day1, day2, day3, day4, day5],
            coverImageData: sampleTripCoverImageData.isEmpty ? nil : sampleTripCoverImageData,
            showParkedIdeas: true,
            parkedIdeas: sampleParkedIdeas(ideas: Array(destination.ideas.prefix(3)))
        )
    }
    
    private enum SampleFlightKind {
        case outbound
        case returning
    }
    
    private func sampleRoundTripFlight(kind: SampleFlightKind, day: Date, from home: SampleCityAirport, to destination: SampleCityAirport) -> FlightItem {
        
        let cal = Calendar.current
        let base = cal.startOfDay(for: day)
        let startTime: Date
        let endTime: Date
        if kind == .outbound {
            // Realistic SFO → HND: ~11h. Depart night before, arrive 9:45 AM on Day 1.
            startTime = cal.date(byAdding: .day, value: -1, to: base)?.addingTimeInterval(22 * 3600 + 45 * 60) ?? base
            endTime = base.addingTimeInterval(9 * 3600 + 45 * 60)
        } else {
            // Return flight after checkout and a little exploring; realistic duration (~9h).
            startTime = base.addingTimeInterval(18 * 3600 + 30 * 60)
            endTime = startTime.addingTimeInterval(9 * 3600)
        }
        
        let cost = kind == .outbound ? 1986.0 : nil
        
        if kind == .outbound {
            return FlightItem(
                fromName: home.airportName,
                fromCode: home.airportCode,
                fromCity: home.city,
                fromLatitude: home.lat,
                fromLongitude: home.lon,
                fromTerminal: "1",
                fromGate: "A12",
                toName: destination.airportName,
                toCode: destination.airportCode,
                toCity: destination.city,
                toLatitude: destination.lat,
                toLongitude: destination.lon,
                toTerminal: "2",
                toGate: "B7",
                flightNumber: "\(home.airportCode)327",
                notes: "",
                accent: .neutral,
                startTime: startTime,
                endTime: endTime,
                cost: cost,
                costCurrencyCode: "USD"
            )
        } else {
            return FlightItem(
                fromName: destination.airportName,
                fromCode: destination.airportCode,
                fromCity: destination.city,
                fromLatitude: destination.lat,
                fromLongitude: destination.lon,
                fromTerminal: "2",
                fromGate: "B9",
                toName: home.airportName,
                toCode: home.airportCode,
                toCity: home.city,
                toLatitude: home.lat,
                toLongitude: home.lon,
                toTerminal: "1",
                toGate: "A3",
                flightNumber: "\(destination.airportCode)812",
                notes: "",
                accent: .neutral,
                startTime: startTime,
                endTime: endTime,
                cost: cost,
                costCurrencyCode: nil
            )
        }
    }
    
    private func samplePackingChecklist(createdAt: Date) -> ChecklistItem {
        ChecklistItem(
            id: UUID(),
            title: "Packing Checklist",
            items: [
                ChecklistEntry(id: UUID(), text: "Passport / ID", isDone: false),
                ChecklistEntry(id: UUID(), text: "Phone charger", isDone: false),
                ChecklistEntry(id: UUID(), text: "Sunglasses", isDone: false),
                ChecklistEntry(id: UUID(), text: "Comfortable shoes", isDone: false),
                ChecklistEntry(id: UUID(), text: "Medication", isDone: false),
                ChecklistEntry(id: UUID(), text: "Travel adapter", isDone: false),
                ChecklistEntry(id: UUID(), text: "Reusable water bottle", isDone: false)
            ],
            createdAt: createdAt
        )
    }
    
    private func sampleEvents(baseDate: Date, places: [SamplePlace], startHourBase: Int) -> [EventItem] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: baseDate)
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        
        return Array(places.enumerated()).map { idx, p in
            // Keep events spaced out throughout the day.
            let startHour = startHourBase + (idx * 2)
            let start = dayStart.addingTimeInterval(TimeInterval(startHour * 3600))
            let end = start.addingTimeInterval(90 * 60)
            let timeText = "\(f.string(from: start)) - \(f.string(from: end))"
            
            return EventItem(
                id: UUID(),
                title: p.name,
                description: noteText(for: p),
                time: timeText,
                location: "\(p.name), \(p.address)",
                latitude: p.lat,
                longitude: p.lon,
                icon: p.icon,
                accent: p.accent,
                photoData: nil,
                rating: 0,
                cost: p.costUSD,
                costCurrencyCode: p.costUSD == nil ? nil : "USD"
            )
        }
    }

    private func makeEvent(
        on day: Date,
        startHour: Int,
        startMinute: Int,
        durationMinutes: Int,
        title: String,
        notes: String,
        location: String,
        lat: Double,
        lon: Double,
        icon: String,
        accent: EventAccent,
        costUSD: Double?
    ) -> EventItem {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        let start = dayStart.addingTimeInterval(TimeInterval(startHour * 3600 + startMinute * 60))
        let end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
        
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        let timeText = "\(f.string(from: start)) - \(f.string(from: end))"
        
        return EventItem(
            id: UUID(),
            title: title,
            description: notes,
            time: timeText,
            location: location,
            latitude: lat,
            longitude: lon,
            icon: icon,
            accent: accent,
            photoData: nil,
            rating: 0,
            cost: costUSD,
            costCurrencyCode: costUSD == nil ? nil : "USD"
        )
    }
    
    private func sampleParkedIdeas(ideas: [SamplePlace]) -> [EventItem] {
        ideas.map { p in
            EventItem(
                id: UUID(),
                title: p.name,
                description: noteText(for: p),
                time: "",
                location: p.address,
                latitude: p.lat,
                longitude: p.lon,
                icon: p.icon,
                accent: p.accent,
                photoData: nil,
                rating: 0,
                cost: p.costUSD,
                costCurrencyCode: p.costUSD == nil ? nil : "USD"
            )
        }
    }

    private func noteText(for place: SamplePlace) -> String {
        switch place.icon {
        case "fork.knife", "takeoutbag.and.cup.and.straw.fill":
            return "Tip: Go early to avoid the rush."
        case "ticket.fill", "camera.fill":
            return "Tip: Book tickets in advance if needed."
        case "leaf.fill":
            return "Tip: Great spot for a short break and photos."
        case "tram.fill":
            return "Tip: Use Suica/PASMO for quick tap-to-pay."
        case "mappin.and.ellipse":
            return "Tip: Best views around sunset."
        case "cart.fill", "bag.fill":
            return "Tip: Bring cash—some stalls are card-free."
        default:
            return "Tip: Save this to your itinerary and adjust later."
        }
    }
    
    @MainActor
    func fetchSampleCoverIfNeeded() async {
        guard exploreSampleEnabled, !auth.isSignedIn else { return }
        guard sampleTripCoverImageData.isEmpty else { return }
        guard !isFetchingSampleCover else { return }
        isFetchingSampleCover = true
        defer { isFetchingSampleCover = false }
        
        do {
            let client = UnsplashAPIClient()
            let resp = try await client.searchPhotos(query: "Tokyo", page: 1, perPage: 10)
            guard let photo = resp.results.first,
                  let regular = photo.urls.regular,
                  let url = URL(string: regular) else { return }
            
            if let dl = photo.download_location {
                Task.detached {
                    try? await client.trackDownload(downloadLocation: dl)
                }
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            guard !data.isEmpty else { return }
            
            sampleTripCoverImageData = data
            TripCoverAttribution.setName(photo.user.name, for: Self.sampleTripID)
            
            // Refresh the in-memory sample trip so the UI updates immediately.
            if isSampleTripList(tripStore.trips) {
                var t = makeSampleTripTokyoJuly2026()
                t.coverImageData = data
                tripStore.trips = [t]
            }
        } catch {
            // Best-effort only; silently fail.
        }
    }
}

/// Activates the system search-tab morph (liquid glass field above the keyboard) on iOS 26+.
private struct SearchTabActivationModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .tabViewSearchActivation(.searchTabSelection)
        } else {
            content
        }
    }
}

/// Liquid-glass AI accessory above the tab bar on Trips and Places (iOS 26+).
private struct AITabBarAccessoryModifier: ViewModifier {
    let selectedTab: ContentView.RootTab
    @Environment(RootTabChrome.self) private var tabChrome
    
    private var showsAccessory: Bool {
        (selectedTab == .myTrips || selectedTab == .places) && !tabChrome.suppressBottomAIAccessory
    }
    
    private var accessoryTitle: String {
        selectedTab == .places ? "Find Places" : "Create Trip"
    }
    
    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content
                .tabBarMinimizeBehavior(.onScrollDown)
                .tabViewBottomAccessory(isEnabled: showsAccessory) {
                    accessoryButton
                }
        } else if #available(iOS 26.0, *) {
            content
                .tabBarMinimizeBehavior(.onScrollDown)
                .tabViewBottomAccessory {
                    if showsAccessory {
                        accessoryButton
                    }
                }
        } else {
            content
        }
    }
    
    @available(iOS 26.0, *)
    private var accessoryButton: some View {
        AITabBarAccessory(title: accessoryTitle, chrome: .systemTabAccessory) {
            switch selectedTab {
            case .places:
                NotificationCenter.default.post(name: .openAIFindPlaces, object: nil)
            case .myTrips:
                NotificationCenter.default.post(name: .openAICreateTrip, object: nil)
            default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
}
