import Foundation

struct PlanDayParser {
    static func parse(
        text: String,
        tripContext: PlanDayTripContext,
        dayOptions: [DayOption],
        defaultDayID: UUID?
    ) -> PlanDayDraft {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let facts = extractFacts(from: normalized)
        let lines = splitLines(normalized)
        
        var items: [PlanDayItem] = []
        items.reserveCapacity(max(8, lines.count))
        
        let fallbackDayID = defaultDayID ?? firstNonIdeasDayID(in: dayOptions)
        
        if let checklist = buildChecklistIfApplicable(lines: lines, facts: facts, fallbackDayID: fallbackDayID) {
            items.append(checklist)
        } else {
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                
                if isChecklistLine(trimmed) {
                    let title = "Checklist"
                    let checklistText = checklistItemText(from: trimmed)
                    items.append(
                        PlanDayItem(
                            kind: .checklist,
                            dayID: fallbackDayID,
                            title: title,
                            checklistItemsText: checklistText,
                            sourceSnippet: trimmed
                        )
                    )
                    continue
                }
                
                if isFlightLike(trimmed) {
                    let parsed = parseFlightLike(trimmed)
                    let dayID = dayIDForDetectedDate(in: trimmed, facts: facts, tripContext: tripContext, dayOptions: dayOptions) ?? fallbackDayID
                    items.append(
                        PlanDayItem(
                            kind: .flight,
                            dayID: dayID,
                            title: parsed.displayTitle,
                            notes: parsed.notes,
                            startTime: parsed.startTime,
                            endTime: parsed.endTime,
                            flightFromCode: parsed.fromCode,
                            flightToCode: parsed.toCode,
                            flightNumber: parsed.flightNumber,
                            sourceSnippet: trimmed
                        )
                    )
                    continue
                }
                
                if isReminderLike(trimmed) {
                    let dayID = dayIDForDetectedDate(in: trimmed, facts: facts, tripContext: tripContext, dayOptions: dayOptions) ?? fallbackDayID
                    items.append(
                        PlanDayItem(
                            kind: .reminder,
                            dayID: dayID,
                            title: trimmed,
                            sourceSnippet: trimmed
                        )
                    )
                    continue
                }
                
                let dayID = dayIDForDetectedDate(in: trimmed, facts: facts, tripContext: tripContext, dayOptions: dayOptions) ?? fallbackDayID
                let (title, location) = splitTitleLocation(from: trimmed)
                let time = bestTimeForLine(trimmed, facts: facts)
                items.append(
                    PlanDayItem(
                        kind: .activity,
                        dayID: dayID,
                        title: title,
                        location: location,
                        startTime: time,
                        sourceSnippet: trimmed
                    )
                )
            }
        }
        
