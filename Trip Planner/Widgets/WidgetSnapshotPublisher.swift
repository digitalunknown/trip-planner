import Foundation
import SwiftUI
import UIKit
import WidgetKit

enum WidgetSnapshotPublisher {
    static func publish(trips: [Trip], lastTouchedID: UUID? = nil, now: Date = Date()) {
        let envelope: WidgetSnapshotEnvelope
        if let snapshot = WidgetSnapshotBuilder.build(trips: trips, lastTouchedID: lastTouchedID, now: now) {
            envelope = WidgetSnapshotEnvelope(trip: snapshot, lastUpdated: now)
        } else {
            envelope = WidgetSnapshotEnvelope(trip: nil, lastUpdated: now)
        }
        
        let cover = thumbnailJPEG(from: selectedCoverData(in: trips, snapshot: envelope.trip))
        var written = envelope
        written.trip?.coverFileName = cover == nil ? nil : WidgetAppGroup.coverFile
        WidgetSnapshotStore.write(written, coverJPEG: cover)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKindID.trip)
        WidgetCenter.shared.reloadAllTimelines()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetKindID.trip)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    private static func selectedCoverData(in trips: [Trip], snapshot: WidgetTripSnapshot?) -> Data? {
        guard let snapshot else { return nil }
        return trips.first(where: { $0.id == snapshot.tripID })?.coverImageData
    }
    
    private static func thumbnailJPEG(from data: Data?) -> Data? {
        guard let data, let image = UIImage(data: data) else { return nil }
        let maxSide: CGFloat = 480
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let renderer = UIGraphicsImageRenderer(size: target)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: 0.72)
    }
}

enum WidgetSnapshotBuilder {
    static func build(trips: [Trip], lastTouchedID: UUID?, now: Date) -> WidgetTripSnapshot? {
        guard let trip = selectTrip(in: trips, lastTouchedID: lastTouchedID, now: now) else { return nil }
        let calendar = Calendar.current
        let day = selectDay(in: trip, now: now, calendar: calendar)
        let items = upcomingItems(on: day, now: now, calendar: calendar, limit: 3)
        let selection = selectionKind(for: trip, now: now, calendar: calendar)
        let resolvedDayDate = day.map { calendar.startOfDay(for: $0.date) }
            ?? (trip.isDatesSet ? calendar.startOfDay(for: trip.startDate) : nil)
        
        return WidgetTripSnapshot(
            tripID: trip.id,
            tripName: trip.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? (trip.destination.isEmpty ? "Trip" : trip.destination)
                : trip.name,
            destination: trip.destination,
            coverFileName: nil,
            tintHex: tintHex(for: trip),
            dateMode: trip.isDatesSet ? .dated : .undated,
            selection: selection,
            statusLine: statusLine(for: trip, day: day, selection: selection, now: now, calendar: calendar),
            dayID: day?.id,
            dayLabel: dayLabel(for: trip, day: day, calendar: calendar),
            dayDate: resolvedDayDate,
            items: items,
            ideaCount: ideaCount(in: trip),
            lastUpdated: now,
            dayNumber: day?.order ?? 1,
            dateSpanText: dateSpanText(for: trip, calendar: calendar),
            followingDays: followingDays(after: day, in: trip, calendar: calendar)
        )
    }
    
    static func selectTrip(in trips: [Trip], lastTouchedID: UUID?, now: Date) -> Trip? {
        let realTrips = trips.filter { $0.id != WidgetKnownTripID.onboardingSample }
        let pool = realTrips.isEmpty ? trips : realTrips
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        
        let inProgress = pool.filter { trip in
            guard trip.isDatesSet else { return false }
            let start = calendar.startOfDay(for: trip.startDate)
            let end = calendar.startOfDay(for: trip.endDate)
            return today >= start && today <= end
        }.sorted { $0.startDate < $1.startDate }
        if let trip = inProgress.first { return trip }
        
        let upcoming = pool.filter { trip in
            guard trip.isDatesSet else { return false }
            return calendar.startOfDay(for: trip.startDate) > today
        }.sorted { $0.startDate < $1.startDate }
        if let trip = upcoming.first { return trip }
        
        let unscheduled = pool.filter { !$0.isDatesSet }
        if let lastTouchedID, let trip = unscheduled.first(where: { $0.id == lastTouchedID }) {
            return trip
        }
        if let trip = unscheduled.last { return trip }
        
        return pool
            .filter { $0.isDatesSet && calendar.startOfDay(for: $0.endDate) < today }
            .sorted { $0.endDate > $1.endDate }
            .first
    }
    
    private static func selectionKind(for trip: Trip, now: Date, calendar: Calendar) -> WidgetTripSelection {
        guard trip.isDatesSet else { return .unscheduled }
        let today = calendar.startOfDay(for: now)
        let start = calendar.startOfDay(for: trip.startDate)
        let end = calendar.startOfDay(for: trip.endDate)
        if today >= start && today <= end { return .inProgress }
        if start > today { return .upcoming }
        return .past
    }
    
