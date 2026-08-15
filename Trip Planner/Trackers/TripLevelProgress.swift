import Foundation

/// Trip-count leveling for Profile achievements.
enum TripLevelProgress {
    /// Completed / logged trip count thresholds:
    /// Level 0: under 5 · Level 1: 5–9 · Level 2: 10–19 · Level 3: 20+
    static func level(forTripCount count: Int) -> Int {
        switch count {
        case ..<5: return 0
        case 5..<10: return 1
        case 10..<20: return 2
        default: return 3
        }
    }
    
    /// Trips required to reach the next level (nil at max level).
    static func nextThreshold(forLevel level: Int) -> Int? {
        switch level {
        case 0: return 5
        case 1: return 10
        case 2: return 20
        default: return nil
        }
    }
    
    /// Lower bound trip count for the current level.
    static func startThreshold(forLevel level: Int) -> Int {
        switch level {
        case 0: return 0
        case 1: return 5
        case 2: return 10
        default: return 20
        }
    }
    
    /// 0...1 progress toward the next level threshold (absolute trip count / next threshold).
    static func progress(forTripCount count: Int) -> Double {
        let level = level(forTripCount: count)
        guard let next = nextThreshold(forLevel: level) else { return 1 }
        return min(max(Double(count) / Double(next), 0), 1)
    }
    
    /// Display name for levels 1–3 (nil for level 0).
    static func title(forLevel level: Int) -> String? {
        switch level {
        case 1: return "Wanderer"
        case 2: return "Traveler"
        case 3: return "Adventurer"
        default: return nil
        }
    }
    
    /// Asset name for levels 1–3 (nil for level 0).
    static func illustrationName(forLevel level: Int) -> String? {
        switch level {
        case 1: return "illustrations/achievement-level-1"
        case 2: return "illustrations/achievement-level-2"
        case 3: return "illustrations/achievement-level-3"
        default: return nil
        }
    }
    
    static func tripsRemaining(forTripCount count: Int) -> Int? {
        let level = level(forTripCount: count)
        guard let next = nextThreshold(forLevel: level) else { return nil }
        return max(next - count, 0)
    }
}
