import Foundation

/// Builds a celebratory headline for the Stats tab (count-first, natural language).
enum StatsNarrative {
    struct Snapshot {
        let tripsLogged: Int
        let countries: Int
        let countriesTotal: Int
        let states: Int
        let statesTotal: Int
        let continents: Int
        let continentsTotal: Int
    }
    
    static func sentence(for snapshot: Snapshot) -> String {
        if snapshot.tripsLogged == 0 {
            return "Your travel story starts with the first trip you finish."
        }
        
        let countryPct = ratio(snapshot.countries, snapshot.countriesTotal)
        let statePct = ratio(snapshot.states, snapshot.statesTotal)
        let continentPct = ratio(snapshot.continents, snapshot.continentsTotal)
        
        if let beat = milestoneBeat(label: "U.S. states", count: snapshot.states, total: snapshot.statesTotal, percent: statePct) {
            return "You’ve logged \(tripPhrase(snapshot.tripsLogged)) across \(countryPhrase(snapshot.countries)) — \(beat)."
        }
        if let beat = milestoneBeat(label: "countries", count: snapshot.countries, total: snapshot.countriesTotal, percent: countryPct) {
            return "You’ve logged \(tripPhrase(snapshot.tripsLogged)) — \(beat)."
        }
        if let beat = milestoneBeat(label: "continents", count: snapshot.continents, total: snapshot.continentsTotal, percent: continentPct) {
            return "You’ve logged \(tripPhrase(snapshot.tripsLogged)) — \(beat)."
        }
        
        if statePct >= 0.45 && snapshot.statesTotal > 0 {
            return "You’ve logged \(tripPhrase(snapshot.tripsLogged)) across \(countryPhrase(snapshot.countries)) and \(snapshot.states) states — almost halfway across the U.S."
        }
        
        if snapshot.countries > 0 && snapshot.states > 0 {
            return "You’ve logged \(tripPhrase(snapshot.tripsLogged)) across \(countryPhrase(snapshot.countries)) and \(statePhrase(snapshot.states))."
        }
        if snapshot.countries > 0 {
            return "You’ve logged \(tripPhrase(snapshot.tripsLogged)) across \(countryPhrase(snapshot.countries))."
        }
        if snapshot.states > 0 {
            return "You’ve logged \(tripPhrase(snapshot.tripsLogged)) across \(statePhrase(snapshot.states))."
        }
        return "You’ve logged \(tripPhrase(snapshot.tripsLogged)) — your passport is growing."
    }
    
    private static func tripPhrase(_ count: Int) -> String {
        count == 1 ? "1 trip" : "\(count) trips"
    }
    
    private static func countryPhrase(_ count: Int) -> String {
        count == 1 ? "1 country" : "\(count) countries"
    }
    
    private static func statePhrase(_ count: Int) -> String {
        count == 1 ? "1 state" : "\(count) states"
    }
    
    private static func ratio(_ count: Int, _ total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
    
    /// When within ~8% of a milestone (or exactly on one), surface that as the narrative hook.
    private static func milestoneBeat(label: String, count: Int, total: Int, percent: Double) -> String? {
        guard total > 0, count > 0 else { return nil }
        let milestones: [Double] = [0.25, 0.5, 0.75, 1.0]
        for milestone in milestones {
            let distance = milestone - percent
            if abs(distance) < 0.005 {
                if milestone >= 1.0 {
                    let short = label.replacingOccurrences(of: "U.S. ", with: "")
                    return "every \(short) checked off"
                }
                return "\(Int(milestone * 100))% of \(label) visited"
            }
            if distance > 0 && distance <= 0.08 {
                let remaining = max(1, Int((Double(total) * milestone).rounded()) - count)
                let pctLabel = Int(milestone * 100)
                return "just \(remaining) more to hit \(pctLabel)% of \(label)"
            }
        }
        return nil
    }
}
