import SwiftUI
import MapKit
import UniformTypeIdentifiers
import Combine
import UIKit

struct SwipeBackGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        SwipeBackController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    class SwipeBackController: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            navigationController?.interactivePopGestureRecognizer?.delegate = self
        }
    }
}

extension SwipeBackGestureEnabler.SwipeBackController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

extension View {
    func enableSwipeBack() -> some View {
        background(SwipeBackGestureEnabler())
    }
}

struct DayOption: Identifiable, Hashable {
    let id: UUID
    let title: String
    let isParkedIdeas: Bool
}

struct TripDetailView: View {
    @Binding var trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(PlaceStore.self) private var placeStore
    @Environment(RootTabChrome.self) private var tabChrome
    
    @State private var tripDays: [TripDay] = []
    @State private var isPresentingSettings: Bool = false
    @State private var isPresentingNewActivity: Bool = false
    @State private var isPresentingPlanDay: Bool = false
    @State private var isPresentingAddMany: Bool = false
    @State private var planDayDefaultDayID: UUID?
    @State private var geocodeTask: Task<Void, Never>?
    @State private var splitRatio: CGFloat = 0.45 // Map takes 45% by default
    @AppStorage(AppMapStylePreference.storageKey) private var mapStylePreferenceRaw: String = AppMapStylePreference.standard.rawValue
    
    private var resolvedMapStyle: MapStyle {
        AppMapStylePreference.resolved(fromRaw: mapStylePreferenceRaw).mapStyle
    }
    @State private var newEventTitle: String = ""
    @State private var newEventLocation: String = ""
    @State private var newEventLatitude: Double?
    @State private var newEventLongitude: Double?
    @State private var newEventDescription: String = ""
    @State private var newEventIcon: String = "mappin.and.ellipse"
    @State private var newEventAccent: EventAccent = .purple
    @State private var newEventStart: Date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(9 * 3600)
    @State private var newEventEnd: Date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(10 * 3600)
    @State private var newEventPhoto: UIImage?
    @State private var newEventDocuments: [EventDocument] = []
    @State private var newEventCost: Double?
    @State private var newEventCostCurrencyCode: String?
    @State private var activityAlreadyInPlaces: Bool = false
    /// Stable ID used when Add to Places runs before the activity is saved.
    @State private var placesLinkEventID: UUID?
    @State private var selectedDayID: UUID?
    @State private var editingEvent: EventItem?
    @State private var activitySheetDetent: PresentationDetent = .medium
    @State private var mapPosition: MapCameraPosition
    @State private var showMap = false
    /// Cached MapKit road routes for drive/walk travel items (keyed by flight id).
    @State private var resolvedTravelRoadRoutes: [UUID: [CLLocationCoordinate2D]] = [:]
    
    @State private var isPresentingNewReminder = false
    @State private var newReminderText: String = ""
    @State private var editingReminder: ReminderItem?
    
    @State private var addManyDraftText: String = ""
    @State private var addManyItems: [String] = []
    
    @State private var parkedIdeas: [EventItem] = []
    
    @State private var isPresentingNewChecklist = false
    @State private var editingChecklist: ChecklistItem?
    @State private var checklistTitle: String = ""
    @State private var checklistDraftItems: [ChecklistEntry] = []

    @State private var isPresentingNewFlight = false
    @State private var editingFlight: FlightItem?
    @State private var flightFromName: String = ""
    @State private var flightFromCode: String = ""
    @State private var flightFromCity: String = ""
    @State private var flightFromLatitude: Double?
    @State private var flightFromLongitude: Double?
    @State private var flightToName: String = ""
    @State private var flightToCode: String = ""
    @State private var flightToCity: String = ""
    @State private var flightToLatitude: Double?
    @State private var flightToLongitude: Double?
    @State private var flightFromTerminal: String = ""
    @State private var flightFromGate: String = ""
    @State private var flightToTerminal: String = ""
    @State private var flightToGate: String = ""
    @State private var travelMode: TravelMode = .flight
    @State private var flightNumber: String = ""
    @State private var flightNotes: String = ""
    @State private var flightDocuments: [EventDocument] = []
    @State private var flightStartTime: Date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(9 * 3600)
    @State private var flightEndTime: Date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(9 * 3600)
    @State private var flightCost: Double?
    @State private var flightCostCurrencyCode: String?
    
    @State private var isEdgeSwipingBack: Bool = false
    
    @State private var focusedDayID: UUID?
    @State private var hasUserScrolledDays: Bool = false
    @State private var didScrollToActiveDay: Bool = false
    @State private var displayedDayIDForMarkers: UUID?
    @State private var markersOpacity: Double = 1.0
    @State private var pendingMarkerTransition: DispatchWorkItem?
    @State private var lastDayFocusHapticAt: Date = .distantPast
    
    @State private var settingsSnapshotTrip: Trip?
    @State private var settingsSnapshotTripDays: [TripDay] = []
    @State private var showConvertDatesDropAlert: Bool = false
    @State private var pendingConvertNewDaysCount: Int = 0
    @State private var pendingConvertDroppedCounts: (activities: Int, reminders: Int, checklists: Int, flights: Int) = (0, 0, 0, 0)
    @State private var pendingConvertOldDays: [TripDay] = []
    @Environment(\.colorScheme) private var colorScheme
    
    private var boardDividerColor: Color { colorScheme == .dark ? Color(hex: 0x252525) : Color(hex: 0xFFFFFF) }
    private var dayBoardBackgroundColor: Color { colorScheme == .dark ? Color(hex: 0x171717) : Color(hex: 0xF0F0F0) }
    
    private static let parkedIdeasColumnID = UUID(uuidString: "00000000-0000-0000-0000-000000000999")!
    
    private var dayOptions: [DayOption] {
        let total = tripDays.count
        var opts = tripDays.map { day in
            let title = trip.isDatesSet ? day.displayTitle : "Day \(day.order) of \(total)"
            return DayOption(id: day.id, title: title, isParkedIdeas: false)
        }
        if trip.showParkedIdeas {
            opts.append(DayOption(id: Self.parkedIdeasColumnID, title: "Ideas", isParkedIdeas: true))
        }
        return opts
    }
    
