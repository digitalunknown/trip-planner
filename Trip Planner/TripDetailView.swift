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
    @State private var newEventAccent: EventAccent = .blue
    @State private var newEventStart: Date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(9 * 3600)
    @State private var newEventEnd: Date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(10 * 3600)
    @State private var newEventPhoto: UIImage?
    @State private var selectedDayID: UUID?
    @State private var editingEvent: EventItem?
    @State private var mapRegion: MKCoordinateRegion
    @State private var showMap = false
    
    @State private var isPresentingReminder = false
    @State private var newReminderText: String = ""
    @State private var editingReminder: ReminderItem?
    
    @State private var isPresentingChecklist = false
    @State private var editingChecklist: ChecklistItem?
    @State private var checklistTitle: String = ""
    @State private var checklistDraftItems: [ChecklistEntry] = []
    
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
        self._mapRegion = State(initialValue: initialRegion)
    }
    
    var eventAnnotations: [EventAnnotation] {
        tripDays.flatMap { day in
            day.events.compactMap { event in
                guard let lat = event.latitude, let lon = event.longitude else { return nil }
                return EventAnnotation(
                    id: event.id,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    event: event,
                    color: event.accentColor
                )
            }
        }
    }
    
    var appropriateMapRegion: MKCoordinateRegion {
        if let lat = trip.latitude, let lon = trip.longitude {
            // Use the stored mapSpan from location search, or default to city level
            let span = trip.mapSpan ?? 0.1
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            )
        } else if !eventAnnotations.isEmpty {
            let coordinates = eventAnnotations.map { $0.coordinate }
            let minLat = coordinates.map { $0.latitude }.min() ?? 0
            let maxLat = coordinates.map { $0.latitude }.max() ?? 0
            let minLon = coordinates.map { $0.longitude }.min() ?? 0
            let maxLon = coordinates.map { $0.longitude }.max() ?? 0
            
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            let span = MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.3, 0.05),
                longitudeDelta: max((maxLon - minLon) * 1.3, 0.05)
            )
            return MKCoordinateRegion(center: center, span: span)
        } else {
            // Default world view
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 120)
            )
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            let totalHeight = geo.size.height
            let mapHeight = totalHeight * splitRatio
            let handleHeight: CGFloat = 24
            let kanbanHeight = totalHeight - mapHeight - handleHeight
            
            VStack(spacing: 0) {
                ZStack {
                    Map(coordinateRegion: $mapRegion, interactionModes: .all, annotationItems: eventAnnotations) { annotation in
                        MapAnnotation(coordinate: annotation.coordinate) {
                            Button {
                                openEventFromMarker(annotation.event)
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(annotation.color)
                                        .frame(width: 36, height: 36)
                                    Image(systemName: annotation.event.icon)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                            }
                        }
                    }
                    .opacity(showMap ? 1 : 0)
                    
                    // Hide the Map's initial camera snap (“jump”) by fading in after first layout.
                    if !showMap {
                        Rectangle()
                            .fill(Color(.systemBackground))
                    }
                }
                .frame(height: mapHeight)
                .ignoresSafeArea(edges: .top)
                
                // Drag handle
                ResizeHandle()
                    .frame(height: handleHeight)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newRatio = (mapHeight + value.translation.height) / totalHeight
                                // Clamp between 20% and 80%
                                splitRatio = min(max(newRatio, 0.2), 0.8)
                            }
                    )
                
                kanbanBoard()
                    .frame(height: kanbanHeight)
            }
        }
        .background(backgroundGradient)
        .ignoresSafeArea(edges: .top)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .enableSwipeBack()
        .toolbar(.hidden, for: .tabBar)
        .tint(.primary)
        .toolbar {
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
                        prepareNewEventDefaults()
                        isPresentingAdd = true
                    } label: {
                        Label("Event", systemImage: "calendar.badge.plus")
                    }
                    
                    Button {
                        if selectedDayID == nil { selectedDayID = tripDays.first?.id }
                        newReminderText = ""
                        editingReminder = nil
                        isPresentingReminder = true
                    } label: {
                        Label("Reminder", systemImage: "lightbulb")
                    }
                    
                    Button {
                        if selectedDayID == nil { selectedDayID = tripDays.first?.id }
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
                onApply: updateTripDaysForDates
            )
            .tint(.primary)
        }
        .sheet(isPresented: $isPresentingAdd, onDismiss: {
            // Keep edit state consistent; prevents accidental "add" after an edit auto-save.
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
                days: tripDays,
                tripLocationRegion: trip.latitude != nil && trip.longitude != nil 
                    ? MKCoordinateRegion(
                        center: CLLocationCoordinate2D(
                            latitude: trip.latitude!,
                            longitude: trip.longitude!
                        ),
                        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                    )
                    : nil,
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
                days: tripDays,
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
                days: tripDays,
                isEditing: editingChecklist != nil,
                onSave: saveChecklist
            )
            .tint(.primary)
            .presentationDetents([.large])
        }
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
            mapRegion = appropriateMapRegion
        }
        .onChange(of: trip.longitude) { _, _ in
            mapRegion = appropriateMapRegion
        }
        .onChange(of: trip.mapSpan) { _, _ in
            mapRegion = appropriateMapRegion
        }
        .onChange(of: tripDays) { _, newDays in
            trip.days = newDays
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
            let tripHasNoEvents = tripDays.allSatisfy { $0.events.isEmpty }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(Array(tripDays.enumerated()), id: \.element.id) { index, day in
                        DayColumn(
                            day: day,
                            columnWidth: columnWidth,
                            columnHeight: geo.size.height - 24,
                            onTap: { event in startEditing(event: event, day: day) },
                            onEdit: { event in startEditing(event: event, day: day) },
                            onDelete: { event in deleteEvent(event) },
                            onTapReminder: { reminder in startEditingReminder(reminder, day: day) },
                            onDeleteReminder: { reminder in deleteReminder(reminder) },
                            onTapChecklist: { checklist in startEditingChecklist(checklist, day: day) },
                            onDeleteChecklist: { checklist in deleteChecklist(checklist) },
                            onAddEvent: {
                                selectedDayID = day.id
                                prepareNewEventDefaults()
                                isPresentingAdd = true
                            },
                            showEmptyPlaceholder: index == 0 && tripHasNoEvents
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
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
        if trip.days.isEmpty {
            updateTripDaysForDates()
        } else {
            tripDays = trip.days
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
                    label: existing.label,
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
        newEventAccent = .blue
        newEventPhoto = nil
        let base = Calendar.current.startOfDay(for: Date())
        newEventStart = base.addingTimeInterval(9 * 3600)
        newEventEnd = base.addingTimeInterval(10 * 3600)
    }

    func addNewEvent() {
        guard let dayID = selectedDayID,
              let dayIndex = tripDays.firstIndex(where: { $0.id == dayID }) else { return }

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

            // Idempotent update: remove existing instances (by id) then re-insert once.
            for idx in tripDays.indices {
                tripDays[idx].events.removeAll { $0.id == editingEvent.id }
            }
            tripDays[dayIndex].events.append(updated)
            self.editingEvent = updated
            return
        }

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

        tripDays[dayIndex].events.append(event)
        
        if let lat = newEventLatitude, let lon = newEventLongitude {
            withAnimation {
                mapRegion = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
        }
    }
    
    func addReminder() {
        guard let dayID = selectedDayID,
              let dayIndex = tripDays.firstIndex(where: { $0.id == dayID }) else { return }
        
        let trimmed = newReminderText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if let editingReminder {
            // Remove existing instances by id across all days, then insert once.
            for idx in tripDays.indices {
                tripDays[idx].reminders.removeAll { $0.id == editingReminder.id }
            }
            let updated = ReminderItem(id: editingReminder.id, text: trimmed, createdAt: editingReminder.createdAt)
            tripDays[dayIndex].reminders.insert(updated, at: 0)
            self.editingReminder = updated
        } else {
            let reminder = ReminderItem(id: UUID(), text: trimmed, createdAt: Date())
            tripDays[dayIndex].reminders.insert(reminder, at: 0)
        }
    }
    
    func saveChecklist() {
        guard let dayID = selectedDayID,
              let dayIndex = tripDays.firstIndex(where: { $0.id == dayID }) else { return }
        
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
            tripDays[dayIndex].checklists.insert(updated, at: 0)
            self.editingChecklist = updated
        } else {
            let checklist = ChecklistItem(
                id: UUID(),
                title: trimmedTitle,
                items: normalizedItems,
                createdAt: Date()
            )
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
            withAnimation(.easeInOut(duration: 0.5)) {
                mapRegion = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            }
        }
        
        isPresentingAdd = true
    }
    
    func openEventFromMarker(_ event: EventItem) {
        guard let day = tripDays.first(where: { $0.events.contains(event) }) else { return }
        startEditing(event: event, day: day)
    }
    
    func deleteCurrentEvent() {
        guard let event = editingEvent else { return }
        
        for dayIndex in tripDays.indices {
            if let eventIndex = tripDays[dayIndex].events.firstIndex(where: { $0.id == event.id }) {
                tripDays[dayIndex].events.remove(at: eventIndex)
                break
            }
        }
        
        editingEvent = nil
    }
    
    func deleteEvent(_ event: EventItem) {
        for dayIndex in tripDays.indices {
            if let eventIndex = tripDays[dayIndex].events.firstIndex(where: { $0.id == event.id }) {
                tripDays[dayIndex].events.remove(at: eventIndex)
                break
            }
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
    let columnWidth: CGFloat
    let columnHeight: CGFloat
    let onTap: (EventItem) -> Void
    let onEdit: (EventItem) -> Void
    let onDelete: (EventItem) -> Void
    let onTapReminder: (ReminderItem) -> Void
    let onDeleteReminder: (ReminderItem) -> Void
    let onTapChecklist: (ChecklistItem) -> Void
    let onDeleteChecklist: (ChecklistItem) -> Void
    let onAddEvent: () -> Void
    let showEmptyPlaceholder: Bool
    
    @State private var weatherMode: WeatherPillMode = .conditions

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(day.displayTitle)
                    .font(.headline)
                Text(day.displaySubtitle)
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
                    if day.events.isEmpty && showEmptyPlaceholder {
                        // Empty state placeholder - only on first day when trip has no events
                        Button {
                            onAddEvent()
                        } label: {
                            Text("Add Event")
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
                                        Button {
                                            onTapReminder(reminder)
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        
                                        Button(role: .destructive) {
                                            onDeleteReminder(reminder)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
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
                                        Button {
                                            onTapChecklist(checklist)
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        
                                        Button(role: .destructive) {
                                            onDeleteChecklist(checklist)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                    
                    ForEach(day.events.sorted { $0.startTimeMinutes < $1.startTimeMinutes }) { event in
                        EventCard(event: event)
                            .onTapGesture { onTap(event) }
                            .contextMenu {
                                Button {
                                    onEdit(event)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive) {
                                    onDelete(event)
                                } label: {
                                    Label("Delete", systemImage: "trash")
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
            Image(systemName: "lightbulb")
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
                        
                        HStack(spacing: 10) {
                            if idx < previewItems.count {
                                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(textColor.opacity(isDone ? 0.85 : 0.55))
                            } else {
                                Image(systemName: "circle")
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
                Text(event.time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                        .fill(LinearGradient(colors: [event.accentColor.opacity(0.3), .blue.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing))
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
    @Binding var name: String
    @Binding var location: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var mapSpan: Double?
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var coverImageData: Data?
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
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        coverImageData = coverImage?.jpegData(compressionQuality: 0.8)
                        onApply()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty || location.isEmpty)
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
    let days: [TripDay]
    let tripLocationRegion: MKCoordinateRegion?
    var onAdd: () -> Void
    var onDelete: (() -> Void)?
    var isEditing: Bool = false
    
    @State private var showImagePicker = false
    @State private var hasEndTime = true
    
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
        "ferry.fill",
        "bicycle",
        "figure.walk",
        // Food & Drink
        "fork.knife",
        "cup.and.saucer.fill",
        "wineglass.fill",
        "cart.fill",
        // Lodging
        "bed.double.fill",
        "house.fill",
        "building.2.fill",
        // Nature & Outdoors
        "mountain.2.fill",
        "water.waves",
        "leaf.fill",
        "sun.max.fill",
        "beach.umbrella.fill",
        // Activities & Sightseeing
        "camera.fill",
        "ticket.fill",
        "theatermasks.fill",
        "figure.hiking",
        // Landmarks & Places
        "building.columns.fill",
        "mappin.and.ellipse"
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
                        TextField("Event Name", text: $title)
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
                        ForEach(days) { day in
                            Text(day.displayTitle)
                                .tag(Optional(day.id))
                        }
                    }
                    DatePicker("From", selection: $startTime, displayedComponents: .hourAndMinute)
                    
                    Toggle("Add end time", isOn: $hasEndTime)
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
                                Text("Add Photo")
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
                                Text("Delete Event")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Event" : "Add Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
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
                hasEndTime = endTime > startTime
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
    let days: [TripDay]
    var isEditing: Bool = false
    var onAdd: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Day", selection: $selectedDayID) {
                        ForEach(days) { day in
                            Text(day.displayTitle)
                                .tag(Optional(day.id))
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
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Save" : "Add") {
                        onAdd()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(reminderText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedDayID == nil)
                }
            }
        }
    }
}

struct ChecklistSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var title: String
    @Binding var items: [ChecklistEntry]
    @Binding var selectedDayID: UUID?
    let days: [TripDay]
    var isEditing: Bool = false
    var onSave: () -> Void
    
    @State private var newItemText: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Day", selection: $selectedDayID) {
                        ForEach(days) { day in
                            Text(day.displayTitle)
                                .tag(Optional(day.id))
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
                    ForEach($items) { $item in
                        HStack(spacing: 12) {
                            Button {
                                let wasDone = item.isDone
                                item.isDone.toggle()
                                if !wasDone, item.isDone {
                                    Haptics.bump()
                                }
                            } label: {
                                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isDone ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                            
                            TextField("Item", text: $item.text)
                        }
                    }
                    .onDelete { offsets in
                        items.remove(atOffsets: offsets)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.secondary)
                        TextField("Add item", text: $newItemText)
                        Button("Add") {
                            let t = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !t.isEmpty else { return }
                            items.append(ChecklistEntry(id: UUID(), text: t, isDone: false))
                            newItemText = ""
                        }
                        .disabled(newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Checklist" : "New Checklist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Save" : "Create") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedDayID == nil)
                }
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
                  let coordinate = response.mapItems.first?.placemark.coordinate else {
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

class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer: MKLocalSearchCompleter
    
    var searchQuery: String = "" {
        didSet {
            completer.queryFragment = searchQuery
        }
    }
    
    init(resultTypes: MKLocalSearchCompleter.ResultType = .pointOfInterest, searchRegion: MKCoordinateRegion? = nil) {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = resultTypes
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

// MARK: - Models

struct EventAnnotation: Identifiable {
    let id: UUID
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
        case id, date, events, reminders, checklists, label, order, weatherIcon, temperatureF
    }
    
    init(id: UUID, date: Date, events: [EventItem], reminders: [ReminderItem] = [], checklists: [ChecklistItem] = [], label: String, order: Int, weatherIcon: String, temperatureF: Int) {
        self.id = id
        self.date = date
        self.events = events
        self.reminders = reminders
        self.checklists = checklists
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

enum EventAccent: String, Codable, CaseIterable, Hashable {
    case red, coral, orange, amber, yellow, lime, green, mint, teal, cyan, blue, indigo, purple, violet, pink

    var color: Color {
        switch self {
        case .red: return .red
        case .coral: return Color(red: 1.0, green: 0.5, blue: 0.4)
        case .orange: return .orange
        case .amber: return Color(red: 1.0, green: 0.75, blue: 0.0)
        case .yellow: return .yellow
        case .lime: return Color(red: 0.6, green: 0.8, blue: 0.2)
        case .green: return .green
        case .mint: return .mint
        case .teal: return .teal
        case .cyan: return .cyan
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .violet: return Color(red: 0.55, green: 0.35, blue: 0.85)
        case .pink: return .pink
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

