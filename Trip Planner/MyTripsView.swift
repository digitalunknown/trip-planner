import SwiftUI
import MapKit

struct MyTripsView: View {
    private enum TripSegment: String, CaseIterable, Identifiable {
        case upcoming = "Upcoming"
        case past = "Past"
        case unscheduled = "Unscheduled"
        var id: String { rawValue }
    }
    
    @Environment(TripStore.self) private var tripStore
    @Environment(PlaceStore.self) private var placeStore
    @EnvironmentObject private var auth: AppleSignInManager
    @State private var isPresentingSignInGate: Bool = false
    @State private var showingNewTrip = false
    @State private var showingAICreateTrip = false
    @State private var navigationPath = NavigationPath()
    @State private var pendingNewTripID: UUID?
    @State private var editingTrip: Trip?
    @State private var tripForImagePicker: Trip?
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var tripForUnsplashCoverPicker: Trip?
    @State private var selectedSegment: TripSegment = .upcoming
    @State private var tripPendingDelete: Trip?
    
    private let pendingCreateTripFlagKey = "pendingCreateTripFromQuickAction"
    
    private func requestCreateTrip() {
        if auth.isSignedIn {
            showingNewTrip = true
        } else {
            isPresentingSignInGate = true
        }
    }
    
    private func availableSegments(for trips: [Trip]) -> [TripSegment] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let unscheduledCount = trips.filter { !$0.isDatesSet }.count
        let upcomingCount = trips.filter { trip in
            guard trip.isDatesSet else { return false }
            return calendar.startOfDay(for: trip.endDate) >= today
        }.count
        let pastCount = trips.filter { trip in
            guard trip.isDatesSet else { return false }
            return calendar.startOfDay(for: trip.endDate) < today
        }.count
        
