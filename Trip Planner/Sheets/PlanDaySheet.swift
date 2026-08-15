import SwiftUI

/// Thin wrapper kept for call-site compatibility; prefer `TripStacksAISheet` directly.
struct PlanDaySheet: View {
    let tripContext: PlanDayTripContext
    let dayOptions: [DayOption]
    let defaultDayID: UUID?
    let onCommit: ([PlanDayItem]) -> Void
    
    var body: some View {
        TripStacksAISheet(
            mode: .planDay,
            tripContext: tripContext,
            dayOptions: dayOptions,
            defaultDayID: defaultDayID,
            scopeHint: dayOptions.first(where: { $0.id == defaultDayID })?.title ?? "",
            onCommitPlanItems: onCommit
        )
    }
}