    init(trip: Binding<Trip>) {
        self._trip = trip
        let initialRegion: MKCoordinateRegion
        if let lat = trip.wrappedValue.latitude, let lon = trip.wrappedValue.longitude {
            let span = trip.wrappedValue.mapSpan ?? 0.1
            initialRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            )
        } else {
            initialRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 120)
            )
        }
        self._mapPosition = State(initialValue: .region(initialRegion))
    }
    
    var eventAnnotations: [EventAnnotation] {
        let dayAnnotations = tripDays.flatMap { day in
            day.events.compactMap { event -> EventAnnotation? in
                guard !event.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      let lat = event.latitude,
                      let lon = event.longitude else { return nil }
                return EventAnnotation(
                    id: event.id,
                    dayID: day.id,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    event: event,
                    color: event.accentColor
                )
            }
        }
        
        let parkedAnnotations: [EventAnnotation] = trip.showParkedIdeas ? parkedIdeas.compactMap { event -> EventAnnotation? in
            guard !event.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let lat = event.latitude,
                  let lon = event.longitude else { return nil }
            return EventAnnotation(
                id: event.id,
                dayID: Self.parkedIdeasColumnID,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                event: event,
                color: event.accentColor
            )
        } : []
        
        return dayAnnotations + parkedAnnotations
    }
    
    private var allTravelOverlays: [TravelMapOverlay] {
        TravelMapRouting.overlays(days: tripDays, resolvedRoadRoutes: resolvedTravelRoadRoutes)
    }
    
    private func travelOverlays(for dayID: UUID) -> [TravelMapOverlay] {
        allTravelOverlays.filter { $0.dayID == dayID }
    }
    
    private var visibleTravelOverlays: [TravelMapOverlay] {
        if hasUserScrolledDays, let dayID = displayedDayIDForMarkers {
            let dayOverlays = travelOverlays(for: dayID)
            return dayOverlays.isEmpty ? allTravelOverlays : dayOverlays
        }
        return allTravelOverlays
    }
    
    private var travelRouteRefreshKey: String {
        tripDays
            .flatMap(\.flights)
            .map { flight in
                let from = "\(flight.fromLatitude ?? 0),\(flight.fromLongitude ?? 0)"
                let to = "\(flight.toLatitude ?? 0),\(flight.toLongitude ?? 0)"
                return "\(flight.id.uuidString):\(flight.travelMode.rawValue):\(from):\(to)"
            }
            .sorted()
            .joined(separator: "|")
    }
    
    private var mapContentCoordinates: [CLLocationCoordinate2D] {
        eventAnnotations.map(\.coordinate) + TravelMapRouting.coordinates(in: allTravelOverlays)
    }
    
    var appropriateMapRegion: MKCoordinateRegion {
        if let region = regionFitting(coordinates: mapContentCoordinates) {
            return region
        } else if let lat = trip.latitude, let lon = trip.longitude {
            let span = trip.mapSpan ?? 0.1
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            )
        } else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 120)
            )
        }
    }
    
    private func annotations(for dayID: UUID) -> [EventAnnotation] {
        eventAnnotations.filter { $0.dayID == dayID }
    }
    
    private func dayHasMapContent(_ dayID: UUID) -> Bool {
        !annotations(for: dayID).isEmpty || !travelOverlays(for: dayID).isEmpty
    }
    
    private func coordinates(forDay dayID: UUID) -> [CLLocationCoordinate2D] {
        annotations(for: dayID).map(\.coordinate)
            + TravelMapRouting.coordinates(in: travelOverlays(for: dayID))
    }
    
    private func regionFitting(coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard !coordinates.isEmpty else { return nil }
        let minLat = coordinates.map(\.latitude).min() ?? 0
        let maxLat = coordinates.map(\.latitude).max() ?? 0
        let minLon = coordinates.map(\.longitude).min() ?? 0
        let maxLon = coordinates.map(\.longitude).max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let latSpread = maxLat - minLat
        let lonSpread = maxLon - minLon
        let padding: Double = 1.55
        let span = MKCoordinateSpan(
            latitudeDelta: max(latSpread * padding, 0.012),
            longitudeDelta: max(lonSpread * padding, 0.012)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
    
    private func regionFitting(_ annotations: [EventAnnotation]) -> MKCoordinateRegion? {
        regionFitting(coordinates: annotations.map(\.coordinate))
    }
    
    private var mapModes: MapInteractionModes {
        isEdgeSwipingBack ? [] : .all
    }
    
    private func setMapRegion(_ region: MKCoordinateRegion, animated: Bool = false, duration: Double = 0.25) {
        if animated {
            withAnimation(.easeInOut(duration: duration)) {
                mapPosition = .region(region)
            }
        } else {
            mapPosition = .region(region)
        }
    }
    
    private var mapLayer: some View {
        Map(position: $mapPosition, interactionModes: mapModes) {
            ForEach(visibleTravelOverlays) { overlay in
                let dashed = overlay.usesDashedStroke
                // Black outline first, white fill on top — same for dashed and solid.
                MapPolyline(coordinates: overlay.routeCoordinates)
                    .stroke(TravelMapStrokeStyle.outlineColor, style: TravelMapStrokeStyle.outline(dashed: dashed))
                MapPolyline(coordinates: overlay.routeCoordinates)
                    .stroke(TravelMapStrokeStyle.fillColor, style: TravelMapStrokeStyle.fill(dashed: dashed))
                
                Annotation("", coordinate: overlay.fromCoordinate, anchor: .center) {
                    Button {
                        openFlightFromMarker(overlay.flightID)
                    } label: {
                        SquareMapPinView(
                            fallbackColor: Color(hex: 0x171717),
                            fallbackSystemImage: overlay.travelMode.mapEndpointSystemImage(isOrigin: true)
                        )
                    }
                    .opacity(markersOpacity)
                }
                
                Annotation("", coordinate: overlay.toCoordinate, anchor: .center) {
                    Button {
                        openFlightFromMarker(overlay.flightID)
                    } label: {
                        SquareMapPinView(
                            fallbackColor: Color(hex: 0x171717),
                            fallbackSystemImage: overlay.travelMode.mapEndpointSystemImage(isOrigin: false)
                        )
                    }
                    .opacity(markersOpacity)
                }
            }
            
            ForEach(visibleAnnotations) { annotation in
                Annotation("", coordinate: annotation.coordinate, anchor: .center) {
                    Button {
                        openEventFromMarker(annotation.event)
                    } label: {
                        SquareMapPinView(
                            image: MapPinImageCache.image(for: annotation.event),
                            fallbackColor: annotation.color,
                            fallbackSystemImage: annotation.event.icon
                        )
                    }
                    .opacity(markersOpacity)
                }
            }
        }
        .mapStyle(resolvedMapStyle)
        .id(mapStylePreferenceRaw)
        .opacity(showMap ? 1 : 0)
        .allowsHitTesting(!isEdgeSwipingBack)
    }
    
    private var visibleAnnotations: [EventAnnotation] {
        if hasUserScrolledDays, let dayID = displayedDayIDForMarkers {
            let anns = annotations(for: dayID)
            return anns.isEmpty ? eventAnnotations : anns
        }
        return eventAnnotations
    }
    
    
    @ViewBuilder
    private var mapPlaceholder: some View {
        if !showMap {
            Rectangle()
                .fill(Color(.systemBackground))
        }
    }
    
    private func dragHandle(mapHeight: CGFloat, totalHeight: CGFloat, handleHeight: CGFloat) -> some View {
        ResizeHandle()
            .frame(height: handleHeight)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newRatio = (mapHeight + value.translation.height) / totalHeight
                        let clamped = min(max(newRatio, 0.2), 0.8)
                        splitRatio = clamped
                        applyResizeZoom(for: clamped)
                    }
            )
    }
    
    private func resizeZoomFactor(for ratio: CGFloat) -> Double {
        let minR: CGFloat = 0.2
        let maxR: CGFloat = 0.8
        let base: CGFloat = 0.45
        
        if ratio <= base {
            let t = Double((base - ratio) / (base - minR)) // 0...1
            return 1.0 + (0.60 * t) // zoom out as map gets smaller
        } else {
            let t = Double((ratio - base) / (maxR - base)) // 0...1
            return 1.0 - (0.35 * t) // zoom in as map gets larger
        }
    }
    
    private func resizeBaseRegion() -> MKCoordinateRegion {
        if hasUserScrolledDays, let dayID = displayedDayIDForMarkers,
           let r = regionFitting(coordinates: coordinates(forDay: dayID)) {
            return r
        }
        return appropriateMapRegion
    }
    
    private func applyResizeZoom(for ratio: CGFloat) {
        let base = resizeBaseRegion()
        let factor = resizeZoomFactor(for: ratio)
        
        let minDelta: Double = 0.005
        let maxDelta: Double = 180.0
        
        let newSpan = MKCoordinateSpan(
            latitudeDelta: min(max(base.span.latitudeDelta * factor, minDelta), maxDelta),
            longitudeDelta: min(max(base.span.longitudeDelta * factor, minDelta), maxDelta)
        )
        
        setMapRegion(MKCoordinateRegion(center: base.center, span: newSpan), animated: false)
    }

    private var mainLayout: some View {
        GeometryReader { geo in
            let totalHeight = geo.size.height
            let handleHeight: CGFloat = 24
            let mapHeight = totalHeight * splitRatio
            let kanbanHeight = totalHeight - mapHeight - handleHeight
            
            VStack(spacing: 0) {
                ZStack {
                    mapLayer
                    mapPlaceholder
                }
                .frame(height: mapHeight)
                .ignoresSafeArea(edges: .top)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(boardDividerColor)
                        .frame(height: 1)
                }
                
                dragHandle(mapHeight: mapHeight, totalHeight: totalHeight, handleHeight: handleHeight)
                
                kanbanBoard()
                    .frame(height: kanbanHeight)
            }
        }
    }
    
    private var edgeSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                guard value.startLocation.x < 24, value.translation.width > 0 else { return }
                isEdgeSwipingBack = true
            }
            .onEnded { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    isEdgeSwipingBack = false
                }
            }
    }
    
    @ToolbarContentBuilder
    private var tripDetailToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            LiquidGlassIconButton(systemName: "chevron.left", accessibilityLabelText: "Back") {
                dismiss()
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            LiquidGlassToolbarIconPair {
                Button {
                    settingsSnapshotTrip = trip
                    settingsSnapshotTripDays = tripDays
                    isPresentingSettings = true
                } label: {
                    LiquidGlassToolbarIconLabel(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .tint(.primary)
                .accessibilityLabel("Trip settings")
                
                Menu {
                    Button {
                        let focusedIsParked = trip.showParkedIdeas && focusedDayID == Self.parkedIdeasColumnID
                        if focusedIsParked {
                            selectedDayID = Self.parkedIdeasColumnID
                        } else {
                            let focusedDayCandidate = tripDays.first(where: { $0.id == focusedDayID })?.id
                            selectedDayID = focusedDayCandidate ?? tripDays.first(where: { Calendar.current.isDateInToday($0.date) })?.id ?? tripDays.first?.id
                        }
                        prepareNewEventDefaults()
                        activitySheetDetent = .large
                        isPresentingNewActivity = true
                    } label: {
                        Label("Activity", systemImage: "calendar.badge.plus")
                    }
                    
                    Menu {
                        ForEach(TravelMode.allCases, id: \.self) { mode in
                            Button {
                                let focusedDayCandidate = tripDays.first(where: { $0.id == focusedDayID })?.id
                                selectedDayID = focusedDayCandidate ?? tripDays.first(where: { Calendar.current.isDateInToday($0.date) })?.id ?? tripDays.first?.id
                                prepareNewFlightDefaults(mode: mode)
                                isPresentingNewFlight = true
                            } label: {
                                Label(mode.title, systemImage: mode.systemImageName)
                            }
                        }
                    } label: {
                        Label("Travel", systemImage: "arrow.left.arrow.right")
                    }
                    
                    Button {
                        let focusedDayCandidate = tripDays.first(where: { $0.id == focusedDayID })?.id
                        selectedDayID = focusedDayCandidate ?? tripDays.first(where: { Calendar.current.isDateInToday($0.date) })?.id ?? tripDays.first?.id
                        newReminderText = ""
                        editingReminder = nil
                        isPresentingNewReminder = true
                    } label: {
                        Label("Reminder", systemImage: "pin.fill")
                    }
                    
                    Button {
                        let focusedDayCandidate = tripDays.first(where: { $0.id == focusedDayID })?.id
                        selectedDayID = focusedDayCandidate ?? tripDays.first(where: { Calendar.current.isDateInToday($0.date) })?.id ?? tripDays.first?.id
                        checklistTitle = ""
                        checklistDraftItems = []
                        editingChecklist = nil
                        isPresentingNewChecklist = true
                    } label: {
                        Label("Checklist", systemImage: "checklist.checked")
                    }
                    
                    Divider()
                    
                    Button {
                        let focusedDayCandidate = tripDays.first(where: { $0.id == focusedDayID })?.id
                        planDayDefaultDayID = focusedDayCandidate ?? tripDays.first(where: { Calendar.current.isDateInToday($0.date) })?.id ?? tripDays.first?.id
                        isPresentingPlanDay = true
                    } label: {
                        Label("Plan Day", systemImage: "sparkles")
                    }
                    
                    Button {
                        let focusedDayCandidate = tripDays.first(where: { $0.id == focusedDayID })?.id
                        selectedDayID = focusedDayCandidate ?? tripDays.first(where: { Calendar.current.isDateInToday($0.date) })?.id ?? tripDays.first?.id
                        addManyDraftText = ""
                        addManyItems = []
                        isPresentingAddMany = true
                    } label: {
                        Label("Add Many", systemImage: "text.badge.plus")
                    }
                } label: {
                    LiquidGlassToolbarIconLabel(systemName: "plus")
                }
                .buttonStyle(.plain)
                .tint(.primary)
                .accessibilityLabel("Add to trip")
            }
        }
        ToolbarItem(placement: .principal) {
            VStack(spacing: 2) {
                Text(trip.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Trip" : trip.name)
                    .font(.app(17, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
                Text(tripDateRangeText)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            // Avoid expanding into leading/trailing bar button hit areas.
            .frame(maxWidth: 220)
            .allowsHitTesting(false)
        }
    }

    private var eventSheetTripRegion: MKCoordinateRegion? {
        guard let lat = trip.latitude, let lon = trip.longitude else { return nil }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
    }
    
    private var settingsCostItems: [TotalCostsSheet.LineItem] {
        var items: [TotalCostsSheet.LineItem] = []
        
        func add(id: String, title: String, subtitle: String?, amount: Double?, currencyCode: String?) {
            guard let amount else { return }
            let code = currencyCode ?? (UserDefaults.standard.string(forKey: "currencyCode") ?? "USD")
            items.append(.init(id: id, title: title, subtitle: subtitle, amount: amount, currencyCode: code))
        }
        
        // Days
        for day in tripDays {
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
                let title = travelListTitle(for: flight)
                let route = travelRouteText(for: flight)
                
                add(
                    id: "flight-\(flight.id.uuidString)",
                    title: title,
                    subtitle: [dayLabel, route].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " • "),
                    amount: flight.cost,
                    currencyCode: flight.costCurrencyCode
                )
            }
        }
        
        // Ideas
        for idea in parkedIdeas {
            add(
                id: "idea-\(idea.id.uuidString)",
                title: idea.title,
                subtitle: ["Ideas", idea.location].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " • "),
                amount: idea.cost,
                currencyCode: idea.costCurrencyCode
            )
        }
        
        return items.sorted { a, b in
            if a.title != b.title { return a.title < b.title }
            return a.id < b.id
        }
    }
    
    private var settingsDocumentItems: [TripSettingsSheet.DocumentItem] {
        var rows: [TripSettingsSheet.DocumentItem] = []
        
        func appendDocuments(from event: EventItem, dayLabel: String, isIdeas: Bool) {
            let activityTitle = event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Activity" : event.title.trimmingCharacters(in: .whitespacesAndNewlines)
            for document in event.documents {
                rows.append(
                    .init(
                        id: "\(event.id.uuidString)-\(document.id.uuidString)",
                        activityID: event.id,
                        activityTitle: activityTitle,
                        dayLabel: dayLabel,
                        isIdeas: isIdeas,
                        document: document
                    )
                )
            }
        }

        func appendDocuments(from flight: FlightItem, dayLabel: String) {
            let travelTitle = travelListTitle(for: flight).trimmingCharacters(in: .whitespacesAndNewlines)
            let activityTitle = travelTitle.isEmpty ? flight.travelMode.title : travelTitle
            for document in flight.documents {
                rows.append(
                    .init(
                        id: "\(flight.id.uuidString)-\(document.id.uuidString)",
                        activityID: flight.id,
                        activityTitle: activityTitle,
                        dayLabel: dayLabel,
                        isIdeas: false,
                        document: document
                    )
                )
            }
        }
        
        for day in tripDays {
            let dayLabel = trip.isDatesSet ? day.displayTitle : "Day \(day.order)"
            for event in day.events {
                appendDocuments(from: event, dayLabel: dayLabel, isIdeas: false)
            }
            for flight in day.flights {
                appendDocuments(from: flight, dayLabel: dayLabel)
            }
        }
        for idea in parkedIdeas {
            appendDocuments(from: idea, dayLabel: "Ideas", isIdeas: true)
        }
        
        return rows.sorted { lhs, rhs in
            if lhs.dayLabel != rhs.dayLabel { return lhs.dayLabel < rhs.dayLabel }
            if lhs.activityTitle != rhs.activityTitle { return lhs.activityTitle < rhs.activityTitle }
            return lhs.document.fileName < rhs.document.fileName
        }
    }

    private var itineraryClipboardText: String {
        var lines: [String] = []
        
        let tripName = trip.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let dest = trip.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !tripName.isEmpty || !dest.isEmpty {
            let header = [tripName, dest].filter { !$0.isEmpty }.joined(separator: " — ")
            if !header.isEmpty { lines.append(header) }
        }
        
        if trip.isDatesSet {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .none
            lines.append("\(f.string(from: trip.startDate)) – \(f.string(from: trip.endDate))")
        }
        
        lines.append("")
        
        let time = DateFormatter()
        time.dateStyle = .none
        time.timeStyle = .short
        
        for day in tripDays.sorted(by: { $0.order < $1.order }) {
            let dayTitle = trip.isDatesSet ? day.displayTitle : "Day \(day.order)"
            let subtitle = day.label.trimmingCharacters(in: .whitespacesAndNewlines)
            lines.append(subtitle.isEmpty ? dayTitle : "\(dayTitle) — \(subtitle)")
            
            let events = day.events.sorted(by: { $0.startTimeMinutes < $1.startTimeMinutes })
            for e in events {
                let t = e.time.trimmingCharacters(in: .whitespacesAndNewlines)
                let name = e.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let loc = e.location.trimmingCharacters(in: .whitespacesAndNewlines)
                let bits = [t, name].filter { !$0.isEmpty }.joined(separator: " ")
                let line = loc.isEmpty ? bits : "\(bits) • \(loc)"
                if !line.isEmpty { lines.append("- \(line)") }
            }
            
            for r in day.reminders {
                let text = r.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { lines.append("- \(text)") }
            }
            
            for c in day.checklists {
                let ct = c.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if !ct.isEmpty { lines.append("- \(ct)") }
                for entry in c.items {
                    let et = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !et.isEmpty else { continue }
                    lines.append("  - \(entry.isDone ? "✓ " : "")\(et)")
                }
            }
            
            for fItem in day.flights.sorted(by: { $0.startTime < $1.startTime }) {
                let ref = fItem.flightNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                let route = travelRouteText(for: fItem)
                let start = time.string(from: fItem.startTime)
                let end = fItem.hasEndTime ? time.string(from: fItem.endTime) : ""
                let times = end.isEmpty ? start : "\(start) - \(end)"
                
                let headBits = [ref.isEmpty ? fItem.travelMode.title : ref, route].filter { !$0.isEmpty }.joined(separator: " ")
                let flightLine = [headBits, times].filter { !$0.isEmpty }.joined(separator: " • ")
                if !flightLine.isEmpty { lines.append("- \(flightLine)") }
            }
            
            lines.append("")
        }
        
        if trip.showParkedIdeas {
            let ideas = parkedIdeas
            if !ideas.isEmpty {
                lines.append("Ideas")
                for e in ideas {
                    let t = e.time.trimmingCharacters(in: .whitespacesAndNewlines)
                    let name = e.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let loc = e.location.trimmingCharacters(in: .whitespacesAndNewlines)
                    let bits = [t, name].filter { !$0.isEmpty }.joined(separator: " ")
                    let line = loc.isEmpty ? bits : "\(bits) • \(loc)"
                    if !line.isEmpty { lines.append("- \(line)") }
                }
            }
        }
        
        // Trim trailing blank lines.
        while lines.last == "" { _ = lines.popLast() }
        return lines.joined(separator: "\n")
    }
    
    private func applySheets<V: View>(to view: V) -> some View {
        view
            .sheet(isPresented: $isPresentingSettings) {
                TripSettingsSheet(
                    name: $trip.name,
                    location: $trip.destination,
                    latitude: $trip.latitude,
                    longitude: $trip.longitude,
                    mapSpan: $trip.mapSpan,
                    startDate: $trip.startDate,
                    endDate: $trip.endDate,
                    isDatesSet: $trip.isDatesSet,
                    unscheduledDaysCount: $trip.unscheduledDaysCount,
                    coverImageData: $trip.coverImageData,
                    tripID: trip.id,
                    showParkedIdeas: $trip.showParkedIdeas,
                    costItems: settingsCostItems,
                    documentItems: settingsDocumentItems,
                    itineraryText: itineraryClipboardText,
                    onApply: applyTripSettingsFromSheet
                )
                .tint(.primary)
            }
            .alert("Shorter date range", isPresented: $showConvertDatesDropAlert) {
                Button("Cancel", role: .cancel) {
                    if let snap = settingsSnapshotTrip {
                        trip = snap
                    }
                    tripDays = settingsSnapshotTripDays
                    showConvertDatesDropAlert = false
                }
                Button("Remove & Convert", role: .destructive) {
                    convertCurrentTripDaysToScheduledByIndex(oldDays: pendingConvertOldDays)
                    showConvertDatesDropAlert = false
                }
            } message: {
                Text("This date range is shorter and will remove items from days that no longer fit.\n\n\(pendingConvertDroppedCounts.activities) activities, \(pendingConvertDroppedCounts.reminders) reminders, \(pendingConvertDroppedCounts.checklists) checklists, \(pendingConvertDroppedCounts.flights) flights.")
            }
            .sheet(isPresented: $isPresentingNewActivity, onDismiss: {
                editingEvent = nil
            }) {
                NewActivitySheet(
                    title: $newEventTitle,
                    location: $newEventLocation,
                    latitude: $newEventLatitude,
                    longitude: $newEventLongitude,
                    description: $newEventDescription,
                    icon: $newEventIcon,
                    accent: $newEventAccent,
                    startTime: $newEventStart,
                    endTime: $newEventEnd,
                    documents: $newEventDocuments,
                    cost: $newEventCost,
                    costCurrencyCode: $newEventCostCurrencyCode,
                    selectedDayID: $selectedDayID,
                    dayOptions: dayOptions,
                    tripLocationRegion: eventSheetTripRegion,
                    onAdd: addNewEvent,
                    onDelete: deleteCurrentEvent,
                    onAddToPlaces: addCurrentActivityToPlaces,
                    isEditing: editingEvent != nil,
                    isAlreadyInPlaces: activityAlreadyInPlaces
                )
                .tint(.primary)
                .presentationDetents(
                    UIDevice.current.userInterfaceIdiom == .pad ? [.large] : [.medium, .large],
                    selection: $activitySheetDetent
                )
            }
            .sheet(isPresented: $isPresentingNewReminder, onDismiss: {
                editingReminder = nil
            }) {
                NewReminderSheet(
                    reminderText: $newReminderText,
                    selectedDayID: $selectedDayID,
                    dayOptions: dayOptions,
                    isEditing: editingReminder != nil,
                    onAdd: addReminder,
                    onDelete: {
                        if let editingReminder {
                            deleteReminder(editingReminder)
                        }
                    }
                )
                .tint(.primary)
                .presentationDetents(UIDevice.current.userInterfaceIdiom == .pad ? [.large] : [.medium])
            }
            .sheet(isPresented: $isPresentingNewChecklist, onDismiss: {
                editingChecklist = nil
            }) {
                NewChecklistSheet(
                    title: $checklistTitle,
                    items: $checklistDraftItems,
                    selectedDayID: $selectedDayID,
                    dayOptions: dayOptions,
                    isEditing: editingChecklist != nil,
                    onSave: saveChecklist,
                    onDelete: {
                        if let editingChecklist {
                            deleteChecklist(editingChecklist)
                        }
                    }
                )
                .tint(.primary)
                .presentationDetents(UIDevice.current.userInterfaceIdiom == .pad ? [.large] : [.medium, .large])
            }
            .sheet(isPresented: $isPresentingNewFlight, onDismiss: {
                editingFlight = nil
            }) {
                let deleteHandler: (() -> Void)? = (editingFlight != nil) ? { deleteCurrentFlight() } : nil
                NewFlightSheet(
                    fromName: $flightFromName,
                    fromCode: $flightFromCode,
                    fromCity: $flightFromCity,
                    fromLatitude: $flightFromLatitude,
                    fromLongitude: $flightFromLongitude,
                    fromTerminal: $flightFromTerminal,
                    fromGate: $flightFromGate,
                    toName: $flightToName,
                    toCode: $flightToCode,
                    toCity: $flightToCity,
                    toLatitude: $flightToLatitude,
                    toLongitude: $flightToLongitude,
                    toTerminal: $flightToTerminal,
                    toGate: $flightToGate,
                    travelMode: $travelMode,
                    flightNumber: $flightNumber,
                    notes: $flightNotes,
                    documents: $flightDocuments,
                    startTime: $flightStartTime,
                    endTime: $flightEndTime,
                    cost: $flightCost,
                    costCurrencyCode: $flightCostCurrencyCode,
                    selectedDayID: $selectedDayID,
                    dayOptions: dayOptions,
                    tripLocationRegion: eventSheetTripRegion,
                    isEditing: editingFlight != nil,
                    onSave: saveFlight,
                    onDelete: deleteHandler
                )
                .tint(.primary)
                .presentationDetents(UIDevice.current.userInterfaceIdiom == .pad ? [.large] : [.medium, .large])
            }
            .sheet(isPresented: $isPresentingPlanDay) {
                TripStacksAISheet(
                    mode: .planDay,
                    tripContext: PlanDayTripContext(
                        isDatesSet: trip.isDatesSet,
                        startDate: trip.startDate,
                        endDate: trip.endDate,
                        unscheduledDaysCount: trip.unscheduledDaysCount,
                        destination: trip.destination,
                        latitude: trip.latitude,
                        longitude: trip.longitude,
                        mapSpan: trip.mapSpan
                    ),
                    dayOptions: dayOptions,
                    defaultDayID: planDayDefaultDayID,
                    scopeHint: dayOptions.first(where: { $0.id == planDayDefaultDayID })?.title ?? "",
                    existingItems: planDayExistingItems,
                    onCommitPlanItems: applyPlanDayItems
                )
                .tint(.primary)
            }
            .sheet(isPresented: $isPresentingAddMany) {
                NewManySheet(title: "Add Many") { titles in
                    addManyActivities(titles)
                }
                .tint(.primary)
                .presentationDetents([.medium, .large])
            }
    }

    private func addManyActivities(_ titles: [String]) {
        let trimmed = titles.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !trimmed.isEmpty else { return }
        
        let targetID = selectedDayID ?? tripDays.first(where: { Calendar.current.isDateInToday($0.date) })?.id ?? tripDays.first?.id
        guard let targetID, let idx = tripDays.firstIndex(where: { $0.id == targetID }) else { return }
        
        let newEvents = trimmed.map { title in
            EventItem(
                id: UUID(),
                title: title,
                description: "",
                time: "",
                location: "",
                latitude: nil,
                longitude: nil,
                icon: "mappin.and.ellipse",
                accent: .neutral,
                photoData: nil
            )
        }
        
        tripDays[idx].events.append(contentsOf: newEvents)
    }
    
    /// Existing itinerary snapshot for AI dedupe (focused day when available, else whole trip).
    private var planDayExistingItems: [PlanDayItem] {
        let focusID = planDayDefaultDayID
        let daysToExport: [TripDay] = {
            if let focusID, let day = tripDays.first(where: { $0.id == focusID }) {
                return [day]
            }
            return tripDays
        }()
        
        var items: [PlanDayItem] = []
        for day in daysToExport {
            for event in day.events {
                items.append(PlanDayItem(
                    kind: .activity,
                    dayID: day.id,
                    title: event.title,
                    location: event.location,
                    notes: event.description,
                    sourceSnippet: event.title
                ))
            }
            for reminder in day.reminders {
                items.append(PlanDayItem(kind: .reminder, dayID: day.id, title: reminder.text, sourceSnippet: reminder.text))
            }
            for checklist in day.checklists {
                items.append(PlanDayItem(
                    kind: .checklist,
                    dayID: day.id,
                    title: checklist.title,
                    checklistItemsText: checklist.items.map(\.text).joined(separator: "\n"),
                    sourceSnippet: checklist.title
                ))
            }
            for flight in day.flights {
                items.append(PlanDayItem(
                    kind: .flight,
                    dayID: day.id,
                    title: flight.flightNumber.isEmpty ? flight.travelMode.title : flight.flightNumber,
                    flightFromCode: flight.fromCode,
                    flightToCode: flight.toCode,
                    flightNumber: flight.flightNumber,
                    sourceSnippet: flight.flightNumber
                ))
            }
        }
        return items
    }

    private func applyPlanDayItems(_ items: [PlanDayItem]) {
        let now = Date()
        
        let ideasID: UUID? = trip.showParkedIdeas ? Self.parkedIdeasColumnID : nil
        let defaultDayID = planDayDefaultDayID ?? tripDays.first?.id
        var newlyAddedEventIDs: [UUID] = []
        
        func timeText(start: Date?, end: Date?) -> String {
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
        
        for item in items where item.include {
            let targetID = item.dayID ?? defaultDayID
            let isIdeasTarget = (ideasID != nil && targetID == ideasID)
            
            switch item.kind {
            case .activity:
                let event = EventItem(
                    id: UUID(),
                    title: item.title,
                    description: item.notes,
                    time: timeText(start: item.startTime, end: item.endTime),
                    location: item.location,
                    latitude: item.latitude,
                    longitude: item.longitude,
                    icon: "mappin.and.ellipse",
                    accent: .neutral,
                    photoData: nil
                )
                
                if isIdeasTarget {
                    parkedIdeas.insert(event, at: 0)
                    if event.needsMapGeocode {
                        newlyAddedEventIDs.append(event.id)
                    }
                    continue
                }
                
                if let targetID, let idx = tripDays.firstIndex(where: { $0.id == targetID }) {
                    tripDays[idx].events.append(event)
                } else if let first = tripDays.indices.first {
                    tripDays[first].events.append(event)
                }
                
                if event.needsMapGeocode {
                    newlyAddedEventIDs.append(event.id)
                }
                
            case .reminder:
                let reminder = ReminderItem(id: UUID(), text: item.title, createdAt: now)
                let fallbackID = isIdeasTarget ? defaultDayID : targetID
                if let fallbackID, let idx = tripDays.firstIndex(where: { $0.id == fallbackID }) {
                    tripDays[idx].reminders.append(reminder)
                } else if let first = tripDays.indices.first {
                    tripDays[first].reminders.append(reminder)
                }
                
            case .checklist:
                let rawLines = item.checklistItemsText
                    .replacingOccurrences(of: "\r\n", with: "\n")
                    .replacingOccurrences(of: "\r", with: "\n")
                    .components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                let entries: [ChecklistEntry] = rawLines.map { ChecklistEntry(id: UUID(), text: $0, isDone: false) }
                let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Checklist" : item.title
                let checklist = ChecklistItem(id: UUID(), title: title, items: entries, createdAt: now)
                
                let fallbackID = isIdeasTarget ? defaultDayID : targetID
                if let fallbackID, let idx = tripDays.firstIndex(where: { $0.id == fallbackID }) {
                    tripDays[idx].checklists.append(checklist)
                } else if let first = tripDays.indices.first {
                    tripDays[first].checklists.append(checklist)
                }
                
            case .flight:
                let start = item.startTime ?? now
                let end = item.endTime ?? start
                let flight = FlightItem(
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
                    endTime: end
                )
                
                let fallbackID = isIdeasTarget ? defaultDayID : targetID
                if let fallbackID, let idx = tripDays.firstIndex(where: { $0.id == fallbackID }) {
                    tripDays[idx].flights.append(flight)
                } else if let first = tripDays.indices.first {
                    tripDays[first].flights.append(flight)
                }
                
            case .place:
                // Place Finder items are committed via PlaceStore, not trip days.
                continue
            }
        }
        
        if trip.isDatesSet {
            for idx in tripDays.indices {
                tripDays[idx].events.sort { $0.startTimeMinutes < $1.startTimeMinutes }
            }
        } else {
            for idx in tripDays.indices {
                tripDays[idx].events.sort { $0.startTimeMinutes < $1.startTimeMinutes }
            }
        }
        
        if trip.showParkedIdeas {
            parkedIdeas.sort { a, b in
                let aT = a.startTimeMinutes
                let bT = b.startTimeMinutes
                if aT != bT { return aT < bT }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        }
        
        if let focused = focusedDayID, focused == Self.parkedIdeasColumnID, !trip.showParkedIdeas {
            focusedDayID = nil
        }
        
        let plannedDayIDs = Set(
            items
                .filter { $0.include && $0.kind != .place }
                .compactMap { item -> UUID? in
                    item.dayID ?? defaultDayID
                }
        )
        AchievementCounters.recordAIDaysPlanned(plannedDayIDs.count)
        
        if !newlyAddedEventIDs.isEmpty {
            geocodeTask?.cancel()
            geocodeTask = Task {
                await geocodeEventsIfNeeded(eventIDs: newlyAddedEventIDs)
            }
        }
    }
    
    private func geocodeMissingEventCoordinatesIfNeeded() {
        var missingIDs: [UUID] = []
        for day in tripDays {
            for event in day.events where event.needsMapGeocode {
                missingIDs.append(event.id)
            }
        }
        if trip.showParkedIdeas {
            for event in parkedIdeas where event.needsMapGeocode {
                missingIDs.append(event.id)
            }
        }
        guard !missingIDs.isEmpty else { return }
        geocodeTask?.cancel()
        geocodeTask = Task {
            await geocodeEventsIfNeeded(eventIDs: missingIDs)
        }
    }
    
    private func geocodeMissingTravelCoordinatesIfNeeded() {
        let needsWork = tripDays.contains { day in
            day.flights.contains { flight in
                travelEndpointNeedsGeocode(flight, isFrom: true)
                    || travelEndpointNeedsGeocode(flight, isFrom: false)
            }
        }
        guard needsWork else { return }
        Task {
            await geocodeTravelEndpointsIfNeeded()
        }
    }
    
    private func travelEndpointNeedsGeocode(_ flight: FlightItem, isFrom: Bool) -> Bool {
        let lat = isFrom ? flight.fromLatitude : flight.toLatitude
        let lon = isFrom ? flight.fromLongitude : flight.toLongitude
        guard lat == nil || lon == nil else { return false }
        return travelEndpointQuery(flight, isFrom: isFrom) != nil
    }
    
    private func travelEndpointQuery(_ flight: FlightItem, isFrom: Bool) -> String? {
        let name = (isFrom ? flight.fromName : flight.toName)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let code = (isFrom ? flight.fromCode : flight.toCode)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let city = (isFrom ? flight.fromCity : flight.toCity)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch flight.travelMode {
        case .flight:
            if !code.isEmpty { return "\(code) airport" }
            if !name.isEmpty { return "\(name) airport" }
            if !city.isEmpty { return "\(city) airport" }
            return nil
        case .train:
            if !name.isEmpty { return "\(name) train station" }
            if !code.isEmpty { return "\(code) station" }
            return nil
        case .drive, .walk:
            let parts = [name, city, trip.destination]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !parts.isEmpty else { return nil }
            return parts.joined(separator: " ")
        }
    }

    private func geocodeEventsIfNeeded(eventIDs: [UUID]) async {
        let region: MKCoordinateRegion? = await MainActor.run { geocodeBiasRegion() }
        var resolvedAny = false
        
        for id in eventIDs {
            if Task.isCancelled { return }
            
            let payload: (query: String, isIdeas: Bool)? = await MainActor.run {
                geocodeQuery(forEventID: id)
            }
            guard let payload else { continue }
            
            if Task.isCancelled { return }
            if let resolved = await searchPlace(for: payload.query, region: region) {
                await MainActor.run {
                    applyResolvedPlace(resolved, toEventID: id, isIdeas: payload.isIdeas)
                }
                resolvedAny = true
            }
            
            try? await Task.sleep(nanoseconds: 220_000_000)
        }
        
        if resolvedAny {
            await MainActor.run {
                setMapRegion(appropriateMapRegion, animated: true)
            }
        }
    }
    
    private func geocodeTravelEndpointsIfNeeded() async {
        let region: MKCoordinateRegion? = await MainActor.run { geocodeBiasRegion() }
        var resolvedAny = false
        
        let jobs: [(flightID: UUID, isFrom: Bool, query: String)] = await MainActor.run {
            var result: [(UUID, Bool, String)] = []
            for day in tripDays {
                for flight in day.flights {
                    if travelEndpointNeedsGeocode(flight, isFrom: true),
                       let query = travelEndpointQuery(flight, isFrom: true) {
                        result.append((flight.id, true, query))
                    }
                    if travelEndpointNeedsGeocode(flight, isFrom: false),
                       let query = travelEndpointQuery(flight, isFrom: false) {
                        result.append((flight.id, false, query))
                    }
                }
            }
            return result
        }
        
        for job in jobs {
            if Task.isCancelled { return }
            if let resolved = await searchPlace(for: job.query, region: region) {
                await MainActor.run {
                    applyResolvedTravelEndpoint(
                        coordinate: resolved.coordinate,
                        toFlightID: job.flightID,
                        isFrom: job.isFrom
                    )
                }
                resolvedAny = true
            }
            try? await Task.sleep(nanoseconds: 220_000_000)
        }
        
        if resolvedAny {
            await MainActor.run {
                setMapRegion(appropriateMapRegion, animated: true)
            }
            await refreshTravelRoadRoutes()
        }
    }
    
    @MainActor
    private func applyResolvedTravelEndpoint(
        coordinate: CLLocationCoordinate2D,
        toFlightID id: UUID,
        isFrom: Bool
    ) {
        for dayIdx in tripDays.indices {
            guard let flightIdx = tripDays[dayIdx].flights.firstIndex(where: { $0.id == id }) else { continue }
            if isFrom {
                tripDays[dayIdx].flights[flightIdx].fromLatitude = coordinate.latitude
                tripDays[dayIdx].flights[flightIdx].fromLongitude = coordinate.longitude
            } else {
                tripDays[dayIdx].flights[flightIdx].toLatitude = coordinate.latitude
                tripDays[dayIdx].flights[flightIdx].toLongitude = coordinate.longitude
            }
            return
        }
    }
    
    @MainActor
    private func geocodeBiasRegion() -> MKCoordinateRegion? {
        guard let lat = trip.latitude, let lon = trip.longitude else { return nil }
        let span = max(0.05, min(trip.mapSpan ?? 0.18, 0.6))
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
    }
    
    @MainActor
    private func geocodeQuery(forEventID id: UUID) -> (query: String, isIdeas: Bool)? {
        if let idx = parkedIdeas.firstIndex(where: { $0.id == id }) {
            let e = parkedIdeas[idx]
            let loc = e.location.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !loc.isEmpty, e.latitude == nil, e.longitude == nil else { return nil }
            return (query: "\(e.title) \(loc) \(trip.destination)", isIdeas: true)
        }
        
        for dayIdx in tripDays.indices {
            if let eventIdx = tripDays[dayIdx].events.firstIndex(where: { $0.id == id }) {
                let e = tripDays[dayIdx].events[eventIdx]
                let loc = e.location.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !loc.isEmpty, e.latitude == nil, e.longitude == nil else { return nil }
                return (query: "\(e.title) \(loc) \(trip.destination)", isIdeas: false)
            }
        }
        
        return nil
    }
    
    private func searchPlace(for query: String, region: MKCoordinateRegion?) async -> (coordinate: CLLocationCoordinate2D, location: String?)? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        if let region {
            request.region = region
        }
        
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first,
                  let coordinate = mapItemCoordinate(item) else { return nil }
            
            let address = mapItemAddressString(item)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let refinedLocation: String? = {
                guard let address, !address.isEmpty else {
                    return name.isEmpty ? nil : name
                }
                if !name.isEmpty, !address.localizedCaseInsensitiveContains(name) {
                    return "\(name), \(address)"
                }
                return address
            }()
            
            return (coordinate: coordinate, location: refinedLocation)
        } catch {
            return nil
        }
    }
    
    @MainActor
    private func applyResolvedPlace(
        _ place: (coordinate: CLLocationCoordinate2D, location: String?),
        toEventID id: UUID,
        isIdeas: Bool
    ) {
        let coord = place.coordinate
        let refinedLocation = place.location?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        func apply(to event: inout EventItem) {
            event.latitude = coord.latitude
            event.longitude = coord.longitude
            if let refinedLocation, !refinedLocation.isEmpty {
                let current = event.location.trimmingCharacters(in: .whitespacesAndNewlines)
                let currentLooksSpecific = current.range(of: #"\b\d+\s+\p{L}"#, options: .regularExpression) != nil
                if !currentLooksSpecific {
                    event.location = refinedLocation
                }
            }
        }
        
        if isIdeas, let idx = parkedIdeas.firstIndex(where: { $0.id == id }) {
            apply(to: &parkedIdeas[idx])
            return
        }
        
        for dayIdx in tripDays.indices {
            if let eventIdx = tripDays[dayIdx].events.firstIndex(where: { $0.id == id }) {
                apply(to: &tripDays[dayIdx].events[eventIdx])
                return
            }
        }
    }

    private func applyTripSettingsFromSheet() {
        // Detect unscheduled -> scheduled conversion and map days by index.
        let wasUnscheduled = settingsSnapshotTrip?.isDatesSet == false
        if wasUnscheduled, trip.isDatesSet {
            let calendar = Calendar.current
            let totalDays = max(1, (calendar.dateComponents([.day], from: trip.startDate, to: trip.endDate).day ?? 0) + 1)
            let oldDays = tripDays
            
            if oldDays.count > totalDays {
                let dropped = oldDays.suffix(from: totalDays)
                let activities = dropped.map { $0.events.count }.reduce(0, +)
                let reminders = dropped.map { $0.reminders.count }.reduce(0, +)
                let checklists = dropped.map { $0.checklists.count }.reduce(0, +)
                let flights = dropped.map { $0.flights.count }.reduce(0, +)
                
                pendingConvertNewDaysCount = totalDays
                pendingConvertDroppedCounts = (activities, reminders, checklists, flights)
                pendingConvertOldDays = oldDays
                showConvertDatesDropAlert = true
                return
            }
            
            convertCurrentTripDaysToScheduledByIndex(oldDays: oldDays)
            return
        }
        
        updateTripDaysForDates()
    }
    
    private func convertCurrentTripDaysToScheduledByIndex(oldDays: [TripDay]) {
        let calendar = Calendar.current
        let totalDays = max(1, (calendar.dateComponents([.day], from: trip.startDate, to: trip.endDate).day ?? 0) + 1)
        
        var newDays: [TripDay] = []
        newDays.reserveCapacity(totalDays)
        
        for offset in 0..<totalDays {
            let date = calendar.date(byAdding: .day, value: offset, to: trip.startDate) ?? trip.startDate
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
        
        tripDays = newDays
    }
    
    var body: some View {
        applySheets(to: mainLayout)
            .background(backgroundGradient)
            .ignoresSafeArea(edges: .top)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .enableSwipeBack()
            .toolbar(.hidden, for: .tabBar)
            .tint(.primary)
            .toolbarBackground(.automatic, for: .navigationBar)
            .simultaneousGesture(edgeSwipeGesture)
            .toolbar { tripDetailToolbar }
        .onChange(of: isPresentingNewReminder) { _, isPresented in
            if !isPresented {
                editingReminder = nil
                newReminderText = ""
            }
        }
        .onChange(of: isPresentingNewChecklist) { _, isPresented in
            if !isPresented {
                editingChecklist = nil
                checklistTitle = ""
                checklistDraftItems = []
            }
        }
        .onAppear {
            tabChrome.beginSuppressingAIAccessory()
            initializeTripDays()
            setMapRegion(appropriateMapRegion, animated: false)
            displayedDayIDForMarkers = nil
            markersOpacity = 1.0
            hasUserScrolledDays = false
            didScrollToActiveDay = false
            focusedDayID = nil
            showMap = false
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showMap = true
                }
            }
            geocodeMissingEventCoordinatesIfNeeded()
            geocodeMissingTravelCoordinatesIfNeeded()
        }
        .task(id: travelRouteRefreshKey) {
            await refreshTravelRoadRoutes()
        }
        .onDisappear {
            tabChrome.endSuppressingAIAccessory()
        }
        .onChange(of: trip.latitude) { _, _ in
            setMapRegion(appropriateMapRegion, animated: false)
        }
        .onChange(of: trip.longitude) { _, _ in
            setMapRegion(appropriateMapRegion, animated: false)
        }
        .onChange(of: trip.mapSpan) { _, _ in
            setMapRegion(appropriateMapRegion, animated: false)
        }
        .onChange(of: focusedDayID) { oldValue, newValue in
            guard hasUserScrolledDays else { return }
            
            if oldValue != newValue, newValue != nil {
                let now = Date()
                if now.timeIntervalSince(lastDayFocusHapticAt) > 0.35 {
                    lastDayFocusHapticAt = now
                    Haptics.bump()
                }
            }
            
            let targetDayID: UUID? = {
                guard let dayID = newValue else { return nil }
                return dayHasMapContent(dayID) ? dayID : nil
            }()
            
            pendingMarkerTransition?.cancel()
            // Fade markers out first, then animate the camera, then fade markers in.
            withAnimation(.easeInOut(duration: 0.14)) {
                markersOpacity = 0.0
            }
            
            let targetRegion: MKCoordinateRegion = {
                if let dayID = targetDayID, let region = regionFitting(coordinates: coordinates(forDay: dayID)) {
                    return region
                }
                return appropriateMapRegion
            }()
            
            let work = DispatchWorkItem {
                displayedDayIDForMarkers = targetDayID
                
                // Smooth pan/zoom from current camera.
                setMapRegion(targetRegion, animated: true, duration: 0.42)
                
                // Fade markers in after the camera is mostly settled.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        markersOpacity = 1.0
                    }
                }
            }
            
            pendingMarkerTransition = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14, execute: work)
        }
        .onChange(of: tripDays) { _, newDays in
            trip.days = newDays
        }
        .onChange(of: parkedIdeas) { _, newValue in
            trip.parkedIdeas = newValue
        }
        .onChange(of: trip.showParkedIdeas) { _, newValue in
            if !newValue, focusedDayID == Self.parkedIdeasColumnID {
                focusedDayID = nil
                displayedDayIDForMarkers = nil
                markersOpacity = 1.0
            }
        }
    }
}


