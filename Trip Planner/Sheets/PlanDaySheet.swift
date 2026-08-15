import MapKit
import SwiftUI

struct PlanDaySheet: View {
    @Environment(\.dismiss) private var dismiss
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
    
    private let geminiEndpoint = URL(string: "https://trip-planner-ai-proxy.vercel.app/api/parsePaste")!
    
    private let loaderLabels: [String] = [
        "Thinking",
        "Applying preferences",
        "Researching spots",
        "Organizing day"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $promptText)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color(.separator).opacity(0.35))
                        }
                    
                    if promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("What do you have in mind?")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 220)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
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
            Label(text, systemImage: systemImage)
                .font(.app(15, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                .overlay { Capsule().strokeBorder(Color(.separator).opacity(0.35)) }
        }
        .buttonStyle(.plain)
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

