import MapKit
import SwiftUI
import UIKit

struct ExploreHomeView: View {
    @State private var picks: [ExploreStaffPick] = []
    @State private var isLoadingRemote = false
    @State private var hasLoadedOnce = false
    @State private var loadError: String?
    
    var body: some View {
        Group {
            if picks.isEmpty {
                ScrollView {
                    emptyOrStatus
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                        .padding(.horizontal, RootHomeMetrics.horizontalInset)
                }
                .refreshable {
                    await refreshFeed(hapticOnSuccess: true)
                }
            } else {
                // `List` + `.refreshable` is more reliable inside TabView than ScrollView alone.
                List {
                    ForEach(picks) { pick in
                        NavigationLink(value: pick) {
                            ExploreFeedCard(pick: pick)
                        }
                        .buttonStyle(.plain)
                        .navigationLinkIndicatorVisibility(.hidden)
                        .listRowInsets(
                            EdgeInsets(
                                top: RootHomeMetrics.chromeToContent / 2,
                                leading: RootHomeMetrics.horizontalInset,
                                bottom: RootHomeMetrics.chromeToContent / 2,
                                trailing: RootHomeMetrics.horizontalInset
                            )
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await refreshFeed(hapticOnSuccess: true)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: ExploreStaffPick.self) { pick in
            ExploreDetailView(pick: pick)
        }
        .task {
            await refreshFeed()
        }
    }
    
    @ViewBuilder
    private var emptyOrStatus: some View {
        if isLoadingRemote, !hasLoadedOnce {
            ProgressView("Loading Explore…")
                .font(.appBody)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if let loadError {
            ContentUnavailableView {
                Label("Couldn't load Explore", systemImage: "wifi.exclamationmark")
            } description: {
                Text(loadError)
            } actions: {
                Button("Try Again") {
                    Task { await refreshFeed(hapticOnSuccess: true) }
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            ContentUnavailableView(
                "Nothing to explore yet",
                systemImage: "compass",
                description: Text("Pull to refresh when new staff picks are published.")
            )
        }
    }
    
    /// Always loads from the Vercel Explore API (backed by trip-planner-ai-proxy). No bundled content.
    private func refreshFeed(hapticOnSuccess: Bool = false) async {
        if isLoadingRemote { return }
        isLoadingRemote = true
        defer {
            isLoadingRemote = false
            hasLoadedOnce = true
        }
        let started = ContinuousClock.now
        do {
            let feed = try await ExploreFeedClient().fetchFeed(forceRefresh: true)
            guard !Task.isCancelled else { return }
            picks = feed.picks
            loadError = nil
            if hapticOnSuccess {
                Haptics.bump()
            }
        } catch {
            if picks.isEmpty {
                loadError = "Check your connection and try again."
            }
            #if DEBUG
            print("Explore feed refresh failed: \(error)")
            #endif
        }
        
        // Keep the pull-to-refresh spinner visible briefly even when the feed is unchanged.
        if hapticOnSuccess {
            let minimum: Duration = .milliseconds(1000)
            let elapsed = ContinuousClock.now - started
            if elapsed < minimum {
                try? await Task.sleep(for: minimum - elapsed)
            }
        }
    }
}

/// Trip-card-shaped unit for Explore staff picks (visual + details below).
struct ExploreFeedCard: View {
    let pick: ExploreStaffPick
    
    private let mapInsetSize: CGFloat = 88
    
    private var remoteCoverURL: URL? {
        guard let raw = pick.coverImageURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        return URL(string: raw)
    }
    
    private var hasCoverImage: Bool {
        remoteCoverURL != nil
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
                            AppIcon(systemName: "star.fill", size: 11, strokeWidth: 2, color: .white, filled: true)
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
        if let url = remoteCoverURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    GeometryReader { geo in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .allowsHitTesting(false)
                case .failure:
                    MapSnapshotView(region: pick.mapRegion)
                case .empty:
                    ZStack {
                        MapSnapshotView(region: pick.mapRegion)
                        ProgressView()
                            .tint(.white)
                    }
                @unknown default:
                    MapSnapshotView(region: pick.mapRegion)
                }
            }
        } else {
            MapSnapshotView(region: pick.mapRegion)
        }
    }
    
    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(pick.title)
                .font(.appHeadline)
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
    @Environment(ExpertTipsStore.self) private var expertTips
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
                category: placeType == .unspecified ? "attraction" : placeType.rawValue,
                photoData: coverByActivityID[activity.id] ?? activity.photoData
            )
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageWrappingTitle(title: pick.title)
                
                ExploreMetadataLine(
                    destination: pick.destination,
                    publisher: pick.publisher,
                    itemCount: pick.activities.count
                )
                
                Button {
                    showCreateTripReview = true
                } label: {
                    Label("Create Trip", appIcon: "luggage")
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .applePlaceCardSheet(item: $selectedAppleMapItem)
        .sheet(isPresented: $showCreateTripReview) {
            NavigationStack {
                AICreateTripReviewView(
                    trip: createTripDraft,
                    seedItems: createTripSeedItems,
                    replyText: AIReplyCopy.createTrip(trip: createTripDraft, itemCount: createTripSeedItems.count)
                ) { draft, tripItems, placeItems in
                    Task {
                        await commitExploreTrip(draft, seedItems: tripItems, placeItems: placeItems)
                        await MainActor.run {
                            showCreateTripReview = false
                        }
                    }
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
        let matchedTips = expertTips.tips(
            title: activity.title,
            location: activity.location,
            latitude: activity.latitude,
            longitude: activity.longitude
        )
        
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
        ) {
            if let tip = matchedTips.first {
                ExpertTipInlineCallout(tip: tip)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(ExploreDetailCardGlassBackground(fallback: placeCardFill))
        .task(id: activity.id) {
            await expertTips.refresh()
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
        
        let mapItem = await ApplePlaceLookup.mapItem(
            name: activity.title,
            location: activity.location,
            latitude: activity.latitude,
            longitude: activity.longitude,
            destinationHint: activity.location
        )
        let data: Data?
        if let mapItem {
            data = await PlaceAppleImagery.coverJPEG(for: mapItem)
        } else {
            data = await PlaceAppleImagery.coverJPEG(
                name: activity.title,
                location: activity.location,
                latitude: activity.latitude,
                longitude: activity.longitude
            )
        }
        guard let data, coverByActivityID[activity.id] == nil else { return }
        coverByActivityID[activity.id] = PlaceImageResolver.compressedCoverData(data)
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
    
    private func commitExploreTrip(
        _ draft: AITripDraft,
        seedItems: [PlanDayItem],
        placeItems: [PlanDayItem]
    ) async {
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
        
        var timedSeeds = seedItems
        PlanDayTiming.fillMissingActivityTimes(&timedSeeds)
        for item in timedSeeds where item.include {
            let dayIdx = min(max(item.dayIndex ?? 0, 0), days.count - 1)
            guard item.kind == .activity || item.kind == .place else { continue }
            let placeType = PlaceType.fromAICategory(item.category)
            days[dayIdx].events.append(EventItem(
                title: item.title,
                description: item.notes,
                time: PlanDayTiming.timeText(start: item.startTime, end: item.endTime),
                location: item.location,
                latitude: item.latitude,
                longitude: item.longitude,
                icon: placeType.mapIconName,
                accent: .cream,
                photoData: PlaceImageResolver.compressedCoverData(item.photoData)
            ))
        }
        
        for idx in days.indices {
            days[idx].events.sort { $0.startTimeMinutes < $1.startTimeMinutes }
        }
        
        let coverData = await ExploreCoverImage.jpegData(for: pick)
        
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
        
        await MainActor.run {
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
}

/// Resolves Explore cover images for trip creation from `coverImageURL`.
enum ExploreCoverImage {
    /// Downloads `coverImageURL` when present. Explore covers are not bundled.
    static func jpegData(for pick: ExploreStaffPick) async -> Data? {
        guard
            let raw = pick.coverImageURL?.trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty,
            let url = URL(string: raw)
        else { return nil }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 12
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            guard UIImage(data: data) != nil else { return nil }
            return PlaceImageResolver.compressedCoverData(data) ?? data
        } catch {
            return nil
        }
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

private struct ExploreDetailCardGlassBackground: ViewModifier {
    let fallback: Color
    private let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
                .clipShape(shape)
        } else {
            content
                .background(fallback, in: shape)
        }
    }
}

#Preview {
    NavigationStack {
        ExploreHomeView()
    }
    .environment(TripStore())
    .environment(PlaceStore())
    .environment(ExpertTipsStore())
}