private extension TripDetailView {
    var backgroundGradient: some View {
        (colorScheme == .dark ? Color(hex: 0x0A0A0A) : Color(hex: 0xE0E0E0))
            .ignoresSafeArea()
    }

    func kanbanBoard() -> some View {
        GeometryReader { geo in
            let columnWidth: CGFloat = {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    return 400
                } else {
                    return geo.size.width * 0.8
                }
            }()
            let tripHasNoItems = tripDays.allSatisfy { $0.events.isEmpty && $0.reminders.isEmpty && $0.checklists.isEmpty && $0.flights.isEmpty }
            let viewport = CGRect(x: 0, y: 0, width: geo.size.width, height: geo.size.height)
            let emptyStateFocusedDayID = focusedDayID ?? tripDays.first?.id
            
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(Array(tripDays.enumerated()), id: \.element.id) { _, day in
                            let isToday = trip.isDatesSet && Calendar.current.isDate(day.date, inSameDayAs: Date())
                            DayColumn(
                                day: day,
                                totalDays: tripDays.count,
                                isUnscheduled: !trip.isDatesSet,
                                isCurrentDay: isToday,
                                columnWidth: columnWidth,
                                columnHeight: geo.size.height - 24,
                                onTap: { event in startEditing(event: event, day: day) },
                                onEdit: { event in startEditing(event: event, day: day) },
                                onDuplicate: { event in duplicateEvent(event, in: day) },
                                onDelete: { event in deleteEvent(event) },
                                onMoveEventLeft: { event in moveEvent(event, from: day, direction: -1) },
                                onMoveEventRight: { event in moveEvent(event, from: day, direction: 1) },
                                onMoveEventToParked: trip.showParkedIdeas ? { event in moveEventToParked(event, from: day) } : nil,
                                onTapReminder: { reminder in startEditingReminder(reminder, day: day) },
                                onDeleteReminder: { reminder in deleteReminder(reminder) },
                                onMoveReminderLeft: { reminder in moveReminder(reminder, from: day, direction: -1) },
                                onMoveReminderRight: { reminder in moveReminder(reminder, from: day, direction: 1) },
                                onMoveReminderToParked: trip.showParkedIdeas ? { reminder in moveReminderToParked(reminder, from: day) } : nil,
                                onTapChecklist: { checklist in startEditingChecklist(checklist, day: day) },
                                onDeleteChecklist: { checklist in deleteChecklist(checklist) },
                                onMoveChecklistLeft: { checklist in moveChecklist(checklist, from: day, direction: -1) },
                                onMoveChecklistRight: { checklist in moveChecklist(checklist, from: day, direction: 1) },
                                onMoveChecklistToParked: trip.showParkedIdeas ? { checklist in moveChecklistToParked(checklist, from: day) } : nil,
                                onTapFlight: { flight in startEditingFlight(flight, day: day) },
                                onDeleteFlight: { flight in deleteFlight(flight) },
                                onMoveFlightLeft: { flight in moveFlight(flight, from: day, direction: -1) },
                                onMoveFlightRight: { flight in moveFlight(flight, from: day, direction: 1) },
                                onMoveFlightToParked: trip.showParkedIdeas ? { flight in moveFlightToParked(flight, from: day) } : nil,
                                onPlanDay: {
                                    planDayDefaultDayID = day.id
                                    isPresentingPlanDay = true
                                },
                                showEmptyPlaceholder: tripHasNoItems,
                                isEmptyStateFocused: emptyStateFocusedDayID == day.id
                            )
                            .id(day.id)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear
                                        .preference(
                                            key: DayColumnFramesPreferenceKey.self,
                                            value: [day.id: proxy.frame(in: .named("dayScroll"))]
                                        )
                                }
                            )
                        }
                        
                        if trip.showParkedIdeas {
                            ParkedIdeasColumn(
                                items: parkedIdeas,
                                columnWidth: columnWidth,
                                columnHeight: geo.size.height - 24,
                                onTap: { event in startEditingParkedIdea(event) },
                                onDuplicate: { event in duplicateParkedIdea(event) },
                                onDelete: { event in deleteEvent(event) },
                                onAdd: {
                                    editingEvent = nil
                                    selectedDayID = Self.parkedIdeasColumnID
                                    prepareNewEventDefaults()
                                    activitySheetDetent = .large
                                    isPresentingNewActivity = true
                                },
                                onMoveLeftToLastDay: (tripDays.count > 0) ? { event in moveParkedIdeaLeftToLastDay(event) } : nil
                            )
                            .id(Self.parkedIdeasColumnID)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear
                                        .preference(
                                            key: DayColumnFramesPreferenceKey.self,
                                            value: [Self.parkedIdeasColumnID: proxy.frame(in: .named("dayScroll"))]
                                        )
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .coordinateSpace(name: "dayScroll")
                .onAppear {
                    scrollToActiveDayIfNeeded(using: proxy)
                }
                .onChange(of: tripDays.map(\.id)) { _, _ in
                    scrollToActiveDayIfNeeded(using: proxy)
                }
                .onPreferenceChange(DayColumnFramesPreferenceKey.self) { framesByID in
                    // Track focus for empty-state CTA animation even before the user has
                    // intentionally scrolled (map camera still waits on hasUserScrolledDays).
                    guard tripHasNoItems || hasUserScrolledDays else { return }
                    var bestID: UUID?
                    var bestVisibleWidth: CGFloat = 0
                    
                    for (id, frame) in framesByID {
                        let visibleFrame = frame.intersection(viewport)
                        let visibleWidth = max(0, visibleFrame.width)
                        if visibleWidth > bestVisibleWidth {
                            bestVisibleWidth = visibleWidth
                            bestID = id
                        }
                    }
                    
                    if bestVisibleWidth <= 0 {
                        if focusedDayID != nil { focusedDayID = nil }
                        return
                    }
                    
                    if focusedDayID != bestID {
                        focusedDayID = bestID
                    }
                }
                .scrollDisabled(isEdgeSwipingBack)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 6)
                        .onChanged { value in
                            if !hasUserScrolledDays,
                               abs(value.translation.width) > abs(value.translation.height) {
                                hasUserScrolledDays = true
                            }
                        }
                )
            }
        }
    }
}

