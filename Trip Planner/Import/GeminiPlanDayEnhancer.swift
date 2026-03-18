import Foundation

struct GeminiPlanDayEnhancer {
    let endpoint: URL
    
    init(endpoint: URL) {
        self.endpoint = endpoint
    }
    
    func enhance(draft: PlanDayDraft, tripContext: PlanDayTripContext, preferences: PlanDayUserPreferences?) async throws -> PlanDayDraft {
        let req = GeminiPlanDayEnhanceRequest(
            text: draft.extractedText,
            facts: draft.extractedFacts,
            tripContext: tripContext,
            preferences: preferences,
            existingItems: draft.items
        )
        
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        urlRequest.httpBody = try encoder.encode(req)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw GeminiPlanDayEnhancerError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GeminiPlanDayEnhancerError.http(status: http.statusCode, body: body)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode(GeminiPlanDayEnhanceResponse.self, from: data) {
            return PlanDayDraft(items: decoded.items, extractedText: draft.extractedText, extractedFacts: draft.extractedFacts)
        }
        let loose = try decoder.decode(GeminiPlanDayEnhanceResponseLoose.self, from: data)
        let mapped = loose.items.map { $0.toStrict() }
        return PlanDayDraft(items: mapped, extractedText: draft.extractedText, extractedFacts: draft.extractedFacts)
    }
}

enum GeminiPlanDayEnhancerError: LocalizedError {
    case invalidResponse
    case http(status: Int, body: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server."
        case .http(let status, let body):
            if body.isEmpty {
                return "Server error (\(status))."
            }
            return "Server error (\(status)): \(body)"
        }
    }
}

private struct GeminiPlanDayEnhanceRequest: Codable {
    var text: String
    var facts: PlanDayFacts
    var tripContext: PlanDayTripContext
    var preferences: PlanDayUserPreferences?
    var existingItems: [PlanDayItem]
}

private struct GeminiPlanDayEnhanceResponse: Codable {
    var items: [PlanDayItem]
}

private struct GeminiPlanDayEnhanceResponseLoose: Codable {
    var items: [PlanDayItemLoose]
}

private struct PlanDayItemLoose: Codable {
    var id: String?
    var kind: String?
    var include: BoolOrString?
    var dayID: StringOrNull?
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
    
    func toStrict() -> PlanDayItem {
        let kindValue: PlanDayItemKind = {
            switch (kind ?? "").lowercased() {
            case "reminder": return .reminder
            case "checklist": return .checklist
            case "flight": return .flight
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
        
        func s(_ v: StringOrNull?) -> String {
            if case let .value(x) = v { return x ?? "" }
            return ""
        }
        
        func date(_ v: StringOrNull?) -> Date? {
            if case let .value(x) = v, let x {
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
            return nil
        }
        
        let checklistText: String = {
            switch checklistItemsText {
            case .string(let v):
                return v ?? ""
            case .array(let arr):
                return (arr ?? []).joined(separator: "\n")
            case .null, .none:
                return ""
            }
        }()
        
        let includeValue: Bool = {
            switch include {
            case .bool(let b): return b
            case .string(let s):
                let t = (s ?? "").lowercased()
                if t == "false" || t == "0" || t == "no" { return false }
                return true
            case .none:
                return true
            }
        }()
        
        return PlanDayItem(
            id: uuid,
            kind: kindValue,
            include: includeValue,
            dayID: day,
            title: s(title),
            subtitle: s(subtitle),
            location: s(location),
            notes: s(notes),
            startTime: date(startTime),
            endTime: date(endTime),
            checklistItemsText: checklistText,
            flightFromCode: s(flightFromCode),
            flightToCode: s(flightToCode),
            flightNumber: s(flightNumber),
            confidence: confidence,
            sourceSnippet: {
                let v = s(sourceSnippet)
                return v.isEmpty ? s(title) : v
            }()
        )
    }
}

private enum BoolOrString: Codable {
    case bool(Bool)
    case string(String?)
    
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) {
            self = .bool(b)
            return
        }
        if let s = try? c.decode(String.self) {
            self = .string(s)
            return
        }
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
        let s = try? c.decode(String.self)
        self = .value(s)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .value(let s):
            if let s { try c.encode(s) } else { try c.encodeNil() }
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

