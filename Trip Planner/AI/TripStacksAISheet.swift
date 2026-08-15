import MapKit
import SwiftUI

/// Shared generative AI sheet for plan_day, place_finder, and create_trip.
struct TripStacksAISheet: View {
    let mode: AIMode
    var tripContext: PlanDayTripContext? = nil
    var dayOptions: [DayOption] = []
    var defaultDayID: UUID? = nil
    var scopeHint: String = ""
    var existingItems: [PlanDayItem] = []
    var existingPlaces: [AIPlaceSummary] = []
    var existingTrips: [AITripSummary] = []
    var onCommitPlanItems: (([PlanDayItem]) -> Void)? = nil
    var onCommitPlaces: (([PlanDayItem]) -> Void)? = nil
    var onCommitTrip: ((AITripDraft, [PlanDayItem]) -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("prefFood") private var prefFood: String = ""
    @AppStorage("prefAlcohol") private var prefAlcohol: Bool = false
    @AppStorage("prefInterests") private var prefInterests: String = ""
    
    @State private var promptText: String = ""
    @State private var isProcessing: Bool = false
    @State private var errorText: String?
    @State private var loaderStep: Int = 0
    @State private var clarificationPrompt: String?
    @State private var responseIntent: String = ""
    
    @State private var planDraft: PlanDayDraft?
    @State private var showPlanPreview: Bool = false
    @State private var placeItems: [PlanDayItem] = []
    @State private var showPlacesPreview: Bool = false
    @State private var tripDraft: AITripDraft?
    @State private var tripAlternatives: [AITripDraft] = []
    @State private var tripSeedItems: [PlanDayItem] = []
    @State private var showTripPreview: Bool = false
    
    @State private var aiGlowActive = false
    @State private var aiGlowRotation: Double = 0
    @State private var aiGlowPulse = false
    
    private let client = TripStacksAIClient()
    
    private var chipForeground: Color {
        colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717)
    }
    
    private var chipFallback: Color {
        colorScheme == .dark ? Color(hex: 0x171717) : Color(hex: 0xF0F0F0)
    }
    
