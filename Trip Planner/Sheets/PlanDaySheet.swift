import MapKit
import SwiftUI

struct PlanDaySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("prefFood") private var prefFood: String = ""
    @AppStorage("prefAlcohol") private var prefAlcohol: Bool = false
    @AppStorage("prefInterests") private var prefInterests: String = ""
    
    let tripContext: PlanDayTripContext
    let dayOptions: [DayOption]
    let defaultDayID: UUID?
    let onCommit: ([PlanDayItem]) -> Void
    
    @State private var promptText: String = ""
    @State private var draft: PlanDayDraft?
    @State private var showPreview: Bool = false
    
    @State private var isProcessing: Bool = false
    @State private var errorText: String?
    @State private var loaderStep: Int = 0
    
    /// AI intro glow on the prompt field.
    @State private var aiGlowActive = false
    @State private var aiGlowRotation: Double = 0
    @State private var aiGlowPulse = false
    
    private let geminiEndpoint = URL(string: "https://trip-planner-ai-proxy.vercel.app/api/parsePaste")!
    
    private let loaderLabels: [String] = [
        "Thinking",
        "Applying preferences",
        "Researching spots",
        "Organizing day"
    ]
    
    private var chipForeground: Color {
        colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717)
    }
    
    private var chipFallback: Color {
        colorScheme == .dark ? Color(hex: 0x171717) : Color(hex: 0xF0F0F0)
    }
    
    private var promptFieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
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
                                            Color(hex: 0x5AC8FA)
                                        ],
                                        center: .center,
                                        angle: .degrees(aiGlowRotation)
                                    ),
                                    lineWidth: aiGlowActive ? 2.5 : 0
                                )
                                .opacity(aiGlowActive ? (aiGlowPulse ? 1 : 0.55) : 0)
                                .blur(radius: aiGlowActive ? 0.4 : 0)
                        }
                        .shadow(
                            color: Color(hex: 0x7B61FF).opacity(aiGlowActive ? (aiGlowPulse ? 0.45 : 0.22) : 0),
                            radius: aiGlowActive ? (aiGlowPulse ? 18 : 10) : 0,
                            x: 0,
                            y: 0
                        )
                        .shadow(
                            color: Color(hex: 0x5AC8FA).opacity(aiGlowActive ? (aiGlowPulse ? 0.35 : 0.16) : 0),
                            radius: aiGlowActive ? (aiGlowPulse ? 14 : 8) : 0,
                            x: 0,
                            y: 0
                        )
                    
                    if promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("What do you have in mind?")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 220)
                .onAppear { playAIGlowIntro() }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        quickPromptChip("A day of sightseeing", systemImage: "binoculars.fill")
                        quickPromptChip("A food and drink focused day", systemImage: "fork.knife")
                        quickPromptChip("Fun with kids", systemImage: "figure.and.child.holdinghands")
                        quickPromptChip("An adventurous day", systemImage: "mountain.2.fill")
                        quickPromptChip("Photography day", systemImage: "camera.fill")
                    }
                    .padding(.horizontal, 2)
                }
                .scrollClipDisabled()
                .padding(.bottom, 2)
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Plan Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    LiquidGlassIconButton(systemName: "arrow.right") {
                        Task { await parseAndContinue() }
                    }
                        .disabled(isProcessing || promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .overlay {
                if isProcessing {
                    ZStack {
                        Color.black.opacity(0.12).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.large)
                            
                            Text(loaderLabels[loaderStep])
                                .font(.app(15, weight: .semibold))
                                .foregroundStyle(.primary)
                                .id(loaderStep)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 18)
                        .frame(minWidth: 260)
                        .frame(minHeight: 120)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .task(id: isProcessing) {
                        guard isProcessing else { return }
                        await MainActor.run {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                loaderStep = 0
                            }
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
            .navigationDestination(isPresented: $showPreview) {
                if let draft {
                    PlanDayPreviewView(
                        draft: draft,
                        dayOptions: dayOptions,
                        onCancel: { dismiss() },
                        onConfirm: { items in
                            onCommit(items)
                            dismiss()
                        }
                    )
                }
            }
            .alert("Plan Day Error", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                Button("OK", role: .cancel) { errorText = nil }
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func quickPromptChip(_ text: String, systemImage: String) -> some View {
        Button {
            Task { await runPlan(for: text) }
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
            .modifier(PlanDayChipGlassBackground(fallback: chipFallback))
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
    
    private func parseAndContinue() async {
        let rawPrompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        await runPlan(for: rawPrompt)
    }

    private func runPlan(for rawPrompt: String) async {
        let raw = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        
        let shouldRun: Bool = await MainActor.run {
            if isProcessing { return false }
            isProcessing = true
            errorText = nil
            return true
        }
        guard shouldRun else { return }
        
        let expandedPrompt = promptExpandedText(from: raw)
        let draftForAI = PlanDayDraft(items: [], extractedText: expandedPrompt, extractedFacts: PlanDayFacts())
        
        do {
            let enhancer = GeminiPlanDayEnhancer(endpoint: geminiEndpoint)
            let prefs = PlanDayUserPreferences(favoriteFoodCSV: prefFood, drinksAlcohol: prefAlcohol, interestsCSV: prefInterests)
            let enhanced = try await enhancer.enhance(draft: draftForAI, tripContext: tripContext, preferences: prefs.isEmpty ? nil : prefs)
            let sanitized = sanitizeAIResponse(enhanced)
            guard !sanitized.items.isEmpty else {
                await MainActor.run {
                    errorText = "Gemini returned no usable items. Try a more specific prompt (e.g. include “8 activities” and “a packing checklist”)."
                    isProcessing = false
                }
                return
            }
            let refined = await PlanDayLocationResolver.refineLocations(
                in: sanitized,
                destination: tripContext.destination,
                biasRegion: searchBiasRegion()
            )
            await MainActor.run {
                draft = applyingDefaultDay(to: refined)
                showPreview = true
            }
        } catch {
            await MainActor.run {
                errorText = userFriendlyError(error)
            }
        }
        
        await MainActor.run { isProcessing = false }
    }
    
    private func userFriendlyError(_ error: Error) -> String {
        if let e = error as? GeminiPlanDayEnhancerError,
           case let .http(status, body) = e {
            if status == 429 {
                let retrySeconds = retryDelaySeconds(from: body)
                if let retrySeconds {
                    return "Too many requests. Try again in \(retrySeconds)s."
                }
                return "Too many requests. Try again in a moment."
            }
            return "AI planning failed.\n\n\(e.localizedDescription)"
        }
        return "AI planning failed.\n\n\(error.localizedDescription)"
    }
    
    private func retryDelaySeconds(from body: String) -> Int? {
        if let range = body.range(of: #"retryDelay"\s*:\s*"(\d+)s""#, options: .regularExpression) {
            let snippet = String(body[range])
            let digits = snippet.filter { $0.isNumber }
            return Int(digits)
        }
        if let range = body.range(of: #"retry in ([0-9]+)"#, options: .regularExpression) {
            let snippet = String(body[range])
            let digits = snippet.filter { $0.isNumber }
            return Int(digits)
        }
        return nil
    }
    
    private func promptExpandedText(from rawText: String) -> String {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        
        let ctx = tripContext
        let tripInfo = ctx.isDatesSet ? "Trip dates: \(isoDate(ctx.startDate)) to \(isoDate(ctx.endDate))." : "Trip is unscheduled (\(ctx.unscheduledDaysCount) days)."
        let dayTitle = dayOptions.first(where: { $0.id == defaultDayID })?.title ?? "Selected day"
        
        return """
You are a trip-planning assistant. Generate itinerary ideas for ONE day.

User prompt:
\(trimmed)

Constraints:
- Generate: 6–10 activities, 1 checklist (5–12 items), and 0–3 reminders.
- Activities should have concrete titles.
- Location rules:
  - If the activity is a specific establishment (restaurant, museum, cafe, shop, hotel, landmark building, etc.), set location to that place’s street address (include street number when known), not just the neighborhood/district/city.
  - If the activity is intentionally a general area (neighborhood stroll, beach day, explore a district), a neighborhood/area name is fine.
  - Prefer real places in the destination. Never invent a vague area when a venue has a known address.
- Do not output an activity whose title is exactly the same as the user prompt.
- Return STRICT JSON matching the schema. Provide ALL fields. If unknown, use empty string or null.
- Set dayID to null or the selected day; the app will assign missing dayIDs to the selected day.

Context:
- Destination: \(ctx.destination)
- \(tripInfo)
- Selected day: \(dayTitle)

Return JSON only.
"""
    }
    
    private func applyingDefaultDay(to draft: PlanDayDraft) -> PlanDayDraft {
        guard let id = defaultDayID else { return draft }
        var updated = draft
        for idx in updated.items.indices {
            if updated.items[idx].dayID == nil {
                updated.items[idx].dayID = id
            }
        }
        return updated
    }

    private func sanitizeAIResponse(_ draft: PlanDayDraft) -> PlanDayDraft {
        var updated = draft
        updated.items = updated.items
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
                case .activity:
                    return !title.isEmpty
                case .reminder:
                    return !title.isEmpty
                case .checklist:
                    let hasTitle = !title.isEmpty
                    let hasItems = !item.checklistItemsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    return hasTitle && hasItems
                case .flight:
                    let hasAnyFlightField =
                        !item.flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        !item.flightFromCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        !item.flightToCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    return hasAnyFlightField
                }
            }

        return updated
    }
    
    private func searchBiasRegion() -> MKCoordinateRegion? {
        guard let lat = tripContext.latitude, let lon = tripContext.longitude else { return nil }
        let span = max(0.05, min(tripContext.mapSpan ?? 0.18, 0.6))
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
    }
    
    private func isoDate(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.string(from: date)
    }
}

// MARK: - Chip glass (matches Places filter chips)

private struct PlanDayChipGlassBackground: ViewModifier {
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

