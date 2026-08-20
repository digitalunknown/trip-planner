import SwiftUI

struct DayColumn: View {
    let day: TripDay
    let totalDays: Int
    let isUnscheduled: Bool
    let isCurrentDay: Bool
    let columnWidth: CGFloat
    let columnHeight: CGFloat
    let onTap: (EventItem) -> Void
    let onEdit: (EventItem) -> Void
    let onDuplicate: (EventItem) -> Void
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
    var onPlanDay: (() -> Void)? = nil
    let showEmptyPlaceholder: Bool
    /// When true, empty-state CTA is fully visible; otherwise it animates completely out.
    var isEmptyStateFocused: Bool = true
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var dayBackground: Color { colorScheme == .dark ? Color(hex: 0x171717) : Color(hex: 0xF0F0F0) }
    private var columnStroke: Color { colorScheme == .dark ? Color(hex: 0x252525) : Color(hex: 0xD0D0D6) }
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var textSecondary: Color { textPrimary.opacity(colorScheme == .dark ? 0.72 : 0.62) }
    private var highlightStrokeColor: Color { colorScheme == .dark ? Color(hex: 0x5A5A5A) : Color(hex: 0xA8A8B0) }
    private var highlightFillColor: Color { colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.04) }
    
    private struct TimedRow: Identifiable {
        enum Kind {
            case flight(FlightItem)
            case activity(EventItem)
        }
        
        let id: String
        let minutes: Int
        let orderIndex: Int
        let kind: Kind
    }
    
    private var timelineRows: [TimedRow] {
        let flightRows = day.flights.enumerated().map { idx, flight in
            let cal = Calendar.current
            let comps = cal.dateComponents([.hour, .minute], from: flight.startTime)
            var minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            
            // If a flight started the previous night but is attached to this day,
            // force it to appear at the top of the timeline.
            if !cal.isDate(flight.startTime, inSameDayAs: day.date),
               flight.startTime < cal.startOfDay(for: day.date) {
                minutes = -1
            }
            return TimedRow(id: "flight-\(flight.id)", minutes: minutes, orderIndex: idx, kind: .flight(flight))
        }
        
        let activityRows = day.events.enumerated().map { idx, event in
            TimedRow(id: "activity-\(event.id)", minutes: event.startTimeMinutes, orderIndex: idx, kind: .activity(event))
        }
        
        return (flightRows + activityRows)
            .sorted { a, b in
                if a.minutes != b.minutes { return a.minutes < b.minutes }
                // Tie-break: flights first, then activities
                switch (a.kind, b.kind) {
                case (.flight, .activity): return true
                case (.activity, .flight): return false
                default: return a.orderIndex < b.orderIndex
                }
            }
    }

    private var isDayEmpty: Bool {
        day.events.isEmpty && day.reminders.isEmpty && day.checklists.isEmpty && day.flights.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isUnscheduled ? "No Date" : day.displayTitle)
                    .font(.app(17, weight: .semibold))
                    .foregroundStyle(textPrimary)
                Text("Day \(day.order) of \(totalDays)")
                    .font(.appCaption)
                    .foregroundStyle(textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)

            if isDayEmpty && showEmptyPlaceholder {
                dayEmptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(isEmptyStateFocused ? 1 : 0)
                    .scaleEffect(isEmptyStateFocused ? 1 : 0.92, anchor: .center)
                    .allowsHitTesting(isEmptyStateFocused)
                    .animation(.easeInOut(duration: 0.32), value: isEmptyStateFocused)
            } else {
                dayContentScroll
            }
        }
        .frame(width: columnWidth, height: columnHeight, alignment: .top)
        .modifier(DayColumnGlassChrome(
            isCurrentDay: isCurrentDay,
            dayBackground: dayBackground,
            columnStroke: columnStroke,
            highlightStrokeColor: highlightStrokeColor,
            highlightFillColor: highlightFillColor
        ))
    }
    
    private var dayContentScroll: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 10) {
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
                                            Label("Move to Ideas", systemImage: "arrow.right")
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
                                    .tint(.red)
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
                                            Label("Move to Ideas", systemImage: "arrow.right")
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
                                    .tint(.red)
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
                                        Label("Move to Ideas", systemImage: "arrow.right")
                                    }
                                }
                                Divider()
                                
                                Button {
                                    onTapFlight(flight)
                                } label: {
                                    Label("Edit Travel", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive) {
                                    onDeleteFlight(flight)
                                } label: {
                                    Label("Delete Travel", systemImage: "trash")
                                }
                                .tint(.red)
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
                                        Label("Move to Ideas", systemImage: "arrow.right")
                                    }
                                }
                                Divider()
                                
                                Button {
                                    onEdit(event)
                                } label: {
                                    Label("Edit Activity", systemImage: "pencil")
                                }
                                
                                Button {
                                    onDuplicate(event)
                                } label: {
                                    Label("Duplicate Activity", systemImage: "doc.on.doc")
                                }
                                
                                Button(role: .destructive) {
                                    onDelete(event)
                                } label: {
                                    Label("Delete Activity", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                    }
                }
                
                Spacer(minLength: 20)
            }
            .padding(14)
        }
    }
    
    private var dayEmptyState: some View {
        ViewThatFits(in: .vertical) {
            emptyStateStack(spacing: 18, showsMessage: true)
            emptyStateStack(spacing: 10, showsMessage: true)
            emptyStateStack(spacing: 0, showsMessage: false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func emptyStateStack(spacing: CGFloat, showsMessage: Bool) -> some View {
        VStack(spacing: spacing) {
            if showsMessage {
                Text("You haven’t added anything to this day yet")
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)
            }
            
            Button {
                onPlanDay?()
            } label: {
                Label("Plan Day", systemImage: "sparkles")
            }
            .buttonStyle(.primaryCapsule)
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Liquid glass day-column chrome in dark mode on iOS 26+; solid fill + stroke in light
/// mode (and on earlier OS) so columns stay visible against the sheet.
private struct DayColumnGlassChrome: ViewModifier {
    let isCurrentDay: Bool
    let dayBackground: Color
    let columnStroke: Color
    let highlightStrokeColor: Color
    let highlightFillColor: Color
    
    @Environment(\.colorScheme) private var colorScheme
    
    private let cornerRadius: CGFloat = 20
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
    
    private var borderColor: Color {
        isCurrentDay ? highlightStrokeColor : columnStroke
    }
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), colorScheme == .dark {
            content
                .glassEffect(.regular, in: shape)
                .clipShape(shape)
                .overlay {
                    shape
                        .strokeBorder(
                            isCurrentDay ? highlightStrokeColor : Color.clear,
                            lineWidth: isCurrentDay ? 1 : 0
                        )
                        .shadow(
                            color: isCurrentDay ? highlightStrokeColor.opacity(0.35) : .clear,
                            radius: 2,
                            x: 0,
                            y: 0
                        )
                }
        } else {
            content
                .background(
                    shape
                        .fill(dayBackground)
                        .overlay(
                            shape
                                .fill(isCurrentDay ? highlightFillColor : .clear)
                        )
                )
                .clipShape(shape)
                .overlay {
                    shape
                        .strokeBorder(borderColor, lineWidth: 1)
                        .shadow(
                            color: isCurrentDay ? highlightStrokeColor.opacity(0.35) : .clear,
                            radius: 2,
                            x: 0,
                            y: 0
                        )
                }
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.08 : 0.06),
                    radius: colorScheme == .dark ? 18 : 10,
                    x: 0,
                    y: colorScheme == .dark ? 14 : 4
                )
        }
    }
}