    private static func selectDay(in trip: Trip, now: Date, calendar: Calendar) -> TripDay? {
        let days = trip.days.sorted { $0.order < $1.order }
        guard !days.isEmpty else { return nil }
        
        if trip.isDatesSet {
            let today = calendar.startOfDay(for: now)
            if let todayDay = days.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
                if hasItems(todayDay) { return todayDay }
                if let next = days.first(where: {
                    calendar.startOfDay(for: $0.date) > today && hasItems($0)
                }) {
                    return next
                }
                return todayDay
            }
            if today < calendar.startOfDay(for: trip.startDate) {
                return days.first(where: { hasItems($0) }) ?? days.first
            }
        }
        return days.first(where: { hasItems($0) }) ?? days.first
    }
    
    private static func hasItems(_ day: TripDay) -> Bool {
        !day.events.isEmpty || !day.flights.isEmpty || !day.checklists.isEmpty || !day.reminders.isEmpty
    }
    
    private static func upcomingItems(on day: TripDay?, now: Date, calendar: Calendar, limit: Int) -> [WidgetTripItem] {
        guard let day else { return [] }
        let nowMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let isToday = calendar.isDateInToday(day.date)
        
        var rows: [(item: WidgetTripItem, minutes: Int, hasTime: Bool, order: Int)] = []
        
        for (idx, flight) in day.flights.enumerated() {
            let comps = calendar.dateComponents([.hour, .minute], from: flight.startTime)
            let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            rows.append((makeFlightItem(flight, minutes: minutes), minutes, true, idx))
        }
        for (idx, event) in day.events.enumerated() {
            let trimmed = event.time.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasTime = !trimmed.isEmpty
            let minutes = event.startTimeMinutes
            rows.append((makeEventItem(event, hasTime: hasTime), minutes, hasTime, 100 + idx))
        }
        for (idx, checklist) in day.checklists.enumerated() {
            let icon = resolvedIconName("list-checks")
            let accent = EventAccent.mustard.backgroundHex
            let foreground = EventAccent.mustard.foregroundHex
            rows.append((
                WidgetTripItem(
                    id: checklist.id,
                    kind: .checklist,
                    title: checklist.title,
                    startTime: nil,
                    startMinutes: nil,
                    icon: icon,
                    accentHex: accent,
                    accentForegroundHex: foreground,
                    iconPNG: rasterizeBadge(icon: icon, backgroundHex: accent, foregroundHex: foreground)
                ),
                24 * 60 + idx,
                false,
                200 + idx
            ))
        }
        for (idx, reminder) in day.reminders.enumerated() {
            let icon = resolvedIconName("pin")
            let accent = EventAccent.cream.backgroundHex
            let foreground = EventAccent.cream.foregroundHex
            rows.append((
                WidgetTripItem(
                    id: reminder.id,
                    kind: .reminder,
                    title: reminder.text,
                    startTime: nil,
                    startMinutes: nil,
                    icon: icon,
                    accentHex: accent,
                    accentForegroundHex: foreground,
                    iconPNG: rasterizeBadge(icon: icon, backgroundHex: accent, foregroundHex: foreground)
                ),
                24 * 60 + 50 + idx,
                false,
                300 + idx
            ))
        }
        
        let filtered = rows.filter { row in
            guard isToday, row.hasTime else { return true }
            return row.minutes >= nowMinutes
        }
        let source = filtered.isEmpty ? rows : filtered
        
        return source
            .sorted { a, b in
                if a.hasTime != b.hasTime { return a.hasTime && !b.hasTime }
                if a.minutes != b.minutes { return a.minutes < b.minutes }
                return a.order < b.order
            }
            .prefix(limit)
            .map(\.item)
    }
    
    private static func makeFlightItem(_ flight: FlightItem, minutes: Int) -> WidgetTripItem {
        let from = flight.fromCode.isEmpty ? flight.fromCity : flight.fromCode
        let to = flight.toCode.isEmpty ? flight.toCity : flight.toCode
        let title: String
        if !from.isEmpty && !to.isEmpty {
            title = "\(from) → \(to)"
        } else if !flight.flightNumber.isEmpty {
            title = flight.flightNumber
        } else {
            title = "Flight"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let icon = resolvedIconName(flight.travelMode.systemImageName)
        let accent = flight.accent.backgroundHex
        let foreground = flight.accent.foregroundHex
        return WidgetTripItem(
            id: flight.id,
            kind: .flight,
            title: title,
            startTime: formatter.string(from: flight.startTime),
            startMinutes: minutes,
            icon: icon,
            accentHex: accent,
            accentForegroundHex: foreground,
            iconPNG: rasterizeBadge(icon: icon, backgroundHex: accent, foregroundHex: foreground)
        )
    }
    
    private static func makeEventItem(_ event: EventItem, hasTime: Bool) -> WidgetTripItem {
        let start = event.time
            .replacingOccurrences(of: "–", with: "-")
            .split(separator: "-", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let iconKey = event.icon.lowercased()
        let kind: WidgetItemKind = (iconKey.contains("bed") || iconKey.contains("hotel")) ? .hotel : .activity
        let icon = resolvedIconName(event.icon)
        let accent = event.accent.backgroundHex
        let foreground = event.accent.foregroundHex
        return WidgetTripItem(
            id: event.id,
            kind: kind,
            title: event.title.isEmpty ? "Untitled" : event.title,
            startTime: hasTime ? start : nil,
            startMinutes: hasTime ? event.startTimeMinutes : nil,
            icon: icon,
            accentHex: accent,
            accentForegroundHex: foreground,
            iconPNG: rasterizeBadge(icon: icon, backgroundHex: accent, foregroundHex: foreground)
        )
    }
    
    private static func resolvedIconName(_ raw: String) -> String {
        AppLucide.lucideName(forSystemName: raw) ?? raw
    }
    
    private static func rasterizeBadge(icon: String, backgroundHex: UInt32, foregroundHex: UInt32) -> Data? {
        WidgetIconRasterizer.png(icon: icon, backgroundHex: backgroundHex, foregroundHex: foregroundHex)
    }
    
    private static func statusLine(
        for trip: Trip,
        day: TripDay?,
        selection: WidgetTripSelection,
        now: Date,
        calendar: Calendar
    ) -> String {
        switch selection {
        case .unscheduled:
            return "Unscheduled"
        case .past:
            return "Ended"
        case .upcoming:
            let days = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: trip.startDate)).day ?? 0)
            if days == 0 { return "Today" }
            if days == 1 { return "Tomorrow" }
            return "in \(days) days"
        case .inProgress:
            let order = day?.order ?? 1
            if let day, calendar.isDateInToday(day.date) {
                return "Today · Day \(order)"
            }
            if let day, calendar.isDateInTomorrow(day.date) {
                return "Tomorrow"
            }
            return "Day \(order)"
        }
    }
    
    private static func dayLabel(for trip: Trip, day: TripDay?, calendar: Calendar) -> String {
        if let day {
            return trip.isDatesSet ? day.displayTitle : "Day \(day.order)"
        }
        guard trip.isDatesSet else { return "Day 1" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: calendar.startOfDay(for: trip.startDate))
    }
    
    private static func dateSpanText(for trip: Trip, calendar: Calendar) -> String? {
        guard trip.isDatesSet else { return nil }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        let start = formatter.string(from: calendar.startOfDay(for: trip.startDate))
        let end = formatter.string(from: calendar.startOfDay(for: trip.endDate))
        if start == end { return start }
        return "\(start) – \(end)"
    }
    
    private static func followingDays(after day: TripDay?, in trip: Trip, calendar: Calendar) -> [WidgetDayPeek] {
        let days = trip.days.sorted { $0.order < $1.order }
        let startIndex: Int
        if let day, let idx = days.firstIndex(where: { $0.id == day.id }) {
            startIndex = idx + 1
        } else {
            startIndex = min(1, days.count)
        }
        return days.dropFirst(startIndex).prefix(2).map { next in
            let first = upcomingItems(on: next, now: next.date, calendar: calendar, limit: 1).first
            return WidgetDayPeek(
                id: next.id,
                label: trip.isDatesSet ? next.displayTitle : "Day \(next.order)",
                detail: first?.title ?? "Open",
                itemCount: next.events.count + next.flights.count + next.checklists.count + next.reminders.count
            )
        }
    }
    
    private static func ideaCount(in trip: Trip) -> Int {
        trip.days.reduce(0) { $0 + $1.events.count + $1.flights.count + $1.checklists.count + $1.reminders.count }
            + trip.parkedIdeas.count
    }
    
    private static func tintHex(for trip: Trip) -> UInt32 {
        let tints: [UInt32] = [0xFF8B00, 0xB2A1FF, 0x7EE0B0, 0xFED130, 0xFF7701]
        let idx = abs(trip.id.hashValue) % tints.count
        return tints[idx]
    }
}

enum WidgetIconRasterizer {
    @MainActor
    static func png(icon: String, backgroundHex: UInt32, foregroundHex: UInt32, side: CGFloat = 54) -> Data? {
        let view = ZStack {
            RoundedRectangle(cornerRadius: side * 0.28, style: .continuous)
                .fill(Color(hex: backgroundHex))
            AppIcon(systemName: icon, size: side * 0.52, color: Color(hex: foregroundHex))
        }
        .frame(width: side, height: side)
        
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        renderer.isOpaque = false
        return renderer.uiImage?.pngData()
    }
}
