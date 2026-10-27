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
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isBreakdownExpanded = false
    @State private var showHeaderDivider = false
    @State private var breakdownExpandGeneration = 0
    
    private let breakdownExpandDuration: TimeInterval = 0.08
    
    private var dayBackground: Color { AppDetailSurface.page }
    private var columnStroke: Color { AppColor.divider }
    private var textPrimary: Color { AppColor.textStrong }
    private var textSecondary: Color { AppColor.textWeak }
    private var highlightStrokeColor: Color { colorScheme == .dark ? Color(hex: 0x5A5A5A) : Color(hex: 0xA8A8B0) }
    private var highlightFillColor: Color { colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.04) }
    private var inactiveSegmentColor: Color { colorScheme == .dark ? Color(hex: 0x3A3A3A) : Color(hex: 0xD0D0D6) }
    /// Stronger than `AppColor.divider` so the line stays visible on glass DayColumn chrome.
    private var headerDividerColor: Color {
        colorScheme == .dark ? Color(hex: 0x4A4A4A) : Color(hex: 0xD0D0D6)
    }
    
    private var dayBreakdown: DayBreakdown { DayBreakdown.make(from: day) }
    
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

    var body: some View {
        VStack(spacing: 0) {
            dayHeader
            dayContentScroll
        }
        .frame(width: max(columnWidth, 0), height: max(columnHeight, 0), alignment: .top)
        .modifier(DayColumnGlassChrome(
            isCurrentDay: isCurrentDay,
            dayBackground: dayBackground,
            columnStroke: columnStroke,
            highlightStrokeColor: highlightStrokeColor,
            highlightFillColor: highlightFillColor
        ))
    }
    
    private var dayHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                toggleDayBreakdown()
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isUnscheduled ? "No Date" : day.displayTitle)
                            .font(.app(15, weight: .semibold))
                            .foregroundStyle(textPrimary)
                        Text("Day \(day.order) of \(totalDays)")
                            .font(.appCaption)
                            .foregroundStyle(textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    AppIcon(
                        systemName: isBreakdownExpanded ? "chevron.up" : "chevron.down",
                        size: 24,
                        color: textSecondary
                    )
                    .padding(.top, 2)
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .zIndex(1)
            
            if isBreakdownExpanded {
                dayBreakdownExpanded
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    .transition(.opacity)
                    .zIndex(0)
            }
            
            // Consistent divider separating the header/breakdown from the list below (always visible).
            Rectangle()
                .fill(headerDividerColor)
                .frame(height: 1)
        }
        .clipped()
    }
    
    private func toggleDayBreakdown() {
        if isBreakdownExpanded {
            breakdownExpandGeneration += 1
            showHeaderDivider = false
            withAnimation(.easeOut(duration: 0.08)) {
                isBreakdownExpanded = false
            }
            return
        }
        
        breakdownExpandGeneration += 1
        let generation = breakdownExpandGeneration
        withAnimation(.easeOut(duration: 0.08)) {
            isBreakdownExpanded = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + breakdownExpandDuration) {
            guard generation == breakdownExpandGeneration, isBreakdownExpanded else { return }
            withAnimation(.easeOut(duration: 0.14)) {
                showHeaderDivider = true
            }
        }
    }
    
    private var dayBreakdownExpanded: some View {
        let breakdown = dayBreakdown
        let segments = breakdown.segments(inactiveColor: inactiveSegmentColor)
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(DayBreakdown.formatActive(breakdown.totalActiveMinutes))
                    .font(.app(17, weight: .semibold))
                    .foregroundStyle(textPrimary)
                Text("Total active")
                    .font(.appCaption)
                    .foregroundStyle(textSecondary)
            }
            
            GeometryReader { geo in
                let gap: CGFloat = 3
                let visible = segments.filter { $0.minutes > 0 }
                let gaps = CGFloat(max(visible.count - 1, 0)) * gap
                let rawWidth = geo.size.width
                let width = (rawWidth.isFinite && rawWidth > 0) ? rawWidth : 0
                let available = max(0, width - gaps)
                let dayTotal = CGFloat(DayBreakdown.dayMinutes)
                
                HStack(spacing: gap) {
                    ForEach(visible) { segment in
                        let segmentWidth: CGFloat = {
                            guard available > 0, dayTotal > 0 else { return 0 }
                            let value = available * CGFloat(segment.minutes) / dayTotal
                            guard value.isFinite, value >= 0 else { return 0 }
                            return value
                        }()
                        Capsule(style: .continuous)
                            .fill(segment.color)
                            .frame(width: segmentWidth)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(height: 7)
            
            HStack(spacing: 14) {
                ForEach(segments.filter { $0.id != "inactive" }) { segment in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(segment.color)
                            .frame(width: 7, height: 7)
                        Text(segment.title)
                            .font(.appCaption)
                            .foregroundStyle(textSecondary)
                        Text(DayBreakdown.formatHours(segment.minutes))
                            .font(.app(13, weight: .semibold))
                            .foregroundStyle(textPrimary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
    
    private var dayContentScroll: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
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
                                            Label("Move Left", menuIcon: "square.arrow.left")
                                        }
                                    }
                                    if day.order < totalDays {
                                        Button {
                                            onMoveReminderRight(reminder)
                                        } label: {
                                            Label("Move Right", menuIcon: "square.arrow.right")
                                        }
                                    }
                                    if let moveToParked = onMoveReminderToParked {
                                        Button {
                                            moveToParked(reminder)
                                        } label: {
                                            Label("Move to Ideas", menuIcon: "lightbulb")
                                        }
                                    }
                                    Divider()
                                    
                                    Button {
                                        onTapReminder(reminder)
                                    } label: {
                                        Label("Edit Reminder", menuIcon: "square.and.pencil")
                                    }
                                    
                                    Button(role: .destructive) {
                                        onDeleteReminder(reminder)
                                    } label: {
                                        Label("Delete Reminder", menuIcon: "trash")
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
                                            Label("Move Left", menuIcon: "square.arrow.left")
                                        }
                                    }
                                    if day.order < totalDays {
                                        Button {
                                            onMoveChecklistRight(checklist)
                                        } label: {
                                            Label("Move Right", menuIcon: "square.arrow.right")
                                        }
                                    }
                                    if let moveToParked = onMoveChecklistToParked {
                                        Button {
                                            moveToParked(checklist)
                                        } label: {
                                            Label("Move to Ideas", menuIcon: "lightbulb")
                                        }
                                    }
                                    Divider()
                                    
                                    Button {
                                        onTapChecklist(checklist)
                                    } label: {
                                        Label("Edit Checklist", menuIcon: "square.and.pencil")
                                    }
                                    
                                    Button(role: .destructive) {
                                        onDeleteChecklist(checklist)
                                    } label: {
                                        Label("Delete Checklist", menuIcon: "trash")
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
                                        Label("Move Left", menuIcon: "square.arrow.left")
                                    }
                                }
                                if day.order < totalDays {
                                    Button {
                                        onMoveFlightRight(flight)
                                    } label: {
                                        Label("Move Right", menuIcon: "square.arrow.right")
                                    }
                                }
                                if let moveToParked = onMoveFlightToParked {
                                    Button {
                                        moveToParked(flight)
                                    } label: {
                                        Label("Move to Ideas", menuIcon: "lightbulb")
                                    }
                                }
                                Divider()
                                
                                Button {
                                    onTapFlight(flight)
                                } label: {
                                    Label("Edit Travel", menuIcon: "square.and.pencil")
                                }
                                
                                Button(role: .destructive) {
                                    onDeleteFlight(flight)
                                } label: {
                                    Label("Delete Travel", menuIcon: "trash")
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
                                        Label("Move Left", menuIcon: "square.arrow.left")
                                    }
                                }
                                if day.order < totalDays {
                                    Button {
                                        onMoveEventRight(event)
                                    } label: {
                                        Label("Move Right", menuIcon: "square.arrow.right")
                                    }
                                }
                                if let moveToParked = onMoveEventToParked {
                                    Button {
                                        moveToParked(event)
                                    } label: {
                                        Label("Move to Ideas", menuIcon: "lightbulb")
                                    }
                                }
                                Divider()
                                
                                Button {
                                    onEdit(event)
                                } label: {
                                    Label("Edit Activity", menuIcon: "square.and.pencil")
                                }
                                
                                Button {
                                    onDuplicate(event)
                                } label: {
                                    Label("Duplicate Activity", menuIcon: "doc.on.doc")
                                }
                                
                                Button(role: .destructive) {
                                    onDelete(event)
                                } label: {
                                    Label("Delete Activity", menuIcon: "trash")
                                }
                            }
                    }
                }
                
                Spacer(minLength: 20)
            }
            .padding(14)
        }
    }
}

/// Liquid glass day-column chrome in dark mode on iOS 26+; solid fill + stroke in light
/// mode (and on earlier OS) so columns stay visible against the sheet.
struct DayColumnGlassChrome: ViewModifier {
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