private struct DayColumnFramesPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}


private extension TripDetailView {
    var durationText: String { "\(tripDays.count) day trip" }
    var tripName: String {
        trip.destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? trip.name
        : trip.destination
    }

    var totalEvents: Int {
        tripDays.map(\.events.count).reduce(0, +)
    }

    var tripProgress: Double {
        guard let todayIndex = tripDays.firstIndex(where: { Calendar.current.isDateInToday($0.date) }) else {
            return 0.35
        }
        return Double(todayIndex + 1) / Double(tripDays.count)
    }

    var tripDateRangeText: String {
        let startText = trip.startDate.formatted(Date.FormatStyle().month(.abbreviated).day())
        let endText = trip.endDate.formatted(Date.FormatStyle().month(.abbreviated).day())
        return "\(startText) – \(endText)"
    }
    
    func initializeTripDays() {
        tripDays = trip.days
        parkedIdeas = trip.parkedIdeas
        updateTripDaysForDates()
    }
    
    /// Today’s day column when the trip is currently in progress.
    private var activeTripDayID: UUID? {
        guard trip.isDatesSet else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: trip.startDate)
        let end = calendar.startOfDay(for: trip.endDate)
        guard today >= start, today <= end else { return nil }
        return tripDays.first(where: { calendar.isDate($0.date, inSameDayAs: today) })?.id
    }
    
    private func scrollToActiveDayIfNeeded(using proxy: ScrollViewProxy) {
        guard !didScrollToActiveDay, let dayID = activeTripDayID else { return }
        didScrollToActiveDay = true
        
        DispatchQueue.main.async {
            withTransaction(Transaction(animation: nil)) {
                proxy.scrollTo(dayID, anchor: .center)
            }
            focusedDayID = dayID
            displayedDayIDForMarkers = dayHasMapContent(dayID) ? dayID : nil
            hasUserScrolledDays = true
            if let region = regionFitting(coordinates: coordinates(forDay: dayID)) {
                setMapRegion(region, animated: false)
            }
        }
    }

    func move(event: EventItem, to dayID: UUID, before target: EventItem?) {
        guard let sourceDayIndex = tripDays.firstIndex(where: { $0.events.contains(event) }),
              let sourceEventIndex = tripDays[sourceDayIndex].events.firstIndex(of: event) else { return }

        let updatedEvent = tripDays[sourceDayIndex].events.remove(at: sourceEventIndex)

        if tripDays[sourceDayIndex].id == dayID {
            var currentEvents = tripDays[sourceDayIndex].events
            if let target, let insertIndex = currentEvents.firstIndex(of: target) {
                currentEvents.insert(updatedEvent, at: insertIndex)
            } else {
                currentEvents.append(updatedEvent)
            }
            tripDays[sourceDayIndex].events = currentEvents
            return
        }

        guard let destinationDayIndex = tripDays.firstIndex(where: { $0.id == dayID }) else { return }
        var destinationEvents = tripDays[destinationDayIndex].events

        if let target, let insertIndex = destinationEvents.firstIndex(of: target) {
            destinationEvents.insert(updatedEvent, at: insertIndex)
        } else {
            destinationEvents.append(updatedEvent)
        }

        tripDays[destinationDayIndex].events = destinationEvents
    }

    func updateTripDaysForDates() {
        if !trip.isDatesSet {
            let desiredCount = max(1, trip.unscheduledDaysCount)
            let base = Calendar.current.startOfDay(for: Date())
            var newDays: [TripDay] = []
            newDays.reserveCapacity(desiredCount)
            
            for idx in 0..<desiredCount {
                let date = Calendar.current.date(byAdding: .day, value: idx, to: base) ?? base
                if idx < tripDays.count {
                    let existing = tripDays[idx]
                    let updated = TripDay(
                        id: existing.id,
                        date: date,
                        events: existing.events,
                        reminders: existing.reminders,
                        checklists: existing.checklists,
                        flights: existing.flights,
                        label: "Day \(idx + 1)",
                        order: idx + 1,
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
                        label: "Day \(idx + 1)",
                        order: idx + 1,
                        weatherIcon: "cloud.sun.fill",
                        temperatureF: 72
                    )
                    newDays.append(emptyDay)
                }
            }
            
            tripDays = newDays
            return
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: trip.startDate, to: trip.endDate)
        let totalDays = (components.day ?? 0) + 1
        guard totalDays > 0 else { return }

        var newDays: [TripDay] = []
        for offset in 0..<totalDays {
            let date = calendar.date(byAdding: .day, value: offset, to: trip.startDate) ?? trip.startDate
            if let existing = tripDays.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
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
        tripDays = newDays
    }

    func prepareNewEventDefaults() {
        if selectedDayID == nil {
            selectedDayID = tripDays.first?.id
        }
        editingEvent = nil
        newEventTitle = ""
        newEventLocation = ""
        newEventLatitude = nil
        newEventLongitude = nil
        newEventDescription = ""
        newEventIcon = "mappin.and.ellipse"
        newEventAccent = .purple
        newEventPhoto = nil
        newEventDocuments = []
        newEventCost = nil
        newEventCostCurrencyCode = UserDefaults.standard.string(forKey: "currencyCode") ?? "USD"
        activityAlreadyInPlaces = false
        placesLinkEventID = nil
        let base = Calendar.current.startOfDay(for: Date())
        newEventStart = base.addingTimeInterval(9 * 3600)
        newEventEnd = newEventStart
    }

    func addNewEvent() {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let hasEndTime = abs(newEventEnd.timeIntervalSince(newEventStart)) >= 60
        let timeText = hasEndTime
            ? "\(formatter.string(from: newEventStart)) - \(formatter.string(from: newEventEnd))"
            : "\(formatter.string(from: newEventStart))"
        
        let photoData = newEventPhoto?.jpegData(compressionQuality: 0.8)
        let eventIDForPlaces = editingEvent?.id ?? placesLinkEventID

        if let editingEvent {
            let removedDocuments = editingEvent.documents.filter { existing in
                !newEventDocuments.contains(where: { $0.id == existing.id })
            }
            let updated = EventItem(
                id: editingEvent.id,
                title: newEventTitle.isEmpty ? "Untitled" : newEventTitle,
                description: newEventDescription,
                time: timeText,
                location: newEventLocation,
                latitude: newEventLatitude,
                longitude: newEventLongitude,
                icon: newEventIcon,
                accent: newEventAccent,
                photoData: photoData,
                documents: newEventDocuments,
                rating: 0,
                cost: newEventCost,
                costCurrencyCode: newEventCostCurrencyCode
            )
            ActivityDocumentStore.delete(documents: removedDocuments)
            
            for idx in tripDays.indices {
                tripDays[idx].events.removeAll { $0.id == editingEvent.id }
            }
            parkedIdeas.removeAll { $0.id == editingEvent.id }

            if selectedDayID == Self.parkedIdeasColumnID {
                parkedIdeas.insert(updated, at: 0)
                self.editingEvent = updated
                placesLinkEventID = nil
                return
            }
            
            guard let dayID = selectedDayID,
                  let dayIndex = tripDays.firstIndex(where: { $0.id == dayID }) else { return }
            tripDays[dayIndex].events.append(updated)
            self.editingEvent = updated
            placesLinkEventID = nil
            return
        }
        
        guard let targetID = selectedDayID else { return }
        
        let event = EventItem(
            id: eventIDForPlaces ?? UUID(),
            title: newEventTitle.isEmpty ? "Untitled" : newEventTitle,
            description: newEventDescription,
            time: timeText,
            location: newEventLocation,
            latitude: newEventLatitude,
            longitude: newEventLongitude,
            icon: newEventIcon,
            accent: newEventAccent,
            photoData: photoData,
            documents: newEventDocuments,
            rating: 0,
            cost: newEventCost,
            costCurrencyCode: newEventCostCurrencyCode
        )
        placesLinkEventID = nil
        
        if targetID == Self.parkedIdeasColumnID {
            parkedIdeas.insert(event, at: 0)
        } else if let idx = tripDays.firstIndex(where: { $0.id == targetID }) {
            tripDays[idx].events.append(event)
        }
        
        if let lat = newEventLatitude, let lon = newEventLongitude {
            withAnimation {
                setMapRegion(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    // Zoom in more when a newly-added activity has a location.
                    span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
                ), animated: false)
            }
        }
    }
    
    private func addCurrentActivityToPlaces() {
        guard CloudSyncPaths.isSignedInToApple() else { return }
        
        let location = newEventLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = newEventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let inferredName = PlaceNaming.title(location: location, fallback: title)
        guard !inferredName.isEmpty, inferredName != "Place" || !location.isEmpty || !title.isEmpty else { return }
        
        let linkedEventID = editingEvent?.id ?? placesLinkEventID ?? UUID()
        if editingEvent == nil {
            placesLinkEventID = linkedEventID
        }
        
        let photoData = newEventPhoto?.jpegData(compressionQuality: 0.8)
        let draft = EventItem(
            id: linkedEventID,
            title: title.isEmpty ? "Untitled" : title,
            description: newEventDescription,
            time: "",
            location: location,
            latitude: newEventLatitude,
            longitude: newEventLongitude,
            icon: newEventIcon,
            accent: newEventAccent,
            photoData: photoData,
            documents: newEventDocuments,
            rating: 0,
            cost: newEventCost,
            costCurrencyCode: newEventCostCurrencyCode
        )
        
        var noteParts: [String] = []
        let description = newEventDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty {
            noteParts.append(description)
        }
        if newEventCost != nil {
            noteParts.append(
                "Cost: \(CurrencyFormatting.string(for: newEventCost, currencyCode: newEventCostCurrencyCode))"
            )
        }
        
        _ = placeStore.saveFromActivity(
            name: inferredName,
            location: location,
            note: noteParts.joined(separator: "\n\n"),
            photoData: PlaceImageResolver.imageData(from: draft),
            latitude: newEventLatitude,
            longitude: newEventLongitude,
            tripID: trip.id,
            tripName: trip.name,
            eventID: linkedEventID,
            placeType: PlaceType.inferred(fromActivityIcon: newEventIcon)
        )
        activityAlreadyInPlaces = true
    }
    
    func addReminder() {
        let trimmed = newReminderText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if let editingReminder {
            for idx in tripDays.indices {
                tripDays[idx].reminders.removeAll { $0.id == editingReminder.id }
            }
            let updated = ReminderItem(id: editingReminder.id, text: trimmed, createdAt: editingReminder.createdAt)
            
            if selectedDayID == Self.parkedIdeasColumnID {
                let parked = EventItem(
                    id: UUID(),
                    title: trimmed,
                    description: "",
                    time: "",
                    location: "",
                    latitude: nil,
                    longitude: nil,
                    icon: "pin.fill",
                    accent: .neutral,
                    photoData: nil
                )
                parkedIdeas.insert(parked, at: 0)
                self.editingReminder = updated
                return
            }
            
            guard let dayID = selectedDayID,
                  let dayIndex = tripDays.firstIndex(where: { $0.id == dayID }) else { return }
            tripDays[dayIndex].reminders.insert(updated, at: 0)
            self.editingReminder = updated
        } else {
            guard let targetID = selectedDayID else { return }
            if targetID == Self.parkedIdeasColumnID {
                let parked = EventItem(
                    id: UUID(),
                    title: trimmed,
                    description: "",
                    time: "",
                    location: "",
                    latitude: nil,
                    longitude: nil,
                    icon: "pin.fill",
                    accent: .neutral,
                    photoData: nil
                )
                parkedIdeas.insert(parked, at: 0)
                return
            }
            guard let idx = tripDays.firstIndex(where: { $0.id == targetID }) else { return }
            let reminder = ReminderItem(id: UUID(), text: trimmed, createdAt: Date())
            tripDays[idx].reminders.insert(reminder, at: 0)
        }
    }
    
    func saveChecklist() {
        let trimmedTitle = checklistTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedItems = checklistDraftItems
            .map { ChecklistEntry(id: $0.id, text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines), isDone: $0.isDone) }
            .filter { !$0.text.isEmpty }
        
        guard !trimmedTitle.isEmpty else { return }
        
        if let editingChecklist {
            for idx in tripDays.indices {
                tripDays[idx].checklists.removeAll { $0.id == editingChecklist.id }
            }
            let updated = ChecklistItem(
                id: editingChecklist.id,
                title: trimmedTitle,
                items: normalizedItems,
                createdAt: editingChecklist.createdAt
            )
            
            if selectedDayID == Self.parkedIdeasColumnID {
                let preview = updated.items.prefix(8).map { ($0.isDone ? "✓ " : "• ") + $0.text }
                let parked = EventItem(
                    id: UUID(),
                    title: updated.title,
                    description: preview.joined(separator: "\n"),
                    time: "",
                    location: "",
                    latitude: nil,
                    longitude: nil,
                    icon: "checklist.checked",
                    accent: .yellow,
                    photoData: nil
                )
                parkedIdeas.insert(parked, at: 0)
                self.editingChecklist = updated
                return
            }
            
            guard let dayID = selectedDayID,
                  let dayIndex = tripDays.firstIndex(where: { $0.id == dayID }) else { return }
            tripDays[dayIndex].checklists.insert(updated, at: 0)
            self.editingChecklist = updated
        } else {
            let checklist = ChecklistItem(
                id: UUID(),
                title: trimmedTitle,
                items: normalizedItems,
                createdAt: Date()
            )
            
            if selectedDayID == Self.parkedIdeasColumnID {
                let preview = checklist.items.prefix(8).map { ($0.isDone ? "✓ " : "• ") + $0.text }
                let parked = EventItem(
                    id: UUID(),
                    title: checklist.title,
                    description: preview.joined(separator: "\n"),
                    time: "",
                    location: "",
                    latitude: nil,
                    longitude: nil,
                    icon: "checklist.checked",
                    accent: .yellow,
                    photoData: nil
                )
                parkedIdeas.insert(parked, at: 0)
                return
            }
            
            guard let dayID = selectedDayID,
                  let dayIndex = tripDays.firstIndex(where: { $0.id == dayID }) else { return }
            tripDays[dayIndex].checklists.insert(checklist, at: 0)
        }
    }
    
    func startEditingChecklist(_ checklist: ChecklistItem, day: TripDay) {
        selectedDayID = day.id
        checklistTitle = checklist.title
        checklistDraftItems = checklist.items
        editingChecklist = checklist
        isPresentingNewChecklist = true
    }
    
    func deleteChecklist(_ checklist: ChecklistItem) {
        for idx in tripDays.indices {
            tripDays[idx].checklists.removeAll { $0.id == checklist.id }
        }
    }
    
    func startEditingReminder(_ reminder: ReminderItem, day: TripDay) {
        selectedDayID = day.id
        newReminderText = reminder.text
        editingReminder = reminder
        isPresentingNewReminder = true
    }
    
    func deleteReminder(_ reminder: ReminderItem) {
        for idx in tripDays.indices {
            tripDays[idx].reminders.removeAll { $0.id == reminder.id }
        }
    }

    func startEditing(event: EventItem, day: TripDay) {
        editingEvent = event
        selectedDayID = day.id
        activitySheetDetent = .medium
        newEventTitle = event.title
        newEventLocation = event.location
        newEventLatitude = event.latitude
        newEventLongitude = event.longitude
        newEventDescription = event.description
        newEventIcon = event.icon
        newEventAccent = event.accent
        newEventDocuments = event.documents
        newEventCost = event.cost
        newEventCostCurrencyCode = event.costCurrencyCode ?? (UserDefaults.standard.string(forKey: "currencyCode") ?? "USD")
        
        if let photoData = event.photoData {
            newEventPhoto = UIImage(data: photoData)
        } else {
            newEventPhoto = nil
        }
        
        activityAlreadyInPlaces = placeStore.places.contains { $0.sourceEventID == event.id }

        let normalized = event.time.replacingOccurrences(of: "–", with: "-")
        let parts = normalized
            .split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        
        let short = DateFormatter()
        short.dateStyle = .none
        short.timeStyle = .short
        
        let hhmm = DateFormatter()
        hhmm.dateFormat = "HH:mm"
        
        func parse(_ s: String) -> Date? {
            short.date(from: s) ?? hhmm.date(from: s)
        }
        
        if let start = parts.first.flatMap({ parse($0) }) {
            newEventStart = start
            if parts.count >= 2, let end = parse(parts[1]), end > start {
                newEventEnd = end
            } else {
                newEventEnd = start
            }
        }
        
        if let lat = event.latitude, let lon = event.longitude {
            setMapRegion(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                ),
                animated: true,
                duration: 0.5
            )
        }
        
        isPresentingNewActivity = true
    }
    
    func startEditingParkedIdea(_ event: EventItem) {
        editingEvent = event
        selectedDayID = Self.parkedIdeasColumnID
        activitySheetDetent = .medium
        newEventTitle = event.title
        newEventLocation = event.location
        newEventLatitude = event.latitude
        newEventLongitude = event.longitude
        newEventDescription = event.description
        newEventIcon = event.icon
        newEventAccent = event.accent
        newEventDocuments = event.documents
        newEventCost = event.cost
        newEventCostCurrencyCode = event.costCurrencyCode ?? (UserDefaults.standard.string(forKey: "currencyCode") ?? "USD")
        
        if let photoData = event.photoData {
            newEventPhoto = UIImage(data: photoData)
        } else {
            newEventPhoto = nil
        }
        
        activityAlreadyInPlaces = placeStore.places.contains { $0.sourceEventID == event.id }
        
        let normalized = event.time.replacingOccurrences(of: "–", with: "-")
        let parts = normalized
            .split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        
        let short = DateFormatter()
        short.dateStyle = .none
        short.timeStyle = .short
        
        let hhmm = DateFormatter()
        hhmm.dateFormat = "HH:mm"
        
        func parse(_ s: String) -> Date? {
            short.date(from: s) ?? hhmm.date(from: s)
        }
        
        if let start = parts.first.flatMap({ parse($0) }) {
            newEventStart = start
            if parts.count >= 2, let end = parse(parts[1]), end > start {
                newEventEnd = end
            } else {
                newEventEnd = start
            }
        }
        
        isPresentingNewActivity = true
    }
    
    func openEventFromMarker(_ event: EventItem) {
        if let day = tripDays.first(where: { $0.events.contains(event) }) {
            startEditing(event: event, day: day)
            return
        }
        if parkedIdeas.contains(event) {
            startEditingParkedIdea(event)
        }
    }
    
    func openFlightFromMarker(_ flightID: UUID) {
        for day in tripDays {
            if let flight = day.flights.first(where: { $0.id == flightID }) {
                startEditingFlight(flight, day: day)
                return
            }
        }
    }
    
    @MainActor
    private func refreshTravelRoadRoutes() async {
        let candidates: [(id: UUID, from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, mode: TravelMode)] =
            tripDays.flatMap { day in
                day.flights.compactMap { flight in
                    guard flight.travelMode == .drive || flight.travelMode == .walk,
                          let fromLat = flight.fromLatitude,
                          let fromLon = flight.fromLongitude,
                          let toLat = flight.toLatitude,
                          let toLon = flight.toLongitude
                    else { return nil }
                    let from = CLLocationCoordinate2D(latitude: fromLat, longitude: fromLon)
                    let to = CLLocationCoordinate2D(latitude: toLat, longitude: toLon)
                    guard CLLocationCoordinate2DIsValid(from), CLLocationCoordinate2DIsValid(to) else { return nil }
                    return (flight.id, from, to, flight.travelMode)
                }
            }
        
        let activeIDs = Set(candidates.map(\.id))
        resolvedTravelRoadRoutes = resolvedTravelRoadRoutes.filter { activeIDs.contains($0.key) }
        
        await withTaskGroup(of: (UUID, [CLLocationCoordinate2D]?).self) { group in
            for candidate in candidates {
                if resolvedTravelRoadRoutes[candidate.id] != nil { continue }
                group.addTask {
                    let coords = await TravelMapRouting.fetchRoadRoute(
                        from: candidate.from,
                        to: candidate.to,
                        mode: candidate.mode
                    )
                    return (candidate.id, coords)
                }
            }
            for await (id, coords) in group {
                if let coords, coords.count >= 2 {
                    resolvedTravelRoadRoutes[id] = coords
                }
            }
        }
    }
    
    func deleteCurrentEvent() {
        guard let event = editingEvent else { return }
        ActivityDocumentStore.delete(documents: event.documents)
        if parkedIdeas.contains(where: { $0.id == event.id }) {
            parkedIdeas.removeAll { $0.id == event.id }
            editingEvent = nil
            return
        }
        
        for dayIndex in tripDays.indices {
            if let eventIndex = tripDays[dayIndex].events.firstIndex(where: { $0.id == event.id }) {
                tripDays[dayIndex].events.remove(at: eventIndex)
                break
            }
        }
        
        editingEvent = nil
    }
    
    func deleteEvent(_ event: EventItem) {
        ActivityDocumentStore.delete(documents: event.documents)
        if parkedIdeas.contains(event) {
            parkedIdeas.removeAll { $0.id == event.id }
            return
        }
        for dayIndex in tripDays.indices {
            if let eventIndex = tripDays[dayIndex].events.firstIndex(where: { $0.id == event.id }) {
                tripDays[dayIndex].events.remove(at: eventIndex)
                break
            }
        }
    }
    
    func duplicateEvent(_ event: EventItem, in day: TripDay) {
        guard let dayIndex = tripDays.firstIndex(where: { $0.id == day.id }),
              let eventIndex = tripDays[dayIndex].events.firstIndex(where: { $0.id == event.id }) else { return }
        
        let duplicated = EventItem(
            id: UUID(),
            title: event.title,
            description: event.description,
            time: event.time,
            location: event.location,
            latitude: event.latitude,
            longitude: event.longitude,
            icon: event.icon,
            accent: event.accent,
            photoData: event.photoData,
            documents: event.documents,
            rating: event.rating,
            cost: event.cost
        )
        
        tripDays[dayIndex].events.insert(duplicated, at: min(eventIndex + 1, tripDays[dayIndex].events.count))
    }
    
    func duplicateParkedIdea(_ event: EventItem) {
        guard let idx = parkedIdeas.firstIndex(where: { $0.id == event.id }) else { return }
        
        let duplicated = EventItem(
            id: UUID(),
            title: event.title,
            description: event.description,
            time: event.time,
            location: event.location,
            latitude: event.latitude,
            longitude: event.longitude,
            icon: event.icon,
            accent: event.accent,
            photoData: event.photoData,
            documents: event.documents,
            rating: event.rating,
            cost: event.cost
        )
        
        parkedIdeas.insert(duplicated, at: min(idx + 1, parkedIdeas.count))
    }
    
    private func travelRouteText(for flight: FlightItem) -> String {
        let from = flight.fromCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let to = flight.toCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !from.isEmpty || !to.isEmpty {
            if !from.isEmpty && !to.isEmpty { return "\(from) → \(to)" }
            return !from.isEmpty ? from : to
        }
        
        let fromName = flight.fromName.trimmingCharacters(in: .whitespacesAndNewlines)
        let toName = flight.toName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fromName.isEmpty && !toName.isEmpty {
            return "\(fromName) → \(toName)"
        }
        return [fromName, toName].first { !$0.isEmpty } ?? ""
    }
    
    private func travelListTitle(for flight: FlightItem) -> String {
        let ref = flight.flightNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if ref.isEmpty {
            return flight.travelMode.title
        }
        return flight.travelMode == .drive || flight.travelMode == .walk ? ref : ref.uppercased()
    }

    func prepareNewFlightDefaults(mode: TravelMode = .flight) {
        if selectedDayID == nil {
            selectedDayID = tripDays.first?.id
        }
        editingFlight = nil
        travelMode = mode
        flightFromName = ""
        flightFromCode = ""
        flightFromCity = ""
        flightFromLatitude = nil
        flightFromLongitude = nil
        flightFromTerminal = ""
        flightFromGate = ""
        flightToName = ""
        flightToCode = ""
        flightToCity = ""
        flightToLatitude = nil
        flightToLongitude = nil
        flightToTerminal = ""
        flightToGate = ""
        flightNumber = ""
        flightNotes = ""
        flightDocuments = []
        flightCost = nil
        flightCostCurrencyCode = UserDefaults.standard.string(forKey: "currencyCode") ?? "USD"
        let base = Calendar.current.startOfDay(for: Date())
        flightStartTime = base.addingTimeInterval(9 * 3600)
        flightEndTime = flightStartTime
    }

    func saveFlight() {
        if let editingFlight {
            let removedDocuments = editingFlight.documents.filter { existing in
                !flightDocuments.contains(where: { $0.id == existing.id })
            }
            let updated = FlightItem(
                id: editingFlight.id,
                fromName: flightFromName,
                fromCode: flightFromCode,
                fromCity: flightFromCity,
                fromLatitude: flightFromLatitude,
                fromLongitude: flightFromLongitude,
                fromTerminal: flightFromTerminal,
                fromGate: flightFromGate,
                toName: flightToName,
                toCode: flightToCode,
                toCity: flightToCity,
                toLatitude: flightToLatitude,
                toLongitude: flightToLongitude,
                toTerminal: flightToTerminal,
                toGate: flightToGate,
                travelMode: travelMode,
                flightNumber: flightNumber,
                notes: flightNotes,
                documents: flightDocuments,
                accent: .neutral,
                startTime: flightStartTime,
                endTime: flightEndTime,
                cost: flightCost,
                costCurrencyCode: flightCostCurrencyCode
            )
            ActivityDocumentStore.delete(documents: removedDocuments)
            
            for idx in tripDays.indices {
                tripDays[idx].flights.removeAll { $0.id == editingFlight.id }
            }
            
            if selectedDayID == Self.parkedIdeasColumnID {
                let f = DateFormatter()
                f.dateStyle = .none
                f.timeStyle = .short
                let dep = f.string(from: updated.startTime)
                let arr = updated.hasEndTime ? f.string(from: updated.endTime) : ""
                let time = arr.isEmpty ? dep : "\(dep) - \(arr)"
                
                let loc = travelRouteText(for: updated)
                let title = travelListTitle(for: updated)
                
                let parked = EventItem(
                    id: UUID(),
                    title: title,
                    description: updated.notes,
                    time: time,
                    location: loc,
                    latitude: nil,
                    longitude: nil,
                    icon: updated.travelMode.systemImageName,
                    accent: updated.accent,
                    photoData: nil,
                    documents: updated.documents
                )
                parkedIdeas.insert(parked, at: 0)
                return
            }
            
            guard let dayID = selectedDayID,
                  let dayIndex = tripDays.firstIndex(where: { $0.id == dayID }) else { return }
            tripDays[dayIndex].flights.insert(updated, at: 0)
        } else {
            let flight = FlightItem(
                fromName: flightFromName,
                fromCode: flightFromCode,
                fromCity: flightFromCity,
                fromLatitude: flightFromLatitude,
                fromLongitude: flightFromLongitude,
                fromTerminal: flightFromTerminal,
                fromGate: flightFromGate,
                toName: flightToName,
                toCode: flightToCode,
                toCity: flightToCity,
                toLatitude: flightToLatitude,
                toLongitude: flightToLongitude,
                toTerminal: flightToTerminal,
                toGate: flightToGate,
                travelMode: travelMode,
                flightNumber: flightNumber,
                notes: flightNotes,
                documents: flightDocuments,
                accent: .neutral,
                startTime: flightStartTime,
                endTime: flightEndTime,
                cost: flightCost,
                costCurrencyCode: flightCostCurrencyCode
            )
            
            if selectedDayID == Self.parkedIdeasColumnID {
                let f = DateFormatter()
                f.dateStyle = .none
                f.timeStyle = .short
                let dep = f.string(from: flight.startTime)
                let arr = flight.hasEndTime ? f.string(from: flight.endTime) : ""
                let time = arr.isEmpty ? dep : "\(dep) - \(arr)"
                
                let loc = travelRouteText(for: flight)
                let title = travelListTitle(for: flight)
                
                let parked = EventItem(
                    id: UUID(),
                    title: title,
                    description: flight.notes,
                    time: time,
                    location: loc,
                    latitude: nil,
                    longitude: nil,
                    icon: flight.travelMode.systemImageName,
                    accent: .neutral,
                    photoData: nil,
                    documents: flight.documents
                )
                parkedIdeas.insert(parked, at: 0)
                return
            }
            
            guard let dayID = selectedDayID,
                  let dayIndex = tripDays.firstIndex(where: { $0.id == dayID }) else { return }
            tripDays[dayIndex].flights.insert(flight, at: 0)
        }
    }

    func startEditingFlight(_ flight: FlightItem, day: TripDay) {
        selectedDayID = day.id
        editingFlight = flight
        flightFromName = flight.fromName
        flightFromCode = flight.fromCode
        flightFromCity = flight.fromCity
        flightFromLatitude = flight.fromLatitude
        flightFromLongitude = flight.fromLongitude
        flightFromTerminal = flight.fromTerminal
        flightFromGate = flight.fromGate
        flightToName = flight.toName
        flightToCode = flight.toCode
        flightToCity = flight.toCity
        flightToLatitude = flight.toLatitude
        flightToLongitude = flight.toLongitude
        flightToTerminal = flight.toTerminal
        flightToGate = flight.toGate
        travelMode = flight.travelMode
        flightNumber = flight.flightNumber
        flightNotes = flight.notes
        flightDocuments = flight.documents
        flightStartTime = flight.startTime
        flightEndTime = flight.endTime
        flightCost = flight.cost
        flightCostCurrencyCode = flight.costCurrencyCode ?? (UserDefaults.standard.string(forKey: "currencyCode") ?? "USD")
        isPresentingNewFlight = true
    }

    func deleteFlight(_ flight: FlightItem) {
        ActivityDocumentStore.delete(documents: flight.documents)
        for dayIndex in tripDays.indices {
            if let idx = tripDays[dayIndex].flights.firstIndex(where: { $0.id == flight.id }) {
                tripDays[dayIndex].flights.remove(at: idx)
                break
            }
        }
    }

    func deleteCurrentFlight() {
        guard let editingFlight else { return }
        deleteFlight(editingFlight)
        self.editingFlight = nil
    }

    
    func moveEvent(_ event: EventItem, from day: TripDay, direction: Int) {
        guard let fromIndex = tripDays.firstIndex(where: { $0.id == day.id }) else { return }
        let toIndex = fromIndex + direction
        guard tripDays.indices.contains(toIndex) else { return }
        
        tripDays[fromIndex].events.removeAll { $0.id == event.id }
        tripDays[toIndex].events.append(event)
    }
    
    func moveReminder(_ reminder: ReminderItem, from day: TripDay, direction: Int) {
        guard let fromIndex = tripDays.firstIndex(where: { $0.id == day.id }) else { return }
        let toIndex = fromIndex + direction
        guard tripDays.indices.contains(toIndex) else { return }
        
        tripDays[fromIndex].reminders.removeAll { $0.id == reminder.id }
        tripDays[toIndex].reminders.insert(reminder, at: 0)
    }
    
    func moveChecklist(_ checklist: ChecklistItem, from day: TripDay, direction: Int) {
        guard let fromIndex = tripDays.firstIndex(where: { $0.id == day.id }) else { return }
        let toIndex = fromIndex + direction
        guard tripDays.indices.contains(toIndex) else { return }
        
        tripDays[fromIndex].checklists.removeAll { $0.id == checklist.id }
        tripDays[toIndex].checklists.insert(checklist, at: 0)
    }
    
    func moveFlight(_ flight: FlightItem, from day: TripDay, direction: Int) {
        guard let fromIndex = tripDays.firstIndex(where: { $0.id == day.id }) else { return }
        let toIndex = fromIndex + direction
        guard tripDays.indices.contains(toIndex) else { return }
        
        tripDays[fromIndex].flights.removeAll { $0.id == flight.id }
        tripDays[toIndex].flights.insert(flight, at: 0)
    }
    
    func moveEventToParked(_ event: EventItem, from day: TripDay) {
        guard trip.showParkedIdeas else { return }
        guard let fromIndex = tripDays.firstIndex(where: { $0.id == day.id }) else { return }
        tripDays[fromIndex].events.removeAll { $0.id == event.id }
        parkedIdeas.insert(event, at: 0)
    }
    
    func moveReminderToParked(_ reminder: ReminderItem, from day: TripDay) {
        guard trip.showParkedIdeas else { return }
        guard let fromIndex = tripDays.firstIndex(where: { $0.id == day.id }) else { return }
        tripDays[fromIndex].reminders.removeAll { $0.id == reminder.id }
        
        let parked = EventItem(
            id: UUID(),
            title: reminder.text,
            description: "",
            time: "",
            location: "",
            latitude: nil,
            longitude: nil,
            icon: "pin.fill",
            accent: .neutral,
            photoData: nil
        )
        parkedIdeas.insert(parked, at: 0)
    }
    
    func moveChecklistToParked(_ checklist: ChecklistItem, from day: TripDay) {
        guard trip.showParkedIdeas else { return }
        guard let fromIndex = tripDays.firstIndex(where: { $0.id == day.id }) else { return }
        tripDays[fromIndex].checklists.removeAll { $0.id == checklist.id }
        
        let preview = checklist.items.prefix(8).map { ($0.isDone ? "✓ " : "• ") + $0.text }
        let parked = EventItem(
            id: UUID(),
            title: checklist.title,
            description: preview.joined(separator: "\n"),
            time: "",
            location: "",
            latitude: nil,
            longitude: nil,
            icon: "checklist.checked",
            accent: .yellow,
            photoData: nil
        )
        parkedIdeas.insert(parked, at: 0)
    }
    
    func moveFlightToParked(_ flight: FlightItem, from day: TripDay) {
        guard trip.showParkedIdeas else { return }
        guard let fromIndex = tripDays.firstIndex(where: { $0.id == day.id }) else { return }
        tripDays[fromIndex].flights.removeAll { $0.id == flight.id }
        
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        let dep = f.string(from: flight.startTime)
        let arr = flight.hasEndTime ? f.string(from: flight.endTime) : ""
        let time = arr.isEmpty ? dep : "\(dep) - \(arr)"
        
        let loc = travelRouteText(for: flight)
        let title = travelListTitle(for: flight)
        
        let parked = EventItem(
            id: UUID(),
            title: title,
            description: flight.notes,
            time: time,
            location: loc,
            latitude: nil,
            longitude: nil,
            icon: flight.travelMode.systemImageName,
            accent: .neutral,
            photoData: nil,
            documents: flight.documents
        )
        parkedIdeas.insert(parked, at: 0)
    }
    
    func moveParkedIdeaLeftToLastDay(_ event: EventItem) {
        guard let last = tripDays.last else { return }
        parkedIdeas.removeAll { $0.id == event.id }
        if let idx = tripDays.firstIndex(where: { $0.id == last.id }) {
            tripDays[idx].events.append(event)
        }
    }
}


