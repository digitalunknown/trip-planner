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
                                top: 0,
                                leading: RootHomeMetrics.horizontalInset,
                                bottom: 0,
                                trailing: RootHomeMetrics.horizontalInset
                            )
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .listRowSpacing(AppSpacing.sectionGap)
                .contentMargins(.top, RootHomeMetrics.topInset, for: .scrollContent)
                .contentMargins(.bottom, RootHomeMetrics.bottomInset, for: .scrollContent)
                .refreshable {
                    await refreshFeed(hapticOnSuccess: true)
                }
            }
        }
        .background(AppDetailSurface.page)
        .appRootNavigationTitle("Explore")
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
    
    private let mapInsetSize: CGFloat = TripVisualMetrics.mapInsetSize
    
    private var remoteCoverURL: URL? {
        guard let raw = pick.coverImageURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        return URL(string: raw)
    }
    
    private var hasCoverImage: Bool {
        remoteCoverURL != nil
    }
    
    private var imageShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: TripVisualMetrics.coverRadius, style: .continuous)
    }
    
    private var mapInsetShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: TripVisualMetrics.mapInsetRadius, style: .continuous)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: TripVisualMetrics.imageToTextGap) {
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
                        CoverOverlayBadge(
                            lucide: "star",
                            text: pick.badge,
                            style: .muted
                        )
                    }
                    .padding(TripVisualMetrics.overlayInset)
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
                                        .strokeBorder(AppColor.textStrong, lineWidth: 2)
                                }
                                .padding(TripVisualMetrics.overlayInset)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .clipShape(imageShape)
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
        VStack(alignment: .leading, spacing: AppSpacing.stackMicro) {
            Text(pick.title)
                .font(.app(17, weight: .semibold))
                .foregroundStyle(AppColor.textStrong)
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
    @Environment(RootTabChrome.self) private var tabChrome
    @Environment(\.dismiss) private var dismiss
    
    @State private var openedTripID: UUID?
    @State private var showCreateTripReview = false
    @State private var savedPlaceKeys: Set<String> = []
    @State private var coverByActivityID: [UUID: Data] = [:]
    @State private var loadingMapsID: UUID?
    @State private var selectedAppleMapItem: MKMapItem?
    @State private var activityPendingTripAdd: EventItem?
    @State private var topSafeArea: CGFloat = 0
    
    private var tripsForAddMenu: [Trip] {
        tripStore.trips.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
    
    private var remoteCoverURL: URL? {
        guard let raw = pick.coverImageURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        return URL(string: raw)
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
            VStack(alignment: .leading, spacing: 0) {
                heroImage
                    .padding(.top, -topSafeArea)
                
                VStack(alignment: .leading, spacing: ExploreDetailMetrics.sectionGap) {
                    header
                    
                    Button {
                        showCreateTripReview = true
                    } label: {
                        HStack(spacing: 10) {
                            AppIcon(lucide: "map-plus", size: 20, color: AppColor.page)
                            Text("Create Trip")
                                .font(.app(17, weight: .semibold))
                        }
                        .foregroundStyle(AppColor.page)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColor.textStrong, in: Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Create Trip")
                    
                    if !pick.paragraphs.isEmpty {
                        VStack(alignment: .leading, spacing: ExploreDetailMetrics.paragraphGap) {
                            ForEach(Array(pick.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                                Text(paragraph)
                                    .font(.appBody)
                                    .foregroundStyle(AppColor.textStrong)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    
                    ForEach(pick.activities) { activity in
                        explorePlaceCard(activity)
                    }
                }
                .padding(.horizontal, ExploreDetailMetrics.pagePadding)
                .padding(.top, AppSpacing.pageTop)
                .padding(.bottom, AppSpacing.pageBottom)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .scrollIndicators(.hidden)
        .background(AppDetailSurface.page.ignoresSafeArea())
        .background { topSafeAreaReader }
        .tint(.primary)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .enableSwipeBack()
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                LiquidGlassIconButton(systemName: "chevron.left", accessibilityLabelText: "Back") {
                    dismiss()
                }
            }
        }
        .onAppear { tabChrome.beginSuppressingAIAccessory() }
        .onDisappear { tabChrome.endSuppressingAIAccessory() }
        .applePlaceCardSheet(item: $selectedAppleMapItem)
        .sheet(item: $activityPendingTripAdd) { activity in
            PlaceAddToTripSheet(
                trips: tripsForAddMenu,
                subtitle: tripSubtitle(for:),
                onSelect: { trip in
                    addActivity(activity, to: trip)
                    activityPendingTripAdd = nil
                },
                onCancel: { activityPendingTripAdd = nil }
            )
            .tint(.primary)
        }
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
    
    private var header: some View {
        VStack(alignment: .leading, spacing: ExploreDetailMetrics.titleMetaGap) {
            Text(pick.title)
                .font(.appDisplay)
                .foregroundStyle(AppColor.textStrong)
                .multilineTextAlignment(.leading)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            
            ExploreMetadataLine(
                destination: pick.destination,
                publisher: pick.publisher,
                itemCount: pick.activities.count
            )
        }
    }
    
    private var topSafeAreaReader: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { topSafeArea = geo.safeAreaInsets.top }
                .onChange(of: geo.safeAreaInsets.top) { _, value in
                    topSafeArea = value
                }
        }
    }
    
    private var heroImage: some View {
        StretchyHero {
            if let url = remoteCoverURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        MapSnapshotView(region: pick.mapRegion)
                    case .empty:
                        ZStack {
                            AppDetailSurface.card
                            ProgressView()
                        }
                    @unknown default:
                        MapSnapshotView(region: pick.mapRegion)
                    }
                }
            } else {
                MapSnapshotView(region: pick.mapRegion)
            }
        }
        .accessibilityHidden(true)
    }
    
    private func explorePlaceCard(_ activity: EventItem) -> some View {
        let placeKey = placeIdentityKey(for: activity)
        let coverData = coverByActivityID[activity.id] ?? activity.photoData
        let subtitle: String = {
            let notes = activity.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if !notes.isEmpty { return notes }
            return activity.location.trimmingCharacters(in: .whitespacesAndNewlines)
        }()
        let isSaved = savedPlaceKeys.contains(placeKey) || placeAlreadySaved(activity)
        
        return VStack(alignment: .leading, spacing: ExploreDetailMetrics.cardStackGap) {
            VStack(alignment: .leading, spacing: ExploreDetailMetrics.cardTitleGap) {
                Text(activity.title.isEmpty ? "Untitled" : activity.title)
                    .font(.app(17, weight: .semibold))
                    .foregroundStyle(AppColor.textStrong)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.app(15, weight: .medium))
                        .foregroundStyle(AppColor.textStrong)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            placeCover(data: coverData)
            
            HStack(spacing: ExploreDetailMetrics.actionGap) {
                Button {
                    guard !isSaved else { return }
                    addActivityToPlaces(activity)
                } label: {
                    ExplorePlaceTextAction(
                        lucide: isSaved ? "map-pin-check" : "map-pin-plus",
                        title: isSaved ? "Saved to Places" : "Save to Places"
                    )
                }
                .buttonStyle(.plain)
                .disabled(isSaved)
                
                Button {
                    activityPendingTripAdd = activity
                } label: {
                    ExplorePlaceTextAction(lucide: "map-plus", title: "Add to Trip")
                }
                .buttonStyle(.plain)
            }
            
            Rectangle()
                .fill(AppColor.divider)
                .frame(height: 1)
            
            Button {
                Task { await openAppleMapsListing(for: activity) }
            } label: {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("View More Details")
                            .font(.app(15, weight: .medium))
                            .foregroundStyle(AppColor.textStrong)
                        Text("Photos, hours, ratings & more")
                            .font(.app(13, weight: .medium))
                            .foregroundStyle(AppColor.textWeak)
                    }
                    Spacer(minLength: 8)
                    if loadingMapsID == activity.id {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        AppIcon(lucide: "chevron-right", size: 24, color: AppColor.textWeak)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(loadingMapsID == activity.id)
        }
        .padding(ExploreDetailMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppDetailSurface.card, in: RoundedRectangle(cornerRadius: ExploreDetailMetrics.cardRadius, style: .continuous))
        .task(id: activity.id) {
            await loadAppleMapsCoverIfNeeded(for: activity)
        }
    }
    
    @ViewBuilder
    private func placeCover(data: Data?) -> some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: ExploreDetailMetrics.cardImageHeight)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: ExploreDetailMetrics.imageRadius, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: ExploreDetailMetrics.imageRadius, style: .continuous)
                    .fill(AppDetailSurface.boardCard)
                ProgressView()
            }
            .frame(maxWidth: .infinity)
            .frame(height: ExploreDetailMetrics.cardImageHeight)
            .accessibilityLabel("Loading photo")
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
    
    private func addActivity(_ activity: EventItem, to trip: Trip) {
        guard let index = tripStore.trips.firstIndex(where: { $0.id == trip.id }) else { return }
        let event = EventItem(
            title: activity.title,
            description: activity.description,
            time: activity.time,
            location: activity.location,
            latitude: activity.latitude,
            longitude: activity.longitude,
            icon: activity.icon,
            accent: activity.accent,
            photoData: coverByActivityID[activity.id] ?? activity.photoData
        )
        var updatedTrip = tripStore.trips[index]
        updatedTrip.showParkedIdeas = true
        updatedTrip.parkedIdeas.insert(event, at: 0)
        tripStore.trips[index] = updatedTrip
        tripStore.save()
        Haptics.bump()
    }
    
    private func tripSubtitle(for trip: Trip) -> String? {
        if trip.isDatesSet {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            formatter.setLocalizedDateFormatFromTemplate("MMMd yyyy")
            if Calendar.current.isDate(trip.startDate, inSameDayAs: trip.endDate) {
                return formatter.string(from: trip.startDate)
            }
            return "\(formatter.string(from: trip.startDate)) - \(formatter.string(from: trip.endDate))"
        }
        let destination = trip.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        return destination.isEmpty ? nil : destination
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
                Text(" ⋅ ")
            }
            if !publisher.isEmpty {
                Text("by \(publisher)")
            }
            if !destination.isEmpty || !publisher.isEmpty {
                Text(" ⋅ ")
            }
            Text(itemCountText)
        }
        .font(.app(13, weight: .medium))
        .foregroundStyle(AppColor.textWeak)
        .lineLimit(1)
    }
}

private enum ExploreDetailMetrics {
    static let pagePadding: CGFloat = 20
    static let sectionGap: CGFloat = AppSpacing.sectionGap
    static let titleMetaGap: CGFloat = AppSpacing.sm
    static let paragraphGap: CGFloat = AppSpacing.md
    static let cardPadding: CGFloat = AppSpacing.cardPadding
    static let cardRadius: CGFloat = 20
    static let cardStackGap: CGFloat = AppSpacing.sm
    static let cardTitleGap: CGFloat = AppSpacing.xs
    static let cardImageHeight: CGFloat = 184
    static let imageRadius: CGFloat = 15
    static let actionGap: CGFloat = AppSpacing.md
}

private struct ExplorePlaceTextAction: View {
    let lucide: String
    let title: String
    
    var body: some View {
        HStack(spacing: 5) {
            AppIcon(lucide: lucide, size: 24, color: AppColor.textStrong)
            Text(title)
                .font(.app(15, weight: .semibold))
                .foregroundStyle(AppColor.textStrong)
                .lineLimit(1)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        ExploreHomeView()
    }
    .environment(TripStore())
    .environment(PlaceStore())
    .environment(ExpertTipsStore())
    .environment(PremiumStore())
    .environment(RootTabChrome())
}
