import SwiftUI
import UIKit
import WidgetKit

private func dynamicStatusLine(for snapshot: WidgetTripSnapshot, now: Date) -> String {
    let calendar = Calendar.current
    switch snapshot.selection {
    case .unscheduled:
        return "Unscheduled"
    case .past:
        return "Ended"
    case .upcoming:
        guard let dayDate = snapshot.dayDate else { return "" }
        let days = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: dayDate)).day ?? 0)
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "in \(days) days"
    case .inProgress:
        let order = snapshot.resolvedDayNumber
        if let dayDate = snapshot.dayDate {
            if calendar.isDateInToday(dayDate) { return "Today · Day \(order)" }
            if calendar.isDateInTomorrow(dayDate) { return "Tomorrow" }
        }
        return "Day \(order)"
    }
}

private func dynamicRichStatus(for snapshot: WidgetTripSnapshot, now: Date) -> String {
    let status = dynamicStatusLine(for: snapshot, now: now)
    let dayPart = "Day \(snapshot.resolvedDayNumber)"
    switch snapshot.selection {
    case .upcoming:
        return [dayPart, snapshot.dayLabel, status]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    case .inProgress:
        if status.localizedCaseInsensitiveContains("day") {
            if !snapshot.dayLabel.isEmpty, !status.localizedCaseInsensitiveContains(snapshot.dayLabel) {
                return "\(status) · \(snapshot.dayLabel)"
            }
            return status
        }
        return [status, dayPart, snapshot.dayLabel]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    case .unscheduled:
        return [dayPart, status].filter { !$0.isEmpty }.joined(separator: " · ")
    case .past:
        return [snapshot.dayLabel, status].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

private func visibleItems(for snapshot: WidgetTripSnapshot, now: Date) -> [WidgetTripItem] {
    guard let dayDate = snapshot.dayDate else { return snapshot.items }
    let calendar = Calendar.current
    if !calendar.isDate(calendar.startOfDay(for: now), inSameDayAs: calendar.startOfDay(for: dayDate)) {
        return snapshot.items
    }
    let minutesNow = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
    let filtered = snapshot.items.filter { item in
        guard let mins = item.startMinutes else { return true }
        return mins >= minutesNow
    }
    return filtered.isEmpty ? snapshot.items : filtered
}

enum WidgetPalette {
    static let page = Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255)
    static let card = Color(red: 23 / 255, green: 23 / 255, blue: 23 / 255)
    static let elevated = Color(red: 38 / 255, green: 38 / 255, blue: 38 / 255)
    static let textStrong = Color(red: 244 / 255, green: 245 / 255, blue: 245 / 255)
    static let textSecondary = Color(red: 186 / 255, green: 186 / 255, blue: 186 / 255)
    static let textWeak = Color(red: 138 / 255, green: 138 / 255, blue: 138 / 255)
    static let accent = Color(red: 1, green: 139 / 255, blue: 0)
    static let purple = Color(red: 178 / 255, green: 161 / 255, blue: 1)
    static let mint = Color(red: 126 / 255, green: 224 / 255, blue: 176 / 255)
    static let yellow = Color(red: 254 / 255, green: 209 / 255, blue: 48 / 255)
    
    static func kindColor(_ kind: WidgetItemKind) -> Color {
        switch kind {
        case .flight: return accent
        case .activity: return purple
        case .hotel: return purple
        case .checklist: return mint
        case .reminder: return yellow
        }
    }
}

struct TripStacksWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TripStacksWidgetEntry
    
    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                switch family {
                case .systemSmall:
                    SmallTripWidget(snapshot: snapshot, coverData: entry.coverData, now: entry.date)
                case .systemLarge:
                    LargeTripWidget(snapshot: snapshot, coverData: entry.coverData, now: entry.date)
                default:
                    MediumTripWidget(snapshot: snapshot, coverData: entry.coverData, now: entry.date)
                }
            } else {
                EmptyTripWidget(compact: family == .systemSmall)
            }
        }
        .foregroundStyle(WidgetPalette.textStrong)
    }
}

private struct EmptyTripWidget: View {
    var compact: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 12) {
            Text("TripStacks")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WidgetPalette.accent)
            Text("Open TripStacks to see your trip")
                .font(.system(size: compact ? 15 : 17, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            WidgetGhostStack(compact: true)
            Spacer(minLength: 0)
        }
        .padding(compact ? 14 : 16)
    }
}

private struct SmallTripWidget: View {
    let snapshot: WidgetTripSnapshot
    let coverData: Data?
    let now: Date
    
