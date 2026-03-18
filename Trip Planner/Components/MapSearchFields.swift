import SwiftUI
import MapKit
import Combine


struct LocationSearchField: View {
    @Binding var text: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var mapSpan: Double?
    var resultTypes: MKLocalSearchCompleter.ResultType
    var searchRegion: MKCoordinateRegion?
    
    @StateObject private var completer: LocationSearchCompleter
    @State private var showingResults = false
    
    init(text: Binding<String>, 
         latitude: Binding<Double?>, 
         longitude: Binding<Double?>,
         mapSpan: Binding<Double?> = .constant(nil),
         resultTypes: MKLocalSearchCompleter.ResultType = .pointOfInterest,
         searchRegion: MKCoordinateRegion? = nil) {
        self._text = text
        self._latitude = latitude
        self._longitude = longitude
        self._mapSpan = mapSpan
        self.resultTypes = resultTypes
        self.searchRegion = searchRegion
        self._completer = StateObject(wrappedValue: LocationSearchCompleter(
            resultTypes: resultTypes,
            searchRegion: searchRegion
        ))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TextField("Location", text: $text)
                    .onChange(of: text) { _, newValue in
                        completer.searchQuery = newValue
                        showingResults = !newValue.isEmpty
                    }
                
                if !text.isEmpty {
                    Button {
                        text = ""
                        latitude = nil
                        longitude = nil
                        showingResults = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if showingResults && !completer.results.isEmpty {
                Divider()
                    .padding(.top, 8)
                
                VStack(spacing: 0) {
                    ForEach(completer.results, id: \.self) { result in
                        Button {
                            selectLocation(result)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                Text(result.title)
                                    .font(.appBody)
                                    .foregroundStyle(.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.appCaption)
                                        .foregroundStyle(.secondary)
                                }
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                        
                        if result != completer.results.last {
                            Divider()
                        }
                    }
                }
            } else if showingResults && completer.results.isEmpty && !text.isEmpty {
                Text("No results")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
    }
    
    private func selectLocation(_ result: MKLocalSearchCompletion) {
        self.text = result.title
        self.showingResults = false
        
        let searchRequest = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            guard let response = response,
                  let first = response.mapItems.first,
                  let coordinate = mapItemCoordinate(first) else {
                return
            }
            
            self.latitude = coordinate.latitude
            self.longitude = coordinate.longitude
            
            let span = max(response.boundingRegion.span.latitudeDelta, response.boundingRegion.span.longitudeDelta)
            self.mapSpan = span
        }
    }
}

class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer: MKLocalSearchCompleter
    private let pointOfInterestCategories: [MKPointOfInterestCategory]?
    
    var searchQuery: String = "" {
        didSet {
            completer.queryFragment = searchQuery
        }
    }
    
    init(
        resultTypes: MKLocalSearchCompleter.ResultType = .pointOfInterest,
        searchRegion: MKCoordinateRegion? = nil,
        pointOfInterestCategories: [MKPointOfInterestCategory]? = nil
    ) {
        completer = MKLocalSearchCompleter()
        self.pointOfInterestCategories = pointOfInterestCategories
        super.init()
        completer.delegate = self
        completer.resultTypes = resultTypes
        if let cats = pointOfInterestCategories {
            completer.pointOfInterestFilter = MKPointOfInterestFilter(including: cats)
        }
        if let region = searchRegion {
            completer.region = region
        }
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.results = completer.results
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Location search error: \(error.localizedDescription)")
    }
}


struct AirportSearchField: View {
    let title: String
    @Binding var name: String
    @Binding var code: String
    @Binding var city: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    var searchRegion: MKCoordinateRegion?
    
    @StateObject private var completer: LocationSearchCompleter
    @State private var showingResults = false
    @State private var resolvedCodes: [MKLocalSearchCompletion: String] = [:]
    @State private var failedCodeResolutions: Set<MKLocalSearchCompletion> = []
    @State private var inFlightCodeResolutions: Set<MKLocalSearchCompletion> = []
    @State private var fallbackItems: [MKMapItem] = []
    @State private var isFallbackSearching: Bool = false
    @State private var fallbackTask: Task<Void, Never>?
    
    private var filteredResults: [MKLocalSearchCompletion] {
        completer.results.filter(isAirportCompletion)
    }
    
    private func codeForDisplay(_ result: MKLocalSearchCompletion) -> String {
        let direct = airportCodeCandidate(for: result)
        if !direct.isEmpty { return direct }
        return resolvedCodes[result] ?? ""
    }
    
