import SwiftUI

/// Color-coded day schedule summary (activities / travel / inactive).
struct DayBreakdown: Equatable {
    static let dayMinutes = 24 * 60
    
    struct Segment: Identifiable, Equatable {
        let id: String
        let title: String
        let minutes: Int
        let color: Color
    }
    
    let activityMinutes: Int
    let travelMinutes: Int
    let inactiveMinutes: Int
    
    var totalActiveMinutes: Int { activityMinutes + travelMinutes }
    
    func segments(inactiveColor: Color) -> [Segment] {
        [
            Segment(id: "activities", title: "Activities", minutes: activityMinutes, color: Color(hex: 0xAD8DF0)),
            Segment(id: "travel", title: "Travel", minutes: travelMinutes, color: Color(hex: 0x5B8DEF)),
            Segment(id: "inactive", title: "Inactive", minutes: inactiveMinutes, color: inactiveColor)
        ]
    }
    
    static func make(from day: TripDay) -> DayBreakdown {
        let rawActivity = day.events.reduce(0) { $0 + $1.durationMinutes }
        let rawTravel = day.flights.reduce(0) { total, flight in
            guard flight.hasEndTime else { return total }
            return total + max(0, Int(flight.endTime.timeIntervalSince(flight.startTime) / 60))
        }
        
        let activityMinutes = min(rawActivity, dayMinutes)
        let travelMinutes = min(rawTravel, max(0, dayMinutes - activityMinutes))
        let inactiveMinutes = max(0, dayMinutes - activityMinutes - travelMinutes)
        
        return DayBreakdown(
            activityMinutes: activityMinutes,
            travelMinutes: travelMinutes,
            inactiveMinutes: inactiveMinutes
        )
    }
    
    /// Compact active total (`28m`, `2h`, `1.5h`).
    static func formatActive(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        return formatHours(minutes)
    }
    
    /// Legend hours (`0h`, `0.5h`, `11.5h`).
    static func formatHours(_ minutes: Int) -> String {
        let hours = Double(minutes) / 60.0
        if hours == 0 { return "0h" }
        if abs(hours - hours.rounded()) < 0.05 {
            return "\(Int(hours.rounded()))h"
        }
        let tenths = (hours * 10).rounded() / 10
        if tenths == tenths.rounded() {
            return "\(Int(tenths))h"
        }
        return String(format: "%.1fh", tenths)
    }
}
