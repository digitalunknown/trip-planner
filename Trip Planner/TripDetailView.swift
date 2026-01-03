//
//  TripDetailView.swift
//  Trip Planner
//
//  Created by Piotr Osmenda on 12/16/25.
//

import SwiftUI
import MapKit
import UniformTypeIdentifiers
import Combine
import UIKit

// Enable swipe-back gesture when back button is hidden
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
    
    @State private var tripDays: [TripDay] = []
    @State private var isPresentingSettings: Bool = false
    @State private var isPresentingAdd: Bool = false
    @State private var splitRatio: CGFloat = 0.45 // Map takes 45% by default
    @State private var newEventTitle: String = ""
    @State private var newEventLocation: String = ""
    @State private var newEventLatitude: Double?
    @State private var newEventLongitude: Double?
    @State private var newEventDescription: String = ""
    @State private var newEventIcon: String = "mappin.and.ellipse"
    @State private var newEventAccent: EventAccent = .sky
    @State private var newEventStart: Date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(9 * 3600)
    @State private var newEventEnd: Date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(10 * 3600)
    @State private var newEventPhoto: UIImage?
    @State private var selectedDayID: UUID?
    @State private var editingEvent: EventItem?
    @State private var mapPosition: MapCameraPosition
    @State private var showMap = false
    
    @State private var isPresentingReminder = false
    @State private var newReminderText: String = ""
    @State private var editingReminder: ReminderItem?
    
    // Parked Ideas
    @State private var parkedIdeas: [EventItem] = []
    
    @State private var isPresentingChecklist = false
    @State private var editingChecklist: ChecklistItem?
    @State private var checklistTitle: String = ""
    @State private var checklistDraftItems: [ChecklistEntry] = []

    @State private var isPresentingFlight = false
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
    @State private var flightNumber: String = ""
    @State private var flightNotes: String = ""
    @State private var flightAccent: EventAccent = .sky
    @State private var flightStartTime: Date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(9 * 3600)
    @State private var flightEndTime: Date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(9 * 3600)
    
    @State private var isEdgeSwipingBack: Bool = false
    
    // Day-column focus tracking (for map focus behavior)
    @State private var focusedDayID: UUID?
    @State private var hasUserScrolledDays: Bool = false
    @State private var displayedDayIDForMarkers: UUID?
    @State private var markersOpacity: Double = 1.0
    @State private var pendingMarkerTransition: DispatchWorkItem?
    
    private static let parkedIdeasColumnID = UUID(uuidString: "00000000-0000-0000-0000-000000000999")!
    
    private var dayOptions: [DayOption] {
        var opts = tripDays.map { DayOption(id: $0.id, title: $0.displayTitle, isParkedIdeas: false) }
        if trip.showParkedIdeas {
            opts.append(DayOption(id: Self.parkedIdeasColumnID, title: "Parked Ideas", isParkedIdeas: true))
        }
        return opts
    }
    
    init(trip: Binding<Trip>) {
        self._trip = trip
        // Initialize map region directly from trip data to avoid jump
        let initialRegion: MKCoordinateRegion
        if let lat = trip.wrappedValue.latitude, let lon = trip.wrappedValue.longitude {
            let span = trip.wrappedValue.mapSpan ?? 0.1
            initialRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            )
        } else {
            // Default world view
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
                // No location text or missing coords => no map item
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
    
    var appropriateMapRegion: MKCoordinateRegion {
        // If we have markers, default the map to fit them (more useful than a generic destination zoom).
        if !eventAnnotations.isEmpty {
            let coordinates = eventAnnotations.map { $0.coordinate }
            let minLat = coordinates.map { $0.latitude }.min() ?? 0
            let maxLat = coordinates.map { $0.latitude }.max() ?? 0
            let minLon = coordinates.map { $0.longitude }.min() ?? 0
            let maxLon = coordinates.map { $0.longitude }.max() ?? 0
            
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            
            // Tighter padding than before to reduce overlap.
            // Also allow a smaller minimum span for city-level clusters.
            let latSpread = maxLat - minLat
            let lonSpread = maxLon - minLon
            // Slightly more padding so clusters aren’t tight/overlapping.
            let padding: Double = 1.25
            let span = MKCoordinateSpan(
                latitudeDelta: max(latSpread * padding, 0.012),
                longitudeDelta: max(lonSpread * padding, 0.012)
            )
            return MKCoordinateRegion(center: center, span: span)
        } else if let lat = trip.latitude, let lon = trip.longitude {
            // Use the stored mapSpan from location search, or default to city level
            let span = trip.mapSpan ?? 0.1
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            )
        } else {
            // Default world view
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 120)
            )
        }
    }
    
    private func annotations(for dayID: UUID) -> [EventAnnotation] {
        eventAnnotations.filter { $0.dayID == dayID }
    }
    
    private func regionFitting(_ annotations: [EventAnnotation]) -> MKCoordinateRegion? {
        guard !annotations.isEmpty else { return nil }
        let coordinates = annotations.map { $0.coordinate }
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLon = coordinates.map { $0.longitude }.min() ?? 0
        let maxLon = coordinates.map { $0.longitude }.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let latSpread = maxLat - minLat
        let lonSpread = maxLon - minLon
        // Slightly more padding so clusters aren’t tight/overlapping.
        let padding: Double = 1.25
        let span = MKCoordinateSpan(
            latitudeDelta: max(latSpread * padding, 0.012),
            longitudeDelta: max(lonSpread * padding, 0.012)
        )
        return MKCoordinateRegion(center: center, span: span)
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
            ForEach(visibleAnnotations) { annotation in
                Annotation("", coordinate: annotation.coordinate, anchor: .center) {
                    Button {
                        openEventFromMarker(annotation.event)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(annotation.color)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(.white.opacity(0.9), lineWidth: 1.5)
                                )
                            Image(systemName: annotation.event.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    }
                    .opacity(markersOpacity)
                }
            }
        }
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
                        splitRatio = min(max(newRatio, 0.2), 0.8)
                    }
            )
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
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            // Force non-accent toolbar color even when TabView tint is customized.
            .tint(.primary)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                isPresentingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .tint(.primary)
            
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
                    isPresentingAdd = true
                } label: {
                    Label("Activity", systemImage: "calendar.badge.plus")
                }
                
                Button {
                    let focusedDayCandidate = tripDays.first(where: { $0.id == focusedDayID })?.id
                    selectedDayID = focusedDayCandidate ?? tripDays.first(where: { Calendar.current.isDateInToday($0.date) })?.id ?? tripDays.first?.id
                    prepareNewFlightDefaults()
                    isPresentingFlight = true
                } label: {
                    Label("Flight", systemImage: "airplane")
                }
                
                Button {
                    let focusedDayCandidate = tripDays.first(where: { $0.id == focusedDayID })?.id
                    selectedDayID = focusedDayCandidate ?? tripDays.first(where: { Calendar.current.isDateInToday($0.date) })?.id ?? tripDays.first?.id
                    newReminderText = ""
                    editingReminder = nil
                    isPresentingReminder = true
                } label: {
                    Label("Reminder", systemImage: "pin.fill")
                }
                
                Button {
                    let focusedDayCandidate = tripDays.first(where: { $0.id == focusedDayID })?.id
                    selectedDayID = focusedDayCandidate ?? tripDays.first(where: { Calendar.current.isDateInToday($0.date) })?.id ?? tripDays.first?.id
                    checklistTitle = ""
                    checklistDraftItems = []
                    editingChecklist = nil
                    isPresentingChecklist = true
                } label: {
                    Label("Checklist", systemImage: "checklist.checked")
                }
            } label: {
                Image(systemName: "plus")
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .tint(.primary)
        }
        ToolbarItem(placement: .principal) {
            VStack(spacing: 2) {
                Text(tripName)
                    .font(.headline.weight(.semibold))
                Text(tripDateRangeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var eventSheetTripRegion: MKCoordinateRegion? {
        guard let lat = trip.latitude, let lon = trip.longitude else { return nil }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
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
                    coverImageData: $trip.coverImageData,
                    showParkedIdeas: $trip.showParkedIdeas,
                    onApply: updateTripDaysForDates
                )
                .tint(.primary)
            }
            .sheet(isPresented: $isPresentingAdd, onDismiss: {
                editingEvent = nil
            }) {
                AddEventSheet(
                    title: $newEventTitle,
                    location: $newEventLocation,
                    latitude: $newEventLatitude,
                    longitude: $newEventLongitude,
                    description: $newEventDescription,
                    icon: $newEventIcon,
                    accent: $newEventAccent,
                    startTime: $newEventStart,
                    endTime: $newEventEnd,
                    photo: $newEventPhoto,
                    selectedDayID: $selectedDayID,
                    dayOptions: dayOptions,
                    tripLocationRegion: eventSheetTripRegion,
                    onAdd: addNewEvent,
                    onDelete: deleteCurrentEvent,
                    isEditing: editingEvent != nil
                )
                .tint(.primary)
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $isPresentingReminder) {
                AddReminderSheet(
                    reminderText: $newReminderText,
                    selectedDayID: $selectedDayID,
                    dayOptions: dayOptions,
                    isEditing: editingReminder != nil,
                    onAdd: addReminder
                )
                .tint(.primary)
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $isPresentingChecklist) {
                ChecklistSheet(
                    title: $checklistTitle,
                    items: $checklistDraftItems,
                    selectedDayID: $selectedDayID,
                    dayOptions: dayOptions,
                    isEditing: editingChecklist != nil,
                    onSave: saveChecklist
                )
                .tint(.primary)
                .presentationDetents([.large])
            }
            .sheet(isPresented: $isPresentingFlight, onDismiss: {
                editingFlight = nil
            }) {
                let deleteHandler: (() -> Void)? = (editingFlight != nil) ? { deleteCurrentFlight() } : nil
                AddFlightSheet(
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
                    flightNumber: $flightNumber,
                    notes: $flightNotes,
                    accent: $flightAccent,
                    startTime: $flightStartTime,
                    endTime: $flightEndTime,
                    selectedDayID: $selectedDayID,
                    dayOptions: dayOptions,
                    isEditing: editingFlight != nil,
                    onSave: saveFlight,
                    onDelete: deleteHandler
                )
                .tint(.primary)
                .presentationDetents([.medium, .large])
            }
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
            .simultaneousGesture(edgeSwipeGesture)
            .toolbar { tripDetailToolbar }
        .onChange(of: isPresentingReminder) { _, isPresented in
            if !isPresented {
                editingReminder = nil
                newReminderText = ""
            }
        }
        .onChange(of: isPresentingChecklist) { _, isPresented in
            if !isPresented {
                editingChecklist = nil
                checklistTitle = ""
                checklistDraftItems = []
            }
        }
        .onAppear {
            initializeTripDays()
            // Prefer fitting markers if any exist.
            setMapRegion(appropriateMapRegion, animated: false)
            // Initial load: show markers across all days.
            displayedDayIDForMarkers = nil
            markersOpacity = 1.0
            // Fade the map in after first layout pass to avoid visible “jump”.
            showMap = false
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showMap = true
                }
            }
        }
        .onChange(of: trip.latitude) { _, _ in
            // Avoid animating region changes during initial load; Map’s own update is smoother.
            setMapRegion(appropriateMapRegion, animated: false)
        }
        .onChange(of: trip.longitude) { _, _ in
            setMapRegion(appropriateMapRegion, animated: false)
        }
        .onChange(of: trip.mapSpan) { _, _ in
            setMapRegion(appropriateMapRegion, animated: false)
        }
        .onChange(of: focusedDayID) { _, newValue in
            guard hasUserScrolledDays else { return }
            
            let targetDayID: UUID? = {
                guard let dayID = newValue else { return nil }
                return annotations(for: dayID).isEmpty ? nil : dayID
            }()
            
            // Cross-fade markers when switching days.
            pendingMarkerTransition?.cancel()
            withAnimation(.easeInOut(duration: 0.18)) {
                markersOpacity = 0.0
            }
            let work = DispatchWorkItem {
                displayedDayIDForMarkers = targetDayID
                withAnimation(.easeInOut(duration: 0.18)) {
                    markersOpacity = 1.0
                }
            }
            pendingMarkerTransition = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
            
            // Update map region.
            if let dayID = targetDayID, let region = regionFitting(annotations(for: dayID)) {
                setMapRegion(region, animated: true, duration: 0.25)
            } else {
                setMapRegion(appropriateMapRegion, animated: false)
            }
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

private extension DayColumn {
    var dayBackground: Color {
        Color(.secondarySystemBackground).opacity(0.7)
    }
}

// MARK: - Layout

private extension TripDetailView {
    var backgroundGradient: some View {
        Color(.systemBackground).ignoresSafeArea()
    }

    func kanbanBoard() -> some View {
        GeometryReader { geo in
            let columnWidth = geo.size.width * 0.78
            let tripHasNoItems = tripDays.allSatisfy { $0.events.isEmpty && $0.reminders.isEmpty && $0.checklists.isEmpty && $0.flights.isEmpty }
            let viewport = CGRect(x: 0, y: 0, width: geo.size.width, height: geo.size.height)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(Array(tripDays.enumerated()), id: \.element.id) { index, day in
                        DayColumn(
                            day: day,
                            totalDays: tripDays.count,
                            columnWidth: columnWidth,
                            columnHeight: geo.size.height - 24,
                            onTap: { event in startEditing(event: event, day: day) },
                            onEdit: { event in startEditing(event: event, day: day) },
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
                            onAddEvent: {
                                selectedDayID = day.id
                                prepareNewEventDefaults()
                                isPresentingAdd = true
                            },
                            showEmptyPlaceholder: index == 0 && tripHasNoItems
                        )
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
                            onDelete: { event in deleteEvent(event) },
                            onAdd: {
                                editingEvent = nil
                                selectedDayID = Self.parkedIdeasColumnID
                                prepareNewEventDefaults()
                                isPresentingAdd = true
                            },
                            onMoveLeftToLastDay: (tripDays.count > 0) ? { event in moveParkedIdeaLeftToLastDay(event) } : nil
                        )
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
            .onPreferenceChange(DayColumnFramesPreferenceKey.self) { framesByID in
                guard hasUserScrolledDays else { return }
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

private struct DayColumnFramesPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - Helpers

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
        // Always normalize against current trip start/end to avoid stale ordering/labels.
        tripDays = trip.days
        parkedIdeas = trip.parkedIdeas
        updateTripDaysForDates()
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
        newEventAccent = .sky
        newEventPhoto = nil
        let base = Calendar.current.startOfDay(for: Date())
        newEventStart = base.addingTimeInterval(9 * 3600)
        // Default new activities to "no end time"
        newEventEnd = newEventStart
    }

    func addNewEvent() {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let hasEndTime = abs(newEventEnd.timeIntervalSince(newEventStart)) >= 60
        let timeText = hasEndTime
            ? "\(formatter.string(from: newEventStart)) – \(formatter.string(from: newEventEnd))"
            : "\(formatter.string(from: newEventStart))"
        
        let photoData = newEventPhoto?.jpegData(compressionQuality: 0.8)

        if let editingEvent {
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
                photoData: photoData
            )
            
            // Remove existing instances (by id) across days and parked ideas, then re-insert once.
            for idx in tripDays.indices {
                tripDays[idx].events.removeAll { $0.id == editingEvent.id }
            }
            parkedIdeas.removeAll { $0.id == editingEvent.id }

            if selectedDayID == Self.parkedIdeasColumnID {
                parkedIdeas.insert(updated, at: 0)
                self.editingEvent = updated
                return
            }
            
            guard let dayID = selectedDayID,
                  let dayIndex = tripDays.firstIndex(where: { $0.id == dayID }) else { return }
            tripDays[dayIndex].events.append(updated)
            self.editingEvent = updated
            return
        }
        
        // Create (single destination).
        guard let targetID = selectedDayID else { return }
        
        let event = EventItem(
            id: UUID(),
            title: newEventTitle.isEmpty ? "Untitled" : newEventTitle,
            description: newEventDescription,
            time: timeText,
            location: newEventLocation,
            latitude: newEventLatitude,
            longitude: newEventLongitude,
            icon: newEventIcon,
            accent: newEventAccent,
            photoData: photoData
        )
        
        if targetID == Self.parkedIdeasColumnID {
            parkedIdeas.insert(event, at: 0)
        } else if let idx = tripDays.firstIndex(where: { $0.id == targetID }) {
            tripDays[idx].events.append(event)
        }
        
        if let lat = newEventLatitude, let lon = newEventLongitude {
            withAnimation {
                setMapRegion(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ), animated: false)
            }
        }
    }
    
    func addReminder() {
        let trimmed = newReminderText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if let editingReminder {
            // Remove existing instances by id across all days, then insert once.
            for idx in tripDays.indices {
                tripDays[idx].reminders.removeAll { $0.id == editingReminder.id }
            }
            let updated = ReminderItem(id: editingReminder.id, text: trimmed, createdAt: editingReminder.createdAt)
            
            if selectedDayID == Self.parkedIdeasColumnID {
                // Convert to parked idea
                let parked = EventItem(
                    id: UUID(),
                    title: trimmed,
                    description: "",
                    time: "",
                    location: "",
                    latitude: nil,
                    longitude: nil,
                    icon: "pin.fill",
                    accent: .sand,
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
                    accent: .sand,
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
            // Remove existing instances by id across all days, then re-insert once.
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
                    accent: .gold,
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
                    accent: .gold,
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
        isPresentingChecklist = true
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
        isPresentingReminder = true
    }
    
    func deleteReminder(_ reminder: ReminderItem) {
        for idx in tripDays.indices {
            tripDays[idx].reminders.removeAll { $0.id == reminder.id }
        }
    }

    func startEditing(event: EventItem, day: TripDay) {
        editingEvent = event
        selectedDayID = day.id
        newEventTitle = event.title
        newEventLocation = event.location
        newEventLatitude = event.latitude
        newEventLongitude = event.longitude
        newEventDescription = event.description
        newEventIcon = event.icon
        newEventAccent = event.accent
        
        if let photoData = event.photoData {
            newEventPhoto = UIImage(data: photoData)
        } else {
            newEventPhoto = nil
        }

        // Parse either "start – end" or "start" (no end time)
        let parts = event.time.split(separator: "–").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
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
        
        // Move map to event location if available
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
        
        isPresentingAdd = true
    }
    
    func startEditingParkedIdea(_ event: EventItem) {
        editingEvent = event
        selectedDayID = Self.parkedIdeasColumnID
        newEventTitle = event.title
        newEventLocation = event.location
        newEventLatitude = event.latitude
        newEventLongitude = event.longitude
        newEventDescription = event.description
        newEventIcon = event.icon
        newEventAccent = event.accent
        
        if let photoData = event.photoData {
            newEventPhoto = UIImage(data: photoData)
        } else {
            newEventPhoto = nil
        }
        
        // Parse either "start – end" or "start" (no end time)
        let parts = event.time.split(separator: "–").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
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
        
        isPresentingAdd = true
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
    
    func deleteCurrentEvent() {
        guard let event = editingEvent else { return }
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

    func prepareNewFlightDefaults() {
        if selectedDayID == nil {
            selectedDayID = tripDays.first?.id
        }
        editingFlight = nil
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
        flightAccent = .sky
        let base = Calendar.current.startOfDay(for: Date())
        flightStartTime = base.addingTimeInterval(9 * 3600)
        flightEndTime = flightStartTime
    }

    func saveFlight() {
        if let editingFlight {
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
                flightNumber: flightNumber,
                notes: flightNotes,
                accent: flightAccent,
                startTime: flightStartTime,
                endTime: flightEndTime
            )
            
            // Remove existing instance (by id) across all days.
            for idx in tripDays.indices {
                tripDays[idx].flights.removeAll { $0.id == editingFlight.id }
            }
            
            if selectedDayID == Self.parkedIdeasColumnID {
                // Convert to parked idea
                let f = DateFormatter()
                f.dateStyle = .none
                f.timeStyle = .short
                let dep = f.string(from: updated.startTime)
                let arr = updated.hasEndTime ? f.string(from: updated.endTime) : ""
                let time = arr.isEmpty ? dep : "\(dep) – \(arr)"
                
                let from = updated.fromCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                let to = updated.toCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                let loc = (!from.isEmpty && !to.isEmpty) ? "\(from) → \(to)" : ""
                let title = updated.flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Flight" : updated.flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                
                let parked = EventItem(
                    id: UUID(),
                    title: title,
                    description: updated.notes,
                    time: time,
                    location: loc,
                    latitude: nil,
                    longitude: nil,
                    icon: "airplane",
                    accent: updated.accent,
                    photoData: nil
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
                flightNumber: flightNumber,
                notes: flightNotes,
                accent: flightAccent,
                startTime: flightStartTime,
                endTime: flightEndTime
            )
            
            if selectedDayID == Self.parkedIdeasColumnID {
                // Convert to parked idea
                let f = DateFormatter()
                f.dateStyle = .none
                f.timeStyle = .short
                let dep = f.string(from: flight.startTime)
                let arr = flight.hasEndTime ? f.string(from: flight.endTime) : ""
                let time = arr.isEmpty ? dep : "\(dep) – \(arr)"
                
                let from = flight.fromCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                let to = flight.toCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                let loc = (!from.isEmpty && !to.isEmpty) ? "\(from) → \(to)" : ""
                let title = flight.flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Flight" : flight.flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                
                let parked = EventItem(
                    id: UUID(),
                    title: title,
                    description: flight.notes,
                    time: time,
                    location: loc,
                    latitude: nil,
                    longitude: nil,
                    icon: "airplane",
                    accent: flight.accent,
                    photoData: nil
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
        flightNumber = flight.flightNumber
        flightNotes = flight.notes
        flightAccent = flight.accent
        flightStartTime = flight.startTime
        flightEndTime = flight.endTime
        isPresentingFlight = true
    }

    func deleteFlight(_ flight: FlightItem) {
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

    // MARK: - Quick move left/right + move to Parked Ideas
    
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
            accent: .sand,
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
            accent: .gold,
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
        let time = arr.isEmpty ? dep : "\(dep) – \(arr)"
        
        let from = flight.fromCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let to = flight.toCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let loc = (!from.isEmpty && !to.isEmpty) ? "\(from) → \(to)" : ""
        let title = flight.flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Flight" : flight.flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        let parked = EventItem(
            id: UUID(),
            title: title,
            description: flight.notes,
            time: time,
            location: loc,
            latitude: nil,
            longitude: nil,
            icon: "airplane",
            accent: flight.accent,
            photoData: nil
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

// MARK: - Supporting Views

struct ResizeHandle: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(.systemBackground))
                .frame(height: 12)
            
            HStack {
                Spacer()
                Capsule()
                    .fill(Color(.systemGray3))
                    .frame(width: 40, height: 5)
                Spacer()
            }
            .frame(height: 12)
            .background(Color(.systemBackground))
        }
        .contentShape(Rectangle())
    }
}

struct DayColumn: View {
    let day: TripDay
    let totalDays: Int
    let columnWidth: CGFloat
    let columnHeight: CGFloat
    let onTap: (EventItem) -> Void
    let onEdit: (EventItem) -> Void
    let onDelete: (EventItem) -> Void
    let onMoveEventLeft: (EventItem) -> Void
    let onMoveEventRight: (EventItem) -> Void
    let onMoveEventToParked: ((EventItem) -> Void)?
    let onTapReminder: (ReminderItem) -> Void
    let onDeleteReminder: (ReminderItem) -> Void
    let onMoveReminderLeft: (ReminderItem) -> Void
    let onMoveReminderRight: (ReminderItem) -> Void
    let onMoveReminderToParked: ((ReminderItem) -> Void)?
    let onTapChecklist: (ChecklistItem) -> Void
    let onDeleteChecklist: (ChecklistItem) -> Void
    let onMoveChecklistLeft: (ChecklistItem) -> Void
    let onMoveChecklistRight: (ChecklistItem) -> Void
    let onMoveChecklistToParked: ((ChecklistItem) -> Void)?
    let onTapFlight: (FlightItem) -> Void
    let onDeleteFlight: (FlightItem) -> Void
    let onMoveFlightLeft: (FlightItem) -> Void
    let onMoveFlightRight: (FlightItem) -> Void
    let onMoveFlightToParked: ((FlightItem) -> Void)?
    let onAddEvent: () -> Void
    let showEmptyPlaceholder: Bool
    
    @State private var weatherMode: WeatherPillMode = .conditions
    
    private struct TimedRow: Identifiable {
        enum Kind {
            case flight(FlightItem)
            case activity(EventItem)
        }
        
        let id: String
        let minutes: Int
        let kind: Kind
    }
    
    private var timelineRows: [TimedRow] {
        let flightRows = day.flights.map { flight in
            let comps = Calendar.current.dateComponents([.hour, .minute], from: flight.startTime)
            let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            return TimedRow(id: "flight-\(flight.id)", minutes: minutes, kind: .flight(flight))
        }
        
        let activityRows = day.events.map { event in
            TimedRow(id: "activity-\(event.id)", minutes: event.startTimeMinutes, kind: .activity(event))
        }
        
        return (flightRows + activityRows)
            .sorted { a, b in
                if a.minutes != b.minutes { return a.minutes < b.minutes }
                // Tie-break: flights first, then activities
                switch (a.kind, b.kind) {
                case (.flight, .activity): return true
                case (.activity, .flight): return false
                default: return a.id < b.id
                }
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(day.displayTitle)
                    .font(.headline)
                Text("Day \(day.order) of \(totalDays)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .topTrailing) {
                WeatherPill(
                    mode: $weatherMode,
                    fallbackIcon: day.weatherIcon,
                    fallbackTempF: day.temperatureF,
                    dayDate: day.date
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: Capsule())
                .padding(10)
            }

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 10) {
                    if day.events.isEmpty && day.reminders.isEmpty && day.checklists.isEmpty && day.flights.isEmpty && showEmptyPlaceholder {
                        // Empty state placeholder - only on first day when trip has no events
                        Button {
                            onAddEvent()
                        } label: {
                            Text("Add Activity")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                        .foregroundStyle(Color.secondary.opacity(0.3))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Reminders always show at the top and have no time.
                    if !day.reminders.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(day.reminders) { reminder in
                                ReminderCard(text: reminder.text)
                                    .onTapGesture { onTapReminder(reminder) }
                                    .contextMenu {
                                        if day.order > 1 {
                                            Button {
                                                onMoveReminderLeft(reminder)
                                            } label: {
                                                Label("Move Left", systemImage: "arrow.left")
                                            }
                                        }
                                        if day.order < totalDays {
                                            Button {
                                                onMoveReminderRight(reminder)
                                            } label: {
                                                Label("Move Right", systemImage: "arrow.right")
                                            }
                                        }
                                        if let moveToParked = onMoveReminderToParked {
                                            Button {
                                                moveToParked(reminder)
                                            } label: {
                                                Label("Move to Parked", systemImage: "tray.and.arrow.down")
                                            }
                                        }
                                        Divider()
                                        
                                        Button {
                                            onTapReminder(reminder)
                                        } label: {
                                            Label("Edit Reminder", systemImage: "pencil")
                                        }
                                        
                                        Button(role: .destructive) {
                                            onDeleteReminder(reminder)
                                        } label: {
                                            Label("Delete Reminder", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                    
                    if !day.checklists.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(day.checklists) { checklist in
                                ChecklistCard(checklist: checklist)
                                    .onTapGesture { onTapChecklist(checklist) }
                                    .contextMenu {
                                        if day.order > 1 {
                                            Button {
                                                onMoveChecklistLeft(checklist)
                                            } label: {
                                                Label("Move Left", systemImage: "arrow.left")
                                            }
                                        }
                                        if day.order < totalDays {
                                            Button {
                                                onMoveChecklistRight(checklist)
                                            } label: {
                                                Label("Move Right", systemImage: "arrow.right")
                                            }
                                        }
                                        if let moveToParked = onMoveChecklistToParked {
                                            Button {
                                                moveToParked(checklist)
                                            } label: {
                                                Label("Move to Parked", systemImage: "tray.and.arrow.down")
                                            }
                                        }
                                        Divider()
                                        
                                        Button {
                                            onTapChecklist(checklist)
                                        } label: {
                                            Label("Edit Checklist", systemImage: "pencil")
                                        }
                                        
                                        Button(role: .destructive) {
                                            onDeleteChecklist(checklist)
                                        } label: {
                                            Label("Delete Checklist", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                    
                    ForEach(timelineRows) { row in
                        switch row.kind {
                        case .flight(let flight):
                            FlightCard(flight: flight)
                                .onTapGesture { onTapFlight(flight) }
                                .contextMenu {
                                    if day.order > 1 {
                                        Button {
                                            onMoveFlightLeft(flight)
                                        } label: {
                                            Label("Move Left", systemImage: "arrow.left")
                                        }
                                    }
                                    if day.order < totalDays {
                                        Button {
                                            onMoveFlightRight(flight)
                                        } label: {
                                            Label("Move Right", systemImage: "arrow.right")
                                        }
                                    }
                                    if let moveToParked = onMoveFlightToParked {
                                        Button {
                                            moveToParked(flight)
                                        } label: {
                                            Label("Move to Parked", systemImage: "tray.and.arrow.down")
                                        }
                                    }
                                    Divider()
                                    
                                    Button {
                                        onTapFlight(flight)
                                    } label: {
                                        Label("Edit Flight", systemImage: "pencil")
                                    }
                                    
                                    Button(role: .destructive) {
                                        onDeleteFlight(flight)
                                    } label: {
                                        Label("Delete Flight", systemImage: "trash")
                                    }
                                }
                        case .activity(let event):
                            EventCard(event: event)
                                .onTapGesture { onTap(event) }
                                .contextMenu {
                                    if day.order > 1 {
                                        Button {
                                            onMoveEventLeft(event)
                                        } label: {
                                            Label("Move Left", systemImage: "arrow.left")
                                        }
                                    }
                                    if day.order < totalDays {
                                        Button {
                                            onMoveEventRight(event)
                                        } label: {
                                            Label("Move Right", systemImage: "arrow.right")
                                        }
                                    }
                                    if let moveToParked = onMoveEventToParked {
                                        Button {
                                            moveToParked(event)
                                        } label: {
                                            Label("Move to Parked", systemImage: "tray.and.arrow.down")
                                        }
                                    }
                                    Divider()
                                    
                                    Button {
                                        onEdit(event)
                                    } label: {
                                        Label("Edit Activity", systemImage: "pencil")
                                    }
                                    
                                    Button(role: .destructive) {
                                        onDelete(event)
                                    } label: {
                                        Label("Delete Activity", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(14)
            }
        }
        .frame(width: columnWidth, height: columnHeight)
        .background(dayBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        }
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 14)
    }
}

struct ParkedIdeasColumn: View {
    let items: [EventItem]
    let columnWidth: CGFloat
    let columnHeight: CGFloat
    let onTap: (EventItem) -> Void
    let onDelete: (EventItem) -> Void
    let onAdd: () -> Void
    let onMoveLeftToLastDay: ((EventItem) -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Parked Ideas")
                    .font(.headline)
                Text("Not tied to a day")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items.sorted(by: { $0.startTimeMinutes < $1.startTimeMinutes })) { event in
                        EventCard(event: event)
                            .onTapGesture { onTap(event) }
                            .contextMenu {
                                if let moveLeft = onMoveLeftToLastDay {
                                    Button {
                                        moveLeft(event)
                                    } label: {
                                        Label("Move Left", systemImage: "arrow.left")
                                    }
                                }
                                Divider()
                                Button {
                                    onTap(event)
                                } label: {
                                    Label("Edit Activity", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    onDelete(event)
                                } label: {
                                    Label("Delete Activity", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: columnWidth, height: columnHeight)
        .background(Color(.secondarySystemBackground).opacity(0.7), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
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
                        .font(.caption)
                    Text("\(fallbackTempF)°F")
                        .font(.caption.weight(.semibold))
                }
            case .sunrise:
                HStack(spacing: 6) {
                    Image(systemName: "sunrise.fill")
                        .font(.caption)
                    Text(sunrise.map { timeFormatter.string(from: $0) } ?? "—")
                        .font(.caption.weight(.semibold))
                }
            case .sunset:
                HStack(spacing: 6) {
                    Image(systemName: "sunset.fill")
                        .font(.caption)
                    Text(sunset.map { timeFormatter.string(from: $0) } ?? "—")
                        .font(.caption.weight(.semibold))
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

struct ReminderCard: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "pin.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ChecklistCard: View {
    let checklist: ChecklistItem
    
    private var completedText: String {
        let done = checklist.items.filter(\.isDone).count
        return "\(done)/\(checklist.items.count)"
    }
    
    var body: some View {
        let headerColor = Color(hex: 0xF9C842)
        let listBgColor = Color(hex: 0xFAE78B)
        let lineColor = Color(hex: 0xF9D767)
        let textColor = Color(hex: 0x523E0E)
        
        let previewItems = Array(checklist.items.prefix(3))
        
        VStack(spacing: 0) {
            // Header (square corners; outer rounding applied by the card clip)
            ZStack {
                Rectangle()
                    .fill(headerColor)
                
                HStack(alignment: .firstTextBaseline) {
                    Text(checklist.title)
                        .font(.subheadline.weight(.semibold)) // match event card title style
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(completedText)
                        .font(.subheadline.weight(.semibold)) // match event card title style
                        .foregroundStyle(textColor)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity)
            
            // List preview (top 3 items) - square rows and 1px lines
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { idx in
                    let text = idx < previewItems.count ? previewItems[idx].text : ""
                    let isDone = idx < previewItems.count ? previewItems[idx].isDone : false
                    
                    ZStack {
                        Rectangle()
                            .fill(listBgColor)
                        
                        HStack(spacing: 6) {
                            if idx < previewItems.count {
                                Image(systemName: isDone ? "checkmark.square.fill" : "square")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(textColor.opacity(isDone ? 0.85 : 0.55))
                            } else {
                                Image(systemName: "square")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(textColor.opacity(0.0))
                            }
                            
                            Text(text)
                                .font(.subheadline)
                                .foregroundStyle(textColor)
                                .lineLimit(1)
                                .strikethrough(isDone, color: textColor.opacity(0.6))
                            
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                    }
                    .frame(maxWidth: .infinity)
                    
                    if idx < 2 {
                        Rectangle()
                            .fill(lineColor)
                            .frame(height: 1)
                    }
                }
            }
        }
        // Match EventCard corner radius.
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(textColor.opacity(0.08), lineWidth: 1)
        )
    }
}

struct FlightCard: View {
    let flight: FlightItem
    
    private var fromCode: String { flight.fromCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().isEmpty ? "—" : flight.fromCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
    private var toCode: String { flight.toCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().isEmpty ? "—" : flight.toCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
    
    private var departureText: String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: flight.startTime)
    }
    
    private var arrivalText: String? {
        guard flight.hasEndTime else { return nil }
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: flight.endTime)
    }
    
    private var flightNumberText: String? {
        let t = flight.flightNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t.uppercased()
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                airportTopBlock(
                    code: fromCode,
                    city: flight.fromCity,
                    alignment: .leading
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                
                ZStack {
                    Capsule(style: .continuous)
                        .fill(Color.secondary.opacity(0.25))
                        .frame(height: 3)
                    
                    Image(systemName: "airplane")
                        // Match activity icon size in other cards.
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(.primary)
                }
                .frame(width: 140)
                .layoutPriority(0)
                
                airportTopBlock(
                    code: toCode,
                    city: flight.toCity,
                    alignment: .trailing
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
                .layoutPriority(1)
            }
            
            HStack(alignment: .lastTextBaseline) {
                Text(departureText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer(minLength: 0)
                
                if let flightNumberText {
                    Text(flightNumberText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                } else {
                    Text(" ")
                        .font(.subheadline.weight(.semibold))
                        .hidden()
                }
                
                Spacer(minLength: 0)
                
                if let arrivalText {
                    Text(arrivalText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(" ")
                        .font(.caption)
                        .hidden()
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        // Match Activity (EventCard) styling: plain material card, no gradient/stroke.
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func airportTopBlock(code: String, city: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(code)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? " " : city)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }
}

private extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

struct EventCard: View {
    let event: EventItem

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let photoData = event.photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(event.accentColor.opacity(0.18))
                        Image(systemName: event.icon)
                            .foregroundStyle(event.accentColor)
                            .font(.title3)
                    }
                    .frame(width: 52, height: 52)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                if !event.location.isEmpty {
                    Text(event.location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !event.time.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(event.time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                            .font(.title2.weight(.bold))
                        Text(event.location)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(event.time)
                            .font(.headline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 180)

                VStack(alignment: .leading, spacing: 10) {
                    Label(event.location, systemImage: "mappin.and.ellipse")
                    Label(event.time, systemImage: "clock")
                }
                .font(.headline)

                if !event.description.isEmpty {
                    Text(event.description)
                        .font(.body)
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

struct TripSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Binding var name: String
    @Binding var location: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var mapSpan: Double?
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var coverImageData: Data?
    @Binding var showParkedIdeas: Bool
    var onApply: () -> Void
    
    @State private var coverImage: UIImage?
    @State private var showImagePicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
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
                        text: $location,
                        latitude: $latitude,
                        longitude: $longitude,
                        mapSpan: $mapSpan,
                        resultTypes: .address
                    )
                }

                Section("Dates") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
                
                Section("Cover Image") {
                    if let img = coverImage {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    showImagePicker = true
                                }
                            
                            Button {
                                coverImage = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.7))
                                    .shadow(radius: 2)
                            }
                            .buttonStyle(.plain)
                            .padding(12)
                        }
                    } else {
                        Button {
                            showImagePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                Text("Add Cover Image")
                                Spacer()
                            }
                        }
                    }
                }
                
                Section("Options") {
                    Toggle("Show Parked Ideas", isOn: $showParkedIdeas)
                        .tint(appAccentColor)
                    Text("An extra space for ideation")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    LiquidGlassIconButton(
                        systemName: "checkmark",
                        isEnabled: !(name.isEmpty || location.isEmpty)
                    ) {
                        coverImageData = coverImage?.jpegData(compressionQuality: 0.8)
                        onApply()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $coverImage)
                    .tint(.primary)
            }
            .onAppear {
                if let imageData = coverImageData {
                    coverImage = UIImage(data: imageData)
                }
            }
            .onChange(of: startDate) { _, newValue in
                if endDate < newValue {
                    endDate = newValue
                }
            }
        }
    }
}

struct AddEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Binding var title: String
    @Binding var location: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var description: String
    @Binding var icon: String
    @Binding var accent: EventAccent
    @Binding var startTime: Date
    @Binding var endTime: Date
    @Binding var photo: UIImage?
    @Binding var selectedDayID: UUID?
    let dayOptions: [DayOption]
    let tripLocationRegion: MKCoordinateRegion?
    var onAdd: () -> Void
    var onDelete: (() -> Void)?
    var isEditing: Bool = false
    
    @State private var showImagePicker = false
    @State private var hasEndTime = false
    
    private var durationString: String? {
        let interval = endTime.timeIntervalSince(startTime)
        guard interval > 0 else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = interval >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .short
        return formatter.string(from: interval)
    }

    private let iconOptions: [String] = [
        // Transportation
        "airplane",
        "car.fill",
        "bus.fill",
        "tram.fill",
        "train.side.front.car",
        "ferry.fill",
        "bicycle",
        "figure.walk",
        // Food & Drink
        "fork.knife",
        "cup.and.saucer.fill",
        "wineglass.fill",
        "cart.fill",
        "mug.fill",
        // Lodging
        "bed.double.fill",
        "house.fill",
        "building.2.fill",
        // Nature & Outdoors
        "mountain.2.fill",
        "water.waves",
        "leaf.fill",
        "sun.max.fill",
        "sunrise",
        "sunset",
        "beach.umbrella.fill",
        // Activities & Sightseeing
        "camera.fill",
        "ticket.fill",
        "theatermasks.fill",
        "movieclapper",
        "figure.hiking",
        "dumbbell.fill",
        "trophy.fill",
        // Landmarks & Places
        "building.columns.fill",
        "mappin.and.ellipse",
        // Items
        "duffle.bag.fill",
        "bag.fill",
        "creditcard.fill",
        "airpods.max",
        "stroller.fill",
        "drone.fill",
        "sunglasses.fill",
        "shoe.fill",
        "tshirt.fill",
        "jacket.fill"
    ]
    
    private func deleteEvent() {
        onDelete?()
        dismiss()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Activity Name", text: $title)
                        if !title.isEmpty {
                            Button {
                                title = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    LocationSearchField(
                        text: $location,
                        latitude: $latitude,
                        longitude: $longitude,
                        searchRegion: tripLocationRegion
                    )
                }

                Section("Timing") {
                    Picker("Day", selection: $selectedDayID) {
                        ForEach(dayOptions) { option in
                            Text(option.title)
                                .tag(Optional(option.id))
                        }
                    }
                    DatePicker("From", selection: $startTime, displayedComponents: .hourAndMinute)
                    
                    Toggle("Add end time", isOn: $hasEndTime)
                        .tint(appAccentColor)
                        .onChange(of: hasEndTime) { _, newValue in
                            if !newValue {
                                endTime = startTime
                            } else if endTime <= startTime {
                                endTime = startTime.addingTimeInterval(60 * 60)
                            }
                        }
                    
                    if hasEndTime {
                        DatePicker("To", selection: $endTime, in: startTime..., displayedComponents: .hourAndMinute)
                    }
                    if let durationText = durationString {
                        Text("Duration: \(durationText)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Visuals") {
                    if let photoImage = photo {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: photoImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    showImagePicker = true
                                }
                            
                            Button {
                                photo = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.7))
                                    .shadow(radius: 2)
                            }
                            .buttonStyle(.plain)
                            .padding(12)
                        }
                    } else {
                        Button {
                            showImagePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                            Text("Add Image")
                                Spacer()
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ColorChips(selection: $accent)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Icon")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        IconCarousel(
                            items: iconOptions,
                            selection: $icon,
                            accentColor: accent.color
                        )
                    }
                }
                
                Section("Notes") {
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                }
                
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            deleteEvent()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Activity")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Activity" : "Add Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    LiquidGlassIconButton(systemName: "checkmark") {
                        onAdd()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $photo)
                    .tint(.primary)
            }
            .onAppear {
                if isEditing {
                    hasEndTime = endTime > startTime
                } else {
                    hasEndTime = false
                    endTime = startTime
                }
            }
            .onChange(of: hasEndTime) { _, newValue in
                if !newValue {
                    endTime = startTime
                } else if endTime <= startTime {
                    endTime = startTime.addingTimeInterval(60 * 60)
                }
            }
            .onChange(of: startTime) { _, newValue in
                if !hasEndTime {
                    endTime = newValue
                }
            }
            .onChange(of: title) { _, _ in if isEditing { onAdd() } }
            .onChange(of: location) { _, _ in if isEditing { onAdd() } }
            .onChange(of: description) { _, _ in if isEditing { onAdd() } }
            .onChange(of: icon) { _, _ in if isEditing { onAdd() } }
            .onChange(of: accent) { _, _ in if isEditing { onAdd() } }
            .onChange(of: photo) { _, _ in if isEditing { onAdd() } }
            .onChange(of: startTime) { _, _ in if isEditing { onAdd() } }
            .onChange(of: endTime) { _, _ in if isEditing { onAdd() } }
            .onChange(of: selectedDayID) { _, _ in if isEditing { onAdd() } }
        }
    }
}

struct AddReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var reminderText: String
    @Binding var selectedDayID: UUID?
    let dayOptions: [DayOption]
    var isEditing: Bool = false
    var onAdd: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Day", selection: $selectedDayID) {
                        ForEach(dayOptions) { option in
                            Text(option.title)
                                .tag(Optional(option.id))
                        }
                    }
                }
                
                Section("Reminder") {
                    HStack {
                        TextField("Add a reminder", text: $reminderText)
                        if !reminderText.isEmpty {
                            Button {
                                reminderText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Reminder" : "Add Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    LiquidGlassIconButton(
                        systemName: "checkmark",
                        isEnabled: {
                            let textOK = !reminderText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            return textOK && selectedDayID != nil
                        }()
                    ) {
                        onAdd()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ChecklistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var accentColor
    
    @Binding var title: String
    @Binding var items: [ChecklistEntry]
    @Binding var selectedDayID: UUID?
    let dayOptions: [DayOption]
    var isEditing: Bool = false
    var onSave: () -> Void
    
    @State private var newItemText: String = ""
    @FocusState private var focusedItemID: UUID?
    @State private var pendingDeleteItemID: UUID?
    @State private var didCopyItems: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    Section {
                        Picker("Day", selection: $selectedDayID) {
                            ForEach(dayOptions) { option in
                                Text(option.title)
                                    .tag(Optional(option.id))
                            }
                        }
                    }
                    
                    Section("Checklist") {
                        HStack {
                            TextField("Title", text: $title)
                            if !title.isEmpty {
                                Button {
                                    title = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Section("Items") {
                        ForEach(items) { item in
                            let itemID = item.id
                            HStack(spacing: 12) {
                                Button {
                                    guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
                                    let wasDone = items[idx].isDone
                                    items[idx].isDone.toggle()
                                    if !wasDone, items[idx].isDone { Haptics.bump() }
                                } label: {
                                    let isDone = items.first(where: { $0.id == itemID })?.isDone ?? false
                                    Image(systemName: isDone ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(isDone ? accentColor : .secondary)
                                }
                                .buttonStyle(.plain)
                                
                                TextField(
                                    "Item",
                                    text: Binding(
                                        get: { items.first(where: { $0.id == itemID })?.text ?? "" },
                                        set: { newValue in
                                            guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
                                            items[idx].text = newValue
                                        }
                                    )
                                )
                                .focused($focusedItemID, equals: itemID)
                                
                                if focusedItemID == itemID {
                                    Button {
                                        // Defer mutation to keep Form updates stable.
                                        pendingDeleteItemID = itemID
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .id(itemID)
                        }
                        .onDelete { offsets in
                            for offset in offsets.sorted(by: >) where offset < items.count {
                                items.remove(at: offset)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.secondary)
                            TextField("Add item", text: $newItemText)
                            Button("Add") {
                                let t = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !t.isEmpty else { return }
                                let newID = UUID()
                                items.append(ChecklistEntry(id: newID, text: t, isDone: false))
                                newItemText = ""
                                // Defer focus until after the Form updates to avoid scroll crashes.
                                DispatchQueue.main.async {
                                    focusedItemID = newID
                                }
                            }
                            .disabled(newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    
                    Section {
                        Button {
                            let lines = items
                                .map { entry -> String in
                                    let t = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !t.isEmpty else { return "" }
                                    // Checked items show a checkmark prefix when pasted.
                                    return entry.isDone ? "✓ \(t)" : t
                                }
                                .filter { !$0.isEmpty }
                            
                            let payload = lines.joined(separator: "\n")
                            UIPasteboard.general.string = payload
                            Haptics.bump()
                            withAnimation(.easeInOut(duration: 0.15)) {
                                didCopyItems = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    didCopyItems = false
                                }
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Label(didCopyItems ? "Copied" : "Copy Items", systemImage: "doc.on.doc")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .disabled(didCopyItems || items.isEmpty)
                    }
                }
                .onChange(of: focusedItemID) { _, newValue in
                    guard let id = newValue else { return }
                    // Form + ScrollViewReader can crash if we scroll before the row exists.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        guard items.contains(where: { $0.id == id }) else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
                .onChange(of: pendingDeleteItemID) { _, newValue in
                    guard let id = newValue else { return }
                    // Defer the mutation to the next runloop to keep SwiftUI bindings stable.
                    DispatchQueue.main.async {
                        if focusedItemID == id { focusedItemID = nil }
                        withAnimation(.easeInOut(duration: 0.15)) {
                            items.removeAll(where: { $0.id == id })
                        }
                        pendingDeleteItemID = nil
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Checklist" : "New Checklist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    LiquidGlassIconButton(
                        systemName: "checkmark",
                        isEnabled: !(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedDayID == nil)
                    ) {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AddFlightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    
    @Binding var fromName: String
    @Binding var fromCode: String
    @Binding var fromCity: String
    @Binding var fromLatitude: Double?
    @Binding var fromLongitude: Double?
    @Binding var fromTerminal: String
    @Binding var fromGate: String
    
    @Binding var toName: String
    @Binding var toCode: String
    @Binding var toCity: String
    @Binding var toLatitude: Double?
    @Binding var toLongitude: Double?
    @Binding var toTerminal: String
    @Binding var toGate: String
    
    @Binding var flightNumber: String
    @Binding var notes: String
    @Binding var accent: EventAccent
    @Binding var startTime: Date
    @Binding var endTime: Date
    
    @Binding var selectedDayID: UUID?
    let dayOptions: [DayOption]
    
    var isEditing: Bool
    var onSave: () -> Void
    var onDelete: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Day", selection: $selectedDayID) {
                        ForEach(dayOptions) { option in
                            Text(option.title)
                                .tag(Optional(option.id))
                        }
                    }
                }
                
                Section("Departure") {
                    AirportSearchField(
                        title: "Location",
                        name: $fromName,
                        code: $fromCode,
                        city: $fromCity,
                        latitude: $fromLatitude,
                        longitude: $fromLongitude
                    )
                    airportCodeField(title: "Airport code", code: $fromCode)
                    clearableTextField(title: "Terminal", text: $fromTerminal, capitalization: .characters)
                    clearableTextField(title: "Gate", text: $fromGate, capitalization: .characters)
                    DatePicker("Time", selection: $startTime, displayedComponents: .hourAndMinute)
                }
                
                Section("Arrival") {
                    AirportSearchField(
                        title: "Location",
                        name: $toName,
                        code: $toCode,
                        city: $toCity,
                        latitude: $toLatitude,
                        longitude: $toLongitude
                    )
                    airportCodeField(title: "Airport code", code: $toCode)
                    clearableTextField(title: "Terminal", text: $toTerminal, capitalization: .characters)
                    clearableTextField(title: "Gate", text: $toGate, capitalization: .characters)
                    DatePicker("Time", selection: $endTime, in: startTime..., displayedComponents: .hourAndMinute)
                }
                
                Section("Flight number") {
                    clearableTextField(title: "Flight number", text: $flightNumber, capitalization: .characters)
                }
                
                Section("Visuals") {
                    ColorChips(selection: $accent)
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 90)
                }
                
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            onDelete?()
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Flight")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Flight" : "Add Flight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    LiquidGlassIconButton(
                        systemName: "checkmark",
                        isEnabled: selectedDayID != nil && (!fromName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !toName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    ) {
                        onSave()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if endTime < startTime { endTime = startTime }
            }
            .onChange(of: startTime) { _, newValue in
                if endTime < newValue { endTime = newValue }
            }
        }
        .tint(.primary)
    }
    
    private func airportCodeField(title: String, code: Binding<String>) -> some View {
        HStack {
            TextField(title, text: code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .onChange(of: code.wrappedValue) { _, newValue in
                    let cleaned = newValue
                        .uppercased()
                        .filter { $0.isLetter }
                    code.wrappedValue = String(cleaned.prefix(3))
                }
            
            if !code.wrappedValue.isEmpty {
                Button {
                    code.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func clearableTextField(
        title: String,
        text: Binding<String>,
        capitalization: TextInputAutocapitalization? = nil
    ) -> some View {
        HStack {
            TextField(title, text: text)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
            
            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// Icon grid selection
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
                                    .font(.system(size: 18, weight: .medium))
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
        }
    }
}

// Color chip selection
struct ColorChips: View {
    @Binding var selection: EventAccent

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(EventAccent.allCases, id: \.self) { accent in
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
                    .font(.title2.weight(.bold))
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

// MARK: - Location Search

struct LocationSearchField: View {
    @Binding var text: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var mapSpan: Double?
    var resultTypes: MKLocalSearchCompleter.ResultType
    var searchRegion: MKCoordinateRegion?
    
    @StateObject private var completer: LocationSearchCompleter
    @State private var showingResults = false
    
    init(text: Binding<String>, 
         latitude: Binding<Double?>, 
         longitude: Binding<Double?>,
         mapSpan: Binding<Double?> = .constant(nil),
         resultTypes: MKLocalSearchCompleter.ResultType = .pointOfInterest,
         searchRegion: MKCoordinateRegion? = nil) {
        self._text = text
        self._latitude = latitude
        self._longitude = longitude
        self._mapSpan = mapSpan
        self.resultTypes = resultTypes
        self.searchRegion = searchRegion
        self._completer = StateObject(wrappedValue: LocationSearchCompleter(
            resultTypes: resultTypes,
            searchRegion: searchRegion
        ))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TextField("Location", text: $text)
                    .onChange(of: text) { _, newValue in
                        completer.searchQuery = newValue
                        showingResults = !newValue.isEmpty
                    }
                
                if !text.isEmpty {
                    Button {
                        text = ""
                        latitude = nil
                        longitude = nil
                        showingResults = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if showingResults && !completer.results.isEmpty {
                Divider()
                    .padding(.top, 8)
                
                VStack(spacing: 0) {
                    ForEach(completer.results, id: \.self) { result in
                        Button {
                            selectLocation(result)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                Text(result.title)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                        
                        if result != completer.results.last {
                            Divider()
                        }
                    }
                }
            } else if showingResults && completer.results.isEmpty && !text.isEmpty {
                Text("No results")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
    }
    
    private func selectLocation(_ result: MKLocalSearchCompletion) {
        self.text = result.title
        self.showingResults = false
        
        let searchRequest = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            guard let response = response,
                  let first = response.mapItems.first,
                  let coordinate = mapItemCoordinate(first) else {
                return
            }
            
            self.latitude = coordinate.latitude
            self.longitude = coordinate.longitude
            
            // Capture the bounding region span for appropriate zoom level
            let span = max(response.boundingRegion.span.latitudeDelta, response.boundingRegion.span.longitudeDelta)
            self.mapSpan = span
        }
    }
}

// MARK: - MKMapItem helpers (iOS 26 placemark deprecation)

private func mapItemCoordinate(_ item: MKMapItem) -> CLLocationCoordinate2D? {
    if #available(iOS 26.0, *) {
        return item.location.coordinate
    } else {
        return legacyMapItemCoordinate(item)
    }
}

private func mapItemCity(_ item: MKMapItem) -> String? {
    if #available(iOS 26.0, *) {
        return item.addressRepresentations?.cityWithContext
    } else {
        return legacyMapItemCity(item)
    }
}

private func mapItemAddressString(_ item: MKMapItem) -> String? {
    if #available(iOS 26.0, *) {
        // Prefer the new iOS 26 address object (avoids placemark).
        let addr: String? = item.address?.fullAddress ?? item.address?.shortAddress
        return addr
    } else {
        return legacyMapItemAddressString(item)
    }
}

@available(iOS, introduced: 17.0, obsoleted: 26.0)
private func legacyMapItemCoordinate(_ item: MKMapItem) -> CLLocationCoordinate2D? {
    item.placemark.coordinate
}

@available(iOS, introduced: 17.0, obsoleted: 26.0)
private func legacyMapItemCity(_ item: MKMapItem) -> String? {
    item.placemark.locality ?? item.placemark.administrativeArea
}

@available(iOS, introduced: 17.0, obsoleted: 26.0)
private func legacyMapItemAddressString(_ item: MKMapItem) -> String? {
    item.placemark.title
}

class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer: MKLocalSearchCompleter
    private let pointOfInterestCategories: [MKPointOfInterestCategory]?
    
    var searchQuery: String = "" {
        didSet {
            completer.queryFragment = searchQuery
        }
    }
    
    init(
        resultTypes: MKLocalSearchCompleter.ResultType = .pointOfInterest,
        searchRegion: MKCoordinateRegion? = nil,
        pointOfInterestCategories: [MKPointOfInterestCategory]? = nil
    ) {
        completer = MKLocalSearchCompleter()
        self.pointOfInterestCategories = pointOfInterestCategories
        super.init()
        completer.delegate = self
        completer.resultTypes = resultTypes
        if let cats = pointOfInterestCategories {
            completer.pointOfInterestFilter = MKPointOfInterestFilter(including: cats)
        }
        if let region = searchRegion {
            completer.region = region
        }
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.results = completer.results
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Location search error: \(error.localizedDescription)")
    }
}

// MARK: - Airport Search

struct AirportSearchField: View {
    let title: String
    @Binding var name: String
    @Binding var code: String
    @Binding var city: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    var searchRegion: MKCoordinateRegion?
    
    @StateObject private var completer: LocationSearchCompleter
    @State private var showingResults = false
    @State private var resolvedCodes: [MKLocalSearchCompletion: String] = [:]
    @State private var failedCodeResolutions: Set<MKLocalSearchCompletion> = []
    @State private var inFlightCodeResolutions: Set<MKLocalSearchCompletion> = []
    
    private var filteredResults: [MKLocalSearchCompletion] {
        completer.results.filter(isAirportCompletion)
    }
    
    private func codeForDisplay(_ result: MKLocalSearchCompletion) -> String {
        let direct = airportCodeCandidate(for: result)
        if !direct.isEmpty { return direct }
        return resolvedCodes[result] ?? ""
    }
    
    init(
        title: String,
        name: Binding<String>,
        code: Binding<String>,
        city: Binding<String>,
        latitude: Binding<Double?>,
        longitude: Binding<Double?>,
        searchRegion: MKCoordinateRegion? = nil
    ) {
        self.title = title
        self._name = name
        self._code = code
        self._city = city
        self._latitude = latitude
        self._longitude = longitude
        self.searchRegion = searchRegion
        self._completer = StateObject(
            wrappedValue: LocationSearchCompleter(
                resultTypes: .pointOfInterest,
                searchRegion: searchRegion,
                pointOfInterestCategories: [.airport]
            )
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TextField(title, text: $name)
                    .onChange(of: name) { _, newValue in
                        completer.searchQuery = newValue
                        showingResults = !newValue.isEmpty
                    }
                
                if !name.isEmpty {
                    Button {
                        name = ""
                        code = ""
                        city = ""
                        latitude = nil
                        longitude = nil
                        showingResults = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if showingResults && !filteredResults.isEmpty {
                Divider()
                    .padding(.top, 8)
                
                VStack(spacing: 0) {
                    ForEach(filteredResults, id: \.self) { result in
                        let code = codeForDisplay(result)
                        let airportName = stripLeadingCode(from: result.title)
                        let isResolvingCode = code.isEmpty && !failedCodeResolutions.contains(result)
                        Button {
                            selectAirport(result)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(code.isEmpty ? airportName : "\(code) - \(airportName)")
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 0)
                                
                                if isResolvingCode {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.secondary)
                                } else {
                                    Text(code.isEmpty ? "—" : code)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.thinMaterial, in: Capsule())
                                }
                            }
                            .contentShape(Rectangle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                        
                        if result != filteredResults.last {
                            Divider()
                        }
                    }
                }
            }
        }
        .onChange(of: completer.results) { _, newValue in
            // Resolve codes for the first few visible results.
            for result in Array(newValue.prefix(8)) {
                if !isAirportCompletion(result) { continue }
                if !airportCodeCandidate(for: result).isEmpty { continue }
                if failedCodeResolutions.contains(result) { continue }
                if inFlightCodeResolutions.contains(result) { continue }
                if (resolvedCodes[result] ?? "").isEmpty {
                    resolveCodeForResult(result)
                }
            }
        }
    }
    
    private func selectAirport(_ result: MKLocalSearchCompletion) {
        let airportName = stripLeadingCode(from: result.title)
        name = airportName
        showingResults = false
        let initialCode = codeForDisplay(result)
        
        let request = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            guard let response else { return }
            let items = response.mapItems
            guard let first = items.first else { return }
            guard let coordinate = mapItemCoordinate(first) else { return }
            
            // If MapKit can identify this POI category, require airport to reduce false positives.
            if let poi = first.pointOfInterestCategory, poi != .airport, initialCode.isEmpty {
                return
            }
            let resolvedCity = mapItemCity(first) ?? result.subtitle
            
            // Try to extract a code from any returned map item / placemark text.
            let codeFromItems: String = items
                .compactMap { mapItem in
                    return airportCodeCandidate(fromText: [
                        mapItem.name,
                        mapItemAddressString(mapItem),
                        result.title,
                        result.subtitle
                    ]
                    .compactMap { $0 }
                    .joined(separator: " "))
                }
                .first { !$0.isEmpty } ?? ""
            
            let chosenCode = !initialCode.isEmpty ? initialCode : codeFromItems
            
            DispatchQueue.main.async {
                latitude = coordinate.latitude
                longitude = coordinate.longitude
                city = resolvedCity
                
                // Code is optional; user can type it manually.
                if !chosenCode.isEmpty {
                    code = chosenCode
                }
            }
        }
    }
    
    private func isAirportCompletion(_ result: MKLocalSearchCompletion) -> Bool {
        let combined = "\(result.title) \(result.subtitle)".uppercased()
        if !airportCodeCandidate(for: result).isEmpty { return true }
        // Heuristics to reduce non-airport POIs.
        return combined.contains("AIRPORT") || combined.contains("AEROPORT") || combined.contains("AEROPUERTO") || combined.contains("INTL")
    }
    
    private func airportCodeCandidate(for result: MKLocalSearchCompletion) -> String {
        airportCodeCandidate(fromText: "\(result.title) \(result.subtitle)")
    }
    
    private func airportCodeCandidate(fromText text: String) -> String {
        let combined = text.uppercased()
        
        // Common format: "Some Airport (SFO)"
        if let range = combined.range(of: #"\(([A-Z]{3})\)"#, options: .regularExpression) {
            let match = String(combined[range])
            return match.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
        }
        
        // Prefix format: "SFO - Some Airport"
        if let range = combined.range(of: #"^([A-Z]{3})\s*[-–]\s*"#, options: .regularExpression) {
            let prefix = String(combined[range])
            let letters = prefix.filter { $0.isLetter }
            if letters.count == 3 { return letters }
        }
        
        // "IATA: SFO"
        if let range = combined.range(of: #"\bIATA[:\s]+([A-Z]{3})\b"#, options: .regularExpression) {
            let match = String(combined[range])
            let letters = match.filter { $0.isLetter }
            if letters.count >= 3 { return String(letters.suffix(3)) }
        }
        
        return ""
    }
    
    private func stripLeadingCode(from title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: #"^[A-Z]{3}\s*[-–]\s*"#, options: .regularExpression) {
            return String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }
    
    private func resolveCodeForResult(_ result: MKLocalSearchCompletion) {
        inFlightCodeResolutions.insert(result)
        let request = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            let items = response?.mapItems ?? []
            let found: String = items
                .compactMap { item in
                    airportCodeCandidate(fromText: [item.name, mapItemAddressString(item)].compactMap { $0 }.joined(separator: " "))
                }
                .first(where: { !$0.isEmpty }) ?? ""
            DispatchQueue.main.async {
                inFlightCodeResolutions.remove(result)
                if !found.isEmpty {
                    resolvedCodes[result] = found
                } else {
                    // Mark as failed so we stop showing a spinner / retrying forever.
                    failedCodeResolutions.insert(result)
                    if let error {
                        print("Airport code resolve error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

// MARK: - Models

struct EventAnnotation: Identifiable {
    let id: UUID
    let dayID: UUID
    let coordinate: CLLocationCoordinate2D
    let event: EventItem
    let color: Color
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

    var accentColor: Color { accent.color }
    
    /// Extracts start time in minutes from midnight for sorting
    var startTimeMinutes: Int {
        let startText = time
            .split(separator: "–")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        // 1) Try parsing localized short time (what we save from the picker)
        let short = DateFormatter()
        short.dateStyle = .none
        short.timeStyle = .short
        if let date = short.date(from: startText) {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
            return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        }
        
        // 2) Fallback: support legacy "HH:mm"
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
    
    var flightNumber: String
    var notes: String
    var accent: EventAccent
    var startTime: Date
    var endTime: Date
    
    var hasEndTime: Bool { endTime > startTime }
    
    enum CodingKeys: String, CodingKey {
        case id
        case fromName, fromCode, fromCity, fromLatitude, fromLongitude, fromTerminal, fromGate
        case toName, toCode, toCity, toLatitude, toLongitude, toTerminal, toGate
        case flightNumber, notes, accent, startTime, endTime
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
        flightNumber: String = "",
        notes: String = "",
        accent: EventAccent = .sky,
        startTime: Date = Date(),
        endTime: Date = Date()
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
        self.flightNumber = flightNumber
        self.notes = notes
        self.accent = accent
        self.startTime = startTime
        self.endTime = endTime
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
        
        flightNumber = try c.decode(String.self, forKey: .flightNumber)
        notes = try c.decode(String.self, forKey: .notes)
        accent = try c.decode(EventAccent.self, forKey: .accent)
        startTime = try c.decode(Date.self, forKey: .startTime)
        endTime = try c.decode(Date.self, forKey: .endTime)
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
        
        try c.encode(flightNumber, forKey: .flightNumber)
        try c.encode(notes, forKey: .notes)
        try c.encode(accent, forKey: .accent)
        try c.encode(startTime, forKey: .startTime)
        try c.encode(endTime, forKey: .endTime)
    }
}

enum EventAccent: String, Codable, CaseIterable, Hashable {
    case sand
    case gold
    case burntOrange
    case mint
    case forest
    case deepNavy
    case sky
    case lavender

    var color: Color {
        switch self {
        // Requested palette (8 distinct colors)
        case .sand: return Color(hex: 0xC0B5A1)
        case .gold: return Color(hex: 0xF6C00A)
        case .burntOrange: return Color(hex: 0xD66710)
        case .mint: return Color(hex: 0x27EAA6)
        case .forest: return Color(hex: 0x41634A)
        case .deepNavy: return Color(hex: 0x1B3745)
        case .sky: return Color(hex: 0x94BAFB)
        case .lavender: return Color(hex: 0xB2A1FF)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        
        // New values
        if let v = EventAccent(rawValue: raw) {
            self = v
            return
        }
        
        // Back-compat mapping for older saved palettes
        switch raw {
        case "yellow":
            self = .gold
        case "orange", "amber":
            self = .burntOrange
        case "mint", "teal", "cyan", "lime":
            self = .mint
        case "green":
            self = .forest
        case "blue":
            self = .sky
        case "indigo", "purple", "violet", "pink", "coral", "red":
            self = .lavender
        default:
            self = .sky
        }
    }
}

// MARK: - UTType

private extension UTType {
    static let eventItem = UTType.data
}

#Preview {
    NavigationStack {
        TripDetailView(trip: .constant(Trip.sampleTrips[0]))
    }
}