    init(
        title: String,
        name: Binding<String>,
        code: Binding<String>,
        city: Binding<String>,
        latitude: Binding<Double?>,
        longitude: Binding<Double?>,
        searchRegion: MKCoordinateRegion? = nil
    ) {
        self.title = title
        self._name = name
        self._code = code
        self._city = city
        self._latitude = latitude
        self._longitude = longitude
        self.searchRegion = searchRegion
        self._completer = StateObject(
            wrappedValue: LocationSearchCompleter(
                resultTypes: .pointOfInterest,
                searchRegion: searchRegion,
                pointOfInterestCategories: [.airport]
            )
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TextField(title, text: $name)
                    .onChange(of: name) { _, newValue in
                        completer.searchQuery = newValue
                        showingResults = !newValue.isEmpty
                        scheduleFallbackSearch(for: newValue)
                    }
                
                if !name.isEmpty {
                    Button {
                        name = ""
                        code = ""
                        city = ""
                        latitude = nil
                        longitude = nil
                        showingResults = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if showingResults && !filteredResults.isEmpty {
                Divider()
                    .padding(.top, 8)
                
                VStack(spacing: 0) {
                    ForEach(filteredResults, id: \.self) { result in
                        let code = codeForDisplay(result)
                        let airportName = stripLeadingCode(from: result.title)
                        let isResolvingCode = code.isEmpty && !failedCodeResolutions.contains(result)
                        Button {
                            selectAirport(result)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(code.isEmpty ? airportName : "\(code) - \(airportName)")
                                        .font(.appBody)
                                        .foregroundStyle(.primary)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.appCaption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 0)
                                
                                if isResolvingCode {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.secondary)
                                } else if !code.isEmpty {
                                    Text(code)
                                        .font(.app(12, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.thinMaterial, in: Capsule())
                                }
                            }
                            .contentShape(Rectangle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                        
                        if result != filteredResults.last {
                            Divider()
                        }
                    }
                }
            } else if showingResults && filteredResults.isEmpty && !fallbackItems.isEmpty {
                Divider()
                    .padding(.top, 8)
                
                VStack(spacing: 0) {
                    ForEach(fallbackItems.prefix(10), id: \.self) { item in
                        Button {
                            selectAirportMapItem(item)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    let airportName = item.name ?? name
                                    let code = airportCodeCandidate(fromText: [item.name, mapItemAddressString(item)].compactMap { $0 }.joined(separator: " "))
                                    Text(code.isEmpty ? airportName : "\(code) - \(airportName)")
                                        .font(.appBody)
                                        .foregroundStyle(.primary)
                                    
                                    let subtitle = bestAirportSubtitle(for: item)
                                    if !subtitle.isEmpty {
                                        Text(subtitle)
                                            .font(.appCaption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Spacer(minLength: 0)
                                
                                let code = airportCodeCandidate(fromText: [item.name, mapItemAddressString(item)].compactMap { $0 }.joined(separator: " "))
                                if !code.isEmpty {
                                    Text(code)
                                        .font(.app(12, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.thinMaterial, in: Capsule())
                                }
                            }
                            .contentShape(Rectangle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                        
                        if item != fallbackItems.prefix(10).last {
                            Divider()
                        }
                    }
                }
            } else if showingResults && filteredResults.isEmpty && isFallbackSearching {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.9)
                    Text("Searching airports…")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .onChange(of: completer.results) { _, newValue in
            for result in Array(newValue.prefix(8)) {
                if !isAirportCompletion(result) { continue }
                if !airportCodeCandidate(for: result).isEmpty { continue }
                if failedCodeResolutions.contains(result) { continue }
                if inFlightCodeResolutions.contains(result) { continue }
                if (resolvedCodes[result] ?? "").isEmpty {
                    resolveCodeForResult(result)
                }
            }
        }
    }
    
    private func selectAirport(_ result: MKLocalSearchCompletion) {
        let airportName = stripLeadingCode(from: result.title)
        name = airportName
        showingResults = false
        fallbackTask?.cancel()
        fallbackItems = []
        let initialCode = codeForDisplay(result)
        
        let request = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            guard let response else { return }
            let items = response.mapItems
            guard let first = items.first else { return }
            guard let coordinate = mapItemCoordinate(first) else { return }
            
            if let poi = first.pointOfInterestCategory, poi != .airport, initialCode.isEmpty {
                return
            }
            let resolvedCity = mapItemCity(first) ?? result.subtitle
            
            let codeFromItems: String = items
                .compactMap { mapItem in
                    return airportCodeCandidate(fromText: [
                        mapItem.name,
                        mapItemAddressString(mapItem),
                        result.title,
                        result.subtitle
                    ]
                    .compactMap { $0 }
                    .joined(separator: " "))
                }
                .first { !$0.isEmpty } ?? ""
            
            let chosenCode = !initialCode.isEmpty ? initialCode : codeFromItems
            
            DispatchQueue.main.async {
                latitude = coordinate.latitude
                longitude = coordinate.longitude
                city = resolvedCity.isEmpty ? bestAirportSubtitle(for: first) : resolvedCity
                
                if !chosenCode.isEmpty {
                    code = chosenCode
                }
            }
        }
    }
    
    private func selectAirportMapItem(_ item: MKMapItem) {
        let airportName = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? name
        let addr = mapItemAddressString(item) ?? ""
        let combined = [airportName, addr].joined(separator: " ")
        let detectedCode = airportCodeCandidate(fromText: combined)
        let detectedCity = bestAirportSubtitle(for: item)
        
        DispatchQueue.main.async {
            name = stripLeadingCode(from: airportName)
            if !detectedCode.isEmpty { code = detectedCode }
            if !detectedCity.isEmpty { city = detectedCity }
            latitude = item.placemark.coordinate.latitude
            longitude = item.placemark.coordinate.longitude
            showingResults = false
            fallbackItems = []
        }
    }
    
    private func isAirportCompletion(_ result: MKLocalSearchCompletion) -> Bool {
        let combined = "\(result.title) \(result.subtitle)".uppercased()
        if !airportCodeCandidate(for: result).isEmpty { return true }
        return combined.contains("AIRPORT") || combined.contains("AEROPORT") || combined.contains("AEROPUERTO") || combined.contains("INTL")
    }
    
    private func airportCodeCandidate(for result: MKLocalSearchCompletion) -> String {
        airportCodeCandidate(fromText: "\(result.title) \(result.subtitle)")
    }
    
    private func airportCodeCandidate(fromText text: String) -> String {
        let combined = text.uppercased()
        
        if let range = combined.range(of: #"\(([A-Z]{3})\)"#, options: .regularExpression) {
            let match = String(combined[range])
            return match.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
        }
        
        if let range = combined.range(of: #"^([A-Z]{3})\s*[-–]\s*"#, options: .regularExpression) {
            let prefix = String(combined[range])
            let letters = prefix.filter { $0.isLetter }
            if letters.count == 3 { return letters }
        }
        
        if let range = combined.range(of: #"\bIATA[:\s]+([A-Z]{3})\b"#, options: .regularExpression) {
            let match = String(combined[range])
            let letters = match.filter { $0.isLetter }
            if letters.count >= 3 { return String(letters.suffix(3)) }
        }
        
        if (combined.contains("AIRPORT") || combined.contains("INTL")) {
            let tokens = combined
                .replacingOccurrences(of: "(", with: " ")
                .replacingOccurrences(of: ")", with: " ")
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count == 3 && $0.allSatisfy { $0.isLetter } }
            let forbidden: Set<String> = ["USA", "THE"]
            if let first = tokens.first(where: { !forbidden.contains($0) }) {
                return first
            }
        }
        
        return ""
    }
    
    private func stripLeadingCode(from title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: #"^[A-Z]{3}\s*[-–]\s*"#, options: .regularExpression) {
            return String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }
    
    private func resolveCodeForResult(_ result: MKLocalSearchCompletion) {
        inFlightCodeResolutions.insert(result)
        let request = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            let items = response?.mapItems ?? []
            let found: String = items
                .compactMap { item in
                    airportCodeCandidate(fromText: [item.name, mapItemAddressString(item)].compactMap { $0 }.joined(separator: " "))
                }
                .first(where: { !$0.isEmpty }) ?? ""
            DispatchQueue.main.async {
                inFlightCodeResolutions.remove(result)
                if !found.isEmpty {
                    resolvedCodes[result] = found
                } else {
                    failedCodeResolutions.insert(result)
                    if let error {
                        print("Airport code resolve error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func scheduleFallbackSearch(for raw: String) {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        fallbackTask?.cancel()
        fallbackItems = []
        isFallbackSearching = false
        guard q.count >= 2 else { return }
        
        fallbackTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }
            await MainActor.run { isFallbackSearching = true }
            runFallbackAirportSearch(query: q)
        }
    }
    
    private func runFallbackAirportSearch(query: String) {
        var q = query
        let upper = q.uppercased()
        let looksLikeCode = upper.count == 3 && upper.allSatisfy { $0.isLetter }
        if !looksLikeCode && !upper.contains("AIRPORT") {
            q += " airport"
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = q
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.airport])
        if let region = searchRegion {
            request.region = region
        }
        
        MKLocalSearch(request: request).start { response, _ in
            let items = (response?.mapItems ?? [])
                .filter { item in
                    if item.pointOfInterestCategory == .airport { return true }
                    let combined = ([item.name, mapItemAddressString(item)].compactMap { $0 }.joined(separator: " ")).uppercased()
                    return combined.contains("AIRPORT") || !airportCodeCandidate(fromText: combined).isEmpty
                }
            
            DispatchQueue.main.async {
                if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.fallbackItems = []
                    self.isFallbackSearching = false
                    return
                }
                self.fallbackItems = Array(items.prefix(10))
                self.isFallbackSearching = false
            }
        }
    }
    
    private func bestAirportSubtitle(for item: MKMapItem) -> String {
        if let city = mapItemCity(item), !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return city
        }
        let addr = mapItemAddressString(item)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if addr.isEmpty { return "" }
        let parts = addr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if parts.count >= 2 {
            return parts[1]
        }
        return addr
    }
}

