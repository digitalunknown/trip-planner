import MapKit
import SwiftUI
import UIKit

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
    var onCommitTrip: ((AITripDraft, [PlanDayItem], [PlanDayItem]) -> Void)? = nil
    
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
    @State private var tripSeedItems: [PlanDayItem] = []
    @State private var showTripPreview: Bool = false
    
    @State private var aiGlowActive = false
    @State private var aiGlowRotation: Double = 0
    @State private var aiGlowPulse = false
    @State private var glowGeneration = 0
    @State private var loaderTask: Task<Void, Never>?
    @State private var promptEditorHeight: CGFloat = 58
    @State private var promptEditorWidth: CGFloat = 0
    /// Biases MapKit refinement toward the user's current location for "near you" chips.
    @State private var nearYouCoordinate: CLLocationCoordinate2D? = nil
    @FocusState private var isPromptFocused: Bool
    
    private let client = TripStacksAIClient()
    private let composerFooterHeight: CGFloat = 56
    /// Matches UITextView defaults used by TextEditor.
    private let promptTextContainerInset = EdgeInsets(top: 8, leading: 5, bottom: 8, trailing: 5)
    private let promptEditorMinHeight: CGFloat = 58
    private let promptEditorMaxHeight: CGFloat = 132
    
    private var chipForeground: Color {
        colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717)
    }
    
    private var chipFallback: Color {
        colorScheme == .dark ? Color(hex: 0x171717) : Color(hex: 0xF0F0F0)
    }
    
    private var promptFieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
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
        case .planDay:
            return "Describe the day you want"
        case .placeFinder:
            return "Tell me what to find and where"
        case .createTrip:
            return "Describe the trip — destination, dates, and vibe"
        }
    }
    
    private var loaderLabels: [String] {
        [
            "Searching the Earth",
            "Applying preferences",
            "Finding the best stuff",
            "Refining recommendations",
        ]
    }
    
    private var quickChips: [AIQuickChip] {
        switch mode {
        case .planDay:
            return [
                AIQuickChip(title: "A day of sightseeing", systemImage: "binoculars.fill"),
                AIQuickChip(title: "A food and drink focused day", systemImage: "fork.knife"),
                AIQuickChip(title: "Fun with kids", systemImage: "figure.and.child.holdinghands"),
                AIQuickChip(title: "An adventurous day", systemImage: "mountain.2.fill"),
                AIQuickChip(title: "Photography day", systemImage: "camera.fill"),
            ]
        case .placeFinder:
            return [
                AIQuickChip(title: "Activities near you", systemImage: "figure.hiking", usesCurrentLocation: true),
                AIQuickChip(title: "Great stays near you", systemImage: "bed.double.fill", usesCurrentLocation: true),
                AIQuickChip(title: "Restaurants near you", systemImage: "fork.knife", usesCurrentLocation: true),
                AIQuickChip(title: "Best of Paris", systemImage: "star.fill"),
                AIQuickChip(title: "Best of Tokyo", systemImage: "star.fill"),
                AIQuickChip(title: "Best of New York", systemImage: "star.fill"),
                AIQuickChip(title: "Best of Los Angeles", systemImage: "star.fill"),
                AIQuickChip(title: "Best of London", systemImage: "star.fill"),
            ]
        case .createTrip:
            return [
                AIQuickChip(title: "Plan a weekend near you", systemImage: "location.fill", usesCurrentLocation: true),
                AIQuickChip(title: "Plan a trip to New York", systemImage: "building.2.fill"),
                AIQuickChip(title: "Plan a trip to Los Angeles", systemImage: "sun.max.fill"),
                AIQuickChip(title: "Plan a trip to Miami", systemImage: "beach.umbrella.fill"),
                AIQuickChip(title: "Plan a trip to Tokyo", systemImage: "building.fill"),
                AIQuickChip(title: "Plan a trip to Copenhagen", systemImage: "leaf.fill"),
                AIQuickChip(title: "Plan a trip to London", systemImage: "building.columns.fill"),
            ]
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                
                Spacer(minLength: 0)
                
                SearchGlobeIllustration()
                
                Spacer(minLength: 0)
                
                VStack(spacing: 12) {
                    if promptText.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(quickChips) { chip in
                                    quickPromptChip(chip)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                        .scrollClipDisabled()
                        .opacity(isProcessing ? 0.45 : 1)
                        .allowsHitTesting(!isProcessing)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    
                    promptComposer
                }
                .animation(.easeInOut(duration: 0.22), value: promptText.isEmpty)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
            }
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
                        seedItems: tripSeedItems
                    ) { chosen, tripSeeds, placeSeeds in
                        onCommitTrip?(chosen, tripSeeds, placeSeeds)
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
            .onChange(of: isProcessing) { _, processing in
                if processing {
                    startAIGlow(autoStopAfter: nil)
                    beginLoaderRotation()
                } else {
                    loaderTask?.cancel()
                    loaderTask = nil
                    stopAIGlow()
                }
            }
            .task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                isPromptFocused = true
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
    
    private var canSend: Bool {
        !isProcessing && !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var promptComposer: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $promptText)
                    .font(.appBody)
                    .scrollContentBackground(.hidden)
                    .focused($isPromptFocused)
                    .disabled(isProcessing)
                    .opacity(isProcessing ? 0.72 : 1)
                    .scrollDisabled(promptEditorHeight < promptEditorMaxHeight)
                
                if promptText.isEmpty && !isProcessing {
                    Text(placeholderText)
                        .font(.appBody)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .padding(promptTextContainerInset)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: promptEditorHeight, alignment: .topLeading)
            .clipped()
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { promptEditorWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, width in
                            promptEditorWidth = width
                            updatePromptEditorHeight()
                        }
                }
            )
            .onChange(of: promptText) { _, _ in
                updatePromptEditorHeight()
            }
            .onAppear {
                updatePromptEditorHeight()
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            
            HStack(alignment: .center, spacing: 12) {
                Group {
                    if isProcessing {
                        Text(loaderLabels[min(loaderStep, loaderLabels.count - 1)])
                            .font(.app(14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .contentTransition(.opacity)
                            .id(loaderStep)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        Color.clear.frame(height: 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Button {
                    Task { await run(prompt: promptText) }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(canSend ? Color(.systemBackground) : Color.secondary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(canSend ? Color.primary : Color(.tertiarySystemFill))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
            .frame(height: composerFooterHeight)
            .padding(.leading, 20)
            .padding(.trailing, 14)
            .animation(.easeInOut(duration: 0.25), value: isProcessing)
            .animation(.easeInOut(duration: 0.25), value: loaderStep)
        }
        .background(Color(.secondarySystemGroupedBackground), in: promptFieldShape)
        .clipShape(promptFieldShape)
        .overlay {
            promptFieldShape
                .strokeBorder(promptBorderStyle, lineWidth: promptBorderWidth)
                .animation(.easeInOut(duration: 0.2), value: isPromptFocused)
                .animation(.easeInOut(duration: 0.2), value: aiGlowActive)
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
                .allowsHitTesting(false)
        }
        .shadow(
            color: promptFocusShadowColor,
            radius: aiGlowActive ? (aiGlowPulse ? 18 : 10) : 0
        )
        .animation(.easeInOut(duration: 0.2), value: isPromptFocused)
        .onAppear {
            startAIGlow(autoStopAfter: 2.6)
        }
    }
    
    private func updatePromptEditorHeight() {
        let width = promptEditorWidth
        guard width > 0 else { return }
        
        let inset = promptTextContainerInset
        let textWidth = max(width - inset.leading - inset.trailing, 1)
        let font = UIFont(descriptor: UIFontDescriptor(fontAttributes: [
            .name: "Inter",
            .size: 17,
            kCTFontVariationAttribute as UIFontDescriptor.AttributeName: [2003265652: 400]
        ]), size: 17)
        
        let measureText = promptText.isEmpty ? " " : promptText
        let bounding = (measureText as NSString).boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        
        let next = min(
            max(ceil(bounding.height) + inset.top + inset.bottom, promptEditorMinHeight),
            promptEditorMaxHeight
        )
        if abs(next - promptEditorHeight) > 0.5 {
            promptEditorHeight = next
        }
    }
    
    private var promptBorderWidth: CGFloat {
        if aiGlowActive { return 0 }
        return 1
    }
    
    private var promptBorderStyle: some ShapeStyle {
        if isPromptFocused && !aiGlowActive {
            return AnyShapeStyle(Color.primary.opacity(0.55))
        }
        return AnyShapeStyle(Color(.separator).opacity(0.35))
    }
    
    private var promptFocusShadowColor: Color {
        if aiGlowActive {
            return Color(hex: 0x7B61FF).opacity(aiGlowPulse ? 0.45 : 0.22)
        }
        return .clear
    }
    
    private func quickPromptChip(_ chip: AIQuickChip) -> some View {
        Button {
            Task { await runChip(chip) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: chip.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(chip.title)
                    .font(.app(13, weight: .semibold))
            }
            .foregroundStyle(chipForeground.opacity(0.78))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .modifier(AIChipGlassBackground(fallback: chipFallback))
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
    }
    
    private func runChip(_ chip: AIQuickChip) async {
        if chip.usesCurrentLocation {
            guard let place = await AICurrentLocation.resolve() else {
                await MainActor.run {
                    errorText = "Location access is needed for Near You suggestions. Enable Location in Settings and try again."
                }
                return
            }
            await MainActor.run {
                nearYouCoordinate = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
            }
            await run(
                prompt: nearYouPrompt(for: chip.title, place: place),
                displayText: chip.title,
                ignoreTripContext: true
            )
            return
        }
        await MainActor.run { nearYouCoordinate = nil }
        if mode == .placeFinder {
            await run(
                prompt: placeFinderListPrompt(chip.title),
                displayText: chip.title
            )
        } else {
            await run(prompt: chip.title, displayText: chip.title)
        }
    }
    
    /// Ensures list-style place prompts ask for 10 venues (chips + short typed asks).
    private func placeFinderListPrompt(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.range(of: #"\b([1-9]|1[0-2])\b"#, options: .regularExpression) != nil {
            return trimmed
        }
        if trimmed.lowercased().hasPrefix("best of ") {
            let city = String(trimmed.dropFirst("Best of ".count))
            return "Suggest 10 of the best places to save in \(city) — mix restaurants, attractions, and stays. Each must be a specific named venue with a maps-searchable location."
        }
        return "\(trimmed)\n\nReturn exactly 10 specific named places (not one summary recommendation)."
    }
    
    private func nearYouPrompt(for chipTitle: String, place: AICurrentLocation.Place) -> String {
        let coords = String(format: "%.4f, %.4f", place.latitude, place.longitude)
        let whereLocal = "\(place.label) (current location approx \(coords))"
        
        switch mode {
        case .placeFinder:
            let lower = chipTitle.lowercased()
            if lower.contains("restaurant") {
                return "Suggest 10 excellent, real restaurants near \(whereLocal). Mix neighborhoods and cuisines within roughly 20 km. Each item must be a specific venue with a maps-searchable location (venue + city). No generic suggestions."
            }
            if lower.contains("stay") || lower.contains("hotel") {
                return "Suggest 10 great hotels / stays near \(whereLocal). Mix boutique and well-known options within roughly 20 km. Each item must be a specific property with a maps-searchable location. No generic suggestions."
            }
            if lower.contains("activit") {
                return "Suggest 10 worthwhile activities and attractions near \(whereLocal) — museums, parks, viewpoints, experiences. Mix types within roughly 25 km. Each item must be a specific place with a maps-searchable location."
            }
            return "Suggest 10 great places near \(whereLocal). Each must be a specific named venue with a maps-searchable location."
            
        case .createTrip:
            return "Plan a weekend trip near \(whereLocal). Use \(place.label) (or a nearby weekend-worthy town within a few hours) as the destination. Return a concrete trip draft plus a rich starter itinerary: 1 hotel, several restaurants, several activities, a packing checklist, and a couple reminders. Prefer real venues."
            
        case .planDay:
            return chipTitle.replacingOccurrences(
                of: "near you",
                with: "near \(whereLocal)",
                options: [.caseInsensitive]
            )
        }
    }
    
    private func startAIGlow(autoStopAfter seconds: Double?) {
        glowGeneration += 1
        let generation = glowGeneration
        aiGlowActive = true
        aiGlowPulse = false
        aiGlowRotation = 0
        withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
            aiGlowRotation = 360
        }
        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
            aiGlowPulse = true
        }
        guard let seconds else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard generation == glowGeneration, !isProcessing else { return }
            withAnimation(.easeOut(duration: 0.7)) {
                aiGlowActive = false
                aiGlowPulse = false
            }
        }
    }
    
    private func stopAIGlow() {
        glowGeneration += 1
        withAnimation(.easeOut(duration: 0.55)) {
            aiGlowActive = false
            aiGlowPulse = false
        }
    }
    
    private func beginLoaderRotation() {
        loaderTask?.cancel()
        loaderStep = 0
        loaderTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_900_000_000)
                guard !Task.isCancelled, isProcessing else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    loaderStep = (loaderStep + 1) % loaderLabels.count
                }
            }
        }
    }
    
    private func run(prompt: String, displayText: String? = nil, ignoreTripContext: Bool = false) async {
        let raw = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        let visible = (displayText ?? prompt).trimmingCharacters(in: .whitespacesAndNewlines)
        
        let shouldRun: Bool = await MainActor.run {
            if isProcessing { return false }
            isProcessing = true
            errorText = nil
            clarificationPrompt = nil
            promptText = visible.isEmpty ? raw : visible
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
        if mode == .placeFinder {
            text = placeFinderListPrompt(raw)
        }
        
        let request = AIRequest(
            mode: mode,
            text: text,
            scopeHint: scopeHint,
            tripContext: ignoreTripContext ? nil : tripContext,
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
                    copy.include = false
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
                let seeds = sanitizePlanItems(response.items)
                let destination = trip.destination.trimmingCharacters(in: .whitespacesAndNewlines)
                let refinedSeeds = await PlanDayLocationResolver.refineLocations(
                    in: PlanDayDraft(items: seeds, extractedText: raw, extractedFacts: PlanDayFacts()),
                    destination: destination.isEmpty ? trip.name : destination,
                    biasRegion: searchBiasRegion()
                )
                await MainActor.run {
                    tripDraft = trip
                    tripSeedItems = refinedSeeds.items
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
                    if let coordinate = mapItemCoordinate(mapItem) {
                        updated[idx].latitude = coordinate.latitude
                        updated[idx].longitude = coordinate.longitude
                    }
                    let locality = [
                        mapItem.placemark.locality,
                        mapItem.placemark.administrativeArea,
                        mapItem.placemark.country,
                    ]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                    if let address = mapItemAddressString(mapItem)?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !address.isEmpty {
                        if !name.isEmpty, !address.localizedCaseInsensitiveContains(name) {
                            updated[idx].location = "\(name), \(address)"
                        } else {
                            updated[idx].location = address
                        }
                    } else if !locality.isEmpty {
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
        if let nearYouCoordinate {
            return MKCoordinateRegion(
                center: nearYouCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
            )
        }
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

private struct AIQuickChip: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let usesCurrentLocation: Bool
    
    init(title: String, systemImage: String, usesCurrentLocation: Bool = false) {
        self.id = title
        self.title = title
        self.systemImage = systemImage
        self.usesCurrentLocation = usesCurrentLocation
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
