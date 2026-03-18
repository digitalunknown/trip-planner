import SwiftUI

struct DateRangePickerField: View {
    @Environment(\.appAccentColor) private var appAccentColor
    
    @Binding var startDate: Date
    @Binding var endDate: Date
    
    @State private var isPresentingPicker = false
    @State private var draftStartDate: Date? = nil
    @State private var draftEndDate: Date? = nil
    @State private var calendarScrollToDate: Date? = nil

    private func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
    
    private var calendarBounds: ClosedRange<Date> {
        let cal = Calendar.current
        let start = cal.date(byAdding: .year, value: -10, to: Date()) ?? Date()
        let end = cal.date(byAdding: .year, value: 10, to: Date()) ?? Date()
        return cal.startOfDay(for: start)...cal.startOfDay(for: end)
    }
    
    private var rangeLabel: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return "\(f.string(from: startDate)) – \(f.string(from: endDate))"
    }
    
    var body: some View {
        Button {
            let cal = Calendar.current
            let s = cal.startOfDay(for: startDate)
            let e = cal.startOfDay(for: max(endDate, startDate))
            draftStartDate = s
            draftEndDate = e
            // Present on next runloop tick so state is applied first.
            DispatchQueue.main.async {
                isPresentingPicker = true
            }
        } label: {
            HStack {
                Text("Dates")
                Spacer()
                Text(rangeLabel)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
        }
        .sheet(isPresented: $isPresentingPicker) {
            ZStack(alignment: .top) {
                VStack(spacing: 14) {
                    VerticalDateRangeCalendar(
                        startDate: $draftStartDate,
                        endDate: $draftEndDate,
                        scrollToDate: $calendarScrollToDate,
                        bounds: calendarBounds,
                        tint: appAccentColor
                    )
                    .environment(\.calendar, .current)
                    .environment(\.timeZone, .current)
                    .environment(\.locale, .current)
                    .safeAreaPadding(.top, 56)
                    
                    Text(rangeSummaryLabel)
                        .font(.app(15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                HStack {
                    LiquidGlassIconButton(systemName: "xmark") { isPresentingPicker = false }
                    Spacer(minLength: 0)
                    Text("Dates")
                        .font(.app(15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    LiquidGlassIconButton(systemName: "checkmark") { applyAndDismiss() }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
            .presentationDetents([.large])
            .tint(.primary)
        }
    }
    
    private var rangeSummaryLabel: String {
        let cal = Calendar.current
        let s = cal.startOfDay(for: draftStartDate ?? startDate)
        let e = cal.startOfDay(for: draftEndDate ?? draftStartDate ?? endDate)
        let start = min(s, e)
        let end = max(s, e)
        
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        
        let dayCount = (cal.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        let dayLabel = dayCount == 1 ? "day" : "days"
        return "\(f.string(from: start)) – \(f.string(from: end)) (\(dayCount) \(dayLabel))"
    }
    
    private func applyAndDismiss() {
        let cal = Calendar.current
        let s = cal.startOfDay(for: draftStartDate ?? startDate)
        let e = cal.startOfDay(for: draftEndDate ?? draftStartDate ?? endDate)
        startDate = min(s, e)
        endDate = max(s, e)
        isPresentingPicker = false
    }
}
