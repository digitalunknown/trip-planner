import Foundation

struct GeminiPasteEnhancer {
    let endpoint: URL
    
    init(endpoint: URL) {
        self.endpoint = endpoint
    }
    
    func enhance(draft: PasteImportDraft, tripContext: PasteImportTripContext, preferences: PasteImportUserPreferences?) async throws -> PasteImportDraft {
        let req = GeminiPasteEnhanceRequest(
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
            throw GeminiPasteEnhancerError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GeminiPasteEnhancerError.http(status: http.statusCode, body: body)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode(GeminiPasteEnhanceResponse.self, from: data) {
            return PasteImportDraft(items: decoded.items, extractedText: draft.extractedText, extractedFacts: draft.extractedFacts)
        }
        let loose = try decoder.decode(GeminiPasteEnhanceResponseLoose.self, from: data)
        let mapped = loose.items.map { $0.toStrict() }
        return PasteImportDraft(items: mapped, extractedText: draft.extractedText, extractedFacts: draft.extractedFacts)
    }
}

enum GeminiPasteEnhancerError: LocalizedError {
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

private struct GeminiPasteEnhanceRequest: Codable {
    var text: String
    var facts: PasteImportFacts
    var tripContext: PasteImportTripContext
    var preferences: PasteImportUserPreferences?
    var existingItems: [PasteImportItem]
}

private struct GeminiPasteEnhanceResponse: Codable {
    var items: [PasteImportItem]
}

private struct GeminiPasteEnhanceResponseLoose: Codable {
    var items: [PasteImportItemLoose]
}

private struct PasteImportItemLoose: Codable {
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
    
    func toStrict() -> PasteImportItem {
        let kindValue: PasteImportItemKind = {
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
                return ISO8601DateFormatter().date(from: x)
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
        
        return PasteImportItem(
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

