import Foundation

struct TripStacksAIClient {
    static let defaultEndpoint = URL(string: "https://trip-planner-ai-proxy.vercel.app/api/ai")!
    
    let endpoint: URL
    
    init(endpoint: URL = TripStacksAIClient.defaultEndpoint) {
        self.endpoint = endpoint
    }
    
    func generate(_ request: AIRequest) async throws -> AIResponse {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw TripStacksAIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw TripStacksAIError.http(status: http.statusCode, body: body)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let decoded = try? decoder.decode(AIResponse.self, from: data) {
            return decoded.normalized()
        }
        
        // Loose fallback for partially messy model payloads.
        if let loose = try? decoder.decode(AIResponseLoose.self, from: data) {
            return loose.toStrict().normalized()
        }
        
        throw TripStacksAIError.invalidResponse
    }
}

private extension AIResponse {
    func normalized() -> AIResponse {
        var copy = self
        copy.items = items.map { item in
            var updated = item
            if updated.sourceSnippet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updated.sourceSnippet = updated.title
            }
            return updated
        }
        return copy
    }
}

// MARK: - Loose decoding

private struct AIResponseLoose: Codable {
    var intent: StringOrNull?
    var clarificationNeeded: BoolOrString?
    var clarificationPrompt: StringOrNull?
    var items: [PlanDayItemLoose]?
    var trip: AITripDraftLoose?
    var alternatives: [AITripDraftLoose]?
    
    func toStrict() -> AIResponse {
        AIResponse(
            intent: stringValue(intent),
            clarificationNeeded: boolValue(clarificationNeeded, default: false),
            clarificationPrompt: stringValue(clarificationPrompt),
            items: (items ?? []).map { $0.toStrict() },
            trip: trip?.toStrict(),
            alternatives: (alternatives ?? []).map { $0.toStrict() }
        )
    }
}

private struct AITripDraftLoose: Codable {
    var name: StringOrNull?
    var destination: StringOrNull?
    var isDatesSet: BoolOrString?
    var startDate: StringOrNull?
    var endDate: StringOrNull?
    var unscheduledDaysCount: IntOrString?
    var summary: StringOrNull?
    var confidence: Double?
    
    func toStrict() -> AITripDraft {
        AITripDraft(
            name: stringValue(name),
            destination: stringValue(destination),
            isDatesSet: boolValue(isDatesSet, default: false),
            startDate: optionalString(startDate),
            endDate: optionalString(endDate),
            unscheduledDaysCount: intValue(unscheduledDaysCount, default: 3),
            summary: stringValue(summary),
            confidence: confidence ?? 0.5
        )
    }
}

private struct PlanDayItemLoose: Codable {
    var id: String?
    var kind: String?
    var include: BoolOrString?
    var dayID: StringOrNull?
    var dayIndex: IntOrString?
    var dayLabel: StringOrNull?
    var title: StringOrNull?
    var subtitle: StringOrNull?
    var location: StringOrNull?
    var notes: StringOrNull?
    var startTime: StringOrNull?
    var endTime: StringOrNull?
    var checklistItemsText: StringOrStringArrayOrNull?
    var flightFromCode: StringOrNull?
    var flightToCode: StringOrNull?
    var flightNumber: StringOrNull?
    var confidence: Double?
    var sourceSnippet: StringOrNull?
    var category: StringOrNull?
    
