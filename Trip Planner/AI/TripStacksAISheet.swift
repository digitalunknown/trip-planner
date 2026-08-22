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
    /// Opens the manual new-trip flow (create_trip mode only).
    var onCreateManually: (() -> Void)? = nil
    
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
    @State private var aiReplyText: String = ""
    
    @State private var planDraft: PlanDayDraft?
    @State private var showPlanPreview: Bool = false
    @State private var placeItems: [PlanDayItem] = []
    @State private var showPlacesPreview: Bool = false
    @State private var tripDraft: AITripDraft?
    @State private var tripSeedItems: [PlanDayItem] = []
    @State private var showTripPreview: Bool = false
    
    @State private var loaderTask: Task<Void, Never>?
    @State private var runTask: Task<Void, Never>?
    @State private var runGeneration = 0
    @State private var promptEditorHeight: CGFloat = 58
    @State private var promptEditorWidth: CGFloat = 0
    /// Biases MapKit refinement toward the user's current location for "near you" chips.
    @State private var nearYouCoordinate: CLLocationCoordinate2D? = nil
    @State private var nearYouLabel: String? = nil
    /// Find Places: city/region resolved from the prompt (overrides conflicting tripContext).
    @State private var placeFinderBiasRegion: MKCoordinateRegion? = nil
    @State private var placeFinderAnchorLabel: String? = nil
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
        // Must contrast with systemGroupedBackground in both schemes.
        colorScheme == .dark ? Color.white.opacity(0.12) : Color(hex: 0xE5E5EA)
    }
    
    private var promptFieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }
    
    private var pageTitleText: String {
        switch mode {
        case .planDay: return "Plan Day"
        case .placeFinder: return "Find Places"
        case .createTrip: return "Plan Trip"
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
    
    private var loaderSteps: [(state: OrbState, label: String)] {
        [
            (.searching, "Searching the Earth"),
            (.solving, "Applying preferences"),
            (.searching, "Finding the best stuff"),
            (.solving, "Refining recommendations"),
        ]
    }
    
    private var loaderOrbState: OrbState {
        loaderSteps[loaderStep % loaderSteps.count].state
    }
    
    private var loaderLabel: String {
        loaderSteps[loaderStep % loaderSteps.count].label
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
            return placeFinderQuickChips
        case .createTrip:
            return [
                AIQuickChip(title: "Create a trip manually", systemImage: "plus", opensManualCreate: true),
                AIQuickChip(title: "Plan a weekend near you", systemImage: "location.fill", usesCurrentLocation: true),
                AIQuickChip(title: "Plan a 3 day trip to New York", systemImage: "building.2.fill"),
                AIQuickChip(title: "Plan a 3 day trip to Los Angeles", systemImage: "sun.max.fill"),
                AIQuickChip(title: "Plan a 3 day trip to Miami", systemImage: "beach.umbrella.fill"),
                AIQuickChip(title: "Plan a 3 day trip to Toronto", systemImage: "building.fill"),
                AIQuickChip(title: "Plan a 5 day trip to Rome", systemImage: "building.columns.fill"),
                AIQuickChip(title: "Plan a 3 day adventure to Yellowstone", systemImage: "leaf.fill"),
                AIQuickChip(title: "Plan a 5 day trip to Paris", systemImage: "building.columns.fill"),
                AIQuickChip(title: "Plan a 5 day trip to Tokyo", systemImage: "building.fill"),
            ]
        }
    }
    
    private var placeFinderQuickChips: [AIQuickChip] {
        var chips: [AIQuickChip] = [
            AIQuickChip(title: "Activities near you", systemImage: "figure.hiking", usesCurrentLocation: true),
            AIQuickChip(title: "Great stays near you", systemImage: "bed.double.fill", usesCurrentLocation: true),
            AIQuickChip(title: "Restaurants near you", systemImage: "fork.knife", usesCurrentLocation: true),
        ]
        
        var usedDestinations = Set<String>()
        
        if let upcoming = bestOfDestination(from: .upcoming) {
            chips.append(AIQuickChip(title: "Best of \(upcoming)", systemImage: "star.fill"))
            usedDestinations.insert(Self.normalizedDestinationKey(upcoming))
        }
        if let unscheduled = bestOfDestination(from: .unscheduled) {
            let key = Self.normalizedDestinationKey(unscheduled)
            if !usedDestinations.contains(key) {
                chips.append(AIQuickChip(title: "Best of \(unscheduled)", systemImage: "star.fill"))
                usedDestinations.insert(key)
            }
        }
        
        let curated = ["New York", "Toronto", "Rome", "Paris", "Tokyo"]
        for destination in curated {
            let key = Self.normalizedDestinationKey(destination)
            guard !usedDestinations.contains(key) else { continue }
            chips.append(AIQuickChip(title: "Best of \(destination)", systemImage: "star.fill"))
            usedDestinations.insert(key)
        }
        
        return chips
    }
    
    private enum BestOfTripBucket {
        case upcoming
        case unscheduled
    }
    
    private func bestOfDestination(from bucket: BestOfTripBucket) -> String? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let matches: [AITripSummary] = existingTrips.compactMap { trip in
            let label = Self.shortDestinationLabel(for: trip)
            guard !label.isEmpty else { return nil }
            
            switch bucket {
            case .upcoming:
                guard trip.isDatesSet else { return nil }
                guard let end = Self.parseISODate(trip.endDate),
                      calendar.startOfDay(for: end) >= today else { return nil }
                return trip
            case .unscheduled:
                guard !trip.isDatesSet else { return nil }
                return trip
            }
        }
        
        let sorted: [AITripSummary]
        switch bucket {
        case .upcoming:
            sorted = matches.sorted {
                (Self.parseISODate($0.startDate) ?? .distantFuture)
                    < (Self.parseISODate($1.startDate) ?? .distantFuture)
            }
        case .unscheduled:
            sorted = matches.sorted {
                $0.destination.localizedCaseInsensitiveCompare($1.destination) == .orderedAscending
            }
        }
        
        return sorted.first.flatMap { Self.shortDestinationLabel(for: $0) }
    }
    
    private static func shortDestinationLabel(for trip: AITripSummary) -> String {
        let destination = trip.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        if !destination.isEmpty {
            return destination
                .split(separator: ",")
                .first
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                ?? destination
        }
        let name = trip.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name
            .split(separator: ",")
            .first
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            ?? name
    }
    
    private static func normalizedDestinationKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    private static func parseISODate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: raw)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isProcessing {
                    processingContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .animation(.easeInOut(duration: 0.28), value: isProcessing)
                } else {
                    GeometryReader { geo in
                        ScrollView {
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                idleContent
                            }
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: geo.size.height)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                        }
                        .scrollIndicators(.hidden)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(.easeInOut(duration: 0.28), value: isProcessing)
                }
                
                VStack(spacing: 10) {
                    if let clarificationPrompt, !clarificationPrompt.isEmpty, !isProcessing {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundStyle(.secondary)
                            Text(clarificationPrompt)
                                .font(.app(14, weight: .semibold))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(12)
                        .background(
                            Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    }
                    
                    if let errorText {
                        aiErrorBanner(errorText)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    
                    promptComposer
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .padding(.top, 4)
                .animation(.easeInOut(duration: 0.22), value: errorText != nil)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(pageTitleText)
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
                        replyText: aiReplyText,
                        destination: tripContext?.destination ?? "",
                        onCancel: { dismiss() },
                        onConfirm: { items in
                            onCommitPlanItems?(items)
                            dismiss()
                        }
                    )
                }
            }
            .navigationDestination(isPresented: $showPlacesPreview) {
                AIPlacesReviewView(
                    items: $placeItems,
                    replyText: aiReplyText,
                    onSavePlaces: { selected in
                        onCommitPlaces?(selected)
                    },
                    onDone: { dismiss() }
                )
            }
            .navigationDestination(isPresented: $showTripPreview) {
                if let tripDraft {
                    AICreateTripReviewView(
                        trip: tripDraft,
                        seedItems: tripSeedItems,
                        replyText: aiReplyText
                    ) { chosen, tripSeeds, placeSeeds in
                        onCommitTrip?(chosen, tripSeeds, placeSeeds)
                        dismiss()
                    }
                }
            }
            .onChange(of: isProcessing) { _, processing in
                if processing {
                    beginLoaderRotation()
                } else {
                    loaderTask?.cancel()
                    loaderTask = nil
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
    
    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(quickChips) { chip in
                quickPromptRow(chip)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var processingContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            
            VStack(spacing: 14) {
                ThinkingOrb(
                    state: loaderOrbState,
                    size: .px64,
                    theme: .auto,
                    displaySize: 176
                )
                .frame(width: 176, height: 176)
                .accessibilityHidden(true)
                .id(loaderOrbState.rawValue)
                
                ZStack {
                    Text(loaderLabel)
                        .font(.app(15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .id(loaderStep)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            )
                        )
                }
                .frame(maxWidth: 260)
                .frame(height: 22, alignment: .center)
                .clipped()
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.55), value: loaderStep)
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
                        .fixedSize(horizontal: false, vertical: true)
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
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 1)
                
                Button {
                    Haptics.bump()
                    if isProcessing {
                        stopAIRun()
                    } else {
                        runTask = Task { await run(prompt: promptText) }
                    }
                } label: {
                    let isActive = isProcessing || canSend
                    let strongFill = colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717)
                    let strongGlyph = colorScheme == .dark ? Color(hex: 0x171717) : Color.white
                    AppIcon(
                        systemName: isProcessing ? "stop.fill" : "arrow.up",
                        size: isProcessing ? 13 : 18,
                        strokeWidth: 2.25,
                        color: isActive ? strongGlyph : Color.secondary,
                        filled: isProcessing
                    )
                    .frame(width: 36, height: 36)
                    .background {
                        Circle()
                            .fill(isActive ? strongFill : Color(.tertiarySystemFill))
                    }
                }
                .buttonStyle(.plain)
                .disabled(!isProcessing && !canSend)
                .accessibilityLabel(isProcessing ? "Stop" : "Send")
            }
            .frame(height: composerFooterHeight)
            .padding(.leading, 20)
            .padding(.trailing, 14)
            .animation(.easeInOut(duration: 0.25), value: isProcessing)
        }
        .modifier(AIPromptFieldGlassBackground(shape: promptFieldShape))
        .overlay {
            promptFieldShape
                .strokeBorder(promptBorderStyle, lineWidth: 1)
                .animation(.easeInOut(duration: 0.2), value: isPromptFocused)
        }
        .animation(.easeInOut(duration: 0.2), value: isPromptFocused)
    }
    
    private func updatePromptEditorHeight() {
        let width = promptEditorWidth
        guard width > 0 else { return }
        
        let inset = promptTextContainerInset
        let textWidth = max(width - inset.leading - inset.trailing, 1)
        let font = AppFont.uiFont(size: 17, weight: .regular)
        
        let measureText = promptText.isEmpty ? placeholderText : promptText
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
    
    private var promptBorderStyle: some ShapeStyle {
        if isPromptFocused {
            return AnyShapeStyle(Color.primary.opacity(0.55))
        }
        return AnyShapeStyle(Color(.separator).opacity(0.35))
    }
    
    private func quickPromptRow(_ chip: AIQuickChip) -> some View {
        Button {
            Haptics.bump()
            runTask = Task { await runChip(chip) }
        } label: {
            HStack(spacing: 14) {
                AppIcon(
                    systemName: chip.systemImage,
                    size: 18,
                    strokeWidth: 2,
                    color: chipForeground.opacity(0.85)
                )
                .frame(width: 36, height: 36)
                .background(chipFallback, in: Circle())
                
                Text(chip.title)
                    .font(.app(16, weight: .regular))
                    .foregroundStyle(.primary.opacity(0.88))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
    }
    
    private func runChip(_ chip: AIQuickChip) async {
        if chip.opensManualCreate {
            await MainActor.run {
                dismiss()
                onCreateManually?()
            }
            return
        }
        if chip.usesCurrentLocation {
            guard let place = await AICurrentLocation.resolve() else {
                await MainActor.run {
                    errorText = "Location access is needed for Near You suggestions. Enable Location in Settings and try again."
                }
                return
            }
            await MainActor.run {
                nearYouCoordinate = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
                nearYouLabel = place.label
            }
            await run(
                prompt: nearYouPrompt(for: chip.title, place: place),
                displayText: chip.title,
                ignoreTripContext: true
            )
            return
        }
        await MainActor.run {
            nearYouCoordinate = nil
            nearYouLabel = nil
        }
        if mode == .placeFinder {
            await run(
                prompt: placeFinderListPrompt(chip.title),
                displayText: chip.title
            )
        } else if mode == .planDay {
            await run(
                prompt: planDayListPrompt(chip.title),
                displayText: chip.title
            )
        } else {
            await run(prompt: chip.title, displayText: chip.title)
        }
    }
    
    /// Ensures list-style place prompts ask for 10 venues (chips + short typed asks).
    private func placeFinderListPrompt(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if hasExplicitPlaceCount(trimmed) { return trimmed }
        if trimmed.range(of: #"return exactly\s+\d+\s+specific named places"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return trimmed
        }
        if trimmed.lowercased().hasPrefix("best of ") {
            let city = String(trimmed.dropFirst("Best of ".count))
            return "Suggest 10 of the best places to save in \(city) — mix restaurants, attractions, and stays. Each must be a specific named venue with a maps-searchable location."
        }
        return "\(trimmed)\n\nReturn exactly 10 specific named places (not one summary recommendation)."
    }
    
    private func placeFinderFillPrompt(original: String, destination: String, priorCount: Int) -> String {
        let dest = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let whereClause = dest.isEmpty ? "the requested area" : dest
        return """
        \(original)
        
        Previous answer only returned \(priorCount) place(s) — that is invalid.
        Return exactly 10 distinct kind=place venues around \(whereClause).
        Each must be a specific named venue with a maps-searchable location. Notes under 10 words.
        Never return a single recommendation.
        """
    }
    
    /// Ensures day-plan / options prompts ask for multiple itinerary items (not one summary).
    private func planDayListPrompt(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if hasExplicitPlaceCount(trimmed) { return trimmed }
        if trimmed.range(of: #"never a single combined day summary"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return trimmed
        }
        if trimmed.range(of: #"return\s+\d+\s+distinct"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return trimmed
        }
        let lower = trimmed.lowercased()
        let looksSingleKind =
            (lower.contains("checklist") || lower.contains("reminder") || lower.contains("flight"))
            && !(lower.contains("day") || lower.contains("sightseeing") || lower.contains("food")
                 || lower.contains("option") || lower.contains("activit") || lower.contains("itinerary"))
        if looksSingleKind { return trimmed }
        return "\(trimmed)\n\nReturn 6–8 distinct itinerary items. One venue/stop per item with short notes and start/end times (HH:mm) sequenced morning to night — never a single combined day summary."
    }
    
    /// Ensures create-trip prompts ask for a full starter itinerary (not a lone hotel).
    private func createTripListPrompt(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.range(of: #"at least \d+ (seed )?items"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return trimmed
        }
        if trimmed.range(of: #"never return only (a )?hotel"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return trimmed
        }
        let days = AIDayMapping.resolvedDayCount(for: AITripDraft(), promptText: trimmed)
        let minItems = AIDayMapping.completableItemCount(dayCount: days)
        return """
        \(trimmed)
        
        Return a full_itinerary draft with at least \(minItems) items for this \(days)-day trip: 1 hotel, a few real restaurants/cafes, activities spread across dayIndex 0…\(days - 1) (not every meal every day), 1 packing checklist, and 1–2 reminders. Include startTime/endTime (HH:mm) on venue activities. Keep notes under 12 words. Never return only a hotel.
        """
    }
    
    private func createTripNeedsRefill(_ items: [PlanDayItem], dayCount: Int) -> Bool {
        let venues = items.filter {
            $0.kind == .activity &&
            $0.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != "hotel"
        }
        let minItems = AIDayMapping.completableItemCount(dayCount: dayCount)
        return items.count < minItems || venues.count < max(4, min(dayCount, 8))
    }
    
    private func createTripFillPrompt(trip: AITripDraft, dayCount: Int, priorCount: Int, prompt: String) -> String {
        let destination = trip.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let dest = destination.isEmpty ? trip.name : destination
        let days = max(1, min(dayCount, 10))
        let minItems = AIDayMapping.completableItemCount(dayCount: days)
        let namedStay = AIDayMapping.extractNamedStay(from: prompt)
        let hotelSlot = namedStay.map {
            "1. kind=activity category=hotel dayIndex=0 — MUST be exactly \"\($0)\" (user-specified stay; do not invent another hotel)"
        } ?? "1. kind=activity category=hotel dayIndex=0 — real hotel in \(dest)"
        var slots: [String] = [hotelSlot]
        var i = 2
        // One highlight per day — 5 slots/day for a 10-day trip will not fit in one response.
        for d in 0..<days {
            let label = "Day \(d + 1)"
            let kind = ["cafe", "attraction", "restaurant", "hike", "beach"][d % 5]
            slots.append("\(i). \(kind) dayIndex=\(d) (\(label)) one real venue with startTime/endTime"); i += 1
        }
        slots.append("\(i). checklist packing list (6 lines)"); i += 1
        slots.append("\(i). reminder prep task")
        
        return """
        Fill a COMPLETE \(days)-day itinerary for \(dest). Intent=full_itinerary. \
        Trip name "\(trip.name.isEmpty ? dest : trip.name)". unscheduledDaysCount=\(days).
        Previous answer only returned \(priorCount) item(s) — that is invalid (never hotel-only).
        Return at least \(minItems) items covering ALL slots:
        \(slots.joined(separator: "\n"))
        Notes under 8 words. Real venues only. Valid complete JSON.
        """
    }
    
    /// Refill when MapKit could not verify a large share of venues.
    private func createTripLocationRefillPrompt(
        trip: AITripDraft,
        dayCount: Int,
        badVenueNames: [String],
        prompt: String
    ) -> String {
        let destination = trip.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let dest = destination.isEmpty ? trip.name : destination
        let days = max(1, min(dayCount, 10))
        let minItems = AIDayMapping.completableItemCount(dayCount: days)
        let badList = badVenueNames.isEmpty
            ? "several invented venues"
            : badVenueNames.map { "\"\($0)\"" }.joined(separator: ", ")
        let namedStay = AIDayMapping.extractNamedStay(from: prompt)
        let hotelLine = namedStay.map {
            "Keep hotel exactly \"\($0)\". "
        } ?? ""
        let datesLine: String = {
            if trip.isDatesSet, let s = trip.startDate, let e = trip.endDate {
                return "Keep isDatesSet=true startDate=\(s) endDate=\(e). "
            }
            return "Keep unscheduledDaysCount=\(days). "
        }()
        return """
        Rewrite the \(days)-day itinerary for \(dest). Intent=full_itinerary. \
        \(datesLine)\(hotelLine)\
        Apple Maps could not verify these venues (they are likely invented): \(badList). \
        Replace ALL venues with well-known, MapKit-resolvable places in \(dest) only — \
        official names people can search in Apple Maps. Return at least \(minItems) items \
        with dayIndex/dayLabel/startTime/endTime on activities. Notes under 8 words. Valid complete JSON.
        """
    }
    
    /// Matches intentional counts like "top 5" / "3 restaurants" — not coords or street numbers.
    private func hasExplicitPlaceCount(_ text: String) -> Bool {
        let patterns = [
            #"\bexactly\s+([1-9]|1[0-2])\b"#,
            #"\b(?:top|best)\s*([1-9]|1[0-2])\b"#,
            #"\b([1-9]|1[0-2])\s+(?:places?|restaurants?|cafes?|hotels?|stays?|bars?|hikes?|trails?|spots?|venues?|options?|ideas?|recommendations?|activities|museums?|parks?)\b"#,
            #"\b(?:find|suggest|give|show|list|return|recommend)\s+(?:me\s+)?([1-9]|1[0-2])\b"#
        ]
        // "top/best N" alone is only trusted when a place-like noun also appears.
        if text.range(of: patterns[1], options: [.regularExpression, .caseInsensitive]) != nil {
            let nouns = #"\b(places?|restaurants?|cafes?|hotels?|stays?|bars?|hikes?|trails?|spots?|venues?|options?|ideas?|recommendations?|activities|museums?|parks?)\b"#
            return text.range(of: nouns, options: [.regularExpression, .caseInsensitive]) != nil
        }
        return patterns.enumerated().contains { index, pattern in
            guard index != 1 else { return false }
            return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
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
    
    private func stopAIRun() {
        runGeneration += 1
        runTask?.cancel()
        runTask = nil
        loaderTask?.cancel()
        loaderTask = nil
        withAnimation(.easeInOut(duration: 0.28)) {
            isProcessing = false
            errorText = nil
        }
    }
    
    private func beginLoaderRotation() {
        loaderTask?.cancel()
        loaderStep = 0
        loaderTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_400_000_000)
                guard !Task.isCancelled, isProcessing else { return }
                withAnimation(.easeInOut(duration: 0.55)) {
                    loaderStep = (loaderStep + 1) % loaderSteps.count
                }
            }
        }
    }
    
    private func run(prompt: String, displayText: String? = nil, ignoreTripContext: Bool = false) async {
        let raw = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        let visible = (displayText ?? prompt).trimmingCharacters(in: .whitespacesAndNewlines)
        
        let generation: Int = await MainActor.run {
            if isProcessing { return -1 }
            isProcessing = true
            errorText = nil
            clarificationPrompt = nil
            promptText = visible.isEmpty ? raw : visible
            if mode != .placeFinder {
                placeFinderBiasRegion = nil
                placeFinderAnchorLabel = nil
            }
            return runGeneration
        }
        guard generation >= 0 else { return }
        
        let prefs = PlanDayUserPreferences(
            favoriteFoodCSV: prefFood,
            drinksAlcohol: prefAlcohol,
            interestsCSV: prefInterests
        )
        
        var text = raw
        if mode == .planDay {
            text = planDayListPrompt(raw)
            if !scopeHint.isEmpty {
                text = "For \(scopeHint): \(text)"
            }
        }
        if mode == .placeFinder {
            text = placeFinderListPrompt(raw)
        }
        if mode == .createTrip {
            text = createTripListPrompt(raw)
        }
        
        var requestTripContext = ignoreTripContext ? nil : tripContext
        var placeFinderDestination = tripContext?.destination ?? ""
        
        if mode == .placeFinder {
            let nearLabel = await MainActor.run { nearYouLabel }
            let nearCoord = await MainActor.run { nearYouCoordinate }
            let anchor = await AIPlaceFinderAnchor.resolve(
                prompt: text,
                tripContext: ignoreTripContext ? nil : tripContext,
                nearYouLabel: nearLabel,
                nearYouCoordinate: nearCoord
            )
            await MainActor.run {
                placeFinderBiasRegion = anchor.region
                placeFinderAnchorLabel = anchor.label
            }
            text = anchor.promptText
            requestTripContext = anchor.tripContextForAPI
            placeFinderDestination = anchor.label
                ?? tripContext?.destination
                ?? ""
        }
        
        let request = AIRequest(
            mode: mode,
            text: text,
            scopeHint: scopeHint,
            tripContext: requestTripContext,
            preferences: prefs.isEmpty ? nil : prefs,
            existingItems: mode == .planDay ? existingItems : [],
            existingPlaces: mode == .placeFinder ? existingPlaces : [],
            existingTrips: mode == .createTrip ? existingTrips : []
        )
        
        do {
            let response = try await client.generate(request)
            try Task.checkCancellation()
            guard await MainActor.run(body: { generation == runGeneration }) else { return }
            
            if response.clarificationNeeded {
                await MainActor.run {
                    guard generation == runGeneration else { return }
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
                        guard generation == runGeneration else { return }
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
                var timedItems = refined.items
                if PlanDayTiming.shouldAutoSchedule(intent: response.intent) {
                    PlanDayTiming.fillMissingActivityTimes(&timedItems)
                }
                try Task.checkCancellation()
                await MainActor.run {
                    guard generation == runGeneration else { return }
                    responseIntent = response.intent
                    aiReplyText = AIReplyCopy.planDay(
                        intent: response.intent,
                        itemCount: timedItems.count,
                        destination: destination
                    )
                    planDraft = PlanDayDraft(
                        items: timedItems,
                        extractedText: refined.extractedText,
                        extractedFacts: refined.extractedFacts
                    )
                    showPlanPreview = true
                    isProcessing = false
                    Haptics.bump()
                }
                
            case .placeFinder:
                var places = response.items.filter { $0.kind == .place || !$0.category.isEmpty }
                // Model sometimes returns 1 place for list asks — refill once.
                if places.count < 5, !Task.isCancelled {
                    let fillText = placeFinderFillPrompt(
                        original: raw,
                        destination: placeFinderDestination,
                        priorCount: places.count
                    )
                    let fillRequest = AIRequest(
                        mode: .placeFinder,
                        text: fillText,
                        tripContext: requestTripContext,
                        preferences: prefs.isEmpty ? nil : prefs,
                        existingPlaces: existingPlaces
                    )
                    if let fillResponse = try? await client.generate(fillRequest),
                       !fillResponse.clarificationNeeded {
                        let fillPlaces = fillResponse.items.filter { $0.kind == .place || !$0.category.isEmpty }
                        if fillPlaces.count > places.count {
                            places = fillPlaces
                        }
                    }
                }
                let normalized: [PlanDayItem] = places.map { item in
                    var copy = item
                    copy.kind = .place
                    copy.include = false
                    if copy.category.isEmpty { copy.category = "other" }
                    return copy
                }
                guard !normalized.isEmpty else {
                    await MainActor.run {
                        guard generation == runGeneration else { return }
                        errorText = "No places came back. Try naming a city or category."
                        isProcessing = false
                    }
                    return
                }
                let destination = placeFinderDestination.trimmingCharacters(in: .whitespacesAndNewlines)
                let refinedDraft = await PlanDayLocationResolver.refineLocations(
                    in: PlanDayDraft(items: normalized, extractedText: raw, extractedFacts: PlanDayFacts()),
                    destination: destination,
                    biasRegion: searchBiasRegion()
                )
                let refined = refinedDraft.items
                try Task.checkCancellation()
                await MainActor.run {
                    guard generation == runGeneration else { return }
                    aiReplyText = AIReplyCopy.places(
                        itemCount: refined.count,
                        destinationHint: placeFinderDestinationHint(from: raw),
                        items: refined
                    )
                    placeItems = refined
                    showPlacesPreview = true
                    isProcessing = false
                    Haptics.bump()
                }
                
            case .createTrip:
                guard var trip = response.trip, !trip.destination.isEmpty || !trip.name.isEmpty else {
                    await MainActor.run {
                        guard generation == runGeneration else { return }
                        errorText = "Couldn't draft a trip. Try adding a destination."
                        isProcessing = false
                    }
                    return
                }
                // Ground-truth dates from the prompt beat a soft model miss.
                if let extracted = AIDayMapping.extractTripDateRange(from: raw) {
                    trip.isDatesSet = true
                    trip.startDate = extracted.start
                    trip.endDate = extracted.end
                    trip.unscheduledDaysCount = 0
                } else if !trip.isDatesSet,
                          let inferred = AIDayMapping.inferredDayCount(from: raw),
                          inferred > max(1, trip.unscheduledDaysCount) {
                    trip.unscheduledDaysCount = inferred
                }
                trip.normalizeUpcomingDates()
                let dayCount = AIDayMapping.resolvedDayCount(for: trip, promptText: raw)
                var seeds = AIDayMapping.applyNamedStay(
                    AIDayMapping.spreadCreateTripItems(
                        sanitizePlanItems(response.items),
                        dayCount: dayCount
                    ),
                    fromPrompt: raw,
                    destination: trip.destination
                )
                
                // Thin count — refill once (server may still under-deliver without schema deploy).
                if createTripNeedsRefill(seeds, dayCount: dayCount) {
                    let fillText = createTripFillPrompt(
                        trip: trip,
                        dayCount: dayCount,
                        priorCount: seeds.count,
                        prompt: raw
                    )
                    let fillRequest = AIRequest(
                        mode: .createTrip,
                        text: fillText,
                        preferences: prefs.isEmpty ? nil : prefs,
                        existingTrips: existingTrips
                    )
                    if let fillResponse = try? await client.generate(fillRequest),
                       !fillResponse.clarificationNeeded {
                        let fillSeeds = AIDayMapping.applyNamedStay(
                            AIDayMapping.spreadCreateTripItems(
                                sanitizePlanItems(fillResponse.items),
                                dayCount: dayCount
                            ),
                            fromPrompt: raw,
                            destination: trip.destination
                        )
                        if fillSeeds.count > seeds.count {
                            seeds = fillSeeds
                        }
                        if let filledTrip = fillResponse.trip,
                           !filledTrip.destination.isEmpty || !filledTrip.name.isEmpty {
                            trip.name = filledTrip.name.isEmpty ? trip.name : filledTrip.name
                            trip.destination = filledTrip.destination.isEmpty ? trip.destination : filledTrip.destination
                            trip.summary = filledTrip.summary.isEmpty ? trip.summary : filledTrip.summary
                            if let extracted = AIDayMapping.extractTripDateRange(from: raw) {
                                trip.isDatesSet = true
                                trip.startDate = extracted.start
                                trip.endDate = extracted.end
                                trip.unscheduledDaysCount = 0
                            } else if !filledTrip.isDatesSet {
                                trip.unscheduledDaysCount = max(trip.unscheduledDaysCount, filledTrip.unscheduledDaysCount, dayCount)
                            }
                            trip.normalizeUpcomingDates()
                        }
                    }
                }
                
                let destination = trip.destination.trimmingCharacters(in: .whitespacesAndNewlines)
                var refinedSeeds = await PlanDayLocationResolver.refineLocations(
                    in: PlanDayDraft(items: seeds, extractedText: raw, extractedFacts: PlanDayFacts()),
                    destination: destination.isEmpty ? trip.name : destination,
                    biasRegion: searchBiasRegion()
                )
                
                // Unresolved MapKit venues → one location-aware refill with real venue names.
                if AIDayMapping.needsLocationRefill(refinedSeeds.items) {
                    let badNames = refinedSeeds.items
                        .filter(\.isLocationUnresolved)
                        .prefix(8)
                        .map(\.title)
                    let locationFill = createTripLocationRefillPrompt(
                        trip: trip,
                        dayCount: dayCount,
                        badVenueNames: Array(badNames),
                        prompt: raw
                    )
                    let locRequest = AIRequest(
                        mode: .createTrip,
                        text: locationFill,
                        preferences: prefs.isEmpty ? nil : prefs,
                        existingTrips: existingTrips
                    )
                    if let locResponse = try? await client.generate(locRequest),
                       !locResponse.clarificationNeeded {
                        let locSeeds = AIDayMapping.applyNamedStay(
                            AIDayMapping.spreadCreateTripItems(
                                sanitizePlanItems(locResponse.items),
                                dayCount: dayCount
                            ),
                            fromPrompt: raw,
                            destination: trip.destination
                        )
                        if locSeeds.count >= seeds.count / 2 {
                            seeds = locSeeds
                            refinedSeeds = await PlanDayLocationResolver.refineLocations(
                                in: PlanDayDraft(items: seeds, extractedText: raw, extractedFacts: PlanDayFacts()),
                                destination: destination.isEmpty ? trip.name : destination,
                                biasRegion: searchBiasRegion()
                            )
                        }
                    }
                }
                
                var timedSeeds = AIDayMapping.applyNamedStay(
                    refinedSeeds.items,
                    fromPrompt: raw,
                    destination: trip.destination,
                    clearCoordinatesWhenRenaming: false
                )
                PlanDayTiming.fillMissingActivityTimes(&timedSeeds)
                try Task.checkCancellation()
                await MainActor.run {
                    guard generation == runGeneration else { return }
                    aiReplyText = AIReplyCopy.createTrip(trip: trip, itemCount: timedSeeds.count)
                    tripDraft = trip
                    tripSeedItems = timedSeeds
                    showTripPreview = true
                    isProcessing = false
                    Haptics.bump()
                }
            }
        } catch is CancellationError {
            await MainActor.run {
                guard generation == runGeneration else { return }
                isProcessing = false
            }
        } catch let urlError as URLError where urlError.code == .cancelled {
            await MainActor.run {
                guard generation == runGeneration else { return }
                isProcessing = false
            }
        } catch {
            await MainActor.run {
                guard generation == runGeneration else { return }
                withAnimation(.easeOut(duration: 0.22)) {
                    errorText = userFriendlyError(error)
                }
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
    
    private func placeFinderDestinationHint(from prompt: String) -> String? {
        if let placeFinderAnchorLabel, !placeFinderAnchorLabel.isEmpty {
            return placeFinderAnchorLabel
        }
        if let nearYouLabel, !nearYouLabel.isEmpty { return nearYouLabel }
        if let extracted = AIPlaceFinderAnchor.extractDestination(from: prompt) {
            return extracted
        }
        let dest = tripContext?.destination.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !dest.isEmpty { return dest }
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("best of ") {
            return String(trimmed.dropFirst("Best of ".count))
        }
        return nil
    }
    
    private func searchBiasRegion() -> MKCoordinateRegion? {
        if let nearYouCoordinate {
            return MKCoordinateRegion(
                center: nearYouCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
            )
        }
        if let placeFinderBiasRegion {
            return placeFinderBiasRegion
        }
        guard let lat = tripContext?.latitude, let lon = tripContext?.longitude else { return nil }
        let span = max(0.05, min(tripContext?.mapSpan ?? 0.18, 0.6))
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
    }
    
    private func aiErrorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .accessibilityHidden(true)
            
            Text("Something went wrong.")
                .font(.app(15, weight: .regular))
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Spacer(minLength: 8)
            
            Button {
                let prompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
                withAnimation(.easeOut(duration: 0.2)) {
                    errorText = nil
                }
                guard !prompt.isEmpty else { return }
                Haptics.bump()
                runTask = Task { await run(prompt: prompt) }
            } label: {
                Text("Try Again")
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            Color(.secondarySystemFill),
            in: Capsule(style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityHint("Try Again")
    }
    
    private func userFriendlyError(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "Check your connection and try again."
            case .timedOut:
                return "That took too long. Try again in a moment."
            default:
                break
            }
        }
        
        if let e = error as? TripStacksAIError {
            switch e {
            case .invalidResponse:
                return "The AI response couldn't be read. Try again."
            case .http(let status, _):
                if status == 429 {
                    return "Too many requests. Try again in a moment."
                }
                let code = (e.serverErrorCode ?? "").lowercased()
                if code.contains("no usable json")
                    || code.contains("invalid json")
                    || code.contains("invalid gemini")
                    || code.contains("missing trip")
                {
                    return "The AI had trouble generating that plan. Please try again."
                }
                if (500..<600).contains(status) {
                    return "Something went wrong on our side. Please try again."
                }
                return "Something went wrong. Please try again."
            }
        }
        
        return "Something went wrong. Please try again."
    }
}

private struct AIPromptFieldGlassBackground: ViewModifier {
    let shape: RoundedRectangle
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .clipShape(shape)
        }
    }
}

private struct AIQuickChip: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let usesCurrentLocation: Bool
    let opensManualCreate: Bool
    
    init(
        title: String,
        systemImage: String,
        usesCurrentLocation: Bool = false,
        opensManualCreate: Bool = false
    ) {
        self.id = title
        self.title = title
        self.systemImage = systemImage
        self.usesCurrentLocation = usesCurrentLocation
        self.opensManualCreate = opensManualCreate
    }
}