        var segs: [TripSegment] = []
        if upcomingCount > 0 { segs.append(.upcoming) }
        if pastCount > 0 { segs.append(.past) }
        if unscheduledCount > 0 { segs.append(.unscheduled) }
        return segs
    }
    
    /// Year label above trip cards — keep metrics identical across segments to avoid layout jump.
    private func tripYearHeader(_ title: String, isFirst: Bool) -> some View {
        HStack {
            Text(title)
                .font(.appCaption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, isFirst ? 0 : 8)
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if tripStore.isLoadingTrips {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Loading trips")
                            .font(.appSubheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if tripStore.trips.isEmpty {
                    emptyStateView
                } else {
                    tripListView
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Trips")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: UUID.self) { tripID in
                if let index = tripStore.trips.firstIndex(where: { $0.id == tripID }) {
                    TripDetailView(trip: Binding(
                        get: { tripStore.trips[index] },
                        set: { newValue in
                            tripStore.trips[index] = newValue
                            tripStore.save()
                        }
                    ))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    LiquidGlassToolbarIconPair {
                        if #unavailable(iOS 26.0) {
                            Button {
                                showingAICreateTrip = true
                            } label: {
                                LiquidGlassToolbarIconLabel(systemName: "sparkles")
                            }
                            .buttonStyle(.plain)
                        }
                        Button {
                            requestCreateTrip()
                        } label: {
                            LiquidGlassToolbarIconLabel(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .fullScreenCover(isPresented: $isPresentingSignInGate) {
                SignInGateView()
                    .environmentObject(auth)
            }
            .sheet(isPresented: $showingNewTrip) {
                NewTripView(tripStore: tripStore) { newTripID in
                    pendingNewTripID = newTripID
                }
                .tint(.primary)
            }
            .sheet(isPresented: $showingAICreateTrip) {
                TripStacksAISheet(
                    mode: .createTrip,
                    existingTrips: tripStore.trips.map { trip in
                        AITripSummary(
                            name: trip.name,
                            destination: trip.destination,
                            startDate: trip.isDatesSet ? isoDate(trip.startDate) : nil,
                            endDate: trip.isDatesSet ? isoDate(trip.endDate) : nil
                        )
                    },
                    onCommitTrip: commitAITrip
                )
                .tint(.primary)
            }
            .onReceive(NotificationCenter.default.publisher(for: .openNewTripSheet)) { _ in
                openCreateTripSheetIfNeeded(force: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .openAICreateTrip)) { _ in
                showingAICreateTrip = true
            }
            .onAppear {
                openCreateTripSheetIfNeeded(force: false)
            }
            .sheet(item: $editingTrip) { trip in
                if let index = tripStore.trips.firstIndex(where: { $0.id == trip.id }) {
                    EditTripView(
                        trip: Binding(
                            get: { tripStore.trips[index] },
                            set: { newValue in
                                tripStore.trips[index] = newValue
                                tripStore.save()
                            }
                        ),
                        onDelete: {
                            withAnimation {
                                tripStore.deleteTrip(trip)
                            }
                        }
                    )
                    .tint(.primary)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                TripImagePicker(image: $selectedImage)
                    .tint(.primary)
            }
            .sheet(item: $tripForUnsplashCoverPicker) { trip in
                UnsplashCoverPickerSheet(initialQuery: trip.destination) { selection in
                    guard let index = tripStore.trips.firstIndex(where: { $0.id == trip.id }) else { return }
                    var updated = tripStore.trips[index]
                    updated.coverImageData = selection.imageData
                    tripStore.trips[index] = updated
                    TripCoverAttribution.setName(selection.photographerName, for: trip.id)
                    tripStore.save()
                    tripForUnsplashCoverPicker = nil
                }
                .presentationDetents([.large])
                .tint(.primary)
            }
            .alert(
                "Delete Trip",
                isPresented: Binding(
                    get: { tripPendingDelete != nil },
                    set: { if !$0 { tripPendingDelete = nil } }
                ),
                presenting: tripPendingDelete
            ) { trip in
                Button("Delete Trip", role: .destructive) {
                    withAnimation {
                        tripStore.deleteTrip(trip)
                    }
                    tripPendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    tripPendingDelete = nil
                }
            } message: { _ in
                Text("Are you sure you want to delete this trip? This action cannot be undone.")
            }
            .onChange(of: selectedImage) { _, newImage in
                if let image = newImage,
                   let tripToUpdate = tripForImagePicker,
                   let index = tripStore.trips.firstIndex(where: { $0.id == tripToUpdate.id }) {
                    var updated = tripStore.trips[index]
                    updated.coverImageData = image.jpegData(compressionQuality: 0.8)
                    tripStore.trips[index] = updated
                    TripCoverAttribution.clear(for: tripToUpdate.id)
                    tripStore.save()
                    selectedImage = nil
                    tripForImagePicker = nil
                }
            }
            .onChange(of: showingNewTrip) { _, isPresented in
                if !isPresented, let id = pendingNewTripID {
                    pendingNewTripID = nil
                    navigationPath.append(id)
                }
            }
            .onChange(of: showingAICreateTrip) { _, isPresented in
                if !isPresented, let id = pendingNewTripID {
                    pendingNewTripID = nil
                    navigationPath.append(id)
                }
            }
        }
        .tint(.primary)
    }
    
    private func isoDate(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.string(from: date)
    }
    
    private func parseISODate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        if let d = f.date(from: raw) { return d }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: raw)
    }
    
    private func commitAITrip(_ draft: AITripDraft, seedItems: [PlanDayItem], placeItems: [PlanDayItem]) {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let destination = draft.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = name.isEmpty ? (destination.isEmpty ? "New Trip" : destination) : name
        let resolvedDestination = destination.isEmpty ? resolvedName : destination
        
        let isDatesSet = draft.isDatesSet
        let start = parseISODate(draft.startDate) ?? Date()
        let end = parseISODate(draft.endDate) ?? start.addingTimeInterval(86400 * 3)
        let unscheduledCount = max(1, draft.unscheduledDaysCount)
        
        var days: [TripDay] = []
        if isDatesSet {
            let calendar = Calendar.current
            let totalDays = max(1, (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
            for offset in 0..<totalDays {
                let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
                days.append(TripDay(
                    id: UUID(),
                    date: date,
                    events: [],
                    reminders: [],
                    checklists: [],
                    flights: [],
                    label: "Day \(offset + 1)",
                    order: offset + 1,
                    weatherIcon: "cloud.sun.fill",
                    temperatureF: 72
                ))
            }
        } else {
            let base = Calendar.current.startOfDay(for: Date())
            for idx in 0..<unscheduledCount {
                let date = Calendar.current.date(byAdding: .day, value: idx, to: base) ?? base
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
        }
        
        applySeedItems(seedItems, to: &days)
        
        let newTrip = Trip(
            name: resolvedName,
            destination: resolvedDestination,
            startDate: start,
            endDate: max(start, end),
            isDatesSet: isDatesSet,
            unscheduledDaysCount: isDatesSet ? 0 : unscheduledCount,
            days: days,
            showParkedIdeas: !seedItems.isEmpty && days.allSatisfy({ $0.events.isEmpty && $0.reminders.isEmpty }),
            parkedIdeas: []
        )
        
        // If seeds didn't land on days, park activities in Ideas.
        var trip = newTrip
        if trip.days.allSatisfy({ $0.events.isEmpty && $0.reminders.isEmpty && $0.checklists.isEmpty && $0.flights.isEmpty }),
           !seedItems.isEmpty {
            trip.showParkedIdeas = true
            trip.parkedIdeas = seedItems.compactMap { item -> EventItem? in
                guard item.kind == .activity || item.kind == .place else { return nil }
                return EventItem(
                    title: item.title,
                    description: item.notes,
                    time: "",
                    location: item.location,
                    latitude: item.latitude,
                    longitude: item.longitude,
                    icon: "mappin.and.ellipse",
                    accent: .neutral,
                    photoData: nil
                )
            }
        }
        
        tripStore.addTrip(trip)
        pendingNewTripID = trip.id
        
        for item in placeItems where item.canSaveToPlaces {
            let placeName = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !placeName.isEmpty else { continue }
            let place = Place(
                name: placeName,
                location: item.location,
                note: item.notes,
                latitude: item.latitude,
                longitude: item.longitude,
                placeType: PlaceType.fromAICategory(item.category),
                sourceTripID: trip.id,
                sourceTripName: trip.name
            )
            placeStore.add(place)
        }
    }
    
    private func applySeedItems(_ items: [PlanDayItem], to days: inout [TripDay]) {
        guard !days.isEmpty else { return }
        let now = Date()
        for item in items where item.include {
            let idx: Int = {
                if let dayIndex = item.dayIndex, dayIndex >= 0, dayIndex < days.count {
                    return dayIndex
                }
                return 0
            }()
            
            switch item.kind {
            case .activity, .place:
                days[idx].events.append(EventItem(
                    title: item.title,
                    description: item.notes,
                    time: "",
                    location: item.location,
                    latitude: item.latitude,
                    longitude: item.longitude,
                    icon: "mappin.and.ellipse",
                    accent: .neutral,
                    photoData: nil
                ))
            case .reminder:
                days[idx].reminders.append(ReminderItem(id: UUID(), text: item.title, createdAt: now))
            case .checklist:
                let lines = item.checklistItemsText
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                let entries = lines.map { ChecklistEntry(id: UUID(), text: $0, isDone: false) }
                days[idx].checklists.append(ChecklistItem(
                    id: UUID(),
                    title: item.title.isEmpty ? "Checklist" : item.title,
                    items: entries,
                    createdAt: now
                ))
            case .flight:
                let start = item.startTime ?? now
                days[idx].flights.append(FlightItem(
                    fromName: "",
                    fromCode: item.flightFromCode,
                    fromCity: "",
                    fromLatitude: nil,
                    fromLongitude: nil,
                    fromTerminal: "",
                    fromGate: "",
                    toName: "",
                    toCode: item.flightToCode,
                    toCity: "",
                    toLatitude: nil,
                    toLongitude: nil,
                    toTerminal: "",
                    toGate: "",
                    travelMode: .flight,
                    flightNumber: item.flightNumber,
                    notes: item.notes,
                    accent: .neutral,
                    startTime: start,
                    endTime: item.endTime ?? start
                ))
            }
        }
    }
    
    private func openCreateTripSheetIfNeeded(force: Bool) {
        if force || UserDefaults.standard.bool(forKey: pendingCreateTripFlagKey) {
            UserDefaults.standard.set(false, forKey: pendingCreateTripFlagKey)
            requestCreateTrip()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 28) {
            Spacer()
            
            SearchGlobeIllustration()
            
            Text("You haven’t created any trips yet")
                .font(.appTitle2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                requestCreateTrip()
            } label: {
                Text("New Trip")
                    .font(.appSubheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(hex: 0x2C2C2E), in: Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    private var tripListView: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let segments = availableSegments(for: tripStore.trips)
        let effectiveSegment = segments.contains(selectedSegment) ? selectedSegment : (segments.first ?? .upcoming)
        
        let filteredTrips: [Trip] = tripStore.trips
            .filter { trip in
                switch effectiveSegment {
                case .upcoming:
                    guard trip.isDatesSet else { return false }
                    let end = calendar.startOfDay(for: trip.endDate)
                    return end >= today
                case .past:
                    guard trip.isDatesSet else { return false }
                    let end = calendar.startOfDay(for: trip.endDate)
                    return end < today
                case .unscheduled:
                    return !trip.isDatesSet
                }
            }
            .sorted { a, b in
                switch effectiveSegment {
                case .upcoming:
                    return a.startDate < b.startDate
                case .past:
                    return a.startDate > b.startDate
                case .unscheduled:
                    return a.id.uuidString > b.id.uuidString
                }
            }
        
        let groupedTrips = Dictionary(grouping: filteredTrips) { trip in
            Calendar.current.component(.year, from: trip.startDate)
        }
        let sortedYears = groupedTrips.keys.sorted(by: { a, b in
            switch selectedSegment {
            case .upcoming, .unscheduled:
                return a < b
            case .past:
                return a > b
            }
        })
        
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 1)
                        .id("top")
                    
                    if segments.count > 1 {
                        Picker("", selection: $selectedSegment) {
                            ForEach(segments) { seg in
                                Text(seg.rawValue).tag(seg)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, RootHomeMetrics.chromeToContent)
                    }
                    
                    LazyVStack(spacing: RootHomeMetrics.chromeToContent, pinnedViews: []) {
                    if filteredTrips.isEmpty {
                        ContentUnavailableView(
                            selectedSegment == .past ? "No Past Trips" : (selectedSegment == .unscheduled ? "No Unscheduled Trips" : "No Upcoming Trips"),
                            systemImage: selectedSegment == .past ? "clock.arrow.circlepath" : (selectedSegment == .unscheduled ? "square.and.pencil" : "calendar"),
                            description: Text(selectedSegment == .past ? "Trips you’ve completed will show up here." : (selectedSegment == .unscheduled ? "Trips without dates will show up here." : "Trips that are coming up (or in progress) will show up here."))
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 36)
                    } else {
                        if selectedSegment == .unscheduled {
                            Section {
                                ForEach(filteredTrips) { trip in
                                    tripCardRow(trip)
                                }
                            } header: {
                                // Match Upcoming/Past year-header height so the list doesn't jump.
                                tripYearHeader("0000", isFirst: true)
                                    .opacity(0)
                                    .accessibilityHidden(true)
                            }
                        } else {
                            ForEach(sortedYears, id: \.self) { year in
                                Section {
                                    let tripsForYear = (groupedTrips[year] ?? []).sorted { a, b in
                                        switch selectedSegment {
                                        case .upcoming:
                                            return a.startDate < b.startDate
                                        case .past:
                                            return a.startDate > b.startDate
                                        case .unscheduled:
                                            return a.id.uuidString > b.id.uuidString
                                        }
                                    }
                                    
                                    ForEach(tripsForYear) { trip in
                                        tripCardRow(trip)
                                    }
                                } header: {
                                    tripYearHeader(String(year), isFirst: year == sortedYears.first)
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 12)
                    }
                }
                .padding(.horizontal, RootHomeMetrics.horizontalInset)
                .padding(.top, RootHomeMetrics.topInset)
                .padding(.bottom, RootHomeMetrics.bottomInset)
            }
            .onAppear {
                if !segments.contains(selectedSegment), let first = segments.first {
                    selectedSegment = first
                }
            }
            .onChange(of: tripStore.trips) { _, _ in
                let updated = availableSegments(for: tripStore.trips)
                if !updated.contains(selectedSegment), let first = updated.first {
                    selectedSegment = first
                }
            }
            .onChange(of: selectedSegment) { _, _ in
                Haptics.bump()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withTransaction(Transaction(animation: nil)) {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func tripCardRow(_ trip: Trip) -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        Button {
            navigationPath.append(trip.id)
        } label: {
            TripCardView(trip: trip)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .contentShape(shape)
        .contextMenu {
            tripCardContextMenu(trip)
        } preview: {
            TripCardView(trip: trip)
                .frame(width: 280)
                .clipShape(shape)
        }
    }
    
    @ViewBuilder
    private func tripCardContextMenu(_ trip: Trip) -> some View {
        Button {
            navigationPath.append(trip.id)
        } label: {
            Label("View Trip", systemImage: "arrow.right.circle")
        }
        
        Divider()
        
        Menu {
            Button {
                tripForUnsplashCoverPicker = trip
            } label: {
                Label("Choose from Unsplash", systemImage: "sparkles")
            }
            
            Button {
                tripForImagePicker = trip
                showImagePicker = true
            } label: {
                Label("Upload from Photos", systemImage: "photo.on.rectangle")
            }
        } label: {
            let hasCover = trip.coverImageData != nil
            Label(
                hasCover ? "Update Cover Image" : "Add Cover Image",
                systemImage: hasCover ? "photo" : "photo.badge.plus"
            )
        }
        
        Button {
            editingTrip = trip
        } label: {
            Label("Edit Trip", systemImage: "pencil")
        }
        
        if auth.isSignedIn {
            Button {
                withAnimation {
                    tripStore.addTrip(trip.duplicatedTrip())
                }
            } label: {
                Label("Duplicate Trip", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button(role: .destructive) {
                tripPendingDelete = trip
            } label: {
                Label("Delete Trip", systemImage: "trash")
            }
            .tint(.red)
        }
    }
}

struct TripImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: TripImagePicker
        
        init(_ parent: TripImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct EditTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Binding var trip: Trip
    var onDelete: () -> Void
    
    @State private var name: String = ""
    @State private var destination: String = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var mapSpan: Double?
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var isDatesSet: Bool = true
    @State private var unscheduledDaysCount: Int = 5
    @State private var coverImage: UIImage?
    @State private var pendingCoverImageData: Data?
    @State private var showImagePicker = false
    @State private var showUnsplashPicker = false
    @State private var showDeleteConfirmation = false
    @State private var showParkedIdeas: Bool = false
    @State private var originalIsDatesSet: Bool = true
    @State private var originalDaysSnapshot: [TripDay] = []
    @State private var showConvertDatesDropAlert: Bool = false
    @State private var pendingDroppedCounts: (activities: Int, reminders: Int, checklists: Int, flights: Int) = (0, 0, 0, 0)
    @State private var showTotalCostsSheet: Bool = false
    
    private var isValid: Bool {
        guard !(name.isEmpty || destination.isEmpty) else { return false }
        if isDatesSet {
            return endDate >= startDate
        }
        return unscheduledDaysCount >= 1
    }
    
    private var costLineItems: [TotalCostsSheet.LineItem] {
        var items: [TotalCostsSheet.LineItem] = []
        
        func add(id: String, title: String, subtitle: String?, amount: Double?, currencyCode: String?) {
            guard let amount else { return }
            let code = currencyCode ?? (UserDefaults.standard.string(forKey: "currencyCode") ?? "USD")
            items.append(.init(id: id, title: title, subtitle: subtitle, amount: amount, currencyCode: code))
        }
        
        // Day items
        for day in trip.days {
            let dayLabel = trip.isDatesSet ? day.displayTitle : "Day \(day.order)"
            
            for event in day.events {
                add(
                    id: "event-\(event.id.uuidString)",
                    title: event.title,
                    subtitle: [dayLabel, event.location].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " • "),
                    amount: event.cost,
                    currencyCode: event.costCurrencyCode
                )
            }
            
            for flight in day.flights {
                let title: String = {
                    let ref = flight.flightNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                    if ref.isEmpty { return flight.travelMode.title }
                    return (flight.travelMode == .drive || flight.travelMode == .walk) ? ref : ref.uppercased()
                }()
                
                let from = flight.fromCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                let to = flight.toCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                let route = (!from.isEmpty && !to.isEmpty) ? "\(from) → \(to)" : ""
                
                add(
                    id: "flight-\(flight.id.uuidString)",
                    title: title,
                    subtitle: [dayLabel, route].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " • "),
                    amount: flight.cost,
                    currencyCode: flight.costCurrencyCode
                )
            }
        }
        
        // Parked ideas can also have costs (stored on Trip.parkedIdeas).
        for idea in trip.parkedIdeas {
            add(
                id: "idea-\(idea.id.uuidString)",
                title: idea.title,
                subtitle: ["Ideas", idea.location].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " • "),
                amount: idea.cost,
                currencyCode: idea.costCurrencyCode
            )
        }
        
        // Stable ordering.
        return items.sorted { a, b in
            if a.title != b.title { return a.title < b.title }
            return a.id < b.id
        }
    }
    
    private var totalCostSummaryText: String? {
        guard !costLineItems.isEmpty else { return nil }
        let grouped = Dictionary(grouping: costLineItems, by: \.currencyCode)
            .mapValues { $0.map(\.amount).reduce(0, +) }
        
        let sorted = grouped
            .map { (currencyCode: $0.key, total: $0.value) }
            .sorted { $0.currencyCode < $1.currencyCode }
        
        guard !sorted.isEmpty else { return nil }
        if sorted.count == 1, let first = sorted.first {
            return "\(CurrencyFormatting.string(for: first.total, currencyCode: first.currencyCode)) \(first.currencyCode)"
        }
        
        let shown = Array(sorted.prefix(2))
        let parts = shown.map { "\((CurrencyFormatting.string(for: $0.total, currencyCode: $0.currencyCode))) \($0.currencyCode)" }
        let extra = sorted.count - shown.count
        if extra > 0 {
            return parts.joined(separator: " • ") + " • +\(extra)"
        }
        return parts.joined(separator: " • ")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Trip Name", text: $name)
                        if !name.isEmpty {
                            Button {
                                name = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    LocationSearchField(
                        text: $destination,
                        latitude: $latitude,
                        longitude: $longitude,
                        mapSpan: $mapSpan,
                        resultTypes: .address
                    )
                }
                
                Section {
                    Toggle("Set Dates", isOn: $isDatesSet)
                        .tint(appAccentColor)
                    
                    if isDatesSet {
                        DatePicker(
                            "Start date",
                            selection: $startDate,
                            in: Date.distantPast...Date.distantFuture,
                            displayedComponents: .date
                        )
                        
                        DatePicker(
                            "End date",
                            selection: $endDate,
                            in: startDate...Date.distantFuture,
                            displayedComponents: .date
                        )
                    } else {
                        Stepper(value: $unscheduledDaysCount, in: 1...30) {
                            HStack {
                                Text("Number of Days")
                                Spacer()
                                Text("\(unscheduledDaysCount)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if let totalCostSummaryText {
                        Button {
                            showTotalCostsSheet = true
                        } label: {
                            HStack {
                                Text("Total Cost")
                                Spacer()
                                Text(totalCostSummaryText)
                                    .foregroundStyle(.primary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                
                Section {
                    if let img = coverImage {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipped()
                                .contentShape(Rectangle())
                                .overlay {
                                    Menu {
                                        Button {
                                            showUnsplashPicker = true
                                        } label: {
                                            Label("Choose from Unsplash", systemImage: "sparkles")
                                        }
                                        
                                        Button {
                                            showImagePicker = true
                                        } label: {
                                            Label("Choose from Photos", systemImage: "photo.on.rectangle")
                                        }
                                    } label: {
                                        Color.clear
                                    }
                                    .buttonStyle(.plain)
                                }
                            
                            Button {
                                coverImage = nil
                                pendingCoverImageData = nil
                                TripCoverAttribution.clear(for: trip.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.appTitle)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.7))
                                    .shadow(radius: 2)
                            }
                            .buttonStyle(.plain)
                            .padding(12)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    } else {
                        Menu {
                            Button {
                                showUnsplashPicker = true
                            } label: {
                                Label("Choose from Unsplash", systemImage: "sparkles")
                            }
                            
                            Button {
                                showImagePicker = true
                            } label: {
                                Label("Choose from Photos", systemImage: "photo.on.rectangle")
                            }
                        } label: {
                            HStack {
                                Text("Add Cover Photo")
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Section {
                    Toggle("Show Ideas", isOn: $showParkedIdeas)
                        .tint(appAccentColor)
                } footer: {
                    Text("Include an extra column for ideation not tied to a day")
                }
                
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Trip")
                            Spacer()
                        }
                    }
                }
            }
            .alert("Delete Trip", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this trip? This action cannot be undone.")
            }
            .navigationTitle(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Trip" : name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    LiquidGlassIconButton(
                        systemName: "checkmark",
                        isEnabled: isValid
                    ) {
                        attemptSaveTrip()
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                TripImagePicker(image: Binding(
                    get: { coverImage },
                    set: { newImage in
                        coverImage = newImage
                        pendingCoverImageData = newImage?.jpegData(compressionQuality: 0.8)
                        TripCoverAttribution.clear(for: trip.id)
                    }
                ))
            }
            .sheet(isPresented: $showUnsplashPicker) {
                UnsplashCoverPickerSheet(initialQuery: destination) { selection in
                    pendingCoverImageData = selection.imageData
                    coverImage = UIImage(data: selection.imageData)
                    TripCoverAttribution.setName(selection.photographerName, for: trip.id)
                }
                .presentationDetents([.large])
                .tint(.primary)
            }
            .sheet(isPresented: $showTotalCostsSheet) {
                TotalCostsSheet(items: costLineItems)
                    .presentationDetents([.medium, .large])
            }
            .onAppear {
                name = trip.name
                destination = trip.destination
                latitude = trip.latitude
                longitude = trip.longitude
                mapSpan = trip.mapSpan
                startDate = trip.startDate
                endDate = trip.endDate
                isDatesSet = trip.isDatesSet
                unscheduledDaysCount = trip.unscheduledDaysCount
                showParkedIdeas = trip.showParkedIdeas
                originalIsDatesSet = trip.isDatesSet
                originalDaysSnapshot = trip.days
                if let imageData = trip.coverImageData {
                    coverImage = UIImage(data: imageData)
                    pendingCoverImageData = imageData
                } else {
                    pendingCoverImageData = nil
                }
            }
            .onChange(of: startDate) { _, newValue in
                if isDatesSet, endDate < newValue {
                    endDate = newValue
                }
            }
            .presentationDetents([.large])
        }
        .alert("Shorter date range", isPresented: $showConvertDatesDropAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove & Convert", role: .destructive) {
                saveTrip(applyDropOnConvert: true)
                dismiss()
            }
        } message: {
            Text("This date range is shorter and will remove items from days that no longer fit.\n\n\(pendingDroppedCounts.activities) activities, \(pendingDroppedCounts.reminders) reminders, \(pendingDroppedCounts.checklists) checklists, \(pendingDroppedCounts.flights) flights.")
        }
    }
    
    private func attemptSaveTrip() {
        if originalIsDatesSet == false, isDatesSet {
            let calendar = Calendar.current
            let totalDays = max(1, (calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1)
            
            if originalDaysSnapshot.count > totalDays {
                let dropped = originalDaysSnapshot.suffix(from: totalDays)
                let activities = dropped.map { $0.events.count }.reduce(0, +)
                let reminders = dropped.map { $0.reminders.count }.reduce(0, +)
                let checklists = dropped.map { $0.checklists.count }.reduce(0, +)
                let flights = dropped.map { $0.flights.count }.reduce(0, +)
                pendingDroppedCounts = (activities, reminders, checklists, flights)
                showConvertDatesDropAlert = true
                return
            }
        }
        
        saveTrip(applyDropOnConvert: false)
        dismiss()
    }
    
    private func saveTrip(applyDropOnConvert: Bool) {
        trip.name = name
        trip.destination = destination
        trip.latitude = latitude
        trip.longitude = longitude
        trip.mapSpan = mapSpan
        trip.startDate = startDate
        trip.endDate = endDate
        trip.isDatesSet = isDatesSet
        trip.unscheduledDaysCount = max(1, unscheduledDaysCount)
        
        let coverData = pendingCoverImageData ?? coverImage?.jpegData(compressionQuality: 0.8)
        trip.coverImageData = coverData
        trip.showParkedIdeas = showParkedIdeas
        
        if originalIsDatesSet == false, isDatesSet {
            let calendar = Calendar.current
            let totalDays = max(1, (calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1)
            let oldDays = applyDropOnConvert ? Array(originalDaysSnapshot.prefix(totalDays)) : originalDaysSnapshot
            
            var newDays: [TripDay] = []
            newDays.reserveCapacity(totalDays)
            
            for offset in 0..<totalDays {
                let date = calendar.date(byAdding: .day, value: offset, to: startDate) ?? startDate
                if offset < oldDays.count {
                    let existing = oldDays[offset]
                    let updated = TripDay(
                        id: existing.id,
                        date: date,
                        events: existing.events,
                        reminders: existing.reminders,
                        checklists: existing.checklists,
                        flights: existing.flights,
                        label: "Day \(offset + 1)",
                        order: offset + 1,
                        weatherIcon: existing.weatherIcon,
                        temperatureF: existing.temperatureF
                    )
                    newDays.append(updated)
                } else {
                    let emptyDay = TripDay(
                        id: UUID(),
                        date: date,
                        events: [],
                        reminders: [],
                        checklists: [],
                        flights: [],
                        label: "Day \(offset + 1)",
                        order: offset + 1,
                        weatherIcon: "cloud.sun.fill",
                        temperatureF: 72
                    )
                    newDays.append(emptyDay)
                }
            }
            
            trip.days = newDays
        }
    }
}

#Preview {
    Group {
        MyTripsView()
    }
    .environment(TripStore())
    .environment(PlaceStore())
    .environment(RootTabChrome())
}

