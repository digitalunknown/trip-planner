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
    @State private var avatarImage: UIImage?
    @State private var photosPickerPresented = false
    @State private var photoItem: PhotosPickerItem?
    
    @EnvironmentObject private var auth: AppleSignInManager
    @Environment(TripStore.self) private var tripStore
    @AppStorage("hiddenStats") private var hiddenStatsRaw: String = ""
    
    private var textPrimary: Color { AppColor.textStrong }
    private var textSecondary: Color { AppColor.textWeak }
    private var travelYear: Int { Calendar.current.component(.year, from: Date()) }
    
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
    
    private var displayName: String {
        let name = (auth.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        return "Profile"
    }
    
    private var initials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }
        return letters.isEmpty ? "T" : letters.joined().uppercased()
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
        List {
            profileIdentityRow
                .profileHomeListRow()
            
            travelTimelineSection
                .profileHomeListRow()
            
            mapSection
                .profileHomeListRow()
            
            trackersSection
                .profileHomeListRow()
                .environment(\.appAccentColor, textPrimary)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .listRowSpacing(AppSpacing.sectionGap)
        .contentMargins(.top, RootHomeMetrics.topInset, for: .scrollContent)
        .contentMargins(.bottom, RootHomeMetrics.bottomInset, for: .scrollContent)
        .background(AppDetailSurface.page)
        .appRootNavigationTitle("Profile")
        .navigationDestination(item: $presentedGlobeTripID) { tripID in
            tripDetail(for: tripID)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    LiquidGlassToolbarIconLabel(systemName: "gearshape")
                }
                .liquidGlassToolbarControl()
                .accessibilityLabel("Settings")
            }
        }
        .sheet(item: $presentedTracker) { type in
            NavigationStack {
                TrackerDetailView(type: type, store: store)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            LiquidGlassIconButton(systemName: "xmark") { presentedTracker = nil }
                        }
                    }
            }
            .environment(\.appAccentColor, textPrimary)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
        HStack(alignment: .center, spacing: AppSpacing.md) {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            
            avatarButton
        }
    }
    
    private var avatarButton: some View {
        Menu {
            Button {
                photosPickerPresented = true
            } label: {
                Label(avatarImage == nil ? "Upload Photo" : "Update Photo", menuIcon: "photo.on.rectangle")
            }
            if avatarImage != nil {
                Button(role: .destructive) {
                    avatarImage = nil
                    ProfileAvatarStore.clear()
                } label: {
                    Label("Remove Photo", menuIcon: "trash")
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(AppColor.elevated)
                if let avatarImage {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text(initials)
                        .font(.app(30, weight: .semibold))
                        .foregroundStyle(textPrimary)
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Travel timeline
    
    private var travelTimelineSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.stackGap) {
            sectionHeader("Travel")
            
            YearTravelGridView(trips: tripStore.trips, year: travelYear)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.cardPadding)
                .background(
                    AppColor.card,
                    in: RoundedRectangle(cornerRadius: TripVisualMetrics.coverRadius, style: .continuous)
                )
        }
    }
    
    private func profileStatCell(
        value: Int,
        label: String,
        action: (() -> Void)? = nil
    ) -> some View {
        let content = VStack(alignment: .leading, spacing: AppSpacing.stackMicro) {
            Text("\(value)")
                .font(.app(24, weight: .semibold))
                .foregroundStyle(textPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(label)
                .font(.app(13, weight: .medium))
                .foregroundStyle(textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    
    // MARK: - Legacy stamp achievements (hidden — kept for later)
    /*
    private var legacyAchievementsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionHeader("Badges")
                Spacer(minLength: 0)
                if !completedTrips.isEmpty {
                    Button {
                        isShowingPassport = true
                    } label: {
                        Text("View all")
                            .font(.app(15, weight: .semibold))
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
        VStack(alignment: .leading, spacing: AppSpacing.stackGap) {
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
                    .clipShape(RoundedRectangle(cornerRadius: TripVisualMetrics.coverRadius, style: .continuous))
                    .allowsHitTesting(false)
                    
                    Text("Explore")
                        .font(.app(13, weight: .medium))
                        .foregroundStyle(AppColor.textStrong)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .modifier(MapExploreGlassBackground())
                        .padding(AppSpacing.md)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Trackers
    
    private var trackersSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.stackGap) {
            sectionHeader("Trackers")
            
            if visibleCollections.isEmpty {
                Text("All trackers are hidden.")
                    .font(.appCaption)
                    .foregroundStyle(textSecondary)
                    .padding(AppSpacing.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        AppColor.card,
                        in: RoundedRectangle(cornerRadius: TripVisualMetrics.coverRadius, style: .continuous)
                    )
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: AppSpacing.sm),
                        GridItem(.flexible(), spacing: AppSpacing.sm)
                    ],
                    spacing: AppSpacing.sm
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
                                Label("View", menuIcon: "arrow.right.circle")
                            }
                            Button {
                                setStatHidden(statID(for: type), true)
                            } label: {
                                Label("Hide", menuIcon: "eye.slash")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        AppSectionHeader(title, color: textSecondary)
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
                Section {
                    ForEach(Self.collectionTrackers) { type in
                        Toggle(isOn: Binding(
                            get: { !isStatHidden(statID(for: type)) },
                            set: { setStatHidden(statID(for: type), !$0) }
                        )) {
                            Label(type.title, appIcon: type.iconSystemName, color: .primary)
                        }
                        .tint(.primary)
                    }
                } header: {
                    AppSectionHeader("Trackers")
                }
                .appDetailFieldBackground()
            }
            .appFormPageSpacing()
            .appDetailFormChrome()
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
    
    private var completedTripsSheet: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: AppSpacing.md) {
                    ForEach(completedTrips) { trip in
                        TripCardView(trip: trip)
                    }
                }
                .padding(AppSpacing.pageInset)
            }
            .background(AppDetailSurface.page)
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

private extension View {
    func profileHomeListRow() -> some View {
        self
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
