import Foundation
import UniformTypeIdentifiers
import Vision
import PDFKit
import UIKit

enum DocumentTextExtractor {
    enum SuggestedFieldType: String {
        case startTime
        case endTime
        case cost
        case currencyCode
        case referenceCode
    }

    enum Confidence: Int {
        case low = 0
        case medium = 1
        case high = 2

        var label: String {
            switch self {
            case .high: return "High"
            case .medium: return "Medium"
            case .low: return "Low"
            }
        }
    }

    struct SuggestedField: Identifiable {
        let id: UUID
        let type: SuggestedFieldType
        let title: String
        let value: String
        let confidence: Confidence
        let sourceDocumentName: String?
        let sourceSnippet: String?
        let timeComponents: DateComponents?
        let numericAmount: Double?

        init(
            id: UUID = UUID(),
            type: SuggestedFieldType,
            title: String,
            value: String,
            confidence: Confidence,
            sourceDocumentName: String? = nil,
            sourceSnippet: String? = nil,
            timeComponents: DateComponents? = nil,
            numericAmount: Double? = nil
        ) {
            self.id = id
            self.type = type
            self.title = title
            self.value = value
            self.confidence = confidence
            self.sourceDocumentName = sourceDocumentName
            self.sourceSnippet = sourceSnippet
            self.timeComponents = timeComponents
            self.numericAmount = numericAmount
        }
    }

    struct ExtractionResult: Identifiable {
        let id: UUID
        let suggestions: [SuggestedField]
        let noteLines: [String]

        init(
            id: UUID = UUID(),
            suggestions: [SuggestedField],
            noteLines: [String]
        ) {
            self.id = id
            self.suggestions = suggestions
            self.noteLines = noteLines
        }

        var hasContent: Bool {
            !suggestions.isEmpty || !noteLines.isEmpty
        }

        func notesBlock(excluding appliedValues: [String]) -> String {
            let normalizedValues = appliedValues
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }

            let filtered = noteLines.filter { line in
                let lower = line.lowercased()
                return !normalizedValues.contains(where: { lower.contains($0) })
            }

