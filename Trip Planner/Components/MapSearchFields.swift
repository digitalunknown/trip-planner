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
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
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
                    .font(.caption)
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
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 0)
                                
                                if isResolvingCode {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.secondary)
                                } else {
                                    Text(code.isEmpty ? "—" : code)
                                        .font(.caption.weight(.semibold))
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
                city = resolvedCity
                
                if !chosenCode.isEmpty {
                    code = chosenCode
                }
            }
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
}