    private var promptFieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
    }
    
    private var navigationTitleText: String {
        switch mode {
        case .planDay: return "Plan Day"
        case .placeFinder: return "Find Places"
        case .createTrip: return "Plan a Trip"
        }
    }
    
    private var placeholderText: String {
        switch mode {
        case .planDay: return "What do you have in mind?"
        case .placeFinder: return "What kind of places are you looking for?"
        case .createTrip: return "Where do you want to go?"
        }
    }
    
    private var loaderLabels: [String] {
        switch mode {
        case .planDay:
            return ["Thinking", "Applying preferences", "Researching spots", "Organizing day"]
        case .placeFinder:
            return ["Thinking", "Matching your taste", "Finding places", "Checking locations"]
        case .createTrip:
            return ["Thinking", "Shaping the trip", "Picking highlights", "Almost ready"]
        }
    }
    
    private var quickChips: [(String, String)] {
        switch mode {
        case .planDay:
            return [
                ("A day of sightseeing", "binoculars.fill"),
                ("A food and drink focused day", "fork.knife"),
                ("Fun with kids", "figure.and.child.holdinghands"),
                ("An adventurous day", "mountain.2.fill"),
                ("Photography day", "camera.fill"),
            ]
        case .placeFinder:
            return [
                ("Great restaurants", "fork.knife"),
                ("Coffee shops", "cup.and.saucer.fill"),
                ("Hotels worth booking", "bed.double.fill"),
                ("Museums and culture", "building.columns.fill"),
                ("Scenic viewpoints", "camera.viewfinder"),
            ]
        case .createTrip:
            return [
                ("Long weekend getaway", "suitcase.fill"),
                ("Food-focused city trip", "fork.knife"),
                ("Nature and hiking", "figure.hiking"),
                ("Family-friendly trip", "figure.and.child.holdinghands"),
                ("5-day adventure", "map.fill"),
            ]
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if let clarificationPrompt, !clarificationPrompt.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundStyle(.secondary)
                        Text(clarificationPrompt)
                            .font(.app(14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $promptText)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground), in: promptFieldShape)
                        .overlay {
                            promptFieldShape
                                .strokeBorder(Color(.separator).opacity(aiGlowActive ? 0 : 0.35), lineWidth: 1)
                        }
                        .overlay {
                            promptFieldShape
                                .strokeBorder(
                                    AngularGradient(
                                        colors: [
                                            Color(hex: 0x5AC8FA),
                                            Color(hex: 0x7B61FF),
                                            Color(hex: 0xFF6BCB),
                                            Color(hex: 0x5AC8FA),
                                        ],
                                        center: .center,
                                        angle: .degrees(aiGlowRotation)
                                    ),
                                    lineWidth: aiGlowActive ? 2.5 : 0
                                )
                                .opacity(aiGlowActive ? (aiGlowPulse ? 1 : 0.55) : 0)
                        }
                        .shadow(
                            color: Color(hex: 0x7B61FF).opacity(aiGlowActive ? (aiGlowPulse ? 0.45 : 0.22) : 0),
                            radius: aiGlowActive ? (aiGlowPulse ? 18 : 10) : 0
                        )
                    
                    if promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(placeholderText)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 200)
                .onAppear { playAIGlowIntro() }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quickChips, id: \.0) { chip in
                            quickPromptChip(chip.0, systemImage: chip.1)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollClipDisabled()
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    LiquidGlassIconButton(systemName: "arrow.right") {
                        Task { await run(prompt: promptText) }
                    }
                    .disabled(isProcessing || promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .overlay { processingOverlay }
            .navigationDestination(isPresented: $showPlanPreview) {
                if let planDraft {
                    PlanDayPreviewView(
                        draft: planDraft,
                        dayOptions: dayOptions,
                        intent: responseIntent,
                        onCancel: { dismiss() },
                        onConfirm: { items in
                            onCommitPlanItems?(items)
                            dismiss()
                        }
                    )
                }
            }
            .navigationDestination(isPresented: $showPlacesPreview) {
                AIPlacesReviewView(items: $placeItems) { selected in
                    onCommitPlaces?(selected)
                    dismiss()
                }
            }
            .navigationDestination(isPresented: $showTripPreview) {
                if let tripDraft {
                    AICreateTripReviewView(
                        trip: tripDraft,
                        alternatives: tripAlternatives,
                        seedItems: tripSeedItems
                    ) { chosen, seeds in
                        onCommitTrip?(chosen, seeds)
                        dismiss()
                    }
                }
            }
            .alert("Something went wrong", isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )) {
                Button("OK", role: .cancel) { errorText = nil }
            } message: {
                Text(errorText ?? "")
            }
        }
    }
    
    @ViewBuilder
    private var processingOverlay: some View {
        if isProcessing {
            ZStack {
                Color.black.opacity(0.12).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text(loaderLabels[min(loaderStep, loaderLabels.count - 1)])
                        .font(.app(15, weight: .semibold))
                        .id(loaderStep)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
                .frame(minWidth: 260, minHeight: 120)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .task(id: isProcessing) {
                guard isProcessing else { return }
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.25)) { loaderStep = 0 }
                }
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_900_000_000)
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            loaderStep = (loaderStep + 1) % loaderLabels.count
                        }
                    }
                }
            }
        }
    }
    
    private func quickPromptChip(_ text: String, systemImage: String) -> some View {
        Button {
            Task { await run(prompt: text) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(text)
                    .font(.app(13, weight: .semibold))
            }
            .foregroundStyle(chipForeground.opacity(0.78))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .modifier(AIChipGlassBackground(fallback: chipFallback))
        }
        .buttonStyle(.plain)
    }
    
    private func playAIGlowIntro() {
        aiGlowActive = true
        aiGlowPulse = false
        aiGlowRotation = 0
        withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
            aiGlowRotation = 360
        }
        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
            aiGlowPulse = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            withAnimation(.easeOut(duration: 0.7)) {
                aiGlowActive = false
                aiGlowPulse = false
            }
        }
    }
    
    private func run(prompt: String) async {
        let raw = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        
        let shouldRun: Bool = await MainActor.run {
            if isProcessing { return false }
            isProcessing = true
            errorText = nil
            clarificationPrompt = nil
            promptText = raw
            return true
        }
        guard shouldRun else { return }
        
        let prefs = PlanDayUserPreferences(
            favoriteFoodCSV: prefFood,
            drinksAlcohol: prefAlcohol,
            interestsCSV: prefInterests
        )
        
        var text = raw
        if mode == .planDay, !scopeHint.isEmpty {
            text = "For \(scopeHint): \(raw)"
        }
        
        let request = AIRequest(
            mode: mode,
            text: text,
            scopeHint: scopeHint,
            tripContext: tripContext,
            preferences: prefs.isEmpty ? nil : prefs,
            existingItems: mode == .planDay ? existingItems : [],
            existingPlaces: mode == .placeFinder ? existingPlaces : [],
            existingTrips: mode == .createTrip ? existingTrips : []
        )
        
        do {
            let response = try await client.generate(request)
            if response.clarificationNeeded {
                await MainActor.run {
                    clarificationPrompt = response.clarificationPrompt.isEmpty
                        ? "Can you add a bit more detail?"
                        : response.clarificationPrompt
                    isProcessing = false
                }
                return
            }
            
            switch mode {
            case .planDay:
                let sanitized = sanitizePlanItems(response.items)
                guard !sanitized.isEmpty else {
                    await MainActor.run {
                        errorText = "No usable suggestions came back. Try a more specific prompt."
                        isProcessing = false
                    }
                    return
                }
                var mapped = AIDayMapping.assignDayIDs(
                    to: sanitized,
                    dayOptions: dayOptions,
                    defaultDayID: defaultDayID
                )
                let destination = tripContext?.destination ?? ""
                let refined = await PlanDayLocationResolver.refineLocations(
                    in: PlanDayDraft(items: mapped, extractedText: raw, extractedFacts: PlanDayFacts()),
                    destination: destination,
                    biasRegion: searchBiasRegion()
                )
                await MainActor.run {
                    responseIntent = response.intent
                    planDraft = refined
                    showPlanPreview = true
                    isProcessing = false
                }
                
            case .placeFinder:
                let places = response.items.filter { $0.kind == .place || !$0.category.isEmpty }
                let normalized: [PlanDayItem] = places.map { item in
                    var copy = item
                    copy.kind = .place
                    if copy.category.isEmpty { copy.category = "other" }
                    return copy
                }
                guard !normalized.isEmpty else {
                    await MainActor.run {
                        errorText = "No places came back. Try naming a city or category."
                        isProcessing = false
                    }
                    return
                }
                let refined = await refinePlaceLocations(normalized)
                await MainActor.run {
                    placeItems = refined
                    showPlacesPreview = true
                    isProcessing = false
                }
                
            case .createTrip:
                guard let trip = response.trip, !trip.destination.isEmpty || !trip.name.isEmpty else {
                    await MainActor.run {
                        errorText = "Couldn't draft a trip. Try adding a destination."
                        isProcessing = false
                    }
                    return
                }
                await MainActor.run {
                    tripDraft = trip
                    tripAlternatives = response.alternatives
                    tripSeedItems = sanitizePlanItems(response.items)
                    showTripPreview = true
                    isProcessing = false
                }
            }
        } catch {
            await MainActor.run {
                errorText = userFriendlyError(error)
                isProcessing = false
            }
        }
    }
    
    private func sanitizePlanItems(_ items: [PlanDayItem]) -> [PlanDayItem] {
        items
            .map { item in
                var item = item
                item.include = true
                if item.sourceSnippet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    item.sourceSnippet = item.title
                }
                return item
            }
            .filter { item in
                let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                switch item.kind {
                case .activity, .reminder, .place:
                    return !title.isEmpty
                case .checklist:
                    return !title.isEmpty && !item.checklistItemsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                case .flight:
                    return !item.flightNumber.isEmpty
                        || !item.flightFromCode.isEmpty
                        || !item.flightToCode.isEmpty
                        || !title.isEmpty
                }
            }
            .filter { $0.kind != .place }
    }
    
    private func refinePlaceLocations(_ items: [PlanDayItem]) async -> [PlanDayItem] {
        var updated = items
        let destination = tripContext?.destination ?? ""
        for idx in updated.indices {
            if Task.isCancelled { break }
            let item = updated[idx]
            let query = [item.title, item.location, destination]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
            guard !query.isEmpty else { continue }
            
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.resultTypes = [.pointOfInterest, .address]
            if let region = searchBiasRegion() {
                request.region = region
            }
            do {
                let response = try await MKLocalSearch(request: request).start()
                if let mapItem = response.mapItems.first {
                    let name = mapItem.name ?? item.title
                    let locality = [
                        mapItem.placemark.locality,
                        mapItem.placemark.administrativeArea,
                        mapItem.placemark.country,
                    ]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                    if !locality.isEmpty {
                        updated[idx].location = "\(name), \(locality)"
                    } else if updated[idx].location.isEmpty {
                        updated[idx].location = name
                    }
                    updated[idx].title = item.title.isEmpty ? name : item.title
                }
            } catch {
                continue
            }
            try? await Task.sleep(nanoseconds: 120_000_000)
        }
        return updated
    }
    
    private func searchBiasRegion() -> MKCoordinateRegion? {
        guard let lat = tripContext?.latitude, let lon = tripContext?.longitude else { return nil }
        let span = max(0.05, min(tripContext?.mapSpan ?? 0.18, 0.6))
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
    }
    
    private func userFriendlyError(_ error: Error) -> String {
        if let e = error as? TripStacksAIError, case let .http(status, body) = e {
            if status == 429 {
                return "Too many requests. Try again in a moment."
            }
            return "AI request failed.\n\n\(e.localizedDescription)"
        }
        return "AI request failed.\n\n\(error.localizedDescription)"
    }
}

private struct AIChipGlassBackground: ViewModifier {
    let fallback: Color
    private let shape = Capsule(style: .continuous)
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
                .clipShape(shape)
        } else {
            content
                .background(fallback, in: shape)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        }
    }
}