enum WeatherPillMode: Int, CaseIterable {
    case conditions
    case sunrise
    case sunset
}

struct WeatherPill: View {
    @Binding var mode: WeatherPillMode
    let fallbackIcon: String
    let fallbackTempF: Int
    let dayDate: Date
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }
    
    private var sunrise: Date? {
        Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: dayDate)
    }
    
    private var sunset: Date? {
        Calendar.current.date(bySettingHour: 19, minute: 45, second: 0, of: dayDate)
    }
    
    var body: some View {
        Group {
            switch mode {
            case .conditions:
                HStack(spacing: 6) {
                    Image(systemName: fallbackIcon)
                        .font(.appCaption)
                    Text("\(fallbackTempF)°F")
                        .font(.app(12, weight: .semibold))
                }
            case .sunrise:
                HStack(spacing: 6) {
                    Image(systemName: "sunrise.fill")
                        .font(.appCaption)
                    Text(sunrise.map { timeFormatter.string(from: $0) } ?? "—")
                        .font(.app(12, weight: .semibold))
                }
            case .sunset:
                HStack(spacing: 6) {
                    Image(systemName: "sunset.fill")
                        .font(.appCaption)
                    Text(sunset.map { timeFormatter.string(from: $0) } ?? "—")
                        .font(.app(12, weight: .semibold))
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            switch mode {
            case .conditions: mode = .sunrise
            case .sunrise: mode = .sunset
            case .sunset: mode = .conditions
            }
        }
    }
}



struct EventDetailView: View {
    let event: EventItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [event.accentColor.opacity(0.35), event.accentColor.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    VStack(alignment: .leading, spacing: 10) {
                        Text(event.title)
                            .font(.app(22, weight: .semibold))
                        Text(event.location)
                            .font(.appSubheadline)
                            .foregroundStyle(.secondary)
                        Text(event.time)
                            .font(.appHeadline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 180)

                VStack(alignment: .leading, spacing: 10) {
                    Label(event.location, systemImage: "mappin.and.ellipse")
                    Label(event.time, systemImage: "clock")
                }
                .font(.appHeadline)

                if !event.description.isEmpty {
                    Text(event.description)
                        .font(.appBody)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .background(
            LinearGradient(colors: [.white, Color(.systemGray6)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}

struct IconCarousel: View {
    let items: [String]
    @Binding var selection: String
    var accentColor: Color = .accentColor

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items, id: \.self) { icon in
                    Button {
                        selection = icon
                    } label: {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selection == icon ? accentColor.opacity(0.2) : Color(.systemGray5))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: icon)
                                    .font(.app(18, weight: .regular))
                                    .foregroundStyle(selection == icon ? accentColor : .secondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(selection == icon ? accentColor : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
            // Prevent selection stroke from clipping at edges.
            .padding(.horizontal, 2)
        }
    }
}

struct ColorChips: View {
    @Binding var selection: EventAccent

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(EventAccent.allCases.reversed()), id: \.self) { accent in
                    Button {
                        selection = accent
                    } label: {
                        Circle()
                            .fill(accent.color)
                            .frame(width: 40, height: 40)
                            .padding(2)
                            .overlay(
                                Circle()
                                    .stroke(selection == accent ? Color.primary : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
            // Prevent selection ring from clipping at edges.
            .padding(.horizontal, 2)
        }
    }
}

struct FloatingAddButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle()
                            .fill(.white.opacity(0.1))
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                    }
                
                Image(systemName: "plus")
                    .font(.app(22, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
        .contentShape(Circle())
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(sourceType) ? sourceType : .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
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


struct EventAnnotation: Identifiable {
    let id: UUID
    let dayID: UUID
    let coordinate: CLLocationCoordinate2D
    let event: EventItem
    let color: Color
}

// (Map clustering removed)

enum EventDocumentSource: String, Codable, Hashable {
    case files
    case photoLibrary
}

struct EventDocument: Identifiable, Hashable, Codable {
    let id: UUID
    var fileName: String
    var fileExtension: String
    var mimeType: String?
    var localRelativePath: String
    var source: EventDocumentSource
    var createdAt: Date
    var thumbnailData: Data?
    
    init(
        id: UUID = UUID(),
        fileName: String,
        fileExtension: String = "",
        mimeType: String? = nil,
        localRelativePath: String,
        source: EventDocumentSource,
        createdAt: Date = Date(),
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.mimeType = mimeType
        self.localRelativePath = localRelativePath
        self.source = source
        self.createdAt = createdAt
        self.thumbnailData = thumbnailData
    }
}

struct EventItem: Identifiable, Hashable, Codable, Transferable {
    let id: UUID
    var title: String
    var description: String
    var time: String
    var location: String
    var latitude: Double?
    var longitude: Double?
    var icon: String
    var accent: EventAccent
    var photoData: Data?
    var documents: [EventDocument] = []
    var rating: Int = 0
    var cost: Double? = nil
    var costCurrencyCode: String? = nil

    var accentColor: Color { accent.color }
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, time, location, latitude, longitude, icon, accent, photoData, documents, rating, cost, costCurrencyCode
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        time: String,
        location: String,
        latitude: Double?,
        longitude: Double?,
        icon: String,
        accent: EventAccent,
        photoData: Data?,
        documents: [EventDocument] = [],
        rating: Int = 0,
        cost: Double? = nil,
        costCurrencyCode: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.time = time
        self.location = location
        self.latitude = latitude
        self.longitude = longitude
        self.icon = icon
        self.accent = accent
        self.photoData = photoData
        self.documents = documents
        self.rating = rating
        self.cost = cost
        self.costCurrencyCode = costCurrencyCode
    }
    
    /// Has a location string but no coordinates yet — needs MapKit geocode for map pins.
    var needsMapGeocode: Bool {
        !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (latitude == nil || longitude == nil)
    }
    
    var startTimeMinutes: Int {
        let normalized = time.replacingOccurrences(of: "–", with: "-")
        let startText = normalized
            .split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        let short = DateFormatter()
        short.dateStyle = .none
        short.timeStyle = .short
        if let date = short.date(from: startText) {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
            return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        }
        
        let hhmm = DateFormatter()
        hhmm.dateFormat = "HH:mm"
        if let date = hhmm.date(from: startText) {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
            return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        }
        
        return 0
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .eventItem)
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decode(String.self, forKey: .description)
        time = try c.decode(String.self, forKey: .time)
        location = try c.decode(String.self, forKey: .location)
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        icon = try c.decode(String.self, forKey: .icon)
        accent = try c.decode(EventAccent.self, forKey: .accent)
        photoData = try c.decodeIfPresent(Data.self, forKey: .photoData)
        documents = try c.decodeIfPresent([EventDocument].self, forKey: .documents) ?? []
        rating = try c.decodeIfPresent(Int.self, forKey: .rating) ?? 0
        cost = try c.decodeIfPresent(Double.self, forKey: .cost)
        costCurrencyCode = try c.decodeIfPresent(String.self, forKey: .costCurrencyCode)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(description, forKey: .description)
        try c.encode(time, forKey: .time)
        try c.encode(location, forKey: .location)
        try c.encode(latitude, forKey: .latitude)
        try c.encode(longitude, forKey: .longitude)
        try c.encode(icon, forKey: .icon)
        try c.encode(accent, forKey: .accent)
        try c.encode(photoData, forKey: .photoData)
        try c.encode(documents, forKey: .documents)
        try c.encode(rating, forKey: .rating)
        try c.encode(cost, forKey: .cost)
        try c.encode(costCurrencyCode, forKey: .costCurrencyCode)
    }
}

struct TripDay: Identifiable, Hashable, Codable {
    let id: UUID
    let date: Date
    var events: [EventItem]
    var reminders: [ReminderItem]
    var checklists: [ChecklistItem]
    var flights: [FlightItem]
    let label: String
    let order: Int
    let weatherIcon: String
    let temperatureF: Int

    var displayTitle: String {
        Self.displayFormatter.string(from: date)
    }

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    var displaySubtitle: String {
        label
    }

    var dayBadge: String { "Day \(order)" }
    
    enum CodingKeys: String, CodingKey {
        case id, date, events, reminders, checklists, flights, label, order, weatherIcon, temperatureF
    }
    
    init(id: UUID, date: Date, events: [EventItem], reminders: [ReminderItem] = [], checklists: [ChecklistItem] = [], flights: [FlightItem] = [], label: String, order: Int, weatherIcon: String, temperatureF: Int) {
        self.id = id
        self.date = date
        self.events = events
        self.reminders = reminders
        self.checklists = checklists
        self.flights = flights
        self.label = label
        self.order = order
        self.weatherIcon = weatherIcon
        self.temperatureF = temperatureF
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        events = try c.decode([EventItem].self, forKey: .events)
        reminders = try c.decodeIfPresent([ReminderItem].self, forKey: .reminders) ?? []
        checklists = try c.decodeIfPresent([ChecklistItem].self, forKey: .checklists) ?? []
        flights = try c.decodeIfPresent([FlightItem].self, forKey: .flights) ?? []
        label = try c.decode(String.self, forKey: .label)
        order = try c.decode(Int.self, forKey: .order)
        weatherIcon = try c.decode(String.self, forKey: .weatherIcon)
        temperatureF = try c.decode(Int.self, forKey: .temperatureF)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(date, forKey: .date)
        try c.encode(events, forKey: .events)
        try c.encode(reminders, forKey: .reminders)
        try c.encode(checklists, forKey: .checklists)
        try c.encode(flights, forKey: .flights)
        try c.encode(label, forKey: .label)
        try c.encode(order, forKey: .order)
        try c.encode(weatherIcon, forKey: .weatherIcon)
        try c.encode(temperatureF, forKey: .temperatureF)
    }
}

struct ReminderItem: Identifiable, Hashable, Codable {
    let id: UUID
    var text: String
    var createdAt: Date
}

struct ChecklistItem: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var items: [ChecklistEntry]
    var createdAt: Date
}

struct ChecklistEntry: Identifiable, Hashable, Codable {
    let id: UUID
    var text: String
    var isDone: Bool
}

struct FlightItem: Identifiable, Hashable, Codable {
    let id: UUID
    
    var fromName: String
    var fromCode: String
    var fromCity: String
    var fromLatitude: Double?
    var fromLongitude: Double?
    var fromTerminal: String
    var fromGate: String
    
    var toName: String
    var toCode: String
    var toCity: String
    var toLatitude: Double?
    var toLongitude: Double?
    var toTerminal: String
    var toGate: String
    
    var travelMode: TravelMode
    var flightNumber: String
    var notes: String
    var documents: [EventDocument] = []
    var accent: EventAccent
    var startTime: Date
    var endTime: Date
    var cost: Double? = nil
    var costCurrencyCode: String? = nil
    
    var hasEndTime: Bool { endTime > startTime }
    
    enum CodingKeys: String, CodingKey {
        case id
        case fromName, fromCode, fromCity, fromLatitude, fromLongitude, fromTerminal, fromGate
        case toName, toCode, toCity, toLatitude, toLongitude, toTerminal, toGate
        case travelMode, flightNumber, notes, documents, accent, startTime, endTime, cost, costCurrencyCode
    }
    
    init(
        id: UUID = UUID(),
        fromName: String = "",
        fromCode: String = "",
        fromCity: String = "",
        fromLatitude: Double? = nil,
        fromLongitude: Double? = nil,
        fromTerminal: String = "",
        fromGate: String = "",
        toName: String = "",
        toCode: String = "",
        toCity: String = "",
        toLatitude: Double? = nil,
        toLongitude: Double? = nil,
        toTerminal: String = "",
        toGate: String = "",
        travelMode: TravelMode = .flight,
        flightNumber: String = "",
        notes: String = "",
        documents: [EventDocument] = [],
        accent: EventAccent = .neutral,
        startTime: Date = Date(),
        endTime: Date = Date(),
        cost: Double? = nil,
        costCurrencyCode: String? = nil
    ) {
        self.id = id
        self.fromName = fromName
        self.fromCode = fromCode
        self.fromCity = fromCity
        self.fromLatitude = fromLatitude
        self.fromLongitude = fromLongitude
        self.fromTerminal = fromTerminal
        self.fromGate = fromGate
        self.toName = toName
        self.toCode = toCode
        self.toCity = toCity
        self.toLatitude = toLatitude
        self.toLongitude = toLongitude
        self.toTerminal = toTerminal
        self.toGate = toGate
        self.travelMode = travelMode
        self.flightNumber = flightNumber
        self.notes = notes
        self.documents = documents
        self.accent = accent
        self.startTime = startTime
        self.endTime = endTime
        self.cost = cost
        self.costCurrencyCode = costCurrencyCode
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        
        fromName = try c.decode(String.self, forKey: .fromName)
        fromCode = try c.decode(String.self, forKey: .fromCode)
        fromCity = try c.decode(String.self, forKey: .fromCity)
        fromLatitude = try c.decodeIfPresent(Double.self, forKey: .fromLatitude)
        fromLongitude = try c.decodeIfPresent(Double.self, forKey: .fromLongitude)
        fromTerminal = try c.decodeIfPresent(String.self, forKey: .fromTerminal) ?? ""
        fromGate = try c.decodeIfPresent(String.self, forKey: .fromGate) ?? ""
        
        toName = try c.decode(String.self, forKey: .toName)
        toCode = try c.decode(String.self, forKey: .toCode)
        toCity = try c.decode(String.self, forKey: .toCity)
        toLatitude = try c.decodeIfPresent(Double.self, forKey: .toLatitude)
        toLongitude = try c.decodeIfPresent(Double.self, forKey: .toLongitude)
        toTerminal = try c.decodeIfPresent(String.self, forKey: .toTerminal) ?? ""
        toGate = try c.decodeIfPresent(String.self, forKey: .toGate) ?? ""
        
        travelMode = try c.decodeIfPresent(TravelMode.self, forKey: .travelMode) ?? .flight
        flightNumber = try c.decode(String.self, forKey: .flightNumber)
        notes = try c.decode(String.self, forKey: .notes)
        documents = try c.decodeIfPresent([EventDocument].self, forKey: .documents) ?? []
        accent = try c.decode(EventAccent.self, forKey: .accent)
        startTime = try c.decode(Date.self, forKey: .startTime)
        endTime = try c.decode(Date.self, forKey: .endTime)
        cost = try c.decodeIfPresent(Double.self, forKey: .cost)
        costCurrencyCode = try c.decodeIfPresent(String.self, forKey: .costCurrencyCode)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        
        try c.encode(fromName, forKey: .fromName)
        try c.encode(fromCode, forKey: .fromCode)
        try c.encode(fromCity, forKey: .fromCity)
        try c.encode(fromLatitude, forKey: .fromLatitude)
        try c.encode(fromLongitude, forKey: .fromLongitude)
        try c.encode(fromTerminal, forKey: .fromTerminal)
        try c.encode(fromGate, forKey: .fromGate)
        
        try c.encode(toName, forKey: .toName)
        try c.encode(toCode, forKey: .toCode)
        try c.encode(toCity, forKey: .toCity)
        try c.encode(toLatitude, forKey: .toLatitude)
        try c.encode(toLongitude, forKey: .toLongitude)
        try c.encode(toTerminal, forKey: .toTerminal)
        try c.encode(toGate, forKey: .toGate)
        
        try c.encode(travelMode, forKey: .travelMode)
        try c.encode(flightNumber, forKey: .flightNumber)
        try c.encode(notes, forKey: .notes)
        try c.encode(documents, forKey: .documents)
        try c.encode(accent, forKey: .accent)
        try c.encode(startTime, forKey: .startTime)
        try c.encode(endTime, forKey: .endTime)
        try c.encode(cost, forKey: .cost)
        try c.encode(costCurrencyCode, forKey: .costCurrencyCode)
    }
}

enum TravelMode: String, Codable, CaseIterable, Hashable {
    case flight
    case drive
    case train
    case walk
    
    var title: String {
        switch self {
        case .flight: return "Flight"
        case .drive: return "Drive"
        case .train: return "Train"
        case .walk: return "Walk"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .flight: return "airplane"
        case .drive: return "car.fill"
        case .train: return "train.side.front.car"
        case .walk: return "figure.walk"
        }
    }
    
    /// Map endpoint icons — flights use departure at origin and arrival at destination.
    func mapEndpointSystemImage(isOrigin: Bool) -> String {
        switch self {
        case .flight:
            return isOrigin ? "airplane.departure" : "airplane.arrival"
        case .drive, .train, .walk:
            return systemImageName
        }
    }
}

enum EventAccent: String, Codable, CaseIterable, Hashable {
    case neutral
    case blue
    case mint
    case yellow
    case orange
    case red
    case purple

    var color: Color {
        switch self {
        case .neutral: return Color(hex: 0x7A7A7A)
        case .blue: return Color(hex: 0x4DA1F7)
        case .mint: return Color(hex: 0x7AE3A9)
        case .yellow: return Color(hex: 0xFFC63B)
        case .orange: return Color(hex: 0xFF7640)
        case .red: return Color(hex: 0xE63B3B)
        case .purple: return Color(hex: 0xAD8DF0)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        
        if let v = EventAccent(rawValue: raw) {
            self = v
            return
        }
        
        switch raw {
        case "sand":
            self = .neutral
        case "gold":
            self = .yellow
        case "burntOrange":
            self = .orange
        case "forest":
            self = .mint
        case "deepNavy":
            self = .blue
        case "sky":
            self = .blue
        case "lavender":
            self = .purple
        case "yellow":
            self = .yellow
        case "orange", "amber":
            self = .orange
        case "mint", "teal", "cyan", "lime":
            self = .mint
        case "green":
            self = .mint
        case "blue":
            self = .blue
        case "indigo", "purple", "violet", "pink", "coral", "red":
            self = .purple
        default:
            self = .neutral
        }
    }
}


private extension UTType {
    static let eventItem = UTType.data
}

#Preview {
    NavigationStack {
        TripDetailView(trip: .constant(Trip.sampleTrips[0]))
    }
    .environment(PlaceStore())
    .environment(RootTabChrome())
}

