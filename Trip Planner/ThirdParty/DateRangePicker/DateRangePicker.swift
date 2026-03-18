// Adapted from https://github.com/14T/DateRangePicker (MIT License)
// Copyright (c) 2025 14T

import SwiftUI

@available(iOS 16.0, *)
struct DateRangePicker: View {
    static var defaultBounds: Range<Date> {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .year, value: -5, to: Date())!
        let end = calendar.date(byAdding: .year, value: 5, to: Date())!
        return start..<end
    }
    
    @Binding private var startDate: Date?
    @Binding private var endDate: Date?
    let bounds: Range<Date>?
    var calendar: Calendar = .current
    
    init(
        startDate: Binding<Date?>,
        endDate: Binding<Date?>,
        bounds: Range<Date>? = nil
    ) {
        self._startDate = startDate
        self._endDate = endDate
        self.bounds = bounds
    }
    
    private var datesBinding: Binding<Set<DateComponents>> {
        Binding {
            DateRangeHelper.getDatesInRange(startDate: startDate, endDate: endDate, calendar: calendar)
        } set: { newValue in
            DateRangeHelper.setDateRangeFromSelection(
                newValue: newValue,
                calendar: calendar,
                startDate: &startDate,
                endDate: &endDate
            )
        }
    }
    
    var body: some View {
        MultiDatePicker("", selection: datesBinding, in: bounds ?? Self.defaultBounds)
            .environment(\.locale, Locale.current)
            .environment(\.timeZone, .current)
            .environment(\.calendar, calendar)
    }
}