    var body: some View {
        // In small, Links are ignored — route via widgetURL. For empty days, send Plan Day.
        let deepLink: WidgetDeepLink = {
            if snapshot.items.isEmpty {
                return .planDay(trip: snapshot.tripID, day: snapshot.dayID)
            }
            return snapshot.dayID.map { WidgetDeepLink.day(trip: snapshot.tripID, day: $0) }
                ?? .trip(snapshot.tripID)
        }()
        let status = dynamicStatusLine(for: snapshot, now: now)
        let items = visibleItems(for: snapshot, now: now)
        
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(snapshot.tripName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(WidgetPalette.textSecondary)
                        .lineLimit(1)
                    Text(status)
                        .font(.system(size: items.isEmpty ? 20 : 13, weight: .semibold))
                        .foregroundStyle(items.isEmpty ? WidgetPalette.textStrong : WidgetPalette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                CoverThumb(coverData: coverData, tintHex: snapshot.tintHex, size: 34, radius: 10)
            }
            
            if items.isEmpty {
                WidgetEmptyStackCard(
                    title: snapshot.emptyDayPrompt,
                    planTitle: "Plan",
                    planURL: nil, // ignored in small — widgetURL handles it
                    compact: true
                )
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(items.prefix(3))) { item in
                        SmallActivityRow(item: item)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .widgetURL(deepLink.url)
    }
}

private struct MediumTripWidget: View {
    let snapshot: WidgetTripSnapshot
    let coverData: Data?
    let now: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Link(destination: WidgetDeepLink.trip(snapshot.tripID).url) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(snapshot.tripName)
                            .font(.system(size: 17, weight: .semibold))
                            .lineLimit(1)
                        Text(dynamicRichStatus(for: snapshot, now: now))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(WidgetPalette.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    CoverThumb(coverData: coverData, tintHex: snapshot.tintHex, size: 36, radius: 10)
                }
            }
            
            let items = visibleItems(for: snapshot, now: now)
            if items.isEmpty {
                WidgetEmptyStackCard(
                    title: snapshot.emptyDayPrompt,
                    planTitle: "Plan this day",
                    planURL: WidgetDeepLink.planDay(trip: snapshot.tripID, day: snapshot.dayID).url,
                    showsGhost: true
                )
            } else {
                WidgetItemStack(items: Array(items.prefix(3)), tripID: snapshot.tripID, dayID: snapshot.dayID)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .widgetURL(WidgetDeepLink.trip(snapshot.tripID).url)
    }
}

private struct LargeTripWidget: View {
    let snapshot: WidgetTripSnapshot
    let coverData: Data?
    let now: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            hero
            
            let items = visibleItems(for: snapshot, now: now)
            if items.isEmpty {
                WidgetEmptyStackCard(
                    title: snapshot.emptyDayPrompt,
                    planTitle: "Plan this day",
                    planURL: WidgetDeepLink.planDay(trip: snapshot.tripID, day: snapshot.dayID).url,
                    showsGhost: true
                )
            } else {
                WidgetItemStack(items: Array(items.prefix(3)), tripID: snapshot.tripID, dayID: snapshot.dayID)
            }
            
