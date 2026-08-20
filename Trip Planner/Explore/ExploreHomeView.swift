import MapKit
import SwiftUI
import UIKit

/// Hardcoded staff-picks feed — stand-in until a real public Explore feed exists.
struct ExploreHomeView: View {
    private let picks: [ExploreStaffPick] = ExploreStaffPick.staffPicks
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: RootHomeMetrics.chromeToContent) {
                ForEach(picks) { pick in
                    NavigationLink(value: pick) {
                        ExploreFeedCard(pick: pick)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, RootHomeMetrics.horizontalInset)
            .padding(.top, RootHomeMetrics.topInset)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: ExploreStaffPick.self) { pick in
            ExploreDetailView(pick: pick)
        }
    }
}

struct ExploreStaffPick: Identifiable, Hashable {
    let id: String
    let title: String
    let destination: String
    let publisher: String
    let badge: String
    let coverImageName: String?
    let latitude: Double
    let longitude: Double
    let mapSpan: Double
    let paragraphs: [String]
    let activities: [EventItem]
    
    var mapRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: mapSpan, longitudeDelta: mapSpan)
        )
    }
    
    static let staffPicks: [ExploreStaffPick] = [
        ExploreStaffPick(
            id: "paris-museums-kids",
            title: "The best Paris museums to visit with kids",
            destination: "Paris, France",
            publisher: "Cara Willenbrock",
            badge: "Staff Pick",
            coverImageName: "explore-content/paris-museums",
            latitude: 48.8606,
            longitude: 2.3376,
            mapSpan: 0.08,
            paragraphs: [
                "Parisian art museums are very welcoming to kids — but what does one actually think of these world-class cultural institutions when you’re touring with a little one in tow?",
                "This shortlist mixes headline collections with spaces that invite sketching, wandering, and hands-on moments. Use it as a flexible route: pair Orsay with Rodin on a dual ticket, leave room for a garden break, and treat fog sculptures and medieval moats as the real souvenirs.",
            ],
            activities: [
                EventItem(
                    title: "Bourse de Commerce",
                    description: "A former government building turned private art collection — ornate interiors colliding with contemporary work. Don’t miss Fujiko Nakaya’s Fog Sculpture when it’s on view.",
                    time: "10:00 AM",
                    location: "2 Rue de Viarmes, Paris",
                    latitude: 48.8628,
                    longitude: 2.3426,
                    icon: "building.columns.fill",
                    accent: .blue,
                    photoData: nil
                ),
                EventItem(
                    title: "Musée d'Orsay",
                    description: "A former train station turned Impressionist temple, crowned by the famous gold clock. Book a dual Orsay + Rodin ticket to skip lines and keep the day flexible.",
                    time: "11:30 AM",
                    location: "1 Rue de la Légion d'Honneur, Paris",
                    latitude: 48.8600,
                    longitude: 2.3266,
                    icon: "clock.fill",
                    accent: .orange,
                    photoData: nil
                ),
                EventItem(
                    title: "Musée Rodin",
                    description: "Hit The Atelier first — interactive, air-conditioned, and packed with activities — then wander the sculpture garden before and after.",
                    time: "1:30 PM",
                    location: "77 Rue de Varenne, Paris",
                    latitude: 48.8553,
                    longitude: 2.3158,
                    icon: "leaf.fill",
                    accent: .mint,
                    photoData: nil
                ),
                EventItem(
                    title: "Grand Palais — Matisse",
                    description: "A Matisse exhibit where the artist’s sketchbook can spark kids to open their own. Worth the stop if the current show is running.",
                    time: "3:30 PM",
                    location: "3 Avenue du Général Eisenhower, Paris",
                    latitude: 48.8660,
                    longitude: 2.3126,
                    icon: "paintpalette.fill",
                    accent: .purple,
                    photoData: nil
                ),
                EventItem(
                    title: "Musée du Louvre",
                    description: "Start at Le Studio for model sand, sketching, and books, then walk the Medieval Louvre — the empty former moat of the fortress, surprisingly peaceful with kids.",
                    time: "5:00 PM",
                    location: "Rue de Rivoli, Paris",
                    latitude: 48.8606,
                    longitude: 2.3376,
                    icon: "building.2.fill",
                    accent: .yellow,
                    photoData: nil
                ),
            ]
        ),
        ExploreStaffPick(
            id: "toronto-designer",
            title: "A designer's curated Toronto itinerary",
            destination: "Toronto, Canada",
            publisher: "Peter Osmenda",
            badge: "Staff Pick",
            coverImageName: "explore-content/toronto",
            latitude: 43.6532,
            longitude: -79.3832,
            mapSpan: 0.12,
            paragraphs: [
                "This is a design-forward day through Toronto — the kind of route a creative director would sketch for a short visit. Expect sharp architecture, thoughtful retail, and neighborhood texture instead of a checklist of tourist checkboxes.",
                "Walk between stops when you can. The point is noticing materials, storefronts, and street rhythm as much as the destinations themselves. Keep the afternoon flexible so coffee can turn into a longer linger.",
            ],
            activities: [
                EventItem(
                    title: "Art Gallery of Ontario",
                    description: "Gehry’s light-filled galleries and Canadian collections.",
                    time: "10:00 AM",
                    location: "317 Dundas St W, Toronto",
                    latitude: 43.6536,
                    longitude: -79.3925,
                    icon: "building.columns.fill",
                    accent: .blue,
                    photoData: nil
                ),
                EventItem(
                    title: "Grainge",
                    description: "Curated design objects and quiet browsing energy.",
                    time: "12:00 PM",
                    location: "Ossington Avenue, Toronto",
                    latitude: 43.6475,
                    longitude: -79.4200,
                    icon: "bag.fill",
                    accent: .mint,
                    photoData: nil
                ),
                EventItem(
                    title: "Lunch at Quetzal",
                    description: "Wood-fired Mexican with a refined room.",
                    time: "1:00 PM",
                    location: "419 College St, Toronto",
                    latitude: 43.6560,
                    longitude: -79.4075,
                    icon: "fork.knife",
                    accent: .orange,
                    photoData: nil
                ),
                EventItem(
                    title: "Distillery District walk",
                    description: "Brick lanes, galleries, and slow window-shopping.",
                    time: "3:00 PM",
                    location: "Distillery District, Toronto",
                    latitude: 43.6503,
                    longitude: -79.3595,
                    icon: "figure.walk",
                    accent: .yellow,
                    photoData: nil
                ),
                EventItem(
                    title: "Evergreen Brick Works",
                    description: "Adaptive reuse, trails, and golden-hour light.",
                    time: "5:00 PM",
                    location: "550 Bayview Ave, Toronto",
                    latitude: 43.6846,
                    longitude: -79.3656,
                    icon: "leaf.fill",
                    accent: .purple,
                    photoData: nil
                ),
            ]
        ),
        ExploreStaffPick(
            id: "nyc-foodies",
            title: "New York foodies",
            destination: "New York, USA",
            publisher: "Peter Osmenda",
            badge: "Staff Pick",
            coverImageName: "explore-content/new-york",
            latitude: 40.7128,
            longitude: -74.0060,
            mapSpan: 0.12,
            paragraphs: [
                "New York eats are endless, so this list stays opinionated: a tight set of places that reward appetite, patience, and a little neighborhood hopping. Think classics with staying power alongside rooms that still feel current.",
                "Don’t try to do every meal back-to-back. Pick two anchors for the day, leave space to wander into a bakery or market, and let the city’s pace decide whether dessert happens at the table or on the sidewalk.",
            ],
            activities: [
                EventItem(
                    title: "Russ & Daughters Cafe",
                    description: "Appetizing-counter legends with a sit-down ritual.",
                    time: "9:30 AM",
                    location: "127 Orchard St, New York",
                    latitude: 40.7195,
                    longitude: -73.9885,
                    icon: "cup.and.saucer.fill",
                    accent: .orange,
                    photoData: nil
                ),
                EventItem(
                    title: "Xi'an Famous Foods",
                    description: "Hand-pulled noodles and cumin heat.",
                    time: "12:30 PM",
                    location: "81 St Marks Pl, New York",
                    latitude: 40.7282,
                    longitude: -73.9857,
                    icon: "fork.knife",
                    accent: .red,
                    photoData: nil
                ),
                EventItem(
                    title: "Chelsea Market graze",
                    description: "A walkable circuit of stalls and small bites.",
                    time: "2:30 PM",
                    location: "75 9th Ave, New York",
                    latitude: 40.7424,
                    longitude: -74.0061,
                    icon: "cart.fill",
                    accent: .mint,
                    photoData: nil
                ),
                EventItem(
                    title: "Lucali",
                    description: "Cash-only pizza worth the Brooklyn pilgrimage.",
                    time: "6:30 PM",
                    location: "575 Henry St, Brooklyn",
                    latitude: 40.6818,
                    longitude: -74.0003,
                    icon: "flame.fill",
                    accent: .yellow,
                    photoData: nil
                ),
                EventItem(
                    title: "Uncle Boons Sister",
                    description: "Thai flavors in a lively late-night room.",
                    time: "9:00 PM",
                    location: "231 Eldridge St, New York",
                    latitude: 40.7214,
                    longitude: -73.9908,
                    icon: "wineglass.fill",
                    accent: .purple,
                    photoData: nil
                ),
            ]
        ),
    ]
}