            guard !filtered.isEmpty else { return "" }
            let bullets = filtered.prefix(8).map { "- \($0)" }
            return (["From documents:"] + bullets).joined(separator: "\n")
        }
    }

    private struct TimeDetection {
        let start: Date?
        let end: Date?
        let startSnippet: String?
        let endSnippet: String?
    }

    struct DetectedCost {
        let amount: Double
        let currencyCode: String?
        let snippet: String?
        let confidence: Confidence
    }

    static func extractText(from documents: [EventDocument]) async -> String {
        let result = await extractInfo(from: documents)
        return result.notesBlock(excluding: [])
    }

    static func extractInfo(from documents: [EventDocument]) async -> ExtractionResult {
        var chunks: [(documentName: String, text: String)] = []

        for document in documents {
            let url = ActivityDocumentStore.fileURL(for: document.localRelativePath)
            let extracted = await extractText(from: url, document: document)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !extracted.isEmpty {
                chunks.append((document.fileName, extracted))
            }
        }

        let combined = chunks.map(\.text).joined(separator: "\n\n")
        let noteLines = prioritizedLines(from: combined)
        var suggestions: [SuggestedField] = []

        let timeDetection = detectTimes(in: combined)
        if let start = timeDetection.start {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: start)
            suggestions.append(
                SuggestedField(
                    type: .startTime,
                    title: "Start time",
                    value: displayTime(from: comps),
                    confidence: .high,
                    sourceDocumentName: sourceDocumentName(for: timeDetection.startSnippet, in: chunks),
                    sourceSnippet: timeDetection.startSnippet,
                    timeComponents: comps
                )
            )
        }
        if let end = timeDetection.end {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: end)
            suggestions.append(
                SuggestedField(
                    type: .endTime,
                    title: "End time",
                    value: displayTime(from: comps),
                    confidence: .high,
                    sourceDocumentName: sourceDocumentName(for: timeDetection.endSnippet, in: chunks),
                    sourceSnippet: timeDetection.endSnippet,
                    timeComponents: comps
                )
            )
        }

        let detectedCosts = detectCostCandidates(in: combined)
        for (index, detectedCost) in detectedCosts.enumerated() {
            let title = index == 0 ? "Cost" : "Cost option"
            suggestions.append(
                SuggestedField(
                    type: .cost,
                    title: title,
                    value: String(format: "%.2f", detectedCost.amount),
                    confidence: detectedCost.confidence,
                    sourceDocumentName: sourceDocumentName(for: detectedCost.snippet, in: chunks),
                    sourceSnippet: detectedCost.snippet,
                    numericAmount: detectedCost.amount
                )
            )
        }
        if let topCurrency = detectedCosts.first?.currencyCode {
            suggestions.append(
                SuggestedField(
                    type: .currencyCode,
                    title: "Currency",
                    value: topCurrency,
                    confidence: detectedCosts.first?.confidence ?? .medium,
                    sourceDocumentName: sourceDocumentName(for: detectedCosts.first?.snippet, in: chunks),
                    sourceSnippet: detectedCosts.first?.snippet
                )
            )
        }

        for reference in detectReferenceCodes(in: combined).prefix(2) {
            suggestions.append(
                SuggestedField(
                    type: .referenceCode,
                    title: "Reference code",
                    value: reference,
                    confidence: .medium,
                    sourceDocumentName: sourceDocumentName(for: reference, in: chunks),
                    sourceSnippet: reference
                )
            )
        }

        return ExtractionResult(suggestions: suggestions, noteLines: noteLines)
    }
    
    private static func extractText(from url: URL, document: EventDocument) async -> String {
        let ext = document.fileExtension.lowercased()
        let type = UTType(filenameExtension: ext)
        
        if type?.conforms(to: .pdf) == true || ext == "pdf" {
            return await extractTextFromPDF(url: url)
        }
        
        if type?.conforms(to: .image) == true || document.mimeType?.lowercased().hasPrefix("image/") == true {
            return await extractTextFromImage(url: url)
        }
        
        // Lightweight fallback for plain text-like files.
        if type?.conforms(to: .plainText) == true || ["txt", "md", "csv", "json"].contains(ext) {
            if let string = try? String(contentsOf: url, encoding: .utf8) {
                return string
            }
        }
        
        return ""
    }
    
    private static func extractTextFromPDF(url: URL) async -> String {
        guard let pdf = PDFDocument(url: url) else { return "" }
        
        var lines: [String] = []
        for index in 0..<pdf.pageCount {
            guard let page = pdf.page(at: index) else { continue }
            let directText = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !directText.isEmpty {
                lines.append(directText)
                continue
            }
            
            // If this page has no embedded text, OCR the rendered page image.
            let pageBounds = page.bounds(for: .mediaBox)
            let target = CGSize(width: max(1200, pageBounds.width), height: max(1200, pageBounds.height))
            let image = page.thumbnail(of: target, for: .mediaBox)
            if let cgImage = image.cgImage {
                let ocr = await recognizeText(in: cgImage).trimmingCharacters(in: .whitespacesAndNewlines)
                if !ocr.isEmpty {
                    lines.append(ocr)
                }
            }
        }
        
        return lines.joined(separator: "\n\n")
    }
    
    private static func extractTextFromImage(url: URL) async -> String {
        guard
            let data = try? Data(contentsOf: url),
            let image = UIImage(data: data),
            let cgImage = image.cgImage
        else {
            return ""
        }
        
        return await recognizeText(in: cgImage)
    }
    
    private static func recognizeText(in cgImage: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n") ?? ""
                continuation.resume(returning: text)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }

    private static func prioritizedLines(from rawText: String) -> [String] {
        let normalized = rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var seen = Set<String>()
        let lines = normalized
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression) }
            .filter { !$0.isEmpty && $0.count > 2 }
            .filter { line in
                let key = line.lowercased()
                if seen.contains(key) { return false }
                seen.insert(key)
                return true
            }

        if lines.isEmpty { return [] }

        let priorityKeywords = [
            "booking", "reservation", "confirmation", "reference", "pnr", "ticket",
            "invoice", "total", "amount", "price", "cost", "paid", "balance",
            "date", "time", "depart", "arrival"
        ]

        var priority: [String] = []
        var details: [String] = []
        for line in lines {
            let lower = line.lowercased()
            if priorityKeywords.contains(where: { lower.contains($0) }) {
                priority.append(line)
            } else {
                details.append(line)
            }
        }

        return Array((priority + details).prefix(20))
    }

    private static func detectTimes(in text: String) -> TimeDetection {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return TimeDetection(start: nil, end: nil, startSnippet: nil, endSnippet: nil)
        }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return TimeDetection(start: nil, end: nil, startSnippet: nil, endSnippet: nil)
        }

        let range = NSRange(location: 0, length: (text as NSString).length)
        let matches = detector.matches(in: text, options: [], range: range)

        var startDate: Date?
        var endDate: Date?
        var startSnippet: String?
        var endSnippet: String?
        let nsText = text as NSString

        for match in matches {
            guard let date = match.date else { continue }
            let snippet = match.range.location != NSNotFound ? nsText.substring(with: match.range) : nil
            if startDate == nil {
                startDate = date
                startSnippet = snippet
            }
            if match.duration > 0, endDate == nil {
                endDate = date.addingTimeInterval(match.duration)
                endSnippet = snippet
            }
            if endDate == nil, let start = startDate, date > start {
                endDate = date
                endSnippet = snippet
            }
            if startDate != nil && endDate != nil { break }
        }

        return TimeDetection(start: startDate, end: endDate, startSnippet: startSnippet, endSnippet: endSnippet)
    }

    private static func detectCostCandidates(in text: String) -> [DetectedCost] {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return [] }

        guard
            let symbolRegex = try? NSRegularExpression(
                pattern: #"([$€£¥])\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})|[0-9]+(?:\.[0-9]{1,2})?)"#,
                options: [.caseInsensitive]
            ),
            let codeRegexLeading = try? NSRegularExpression(
                pattern: #"\b(USD|EUR|GBP|JPY|CAD|AUD|CHF|PLN)\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})|[0-9]+(?:\.[0-9]{1,2})?)\b"#,
                options: [.caseInsensitive]
            ),
            let codeRegexTrailing = try? NSRegularExpression(
                pattern: #"([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})|[0-9]+(?:\.[0-9]{1,2})?)\s*(USD|EUR|GBP|JPY|CAD|AUD|CHF|PLN)\b"#,
                options: [.caseInsensitive]
            )
        else {
            return []
        }

        struct Candidate {
            let amount: Double
            let currencyCode: String?
            let snippet: String
            let score: Int
        }

        var candidates: [Candidate] = []
        var seen = Set<String>()

        for (index, line) in lines.enumerated() {
            let lowerLine = line.lowercased()
            let contextWindow = lines[max(0, index - 1)...min(lines.count - 1, index + 1)]
                .joined(separator: " ")
                .lowercased()
            let nsLine = line as NSString
            let lineRange = NSRange(location: 0, length: nsLine.length)

            func appendCandidate(amountRaw: String, currency: String?, snippet: String) {
                let amountString = amountRaw.replacingOccurrences(of: ",", with: "")
                guard let amount = Double(amountString), amount > 0 else { return }

                var score = 0

                let strongPositive = [
                    "grand total", "total due", "amount due", "total price", "total amount", "charged", "paid in full"
                ]
                let mildPositive = ["total", "amount", "paid", "balance", "invoice", "booking total"]
                let strongNegative = [
                    "per night", "/night", "nightly", "daily", "per day", "/day", "day rate", "night rate", "rate:"
                ]
                let mildNegative = ["tax", "fees", "fee", "deposit", "cleaning", "service fee"]

                for key in strongPositive where contextWindow.contains(key) { score += 5 }
                for key in mildPositive where contextWindow.contains(key) { score += 2 }
                for key in strongNegative where contextWindow.contains(key) { score -= 6 }
                for key in mildNegative where contextWindow.contains(key) { score -= 2 }

                if lowerLine.contains("total") && !contextWindow.contains("per night") && !contextWindow.contains("per day") {
                    score += 3
                }

                if amount >= 100 { score += 1 }
                if amount >= 500 { score += 1 }

                let currencyKey = currency?.uppercased() ?? ""
                let dedupeKey = "\(currencyKey)|\(String(format: "%.2f", amount))"
                guard !seen.contains(dedupeKey) else { return }
                seen.insert(dedupeKey)

                candidates.append(
                    Candidate(
                        amount: amount,
                        currencyCode: currency?.uppercased(),
                        snippet: snippet,
                        score: score
                    )
                )
            }

            for match in symbolRegex.matches(in: line, options: [], range: lineRange) {
                guard match.numberOfRanges >= 3 else { continue }
                let symbol = nsLine.substring(with: match.range(at: 1))
                let amount = nsLine.substring(with: match.range(at: 2))
                appendCandidate(amountRaw: amount, currency: currencyCode(for: symbol), snippet: line)
            }

            for match in codeRegexLeading.matches(in: line, options: [], range: lineRange) {
                guard match.numberOfRanges >= 3 else { continue }
                let code = nsLine.substring(with: match.range(at: 1))
                let amount = nsLine.substring(with: match.range(at: 2))
                appendCandidate(amountRaw: amount, currency: code, snippet: line)
            }

            for match in codeRegexTrailing.matches(in: line, options: [], range: lineRange) {
                guard match.numberOfRanges >= 3 else { continue }
                let amount = nsLine.substring(with: match.range(at: 1))
                let code = nsLine.substring(with: match.range(at: 2))
                appendCandidate(amountRaw: amount, currency: code, snippet: line)
            }
        }

        let sorted = candidates.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.amount > rhs.amount
        }

        return sorted.prefix(3).map { candidate in
            let confidence: Confidence
            if candidate.score >= 8 {
                confidence = .high
            } else if candidate.score >= 3 {
                confidence = .medium
            } else {
                confidence = .low
            }
            return DetectedCost(
                amount: candidate.amount,
                currencyCode: candidate.currencyCode,
                snippet: candidate.snippet,
                confidence: confidence
            )
        }
    }

    private static func detectReferenceCodes(in text: String) -> [String] {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n")
            .map { String($0) }

        let keywords = ["booking", "confirmation", "reference", "pnr", "record locator", "ticket"]
        guard let tokenRegex = try? NSRegularExpression(pattern: #"\b[A-Z0-9]{5,10}\b"#, options: []) else {
            return []
        }

        var results: [String] = []
        var seen = Set<String>()

        for line in lines {
            let lower = line.lowercased()
            guard keywords.contains(where: { lower.contains($0) }) else { continue }
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)
            for match in tokenRegex.matches(in: line, options: [], range: range) {
                let token = nsLine.substring(with: match.range)
                if !seen.contains(token) {
                    seen.insert(token)
                    results.append(token)
                }
            }
        }
        return results
    }

    private static func currencyCode(for symbol: String) -> String? {
        switch symbol {
        case "$": return "USD"
        case "€": return "EUR"
        case "£": return "GBP"
        case "¥": return "JPY"
        default: return nil
        }
    }

    private static func sourceDocumentName(
        for snippet: String?,
        in chunks: [(documentName: String, text: String)]
    ) -> String? {
        guard let snippet = snippet?.trimmingCharacters(in: .whitespacesAndNewlines), !snippet.isEmpty else {
            return nil
        }
        let needle = snippet.lowercased()
        return chunks.first(where: { $0.text.lowercased().contains(needle) })?.documentName
    }

    private static func displayTime(from components: DateComponents) -> String {
        guard let hour = components.hour, let minute = components.minute else { return "" }
        let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
