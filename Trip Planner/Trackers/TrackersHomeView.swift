import SwiftUI
import PhotosUI
import UIKit

struct TrackersHomeView: View {
    @StateObject private var store = TrackerStore()
    @State private var showStatsSettings = false
    @State private var showCompletedTrips = false
    @State private var isShowingPassport = false
    @State private var presentedTracker: TrackerType?
    @State private var presentedGlobeTripID: UUID?
    @State private var showFullMap = false
    @State private var showSettings = false
    @State private var showAchievementsSheet = false
    @State private var avatarImage: UIImage?
    @State private var photosPickerPresented = false
    @State private var photoItem: PhotosPickerItem?
    
    @EnvironmentObject private var auth: AppleSignInManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(TripStore.self) private var tripStore
    @AppStorage("hiddenStats") private var hiddenStatsRaw: String = ""
    
    private var dayBackground: Color { colorScheme == .dark ? Color(hex: 0x171717) : Color(hex: 0xF0F0F0) }
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var textSecondary: Color { textPrimary.opacity(colorScheme == .dark ? 0.72 : 0.62) }
    
    private let stampCarouselSize: CGFloat = 120
    
    private static let collectionTrackers: [TrackerType] = [
        .countries,
        .continents,
        .nationalParks,
        .subwaySystems
    ]
    