            if !snapshot.resolvedFollowingDays.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Coming up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WidgetPalette.textSecondary)
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(snapshot.resolvedFollowingDays) { peek in
                            dayPeek(peek)
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            } else {
                metaRow
            }
        }
        .padding(14)
        .widgetURL(
            (snapshot.dayID.map { WidgetDeepLink.day(trip: snapshot.tripID, day: $0) }
             ?? .trip(snapshot.tripID)).url
        )
    }
    
    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let coverData, let image = UIImage(data: coverData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [Color(hex: snapshot.tintHex).opacity(0.55), WidgetPalette.page],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                }
            }
            .overlay {
                LinearGradient(
                    colors: [.clear, WidgetPalette.page.opacity(0.88)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(snapshot.tripName)
                    .font(.system(size: 20, weight: .semibold))
                    .lineLimit(1)
                Text(dynamicRichStatus(for: snapshot, now: now))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WidgetPalette.textSecondary)
                    .lineLimit(2)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 136)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    private func dayPeek(_ peek: WidgetDayPeek) -> some View {
        Link(destination: WidgetDeepLink.day(trip: snapshot.tripID, day: peek.id).url) {
            ZStack(alignment: .top) {
                WidgetGhostStack(compact: true)
                    .padding(.top, 16)
                VStack(alignment: .leading, spacing: 4) {
                    Text(peek.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WidgetPalette.textSecondary)
                        .lineLimit(1)
                    Text(peek.detail)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if peek.itemCount > 0 {
                        Text(peek.itemCount == 1 ? "1 on the stack" : "\(peek.itemCount) on the stack")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(WidgetPalette.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    WidgetPalette.elevated,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
    
    private var metaRow: some View {
        HStack(spacing: 8) {
            metaChip(snapshot.dateSpanText ?? snapshot.dayLabel)
            if snapshot.ideaCount > 0 {
                metaChip(snapshot.ideaCount == 1 ? "1 idea" : "\(snapshot.ideaCount) ideas")
            }
            if !snapshot.destination.isEmpty {
                metaChip(snapshot.destination)
            }
            Spacer(minLength: 0)
        }
    }
    
    private func metaChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(WidgetPalette.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(WidgetPalette.elevated, in: Capsule(style: .continuous))
    }
}

private struct SmallActivityRow: View {
    let item: WidgetTripItem
    
    var body: some View {
        HStack(spacing: 8) {
            WidgetAccentIcon(item: item, size: 18)
            Text(item.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            WidgetPalette.elevated,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

private struct WidgetAccentIcon: View {
    let item: WidgetTripItem
    var size: CGFloat
    
    var body: some View {
        if let data = item.iconPNG, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        } else {
            let background = item.accentHex.map(Color.init(hex:)) ?? WidgetPalette.kindColor(item.kind)
            let foreground = item.accentForegroundHex.map(Color.init(hex:)) ?? WidgetPalette.page
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(background)
                Image(systemName: item.kind.systemImage)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(foreground)
            }
            .frame(width: size, height: size)
        }
    }
}

private struct WidgetItemStack: View {
    let items: [WidgetTripItem]
    let tripID: UUID
    let dayID: UUID?
    
    var body: some View {
        VStack(spacing: -10) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Link(destination: WidgetDeepLink.item(trip: tripID, item: item.id, day: dayID).url) {
                    WidgetStackCard(item: item, compact: false)
                        .offset(y: CGFloat(index) * 1)
                }
                .zIndex(Double(10 - index))
            }
        }
    }
}

private struct WidgetStackCard: View {
    let item: WidgetTripItem
    var compact: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(WidgetPalette.kindColor(item.kind))
                .frame(width: 3, height: compact ? 22 : 26)
            Image(systemName: item.kind.systemImage)
                .font(.system(size: compact ? 12 : 13, weight: .semibold))
                .foregroundStyle(WidgetPalette.kindColor(item.kind))
                .frame(width: 16)
            Text(item.title)
                .font(.system(size: compact ? 13 : 15, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            if let time = item.startTime, !time.isEmpty {
                Text(time)
                    .font(.system(size: compact ? 11 : 12, weight: .medium))
                    .foregroundStyle(WidgetPalette.textSecondary)
            }
        }
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 9 : 11)
        .background(
            WidgetPalette.elevated,
            in: RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct WidgetEmptyStackCard: View {
    let title: String
    let planTitle: String
    var planURL: URL? = nil
    var compact: Bool = false
    var showsGhost: Bool = false
    
    var body: some View {
        let card = HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(WidgetPalette.accent.opacity(0.85))
                .frame(width: 3, height: compact ? 22 : 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: compact ? 13 : 15, weight: .semibold))
                    .lineLimit(1)
                if let planURL {
                    Link(planTitle, destination: planURL)
                        .font(.system(size: compact ? 12 : 13, weight: .semibold))
                        .foregroundStyle(WidgetPalette.accent)
                } else {
                    Text(planTitle)
                        .font(.system(size: compact ? 12 : 13, weight: .semibold))
                        .foregroundStyle(WidgetPalette.accent)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 9 : 11)
        .background(
            WidgetPalette.elevated,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        }
        
        if showsGhost {
            ZStack(alignment: .top) {
                WidgetGhostStack(compact: false)
                    .padding(.top, 18)
                card
            }
        } else {
            card
        }
    }
}

private struct WidgetGhostStack: View {
    var compact: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(WidgetPalette.card)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
            }
            .frame(height: compact ? 28 : 36)
            .scaleEffect(x: 0.96, y: 1, anchor: .center)
            .opacity(0.7)
    }
}

private struct CoverThumb: View {
    let coverData: Data?
    let tintHex: UInt32
    var size: CGFloat
    var radius: CGFloat
    
    var body: some View {
        Group {
            if let coverData, let image = UIImage(data: coverData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color(hex: tintHex), Color(hex: tintHex).opacity(0.45)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
