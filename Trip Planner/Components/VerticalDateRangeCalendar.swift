import SwiftUI

/// A clean, Apple-like, vertically scrollable calendar for selecting a continuous date range.
/// Users tap a start date and an end date; the days in-between are highlighted automatically.
struct VerticalDateRangeCalendar: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    @Binding var scrollToDate: Date?
    
    let bounds: ClosedRange<Date>
    let tint: Color
    
    // 7 columns for days of week
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    
    private var monthStarts: [Date] {
        let startMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: bounds.lowerBound)) ?? bounds.lowerBound
        let endMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: bounds.upperBound)) ?? bounds.upperBound
        
        var months: [Date] = []
        var current = startMonth
        while current <= endMonth {
            months.append(current)
            guard let next = calendar.date(byAdding: .month, value: 1, to: current) else { break }
            current = next
        }
        return months
    }
    
    private var weekdaySymbols: [String] {
        var symbols = calendar.shortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1 // 0-based
        if first > 0 {
            symbols = Array(symbols[first...]) + Array(symbols[..<first])
        }
        return symbols
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 18) {
                    LazyVStack(spacing: 18, pinnedViews: []) {
                        // Weekday header (once)
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(weekdaySymbols, id: \.self) { s in
                                Text(s.uppercased())
                                    .font(.app(11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                        
                        ForEach(monthStarts, id: \.self) { monthStart in
                            MonthView(
                                monthStart: monthStart,
                                bounds: bounds,
                                tint: tint,
                                startDate: $startDate,
                                endDate: $endDate
                            )
                            .id(monthStart)
                            .padding(.horizontal, 12)
                        }
                    }
                }
                .padding(.bottom, 18)
            }
            .onAppear {
                // Scroll to the selected start month if possible; otherwise to today's month.
                let anchor = startDate ?? Date()
                let month = calendar.date(from: calendar.dateComponents([.year, .month], from: anchor)) ?? anchor
                DispatchQueue.main.async {
                    proxy.scrollTo(month, anchor: .top)
                }
            }
            .onChange(of: startDate) { _, newValue in
                guard let newValue else { return }
                let month = calendar.date(from: calendar.dateComponents([.year, .month], from: newValue)) ?? newValue
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(month, anchor: .top)
                    }
                }
            }
            .onChange(of: scrollToDate) { _, newValue in
                guard let newValue else { return }
                let month = calendar.date(from: calendar.dateComponents([.year, .month], from: newValue)) ?? newValue
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(month, anchor: .top)
                    }
                    scrollToDate = nil
                }
            }
        }
    }
}

private struct MonthView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    
    let monthStart: Date
    let bounds: ClosedRange<Date>
    let tint: Color
    
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    
    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = locale
        f.calendar = calendar
        f.dateFormat = "LLLL yyyy"
        return f.string(from: monthStart)
    }
    
    private var days: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let dayCount = range.count
        
        let firstDay = calendar.date(from: DateComponents(
            year: calendar.component(.year, from: monthStart),
            month: calendar.component(.month, from: monthStart),
            day: 1
        )) ?? monthStart
        
        // offset based on firstWeekday
        let weekday = calendar.component(.weekday, from: firstDay) // 1...7
        let firstWeekday = calendar.firstWeekday // 1...7
        let leading = (weekday - firstWeekday + 7) % 7
        
        var result: [Date?] = Array(repeating: nil, count: leading)
        for d in 1...dayCount {
            let date = calendar.date(byAdding: .day, value: d - 1, to: firstDay)
            result.append(date)
        }
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }
    
    private func isInBounds(_ date: Date) -> Bool {
        let d = calendar.startOfDay(for: date)
        return d >= calendar.startOfDay(for: bounds.lowerBound) && d <= calendar.startOfDay(for: bounds.upperBound)
    }
    
    private func selectionState(for date: Date) -> (isStart: Bool, isEnd: Bool, isInRange: Bool) {
        let d = calendar.startOfDay(for: date)
        let s = startDate.map { calendar.startOfDay(for: $0) }
        let e = endDate.map { calendar.startOfDay(for: $0) }
        
        if let s, let e {
            let lo = min(s, e)
            let hi = max(s, e)
            return (d == lo, d == hi, d >= lo && d <= hi)
        }
        if let s {
            return (d == s, false, d == s)
        }
        return (false, false, false)
    }
    
    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }
    
    private func handleTap(_ date: Date) {
        guard isInBounds(date) else { return }
        let d = calendar.startOfDay(for: date)
        
        if startDate == nil {
            startDate = d
            endDate = nil
            return
        }
        
        if endDate == nil {
            startDate = calendar.startOfDay(for: startDate!)
            endDate = d
            return
        }
        
        // Reset selection
        startDate = d
        endDate = nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(monthTitle)
                .font(.app(15, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.top, 4)
            
            GeometryReader { geo in
                let totalSpacing = CGFloat(6 * 6)
                let cell = floor((geo.size.width - totalSpacing) / 7.0)
                
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, maybeDate in
                        DayCell(
                            date: maybeDate,
                            cellSize: cell,
                            tint: tint,
                            isSelectable: maybeDate.map(isInBounds) ?? false,
                            state: maybeDate.map(selectionState) ?? (false, false, false),
                            isToday: maybeDate.map(isToday) ?? false,
                            onTap: { if let d = maybeDate { handleTap(d) } }
                        )
                    }
                }
            }
            .frame(height: monthGridHeight(for: days.count))
        }
    }
    
    private func monthGridHeight(for cellCount: Int) -> CGFloat {
        let rows = max(1, cellCount / 7)
        // Approximate height; actual is controlled by GeometryReader, but keep stable.
        return CGFloat(rows) * 44 + CGFloat(max(0, rows - 1)) * 6
    }
}

private struct DayCell: View {
    let date: Date?
    let cellSize: CGFloat
    let tint: Color
    let isSelectable: Bool
    let state: (isStart: Bool, isEnd: Bool, isInRange: Bool)
    let isToday: Bool
    let onTap: () -> Void
    
    private var dayNumber: String {
        guard let date else { return "" }
        return String(Calendar.current.component(.day, from: date))
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                if state.isInRange {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.18))
                }
                
                if state.isStart || state.isEnd {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint)
                        .frame(width: cellSize, height: cellSize)
                }
                
                Text(dayNumber)
                    .font(.app(16, weight: .semibold))
                    .foregroundStyle(foregroundColor)
                    .frame(width: cellSize, height: cellSize, alignment: .center)
            }
            .frame(width: cellSize, height: cellSize)
        }
        .buttonStyle(.plain)
        .disabled(!isSelectable || date == nil)
        .opacity(opacity)
        .accessibilityLabel(dayNumber)
    }
    
    private var foregroundColor: Color {
        if state.isStart || state.isEnd { return .white }
        if isToday { return tint }
        return .primary
    }
    
    private var opacity: Double {
        guard date != nil else { return 0.0 }
        return isSelectable ? 1.0 : 0.25
    }
}

