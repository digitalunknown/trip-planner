import SwiftUI

/// Monthly travel bars for a year. Swipe or use the chevrons to move through past years.
struct YearTravelGridView: View {
    let trips: [Trip]
    var year: Int = Calendar.current.component(.year, from: Date())
    
    @State private var selectedYear: Int
    
    private let calendar = Calendar(identifier: .gregorian)
    private let chartHeight: CGFloat = 112
    
    init(trips: [Trip], year: Int = Calendar.current.component(.year, from: Date())) {
        self.trips = trips
        self.year = year
        _selectedYear = State(initialValue: year)
    }
    
    private var years: [Int] {
        var oldest = year
        for trip in trips where trip.isDatesSet {
            oldest = min(oldest, calendar.component(.year, from: trip.startDate))
            oldest = min(oldest, calendar.component(.year, from: trip.endDate))
        }
        oldest = min(oldest, year - 5)
        oldest = max(oldest, year - 10)
        return Array(oldest...year).reversed()
    }
    
    private var selectedIndex: Int {
        years.firstIndex(of: selectedYear) ?? 0
    }
    
    private var daysTraveledLabel: String {
        let count = Self.travelDays(in: selectedYear, trips: trips, calendar: calendar).count
        return count == 1 ? "1 day traveled" : "\(count) days traveled"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .center, spacing: AppSpacing.xs) {
                yearStepButton(lucide: "chevron-left", enabled: selectedIndex < years.count - 1) {
                    moveYear(by: 1)
                }
                
                Text("\(selectedYear)")
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(AppColor.textStrong)
                    .contentTransition(.numericText())
                    .monospacedDigit()
                
                yearStepButton(lucide: "chevron-right", enabled: selectedIndex > 0) {
                    moveYear(by: -1)
                }
                
                Spacer(minLength: 0)
                
                Text(daysTraveledLabel)
                    .font(.appCaption)
                    .foregroundStyle(AppColor.textWeak)
                    .contentTransition(.numericText())
            }
            .animation(.easeInOut(duration: 0.2), value: selectedYear)
            
            TabView(selection: $selectedYear) {
                ForEach(years, id: \.self) { y in
                    YearTravelMonthBars(trips: trips, year: y, calendar: calendar)
                        .tag(y)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: chartHeight)
            
            if years.count > 1 {
                HStack(spacing: 6) {
                    ForEach(Array(years.enumerated()), id: \.element) { index, _ in
                        Circle()
                            .fill(index == selectedIndex ? AppColor.textStrong : AppColor.elevated)
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            }
        }
        .onAppear {
            if !years.contains(selectedYear) {
                selectedYear = year
            }
        }
    }
    
    private func yearStepButton(lucide: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            AppIcon(lucide: lucide, size: 16, color: enabled ? AppColor.textStrong : AppColor.textWeak)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
    
    private func moveYear(by delta: Int) {
        let next = selectedIndex + delta
        guard years.indices.contains(next) else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            selectedYear = years[next]
        }
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
            var steps = 0
            while cursor <= last, steps < 400 {
                days.insert(cursor)
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor), next > cursor else { break }
                cursor = next
                steps += 1
            }
        }
        return days
    }
    
    static func daysByMonth(in year: Int, trips: [Trip], calendar: Calendar) -> [Int] {
        var counts = Array(repeating: 0, count: 12)
        for day in travelDays(in: year, trips: trips, calendar: calendar) {
            let month = calendar.component(.month, from: day)
            guard (1...12).contains(month) else { continue }
            counts[month - 1] += 1
        }
        return counts
    }
}

// MARK: - Monthly bars

private struct YearTravelMonthBars: View {
    let trips: [Trip]
    let year: Int
    let calendar: Calendar
    
    private static let monthLetters = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
    private static let barMaxHeight: CGFloat = 80
    private static let barMinHeight: CGFloat = 4
    
    private var counts: [Int] {
        YearTravelGridView.daysByMonth(in: year, trips: trips, calendar: calendar)
    }
    
    private var peak: Int {
        counts.max() ?? 0
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<12, id: \.self) { index in
                let count = counts[index]
                VStack(spacing: 6) {
                    Capsule(style: .continuous)
                        .fill(count > 0 ? AppColor.textStrong : AppColor.elevated)
                        .frame(maxWidth: 14)
                        .frame(height: barHeight(for: count))
                    
                    Text(Self.monthLetters[index])
                        .font(.app(10, weight: .medium))
                        .foregroundStyle(AppColor.textWeak)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .accessibilityLabel("Travel days in \(year)")
        .accessibilityValue(accessibilityValue)
    }
    
    private func barHeight(for count: Int) -> CGFloat {
        guard peak > 0 else { return Self.barMinHeight }
        let t = CGFloat(count) / CGFloat(peak)
        return Self.barMinHeight + (Self.barMaxHeight - Self.barMinHeight) * t
    }
    
    private var accessibilityValue: String {
        let total = counts.reduce(0, +)
        return total == 1 ? "1 day traveled" : "\(total) days traveled"
    }
}