        return PlanDayDraft(items: items, extractedText: normalized, extractedFacts: facts)
    }
    
    private static func extractFacts(from text: String) -> PlanDayFacts {
        var detectedDates: [PlanDayDetectedDate] = []
        var detectedLinks: [String] = []
        var detectedAddresses: [String] = []
        
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let ns = text as NSString
            let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
            for m in matches {
                guard let date = m.date else { continue }
                let snippet = ns.substring(with: m.range)
                let hasTime = (m.duration > 0) || snippet.range(of: #"(\d{1,2}:\d{2})|(\d{1,2}\s?(am|pm))"#, options: [.regularExpression, .caseInsensitive]) != nil
                detectedDates.append(PlanDayDetectedDate(date: date, hasTime: hasTime, snippet: snippet))
            }
        }
        
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let ns = text as NSString
            let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
            for m in matches {
                if let url = m.url?.absoluteString {
                    detectedLinks.append(url)
                } else {
                    detectedLinks.append(ns.substring(with: m.range))
                }
            }
        }
        
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue) {
            let ns = text as NSString
            let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
            for m in matches {
                detectedAddresses.append(ns.substring(with: m.range))
            }
        }
        
        detectedDates.sort { $0.date < $1.date }
        detectedLinks = Array(Set(detectedLinks)).sorted()
        detectedAddresses = Array(Set(detectedAddresses)).sorted()
        
        return PlanDayFacts(detectedDates: detectedDates, detectedLinks: detectedLinks, detectedAddresses: detectedAddresses)
    }
    
    private static func splitLines(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .flatMap { $0.components(separatedBy: "•") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private static func firstNonIdeasDayID(in options: [DayOption]) -> UUID? {
        options.first(where: { !$0.isParkedIdeas })?.id
    }
    
    private static func buildChecklistIfApplicable(lines: [String], facts: PlanDayFacts, fallbackDayID: UUID?) -> PlanDayItem? {
        let checklistLines = lines.filter { isChecklistLine($0) }
        guard checklistLines.count >= 3 else { return nil }
        let items = checklistLines.map { checklistItemText(from: $0) }.joined(separator: "\n")
        let title = "Checklist"
        let source = checklistLines.prefix(6).joined(separator: "\n")
        return PlanDayItem(kind: .checklist, dayID: fallbackDayID, title: title, checklistItemsText: items, sourceSnippet: source)
    }
    
    private static func isChecklistLine(_ line: String) -> Bool {
        if line.range(of: #"^\s*([-*•]|\d+[\.\)])\s+"#, options: .regularExpression) != nil { return true }
        if line.range(of: #"^\s*\[\s*[xX ]\s*\]\s+"#, options: .regularExpression) != nil { return true }
        return false
    }
    
    private static func checklistItemText(from line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let stripped = trimmed.replacingOccurrences(of: #"^\s*([-*•]|\d+[\.\)])\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\s*\[\s*[xX ]\s*\]\s+"#, with: "", options: .regularExpression)
        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func isReminderLike(_ line: String) -> Bool {
        let lower = line.lowercased()
        let keywords = ["remind", "call", "pay", "book", "reserve", "confirm", "text", "email", "pickup"]
        return keywords.contains(where: { lower.contains($0) })
    }
    
    private static func isFlightLike(_ line: String) -> Bool {
        if line.range(of: #"\b[A-Z]{2}\s?\d{1,4}\b"#, options: .regularExpression) != nil { return true }
        if line.range(of: #"\b[A-Z]{3}\b\s*[-–→]\s*\b[A-Z]{3}\b"#, options: .regularExpression) != nil { return true }
        if line.lowercased().contains("flight") { return true }
        return false
    }
    
    private struct FlightParse {
        var fromCode: String
        var toCode: String
        var flightNumber: String
        var notes: String
        var startTime: Date?
        var endTime: Date?
        var displayTitle: String
    }
    
    private static func parseFlightLike(_ line: String) -> FlightParse {
        let upper = line.uppercased()
        
        let flightNumber: String = {
            if let m = upper.range(of: #"\b[A-Z]{2}\s?\d{1,4}\b"#, options: .regularExpression) {
                return String(upper[m]).replacingOccurrences(of: " ", with: "")
            }
            return ""
        }()
        
        let codes: [String] = {
            let pattern = #"\b[A-Z]{3}\b"#
            let ns = upper as NSString
            let re = try? NSRegularExpression(pattern: pattern)
            let matches = re?.matches(in: upper, range: NSRange(location: 0, length: ns.length)) ?? []
            return matches.map { ns.substring(with: $0.range) }
        }()
        
        let fromCode = codes.first ?? ""
        let toCode = codes.dropFirst().first ?? ""
        
        let displayTitle: String = {
            if !fromCode.isEmpty || !toCode.isEmpty {
                let left = fromCode.isEmpty ? "—" : fromCode
                let right = toCode.isEmpty ? "—" : toCode
                if flightNumber.isEmpty {
                    return "\(left) → \(right)"
                }
                return "\(flightNumber) • \(left) → \(right)"
            }
            if !flightNumber.isEmpty { return flightNumber }
            return "Flight"
        }()
        
        return FlightParse(fromCode: fromCode, toCode: toCode, flightNumber: flightNumber, notes: line, startTime: nil, endTime: nil, displayTitle: displayTitle)
    }
    
    private static func splitTitleLocation(from line: String) -> (String, String) {
        let parts = line.split(separator: " - ", maxSplits: 1, omittingEmptySubsequences: true)
        if parts.count == 2 {
            return (String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines), String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let range = line.range(of: "@") {
            let title = line[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            let loc = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty, !loc.isEmpty { return (String(title), String(loc)) }
        }
        return (line, "")
    }
    
    private static func bestTimeForLine(_ line: String, facts: PlanDayFacts) -> Date? {
        let lower = line.lowercased()
        for d in facts.detectedDates {
            let snippet = d.snippet.lowercased()
            if lower.contains(snippet) { return d.date }
        }
        return facts.detectedDates.first(where: { $0.hasTime })?.date
    }
    
    private static func dayIDForDetectedDate(
        in line: String,
        facts: PlanDayFacts,
        tripContext: PlanDayTripContext,
        dayOptions: [DayOption]
    ) -> UUID? {
        guard tripContext.isDatesSet else { return nil }
        let lower = line.lowercased()
        
        for d in facts.detectedDates {
            if lower.contains(d.snippet.lowercased()) {
                return dayID(for: d.date, tripContext: tripContext, dayOptions: dayOptions)
            }
        }
        
        if let first = facts.detectedDates.first {
            return dayID(for: first.date, tripContext: tripContext, dayOptions: dayOptions)
        }
        
        return nil
    }
    
    private static func dayID(for date: Date, tripContext: PlanDayTripContext, dayOptions: [DayOption]) -> UUID? {
        guard tripContext.isDatesSet else { return nil }
        let cal = Calendar.current
        let target = cal.startOfDay(for: date)
        let start = cal.startOfDay(for: tripContext.startDate)
        let end = cal.startOfDay(for: tripContext.endDate)
        guard target >= start, target <= end else { return nil }
        
        let offset = cal.dateComponents([.day], from: start, to: target).day ?? 0
        let dayIndex = max(0, offset)
        let nonIdeas = dayOptions.filter { !$0.isParkedIdeas }
        guard dayIndex < nonIdeas.count else { return nonIdeas.last?.id }
        return nonIdeas[dayIndex].id
    }
}

