import SwiftUI

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

private extension DayColumn {
    var dayBackground: Color {
        Color(.secondarySystemBackground).opacity(0.7)
    }
}