    func toStrict() -> PlanDayItem {
        let kindValue: PlanDayItemKind = {
            switch (kind ?? "").lowercased() {
            case "reminder": return .reminder
            case "checklist": return .checklist
            case "flight": return .flight
            case "place": return .place
            default: return .activity
            }
        }()
        
        let uuid: UUID = {
            if let id, let u = UUID(uuidString: id) { return u }
            return UUID()
        }()
        
        let day: UUID? = {
            if case let .value(s) = dayID, let s, let u = UUID(uuidString: s) { return u }
            return nil
        }()
        
        let checklistText: String = {
            switch checklistItemsText {
            case .string(let v): return v ?? ""
            case .array(let arr): return (arr ?? []).joined(separator: "\n")
            case .null, .none: return ""
            }
        }()
        
        return PlanDayItem(
            id: uuid,
            kind: kindValue,
            include: boolValue(include, default: true),
            dayID: day,
            dayIndex: optionalInt(dayIndex),
            dayLabel: stringValue(dayLabel),
            title: stringValue(title),
            subtitle: stringValue(subtitle),
            location: stringValue(location),
            notes: stringValue(notes),
            startTime: parseFlexibleDate(startTime),
            endTime: parseFlexibleDate(endTime),
            checklistItemsText: checklistText,
            flightFromCode: stringValue(flightFromCode),
            flightToCode: stringValue(flightToCode),
            flightNumber: stringValue(flightNumber),
            confidence: confidence,
            sourceSnippet: {
                let v = stringValue(sourceSnippet)
                return v.isEmpty ? stringValue(title) : v
            }(),
            category: stringValue(category)
        )
    }
}

private enum BoolOrString: Codable {
    case bool(Bool)
    case string(String?)
    
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        self = .string(nil)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .bool(let b): try c.encode(b)
        case .string(let s): try c.encode(s)
        }
    }
}

private enum StringOrNull: Codable {
    case value(String?)
    
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .value(nil); return }
        self = .value(try? c.decode(String.self))
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        if case let .value(s) = self, let s {
            try c.encode(s)
        } else {
            try c.encodeNil()
        }
    }
}

private enum IntOrString: Codable {
    case int(Int)
    case string(String?)
    
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { self = .int(i); return }
        if let d = try? c.decode(Double.self) { self = .int(Int(d)); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        self = .string(nil)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .int(let i): try c.encode(i)
        case .string(let s): try c.encode(s)
        }
    }
}

private enum StringOrStringArrayOrNull: Codable {
    case string(String?)
    case array([String]?)
    case null
    
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let a = try? c.decode([String].self) { self = .array(a); return }
        self = .null
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s):
            if let s { try c.encode(s) } else { try c.encodeNil() }
        case .array(let a):
            if let a { try c.encode(a) } else { try c.encodeNil() }
        case .null:
            try c.encodeNil()
        }
    }
}

private func stringValue(_ v: StringOrNull?) -> String {
    if case let .value(x) = v { return x ?? "" }
    return ""
}

private func optionalString(_ v: StringOrNull?) -> String? {
    if case let .value(x) = v {
        let t = (x ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
    return nil
}

private func boolValue(_ v: BoolOrString?, default defaultValue: Bool) -> Bool {
    switch v {
    case .bool(let b): return b
    case .string(let s):
        let t = (s ?? "").lowercased()
        if t == "false" || t == "0" || t == "no" { return false }
        if t == "true" || t == "1" || t == "yes" { return true }
        return defaultValue
    case .none:
        return defaultValue
    }
}

private func optionalInt(_ v: IntOrString?) -> Int? {
    switch v {
    case .int(let i): return i
    case .string(let s):
        guard let s, let i = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return i
    case .none:
        return nil
    }
}

private func intValue(_ v: IntOrString?, default defaultValue: Int) -> Int {
    optionalInt(v) ?? defaultValue
}

private func parseFlexibleDate(_ v: StringOrNull?) -> Date? {
    guard case let .value(x) = v, let x else { return nil }
    let trimmed = x.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return nil }
    
    if let iso = ISO8601DateFormatter().date(from: trimmed) {
        return iso
    }
    
    let timeFormats = ["HH:mm", "H:mm", "h:mm a", "hh:mm a", "h a", "ha"]
    let base = Calendar.current.startOfDay(for: Date())
    for fmt in timeFormats {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = fmt
        if let parsed = f.date(from: trimmed) {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: parsed)
            if let hour = comps.hour {
                return Calendar.current.date(
                    bySettingHour: hour,
                    minute: comps.minute ?? 0,
                    second: 0,
                    of: base
                )
            }
        }
    }
    return nil
}