    private var completedTrips: [Trip] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return tripStore.trips
            .filter { trip in
                guard trip.isDatesSet else { return false }
                let end = calendar.startOfDay(for: trip.endDate)
                return end < today
            }
            .sorted { $0.endDate > $1.endDate }
    }
    
    private var stampTrips: [Trip] {
        Array(completedTrips.prefix(12))
    }
    
    private var displayName: String {
        let name = (auth.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        return TripLevelProgress.title(forLevel: tripLevel) ?? "Getting started"
    }
    
    private var initials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }
        return letters.isEmpty ? "T" : letters.joined().uppercased()
    }
    
    private var narrativeSentence: String {
        let trips = completedTrips.count
        let countries = store.visitedCount(in: .countries)
        let continents = store.visitedCount(in: .continents)
        
        if trips == 0 {
            return "Finish your first trip to begin your travel story."
        }
        
        if let title = TripLevelProgress.title(forLevel: tripLevel) {
            var parts: [String] = [title]
            parts.append(trips == 1 ? "1 trip" : "\(trips) trips")
            if countries > 0 {
                parts.append(countries == 1 ? "1 country" : "\(countries) countries")
            }
            if continents > 0 {
                parts.append(continents == 1 ? "1 continent" : "\(continents) continents")
            }
            return parts.joined(separator: " · ")
        }
        
        let remaining = TripLevelProgress.tripsRemaining(forTripCount: trips) ?? 5
        let tripWord = trips == 1 ? "trip" : "trips"
        let moreWord = remaining == 1 ? "trip" : "trips"
        return "\(trips) \(tripWord) logged · \(remaining) more \(moreWord) to become a Wanderer"
    }
    
    private var allTravelItems: [FlightItem] {
        tripStore.trips.flatMap { $0.days.flatMap(\.flights) }
    }
    
    private var flightsCount: Int {
        allTravelItems.filter { $0.travelMode == .flight }.count
    }
    
    private var drivesCount: Int {
        allTravelItems.filter { $0.travelMode == .drive }.count
    }
    
    private var visibleCollections: [TrackerType] {
        Self.collectionTrackers.filter { !isStatHidden(statID(for: $0)) }
    }
    
    private var hiddenStats: Set<String> {
        Set(hiddenStatsRaw.split(separator: "|").map { String($0) }.filter { !$0.isEmpty })
    }
    
    private func statID(for tracker: TrackerType) -> String { "tracker:\(tracker.rawValue)" }
    
    private func isStatHidden(_ id: String) -> Bool { hiddenStats.contains(id) }
    
    private func setStatHidden(_ id: String, _ hidden: Bool) {
        var set = hiddenStats
        if hidden {
            set.insert(id)
        } else {
            set.remove(id)
        }
        hiddenStatsRaw = set.sorted().joined(separator: "|")
    }

    var body: some View {
        SwiftUI.ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 32) {
                profileIdentityRow
                
                statsGrid
                
                achievementsSection
                
                mapSection
                
                trackersSection
            }
            .padding(.horizontal, RootHomeMetrics.horizontalInset)
            .padding(.top, RootHomeMetrics.topInset)
            .padding(.bottom, RootHomeMetrics.bottomInset)
        }
        .background(Color(.systemBackground))
        .tint(.primary)
        .environment(\.appAccentColor, textPrimary)
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $presentedGlobeTripID) { tripID in
            tripDetail(for: tripID)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .fontWeight(.medium)
                }
            }
        }
        .sheet(item: $presentedTracker) { type in
            NavigationStack {
                TrackerDetailView(type: type, store: store)
                    .navigationTitle(type.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            LiquidGlassIconButton(systemName: "xmark") { presentedTracker = nil }
                        }
                    }
            }
            .environment(\.appAccentColor, textPrimary)
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isShowingPassport) {
            NavigationStack {
                PassportView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            LiquidGlassIconButton(systemName: "xmark") { isShowingPassport = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showFullMap) {
            NavigationStack {
                TravelGlobeMapView(trips: completedTrips) { trip in
                    showFullMap = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        presentedGlobeTripID = trip.id
                    }
                }
            }
            .environment(\.appAccentColor, textPrimary)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStatsSettings) {
            statsSettingsSheet
        }
        .sheet(isPresented: $showAchievementsSheet) {
            achievementsSheet
        }
        .sheet(isPresented: $showCompletedTrips) {
            completedTripsSheet
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(auth)
                .tint(.primary)
                .presentationDetents([.medium, .large])
        }
        .photosPicker(isPresented: $photosPickerPresented, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        avatarImage = image
                        ProfileAvatarStore.save(image)
                        photoItem = nil
                    }
                }
            }
        }
        .onAppear {
            if isStatHidden("stamps") {
                setStatHidden("stamps", false)
            }
            if avatarImage == nil {
                avatarImage = ProfileAvatarStore.load()
            }
        }
        .onChange(of: auth.userIdentifier) { _, _ in
            avatarImage = ProfileAvatarStore.load()
        }
    }
    
    // MARK: - Profile identity
    
    private var profileIdentityRow: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(narrativeSentence)
                .font(.app(14, weight: .regular))
                .foregroundStyle(textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            avatarButton
        }
    }
    
    private var avatarButton: some View {
        Menu {
            Button {
                photosPickerPresented = true
            } label: {
                Label(avatarImage == nil ? "Upload Photo" : "Update Photo", systemImage: "photo.on.rectangle")
            }
            if avatarImage != nil {
                Button {
                    avatarImage = nil
                    ProfileAvatarStore.clear()
                } label: {
                    Label("Remove Photo", systemImage: "trash")
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(textPrimary.opacity(0.08))
                if let avatarImage {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text(initials)
                        .font(.app(28, weight: .semibold))
                        .foregroundStyle(textPrimary)
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .strokeBorder(textPrimary.opacity(0.16), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Stats grid
    
    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 0) {
                profileStatCell(
                    value: completedTrips.count,
                    label: "Trips"
                ) {
                    if !completedTrips.isEmpty { showCompletedTrips = true }
                }
                
                profileStatCell(
                    value: flightsCount,
                    label: "Flights"
                )
                
                profileStatCell(
                    value: drivesCount,
                    label: "Drives"
                )
            }
            
            YearTravelGridView(trips: tripStore.trips)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .modifier(ProfileGlassBackground(cornerRadius: 22, fallback: dayBackground))
    }
    
    private func profileStatCell(
        value: Int,
        label: String,
        action: (() -> Void)? = nil
    ) -> some View {
        let content = VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.app(24, weight: .semibold))
                .foregroundStyle(textPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(label)
                .font(.app(12, weight: .regular))
                .foregroundStyle(textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        
        return Group {
            if let action {
                Button(action: action) { content }
                    .buttonStyle(.plain)
            } else {
                content
            }
        }
    }
    
    // MARK: - Achievements (level progress)
    
    private var tripsLoggedCount: Int { completedTrips.count }
    
    private var tripLevel: Int { TripLevelProgress.level(forTripCount: tripsLoggedCount) }
    
    private var tripLevelProgress: Double { TripLevelProgress.progress(forTripCount: tripsLoggedCount) }
    
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Achievements")
            
            Button {
                showAchievementsSheet = true
            } label: {
                HStack(alignment: .center, spacing: 16) {
                    levelBadge
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(TripLevelProgress.title(forLevel: tripLevel) ?? "Getting started")
                            .font(.app(18, weight: .semibold))
                            .foregroundStyle(textPrimary)
                        
                        Text(levelSubtitle)
                            .font(.appCaption)
                            .foregroundStyle(textSecondary)
                        
                        Capsule(style: .continuous)
                            .fill(textPrimary.opacity(colorScheme == .dark ? 0.22 : 0.14))
                            .frame(height: 8)
                            .overlay(alignment: .leading) {
                                Capsule(style: .continuous)
                                    .fill(textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .scaleEffect(x: tripLevelProgress, y: 1, anchor: .leading)
                            }
                            .clipShape(Capsule(style: .continuous))
                            .accessibilityValue("\(Int((tripLevelProgress * 100).rounded())) percent")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image(systemName: "chevron.right")
                        .font(.app(13, weight: .semibold))
                        .foregroundStyle(textSecondary.opacity(0.7))
                }
                .padding(16)
                .modifier(ProfileGlassBackground(cornerRadius: 20, fallback: dayBackground))
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
    
    private var levelSubtitle: String {
        if let remaining = TripLevelProgress.tripsRemaining(forTripCount: tripsLoggedCount),
           let nextTitle = TripLevelProgress.title(forLevel: tripLevel + 1) {
            let tripWord = remaining == 1 ? "trip" : "trips"
            return "\(tripsLoggedCount) logged · \(remaining) \(tripWord) to \(nextTitle)"
        }
        return "\(tripsLoggedCount) trips logged · Max rank"
    }
    
    @ViewBuilder
    private var levelBadge: some View {
        let size: CGFloat = 72
        if let name = TripLevelProgress.illustrationName(forLevel: tripLevel) {
            Image(name)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            // Level 0 — empty slot toward first badge
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(textSecondary.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .frame(width: size, height: size)
                Image(systemName: "sparkles")
                    .font(.app(22, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.55))
            }
        }
    }
    
    // MARK: - Legacy stamp achievements (hidden — kept for later)
    /*
    private var legacyAchievementsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionHeader("Achievements")
                Spacer(minLength: 0)
                if !completedTrips.isEmpty {
                    Button {
                        isShowingPassport = true
                    } label: {
                        Text("View all")
                            .font(.app(14, weight: .semibold))
                            .foregroundStyle(textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if completedTrips.isEmpty {
                emptyStampsPlaceholder
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(stampTrips) { trip in
                            PassportStampView(
                                destination: trip.destination,
                                iconSystemName: "globe",
                                date: trip.endDate,
                                size: stampCarouselSize,
                                tint: textPrimary
                            )
                            .frame(width: stampCarouselSize, height: stampCarouselSize)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isShowingPassport = true
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var emptyStampsPlaceholder: some View {
        HStack(spacing: 14) {
            PassportStampView(
                destination: "TripStacks",
                iconSystemName: "sparkles",
                date: Date(),
                size: 72,
                tint: textPrimary
            )
            
            Text("Complete a trip to earn your first stamp.")
                .font(.appSubheadline)
                .foregroundStyle(textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
        }
    }
    */
    
    // MARK: - Map
    
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Your World")
            
            Button {
                showFullMap = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    TravelGlobeCard(
                        trips: completedTrips,
                        allowsFullInteraction: false,
                        showsEmptyCopy: true,
                        showsFullGlobe: true
                    )
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .allowsHitTesting(false)
                    
                    Text("Explore")
                        .font(.appCaption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .modifier(MapExploreGlassBackground())
                        .padding(12)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Trackers
    
    private var trackersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Trackers")
            
            if visibleCollections.isEmpty {
                Text("All trackers are hidden.")
                    .font(.appCaption)
                    .foregroundStyle(textSecondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(ProfileGlassBackground(cornerRadius: 22, fallback: dayBackground))
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(visibleCollections) { type in
                        Button {
                            presentedTracker = type
                        } label: {
                            TrackerRowCard(
                                type: type,
                                visitedCount: store.visitedCount(in: type),
                                totalCount: TrackerData.items(for: type).count
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                presentedTracker = type
                            } label: {
                                Label("View", systemImage: "arrow.right.circle")
                            }
                            Button {
                                setStatHidden(statID(for: type), true)
                            } label: {
                                Label("Hide", systemImage: "eye.slash")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.app(15, weight: .semibold))
            .foregroundStyle(textSecondary)
            .textCase(.none)
    }
    
    // MARK: - Sheets
    
    @ViewBuilder
    private func tripDetail(for tripID: UUID) -> some View {
        if let index = tripStore.trips.firstIndex(where: { $0.id == tripID }) {
            TripDetailView(trip: Binding(
                get: { tripStore.trips[index] },
                set: { newValue in
                    tripStore.trips[index] = newValue
                    tripStore.save()
                }
            ))
        } else {
            Text("Trip unavailable")
                .foregroundStyle(.secondary)
        }
    }
    
    private var statsSettingsSheet: some View {
        NavigationStack {
            Form {
                Section("Trackers") {
                    ForEach(Self.collectionTrackers) { type in
                        Toggle(type.title, isOn: Binding(
                            get: { !isStatHidden(statID(for: type)) },
                            set: { setStatHidden(statID(for: type), !$0) }
                        ))
                        .tint(.primary)
                    }
                }
            }
            .navigationTitle("Edit Trackers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { showStatsSettings = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    LiquidGlassIconButton(systemName: "checkmark") { showStatsSettings = false }
                }
            }
        }
        .tint(.primary)
        .presentationDetents([.medium])
    }
    
    private var achievementsSheet: some View {
        NavigationStack {
            List {
                ForEach(1...3, id: \.self) { level in
                    achievementRow(level: level)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { showAchievementsSheet = false }
                }
            }
        }
        .tint(.primary)
        .presentationDetents([.medium, .large])
    }
    
    private func achievementRow(level: Int) -> some View {
        let unlocked = tripLevel >= level
        let threshold = TripLevelProgress.startThreshold(forLevel: level)
        let imageName = TripLevelProgress.illustrationName(forLevel: level)
        
        return HStack(spacing: 16) {
            Group {
                if let imageName {
                    Image(imageName)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                } else {
                    Color.clear
                }
            }
            .frame(width: 64, height: 64)
            .opacity(unlocked ? 1 : 0.28)
            .saturation(unlocked ? 1 : 0)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(TripLevelProgress.title(forLevel: level) ?? "Level \(level)")
                    .font(.app(17, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Text(unlocked ? "Unlocked" : "Log \(threshold) trips to unlock")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer(minLength: 0)
            
            if unlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.app(20, weight: .semibold))
                    .foregroundStyle(.primary)
            } else {
                Image(systemName: "lock.fill")
                    .font(.app(16, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
    
    private var completedTripsSheet: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 16) {
                    ForEach(completedTrips) { trip in
                        TripCardView(trip: trip)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Trips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { showCompletedTrips = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct ProfileGlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 22
    var fallback: Color
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        } else {
            content
                .background(
                    fallback,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        }
    }
}

private struct MapExploreGlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: Capsule())
        } else {
            content
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                }
        }
    }
}
