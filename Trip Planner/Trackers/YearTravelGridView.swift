import SwiftUI

/// Year heatmap (GitHub-style): weeks across, weekdays down; trip-covered days are filled.
/// Current year only — stops at today so upcoming days aren't shown.
struct YearTravelGridView: View {
    let trips: [Trip]
    var year: Int = Calendar.current.component(.year, from: Date())
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var gridHeight: CGFloat = 72
    
    private var textSecondary: Color {
        let primary = colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717)
        return primary.opacity(colorScheme == .dark ? 0.72 : 0.62)
    }
    
    private let calendar = Calendar(identifier: .gregorian)
    
    private var daysTraveled: Int {
        Self.travelDays(in: year, trips: trips, calendar: calendar).count
    }
    
    private var daysTraveledLabel: String {
        daysTraveled == 1 ? "1 day traveled" : "\(daysTraveled) days traveled"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            YearTravelYearGrid(trips: trips, year: year, calendar: calendar)
                .frame(height: gridHeight)
                .background {
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { updateGridHeight(width: geo.size.width) }
                            .onChange(of: geo.size.width) { _, width in
                                updateGridHeight(width: width)
                            }
                    }
                }
            
            HStack(alignment: .firstTextBaseline) {
                Text("\(year)")
                    .font(.appCaption)
                    .foregroundStyle(textSecondary)
                
                Spacer(minLength: 8)
                
                Text(daysTraveledLabel)
                    .font(.appCaption)
                    .foregroundStyle(textSecondary)
                    .multilineTextAlignment(.trailing)
            }
            .accessibilityElement(children: .combine)
        }
    }
    
    private func updateGridHeight(width: CGFloat) {
        guard width > 0 else { return }
        let next = YearTravelYearGrid.gridHeight(width: width, year: year, calendar: calendar)
        if abs(next - gridHeight) > 0.5 {
            gridHeight = next
        }
    }
    
    // MARK: - Calendar math
    
    /// Days in `year` from Jan 1 through today (for the current year) or the full year (past).
    static func elapsedDays(in year: Int, calendar: Calendar) -> [Date] {
        let all = days(in: year, calendar: calendar)
        let today = calendar.startOfDay(for: Date())
        let currentYear = calendar.component(.year, from: today)
        if year > currentYear { return [] }
        if year == currentYear {
            return all.filter { $0 <= today }
        }
        return all
    }
    
    static func days(in year: Int, calendar: Calendar) -> [Date] {
        guard
            let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
            let yearEnd = calendar.date(from: DateComponents(year: year, month: 12, day: 31))
        else { return [] }
        
        let yearStartDay = calendar.startOfDay(for: yearStart)
        let yearEndDay = calendar.startOfDay(for: yearEnd)
        var days: [Date] = []
        var cursor = yearStartDay
        while cursor <= yearEndDay {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }
    
    static func travelDays(in year: Int, trips: [Trip], calendar: Calendar) -> Set<Date> {
        guard
            let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
            let yearEnd = calendar.date(from: DateComponents(year: year, month: 12, day: 31))
        else { return [] }
        
        let today = calendar.startOfDay(for: Date())
        let yearStartDay = calendar.startOfDay(for: yearStart)
        let yearEndDay = min(calendar.startOfDay(for: yearEnd), today)
        guard yearEndDay >= yearStartDay else { return [] }
        
        var days = Set<Date>()
        
        for trip in trips where trip.isDatesSet {
            let tripStart = calendar.startOfDay(for: trip.startDate)
            let tripEnd = calendar.startOfDay(for: trip.endDate)
            guard tripEnd >= yearStartDay, tripStart <= yearEndDay else { continue }
            
            var cursor = max(tripStart, yearStartDay)
            let last = min(tripEnd, yearEndDay)
            while cursor <= last {
                days.insert(cursor)
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
        }
        return days
    }
}

// MARK: - Single year grid

private struct YearTravelYearGrid: View {
    let trips: [Trip]
    let year: Int
    let calendar: Calendar
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var inactiveCell: Color { colorScheme == .dark ? Color(hex: 0x2A2A2E) : Color(hex: 0xD4D4D8) }
    private var activeCell: Color { textPrimary }
    
    /// Weekday rows (Sun→Sat or locale first weekday), weeks as columns — like GitHub.
    private let rowCount = 7
    private let gap: CGFloat = 2.5
    
    private var travelDays: Set<Date> {
        YearTravelGridView.travelDays(in: year, trips: trips, calendar: calendar)
    }
    
    /// Column-major slots: week0 Sun…Sat, week1 Sun…Sat, … with leading/trailing empties.
    private var slots: [Date?] {
        Self.githubSlots(year: year, calendar: calendar)
    }
    
    private var weekCount: Int {
        max(slots.count / rowCount, 1)
    }
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0), spacing: gap), count: weekCount)
    }
    
    private var slotCount: Int {
        weekCount * rowCount
    }
    
    var body: some View {
        GeometryReader { geo in
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: gap) {
                ForEach(0..<slotCount, id: \.self) { index in
                    dayCell(at: index)
                }
            }
            .frame(width: geo.size.width, alignment: .leading)
        }
        .accessibilityLabel("Travel days in \(year)")
    }
    
    @ViewBuilder
    private func dayCell(at index: Int) -> some View {
        // LazyVGrid is row-major; remap so each column is one week (vertical days).
        let row = index / weekCount
        let col = index % weekCount
        let slotIndex = col * rowCount + row
        let date: Date? = slots.indices.contains(slotIndex) ? slots[slotIndex] : nil
        
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(fill(for: date))
            .aspectRatio(1, contentMode: .fit)
            .opacity(date == nil ? 0 : 1)
    }
    
    private func fill(for date: Date?) -> Color {
        guard let date else { return .clear }
        return travelDays.contains(date) ? activeCell : inactiveCell
    }
    
    static func githubSlots(year: Int, calendar: Calendar) -> [Date?] {
        // Current year stops at today so upcoming days/weeks aren't shown.
        let yearDays = YearTravelGridView.elapsedDays(in: year, calendar: calendar)
        guard let first = yearDays.first else { return [] }
        
        let weekday = calendar.component(.weekday, from: first)
        let leadingEmpty = (weekday - calendar.firstWeekday + 7) % 7
        
        var slots: [Date?] = Array(repeating: nil, count: leadingEmpty)
        slots.append(contentsOf: yearDays.map { Optional($0) })
        while slots.count % 7 != 0 {
            slots.append(nil)
        }
        return slots
    }
    
    static func gridHeight(width: CGFloat, year: Int, calendar: Calendar) -> CGFloat {
        let rowCount: CGFloat = 7
        let gap: CGFloat = 2.5
        let weeks = max(githubSlots(year: year, calendar: calendar).count / 7, 1)
        let cell = max(3.5, (width - gap * CGFloat(weeks - 1)) / CGFloat(weeks))
        return cell * rowCount + gap * (rowCount - 1)
    }
}