/// Trip-card-shaped unit for Explore staff picks (visual + details below).
struct ExploreFeedCard: View {
    let pick: ExploreStaffPick
    
    private let mapInsetSize: CGFloat = 88
    
    private var hasCoverImage: Bool {
        guard let name = pick.coverImageName else { return false }
        return UIImage(named: name) != nil
    }
    
    private var imageShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
    }
    
    private var mapInsetShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            visual
            details
        }
        .contentShape(Rectangle())
    }
    
    private var visual: some View {
        FixedAspectCover {
            ZStack {
                coverOrMapBackground
                
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 5) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text(pick.badge)
                                .font(.appCaption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .modifier(ExploreBadgeGlassBackground())
                    }
                    .padding(12)
                    Spacer()
                }
                .allowsHitTesting(false)
                
                if hasCoverImage {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            MapSnapshotView(region: pick.mapRegion, snapshotSize: CGSize(width: 160, height: 160))
                                .frame(width: mapInsetSize, height: mapInsetSize)
                                .clipShape(mapInsetShape)
                                .overlay {
                                    mapInsetShape
                                        .strokeBorder(Color.white.opacity(0.92), lineWidth: 2)
                                }
                                .shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 4)
                                .padding(12)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .clipShape(imageShape)
        .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
    }
    
    @ViewBuilder
    private var coverOrMapBackground: some View {
        if let name = pick.coverImageName, let uiImage = UIImage(named: name) {
            FillCroppedImage(image: uiImage)
        } else {
            MapSnapshotView(region: pick.mapRegion)
        }
    }
    
    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(pick.title)
                .font(.appHeadline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .lineLimit(3)
            
            ExploreMetadataLine(
                destination: pick.destination,
                publisher: pick.publisher,
                itemCount: pick.activities.count
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Staff-pick detail: description, activities, and trip / places actions.
struct ExploreDetailView: View {
    let pick: ExploreStaffPick
    
    @Environment(TripStore.self) private var tripStore
    @Environment(PlaceStore.self) private var placeStore
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var openedTripID: UUID?
    @State private var showCreateTripReview = false
    @State private var savedPlaceKeys: Set<String> = []
    @State private var coverByActivityID: [UUID: Data] = [:]
    @State private var loadingMapsID: UUID?
    @State private var selectedAppleMapItem: MKMapItem?
    
    private var placeCardFill: Color {
        colorScheme == .dark ? Color(hex: 0x323234) : Color(hex: 0xE8E8ED)
    }
    
    private var createTripDraft: AITripDraft {
        AITripDraft(
            name: pick.title,
            destination: pick.destination,
            isDatesSet: false,
            unscheduledDaysCount: 1,
            summary: pick.paragraphs.first ?? "",
            confidence: 1
        )
    }
    
    private var createTripSeedItems: [PlanDayItem] {
        pick.activities.map { activity in
            let placeType = PlaceType.inferred(fromActivityIcon: activity.icon)
            return PlanDayItem(
                kind: .activity,
                include: true,
                dayIndex: 0,
                dayLabel: "Day 1",
                title: activity.title,
                location: activity.location,
                latitude: activity.latitude,
                longitude: activity.longitude,
                notes: activity.description,
                startTime: parseClockTime(activity.time),
                category: placeType == .unspecified ? "attraction" : placeType.rawValue
            )
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(pick.title)
                        .font(.appTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    ExploreMetadataLine(
                        destination: pick.destination,
                        publisher: pick.publisher,
                        itemCount: pick.activities.count
                    )
                }
                
                Button {
                    showCreateTripReview = true
                } label: {
                    Label("Create Trip", systemImage: "suitcase.fill")
                }
                .buttonStyle(.primaryCapsule)
                
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(pick.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .font(.appBody)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(pick.activities) { activity in
                        activityRow(activity)
                    }
                }
            }
            .padding(.horizontal, RootHomeMetrics.horizontalInset)
            .padding(.top, RootHomeMetrics.topInset)
            .padding(.bottom, 100)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground))
        .tint(.primary)
        .navigationBarTitleDisplayMode(.inline)
        .applePlaceCardSheet(item: $selectedAppleMapItem)
        .sheet(isPresented: $showCreateTripReview) {
            NavigationStack {
                AICreateTripReviewView(
                    trip: createTripDraft,
                    seedItems: createTripSeedItems,
                    replyText: AIReplyCopy.createTrip(trip: createTripDraft, itemCount: createTripSeedItems.count)
                ) { draft, tripItems, placeItems in
                    commitExploreTrip(draft, seedItems: tripItems, placeItems: placeItems)
                    showCreateTripReview = false
                }
            }
            .tint(.primary)
        }
        .navigationDestination(isPresented: Binding(
            get: { openedTripID != nil },
            set: { if !$0 { openedTripID = nil } }
        )) {
            if let tripID = openedTripID,
               let index = tripStore.trips.firstIndex(where: { $0.id == tripID }) {
                TripDetailView(
                    trip: Binding(
                        get: { tripStore.trips[index] },
                        set: { newValue in
                            tripStore.trips[index] = newValue
                            tripStore.save()
                        }
                    )
                )
            }
        }
    }
    
    private func activityRow(_ activity: EventItem) -> some View {
        let placeKey = placeIdentityKey(for: activity)
        let coverData = coverByActivityID[activity.id] ?? activity.photoData
        let subtitle: String = {
            let notes = activity.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if !notes.isEmpty { return notes }
            return activity.location.trimmingCharacters(in: .whitespacesAndNewlines)
        }()
        
        return AIResultItemCard(
            title: activity.title,
            subtitle: subtitle,
            photoData: coverData,
            primaryAction: .savePlace(isOn: Binding(
                get: {
                    savedPlaceKeys.contains(placeKey) || placeAlreadySaved(activity)
                },
                set: { newValue in
                    if newValue {
                        addActivityToPlaces(activity)
                    }
                }
            )),
            showsMapButton: true,
            isMapLoading: loadingMapsID == activity.id,
            showsPhotoPlaceholder: coverData == nil,
            onMapTap: {
                Task { await openAppleMapsListing(for: activity) }
            }
        )
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(placeCardFill)
        )
        .task(id: activity.id) {
            await loadAppleMapsCoverIfNeeded(for: activity)
        }
    }
    
    @MainActor
    private func loadAppleMapsCoverIfNeeded(for activity: EventItem) async {
        if coverByActivityID[activity.id] != nil { return }
        if let existing = activity.photoData, !existing.isEmpty {
            coverByActivityID[activity.id] = existing
            return
        }
        
        let data = await PlaceAppleImagery.coverJPEG(
            name: activity.title,
            location: activity.location,
            latitude: activity.latitude,
            longitude: activity.longitude
        )
        guard let data, coverByActivityID[activity.id] == nil else { return }
        coverByActivityID[activity.id] = data
    }
    
    @MainActor
    private func openAppleMapsListing(for activity: EventItem) async {
        loadingMapsID = activity.id
        defer { loadingMapsID = nil }
        await AIResultMaps.openListing(
            title: activity.title,
            location: activity.location,
            latitude: activity.latitude,
            longitude: activity.longitude,
            selectedMapItem: $selectedAppleMapItem
        )
    }
    
    private func addActivityToPlaces(_ activity: EventItem) {
        let key = placeIdentityKey(for: activity)
        guard !savedPlaceKeys.contains(key), !placeAlreadySaved(activity) else { return }
        savedPlaceKeys.insert(key)
        
        let placeType = PlaceType.inferred(fromActivityIcon: activity.icon)
        Task {
            let photoData = await resolvedCover(for: activity)
            await MainActor.run {
                let place = Place(
                    name: activity.title,
                    location: activity.location,
                    note: activity.description,
                    photoData: photoData,
                    latitude: activity.latitude,
                    longitude: activity.longitude,
                    placeType: placeType == .unspecified ? .attraction : placeType
                )
                placeStore.add(place)
                Haptics.bump()
            }
        }
    }
    
    private func resolvedCover(for activity: EventItem) async -> Data? {
        if let cached = coverByActivityID[activity.id], !cached.isEmpty { return cached }
        if let existing = activity.photoData, !existing.isEmpty { return existing }
        return await PlaceAppleImagery.coverJPEG(
            name: activity.title,
            location: activity.location,
            latitude: activity.latitude,
            longitude: activity.longitude
        )
    }
    
    private func placeAlreadySaved(_ activity: EventItem) -> Bool {
        let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let locationKey = PlaceNaming.normalizedLocationKey(activity.location)
        return placeStore.places.contains { place in
            place.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == title
                && PlaceNaming.normalizedLocationKey(place.location) == locationKey
        }
    }
    
    private func placeIdentityKey(for activity: EventItem) -> String {
        let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(title)|\(PlaceNaming.normalizedLocationKey(activity.location))"
    }
    
    private func parseClockTime(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        if let date = formatter.date(from: trimmed) { return date }
        formatter.dateFormat = "h:mm a"
        return formatter.date(from: trimmed)
    }
    
    private func timeText(start: Date?, end: Date?) -> String {
        guard let start else { return "" }
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        let s = f.string(from: start)
        if let end, end > start {
            return "\(s) - \(f.string(from: end))"
        }
        return s
    }
    
    private func commitExploreTrip(
        _ draft: AITripDraft,
        seedItems: [PlanDayItem],
        placeItems: [PlanDayItem]
    ) {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let destination = draft.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = name.isEmpty ? (destination.isEmpty ? "New Trip" : destination) : name
        let resolvedDestination = destination.isEmpty ? resolvedName : destination
        
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let dayCount = max(1, draft.unscheduledDaysCount)
        
        var days: [TripDay] = []
        for idx in 0..<dayCount {
            let date = calendar.date(byAdding: .day, value: idx, to: start) ?? start
            days.append(TripDay(
                id: UUID(),
                date: date,
                events: [],
                reminders: [],
                checklists: [],
                flights: [],
                label: "Day \(idx + 1)",
                order: idx + 1,
                weatherIcon: "cloud.sun.fill",
                temperatureF: 72
            ))
        }
        
        for item in seedItems where item.include {
            let dayIdx = min(max(item.dayIndex ?? 0, 0), days.count - 1)
            guard item.kind == .activity || item.kind == .place else { continue }
            let placeType = PlaceType.fromAICategory(item.category)
            days[dayIdx].events.append(EventItem(
                title: item.title,
                description: item.notes,
                time: timeText(start: item.startTime, end: item.endTime),
                location: item.location,
                latitude: item.latitude,
                longitude: item.longitude,
                icon: placeType == .unspecified ? "mappin.and.ellipse" : placeType.iconSystemName,
                accent: .neutral,
                photoData: item.photoData
            ))
        }
        
        for idx in days.indices {
            days[idx].events.sort { $0.startTimeMinutes < $1.startTimeMinutes }
        }
        
        let coverData: Data? = {
            guard let name = pick.coverImageName,
                  let image = UIImage(named: name) else { return nil }
            return image.jpegData(compressionQuality: 0.85)
        }()
        
        let trip = Trip(
            name: resolvedName,
            destination: resolvedDestination,
            startDate: start,
            endDate: calendar.date(byAdding: .day, value: max(0, dayCount - 1), to: start) ?? start,
            latitude: pick.latitude,
            longitude: pick.longitude,
            mapSpan: pick.mapSpan,
            isDatesSet: false,
            unscheduledDaysCount: dayCount,
            days: days,
            coverImageData: coverData,
            showParkedIdeas: false,
            parkedIdeas: []
        )
        
        tripStore.addTrip(trip)
        
        AchievementCounters.recordAIDaysPlanned(dayCount)
        
        for item in placeItems where item.canSaveToPlaces {
            let placeName = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !placeName.isEmpty else { continue }
            let place = Place(
                name: placeName,
                location: item.location,
                note: item.notes,
                photoData: item.photoData,
                latitude: item.latitude,
                longitude: item.longitude,
                placeType: PlaceType.fromAICategory(item.category),
                sourceTripID: trip.id,
                sourceTripName: trip.name
            )
            placeStore.add(place)
        }
        
        Haptics.bump()
        openedTripID = trip.id
    }
}

/// Shared metadata line for Explore feed + detail (caption, middle dots).
private struct ExploreMetadataLine: View {
    let destination: String
    let publisher: String
    let itemCount: Int
    
    private var itemCountText: String {
        "\(itemCount) \(itemCount == 1 ? "place" : "places")"
    }
    
    var body: some View {
        let destination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let publisher = publisher.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return HStack(spacing: 0) {
            if !destination.isEmpty {
                Text(destination)
            }
            if !destination.isEmpty, !publisher.isEmpty {
                Text("  ·  ")
            }
            if !publisher.isEmpty {
                Text("by \(publisher)")
            }
            if !destination.isEmpty || !publisher.isEmpty {
                Text("  ·  ")
            }
            Text(itemCountText)
        }
        .font(.appCaption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

private struct ExploreBadgeGlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: Capsule(style: .continuous))
        } else {
            content
                .background {
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                }
        }
    }
}

#Preview {
    NavigationStack {
        ExploreHomeView()
    }
    .environment(TripStore())
    .environment(PlaceStore())
}
