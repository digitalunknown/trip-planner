import SwiftUI
import WidgetKit

struct TripStacksWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetTripSnapshot?
    let coverData: Data?
}

struct TripStacksTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TripStacksWidgetEntry {
        TripStacksWidgetEntry(date: Date(), snapshot: nil, coverData: nil)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TripStacksWidgetEntry) -> Void) {
        let real = currentEntry()
        if real.snapshot != nil {
            completion(real)
            return
        }
        // Gallery only. Never put canvas fixtures on the Home Screen.
        if context.isPreview {
            completion(TripStacksWidgetEntry(date: Date(), snapshot: .previewInProgress, coverData: nil))
            return
        }
        completion(real)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TripStacksWidgetEntry>) -> Void) {
        let base = currentEntry()
        // If there is no snapshot yet, avoid 15s polling — the app will publish and reload timelines.
        guard let snapshot = base.snapshot else {
            completion(Timeline(entries: [base], policy: .never))
            return
        }
        
        // Produce entries at relevant boundaries so text (“in N days”, “Today”) and passed items
        // advance without a new publish: now, each item start, the next midnight, and (for upcoming)
        // the start of the selected day.
        let now = Date()
        let calendar = Calendar.current
        var times: [Date] = [now]
        
        if let midnight = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) {
            times.append(midnight)
        }
        if snapshot.selection == .upcoming, let dayDate = snapshot.dayDate {
            times.append(calendar.startOfDay(for: dayDate))
        }
        if let dayDate = snapshot.dayDate {
            for item in snapshot.items {
                guard let minutes = item.startMinutes else { continue }
                if let date = calendar.date(byAdding: .minute, value: minutes, to: calendar.startOfDay(for: dayDate)),
                   date > now {
                    times.append(date)
                }
            }
        }
        
        // Deduplicate and clamp to a reasonable horizon.
        let uniqueSorted = Array(Set(times)).sorted()
        let firstFew = Array(uniqueSorted.prefix(10))
        let entries = firstFew.map { when in
            TripStacksWidgetEntry(date: when, snapshot: snapshot, coverData: base.coverData)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
    
    private func currentEntry() -> TripStacksWidgetEntry {
        let result = WidgetSnapshotStore.read()
        let trip = result.envelope?.trip
        if let trip, trip.isCanvasPreview {
            return TripStacksWidgetEntry(date: Date(), snapshot: nil, coverData: nil)
        }
        return TripStacksWidgetEntry(
            date: Date(),
            snapshot: trip,
            coverData: trip == nil ? nil : WidgetSnapshotStore.readCoverJPEG()
        )
    }
}

struct TripStacksWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKindID.trip, provider: TripStacksTimelineProvider()) { entry in
            TripStacksWidgetView(entry: entry)
                .widgetAccentable() // adopt system-tinted/accented rendering where appropriate
                .containerBackground(for: .widget) {
                    WidgetPalette.page
                }
        }
        .configurationDisplayName("TripStacks")
        .description("See the trip that matters now — today’s stack or what’s next.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

@main
struct TripStacksWidgetBundle: WidgetBundle {
    var body: some Widget {
        TripStacksWidget()
    }
}

#Preview("Small upcoming empty", as: .systemSmall) {
    TripStacksWidget()
} timeline: {
    TripStacksWidgetEntry(date: .now, snapshot: .previewEmptyDay, coverData: nil)
}

#Preview("Small in progress", as: .systemSmall) {
    TripStacksWidget()
} timeline: {
    TripStacksWidgetEntry(date: .now, snapshot: .previewInProgress, coverData: nil)
}

#Preview("Medium upcoming empty", as: .systemMedium) {
    TripStacksWidget()
} timeline: {
    TripStacksWidgetEntry(date: .now, snapshot: .previewEmptyDay, coverData: nil)
}

#Preview("Medium in progress", as: .systemMedium) {
    TripStacksWidget()
} timeline: {
    TripStacksWidgetEntry(date: .now, snapshot: .previewInProgress, coverData: nil)
}

#Preview("Small unscheduled", as: .systemSmall) {
    TripStacksWidget()
} timeline: {
    TripStacksWidgetEntry(date: .now, snapshot: .previewUnscheduled, coverData: nil)
}

#Preview("Medium unscheduled", as: .systemMedium) {
    TripStacksWidget()
} timeline: {
    TripStacksWidgetEntry(date: .now, snapshot: .previewUnscheduled, coverData: nil)
}

#Preview("Large upcoming empty", as: .systemLarge) {
    TripStacksWidget()
} timeline: {
    TripStacksWidgetEntry(date: .now, snapshot: .previewEmptyDay, coverData: nil)
}

#Preview("Large in progress", as: .systemLarge) {
    TripStacksWidget()
} timeline: {
    TripStacksWidgetEntry(date: .now, snapshot: .previewInProgress, coverData: nil)
}

#Preview("Missing snapshot", as: .systemMedium) {
    TripStacksWidget()
} timeline: {
    TripStacksWidgetEntry(date: .now, snapshot: nil, coverData: nil)
}
