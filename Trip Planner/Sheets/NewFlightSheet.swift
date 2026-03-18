import SwiftUI
import MapKit
import UIKit
import UniformTypeIdentifiers
import QuickLook

struct NewFlightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    
    @Binding var fromName: String
    @Binding var fromCode: String
    @Binding var fromCity: String
    @Binding var fromLatitude: Double?
    @Binding var fromLongitude: Double?
    @Binding var fromTerminal: String
    @Binding var fromGate: String
    
    @Binding var toName: String
    @Binding var toCode: String
    @Binding var toCity: String
    @Binding var toLatitude: Double?
    @Binding var toLongitude: Double?
    @Binding var toTerminal: String
    @Binding var toGate: String
    
    @Binding var travelMode: TravelMode
    @Binding var flightNumber: String
    @Binding var notes: String
    @Binding var documents: [EventDocument]
    @Binding var accent: EventAccent
    @Binding var startTime: Date
    @Binding var endTime: Date
    @Binding var cost: Double?
    @Binding var costCurrencyCode: String?
    
    @Binding var selectedDayID: UUID?
    let dayOptions: [DayOption]
    
    var isEditing: Bool
    var onSave: () -> Void
    var onDelete: (() -> Void)?
    
    @State private var showCostSheet = false
    @State private var showDocumentImagePicker = false
    @State private var showDocumentCameraPicker = false
    @State private var showDocumentFileImporter = false
    @State private var isExtractingDocumentText = false
    @State private var pendingDocumentImage: UIImage?
    @State private var pendingDocumentCameraImage: UIImage?
    @State private var extractionReviewResult: DocumentTextExtractor.ExtractionResult?
    @State private var selectedPreviewDocumentID: UUID?
    @State private var selectedQuickLookDocument: EventDocument?
    
    private let gridSpacing: CGFloat = 12
    private let columnsCount: Int = 6
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: columnsCount)
    }
    private let tileHeight: CGFloat = 48
    private var colorOptions: [EventAccent] { Array(EventAccent.allCases.reversed()) }
    
    private var referenceFieldTitle: String? {
        switch travelMode {
        case .flight: return "Flight number"
        case .train: return "Train line / number"
        case .drive: return "Vehicle / route"
        case .walk: return nil
        }
    }
    
    private var isSavable: Bool {
        selectedDayID != nil && (
            !fromName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !toName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !fromCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !toCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !fromCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !toCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
    }

    private func isImageDocument(_ document: EventDocument) -> Bool {
        if let mime = document.mimeType?.lowercased(), mime.hasPrefix("image/") {
            return true
        }
        if let type = UTType(filenameExtension: document.fileExtension.lowercased()) {
            return type.conforms(to: .image)
        }
        return false
    }

    private func openDocument(_ document: EventDocument) {
        selectedPreviewDocumentID = document.id
    }

    private func addDocumentFromImportedURL(_ url: URL) {
        do {
            let saved = try ActivityDocumentStore.saveImportedFile(from: url, source: .files)
            documents.append(saved)
        } catch {
            return
        }
    }

    private func addDocumentFromImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        do {
            let saved = try ActivityDocumentStore.saveImageData(
                data,
                source: .photoLibrary,
                preferredFileName: "Travel-\(Date().timeIntervalSince1970).jpg"
            )
            documents.append(saved)
        } catch {
            return
        }
    }

    private func removeCurrentlyPreviewedDocument() {
        guard let selectedPreviewDocumentID else { return }
        guard let currentIndex = documents.firstIndex(where: { $0.id == selectedPreviewDocumentID }) else {
            self.selectedPreviewDocumentID = nil
            return
        }

        let doc = documents[currentIndex]
        documents.removeAll { $0.id == doc.id }
        ActivityDocumentStore.delete(document: doc)

        if documents.isEmpty {
            self.selectedPreviewDocumentID = nil
        } else {
            let nextIndex = min(currentIndex, documents.count - 1)
            self.selectedPreviewDocumentID = documents[nextIndex].id
        }
    }

    private func applying(
        _ components: DateComponents,
        to baseDate: Date
    ) -> Date? {
        guard let hour = components.hour, let minute = components.minute else { return nil }
        return Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: baseDate
        )
    }

    private func appendToNotes(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let existing = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        notes = existing.isEmpty ? trimmed : "\(notes)\n\n\(trimmed)"
    }

    private func applyExtractionSelections(
        _ selections: [DocumentTextExtractor.SuggestedField],
        from result: DocumentTextExtractor.ExtractionResult
    ) {
        var appliedValues: [String] = []

        for suggestion in selections {
            switch suggestion.type {
            case .startTime:
                if let components = suggestion.timeComponents,
                   let detectedStart = applying(components, to: startTime) {
                    startTime = detectedStart
                    appliedValues.append(suggestion.value)
                }
            case .endTime:
                if let components = suggestion.timeComponents,
                   let detectedEnd = applying(components, to: startTime) {
                    endTime = max(detectedEnd, startTime)
                    appliedValues.append(suggestion.value)
                }
            case .cost:
                if let amount = suggestion.numericAmount {
                    cost = amount
                    appliedValues.append(suggestion.value)
                }
            case .currencyCode:
                costCurrencyCode = suggestion.value.uppercased()
                appliedValues.append(suggestion.value)
            case .referenceCode:
                flightNumber = suggestion.value.uppercased()
                appliedValues.append(suggestion.value)
            }
        }

        let notesBlock = result.notesBlock(excluding: appliedValues)
        appendToNotes(notesBlock)

        extractionReviewResult = nil
    }

    private func extractInfoFromDocuments() {
        guard !documents.isEmpty, !isExtractingDocumentText else { return }

        isExtractingDocumentText = true
        Task {
            let extraction = await DocumentTextExtractor.extractInfo(from: documents)

            await MainActor.run {
                if extraction.hasContent {
                    extractionReviewResult = extraction
                }
                isExtractingDocumentText = false
            }
        }
    }

    private func previewPage(_ document: EventDocument) -> some View {
        Group {
            if isImageDocument(document),
               let data = try? Data(contentsOf: ActivityDocumentStore.fileURL(for: document.localRelativePath)),
               let uiImage = UIImage(data: data) {
                VStack {
                    Spacer(minLength: 0)
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Spacer(minLength: 0)
                }
                .padding()
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "doc.fill")
                        .font(.app(44, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Button("Open File") {
                        selectedQuickLookDocument = document
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Day", selection: $selectedDayID) {
                        ForEach(dayOptions) { option in
                            Text(option.title)
                                .tag(Optional(option.id))
                        }
                    }
                }
                
                Section {
                    Picker("Travel method", selection: $travelMode) {
                        ForEach(TravelMode.allCases, id: \.self) { mode in
                            Text(mode.title)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                if let referenceFieldTitle {
                    Section {
                        clearableTextField(
                            title: referenceFieldTitle,
                            text: $flightNumber,
                            capitalization: (travelMode == .flight || travelMode == .train) ? .characters : nil
                        )
                    }
                }
                
                Section {
                    locationFields(isFrom: true)
                    DatePicker("Time", selection: $startTime, displayedComponents: .hourAndMinute)
                } header: {
                    Text("From")
                }
                
                Section {
                    locationFields(isFrom: false)
                    DatePicker("Time", selection: $endTime, in: startTime..., displayedComponents: .hourAndMinute)
                } header: {
                    Text("To")
                }
                
                Section {
                    Button {
                        showCostSheet = true
                    } label: {
                        HStack {
                            Text("Cost")
                            Spacer()
                            Text(CurrencyFormatting.string(for: cost, currencyCode: costCurrencyCode))
                                .foregroundStyle(.primary)
                                .monospacedDigit()
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color")
                            .font(.appFootnote)
                            .foregroundStyle(.secondary)
                        
                        LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                            ForEach(colorOptions, id: \.self) { option in
                                Button {
                                    accent = option
                                } label: {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(option.color)
                                        .frame(height: tileHeight)
                                        .overlay {
                                            if option == accent {
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .strokeBorder(Color.primary, lineWidth: 2.5)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Color")
                            }
                        }
                    }
                }
                
                documentsSection

                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...12)
                        .textInputAutocapitalization(.sentences)
                }
                
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            onDelete?()
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete \(travelMode.title)")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? travelMode.title : "Add Travel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    LiquidGlassIconButton(
                        systemName: "checkmark",
                        isEnabled: isSavable
                    ) {
                        onSave()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if endTime < startTime { endTime = startTime }
            }
            .onChange(of: startTime) { _, newValue in
                if endTime < newValue { endTime = newValue }
            }
            .onChange(of: travelMode) { _, mode in
                if mode != .flight {
                    fromTerminal = ""
                    fromGate = ""
                    toTerminal = ""
                    toGate = ""
                }
                if mode == .drive || mode == .walk {
                    fromCode = ""
                    toCode = ""
                }
                if mode == .walk {
                    flightNumber = ""
                }
            }
        }
        .tint(.primary)
        .sheet(isPresented: $showDocumentImagePicker) {
            ImagePicker(image: $pendingDocumentImage)
                .tint(.primary)
        }
        .sheet(isPresented: $showDocumentCameraPicker) {
            ImagePicker(image: $pendingDocumentCameraImage, sourceType: .camera)
                .tint(.primary)
        }
        .fileImporter(
            isPresented: $showDocumentFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                urls.forEach(addDocumentFromImportedURL(_:))
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedPreviewDocumentID != nil },
            set: { if !$0 { selectedPreviewDocumentID = nil } }
        )) {
            documentPreviewScreen()
        }
        .sheet(item: $selectedQuickLookDocument) { document in
            QuickLookPreview(url: ActivityDocumentStore.fileURL(for: document.localRelativePath))
        }
        .sheet(item: $extractionReviewResult) { result in
            ExtractionReviewSheet(
                suggestions: result.suggestions,
                allowedFieldTypes: referenceFieldTitle == nil
                    ? [.startTime, .endTime, .cost, .currencyCode]
                    : [.startTime, .endTime, .cost, .currencyCode, .referenceCode],
                onApplySelected: { selections in
                    applyExtractionSelections(selections, from: result)
                },
                onSkip: {
                    let notesBlock = result.notesBlock(excluding: [])
                    appendToNotes(notesBlock)
                    extractionReviewResult = nil
                }
            )
            .presentationDetents([.medium, .large])
            .tint(.primary)
        }
        .onChange(of: pendingDocumentImage) { _, image in
            guard let image else { return }
            addDocumentFromImage(image)
            pendingDocumentImage = nil
        }
        .onChange(of: pendingDocumentCameraImage) { _, image in
            guard let image else { return }
            addDocumentFromImage(image)
            pendingDocumentCameraImage = nil
        }
        .sheet(isPresented: $showCostSheet) {
            CostEntrySheet(
                cost: $cost,
                currencyCode: Binding(
                    get: { costCurrencyCode ?? (UserDefaults.standard.string(forKey: "currencyCode") ?? "USD") },
                    set: { costCurrencyCode = $0 }
                )
            )
                .tint(.primary)
                .presentationDetents([.large])
        }
    }

    private var documentsSection: some View {
        Section("Documents") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(documents) { document in
                        Button {
                            openDocument(document)
                        } label: {
                            documentCard(document)
                        }
                        .buttonStyle(.plain)
                    }

                    Menu {
                        Button {
                            showDocumentFileImporter = true
                        } label: {
                            Label("Upload from Files", systemImage: "folder")
                        }
                        Button {
                            showDocumentImagePicker = true
                        } label: {
                            Label("Upload from Photos", systemImage: "photo.on.rectangle")
                        }
                        Button {
                            showDocumentCameraPicker = true
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                        }
                    } label: {
                        addDocumentCard
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }

            if !documents.isEmpty {
                Button {
                    extractInfoFromDocuments()
                } label: {
                    HStack {
                        if isExtractingDocumentText {
                            ProgressView()
                                .controlSize(.small)
                            Text("Extracting…")
                        } else {
                            Text("Extract information from documents")
                        }
                    }
                }
                .disabled(isExtractingDocumentText)
            }
        }
    }

    private func documentCard(_ document: EventDocument) -> some View {
        let previewSize: CGFloat = 92
        return Group {
            if isImageDocument(document),
               let thumbnail = document.thumbnailData,
               let image = UIImage(data: thumbnail) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .overlay {
                        Image(systemName: "doc.fill")
                            .font(.app(18, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: previewSize, height: previewSize)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var addDocumentCard: some View {
        let previewSize: CGFloat = 92
        return ZStack {
            Rectangle()
                .fill(Color(.tertiarySystemGroupedBackground))
            Image(systemName: "plus")
                .font(.app(16, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: previewSize, height: previewSize)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func documentPreviewScreen() -> some View {
        NavigationStack {
            TabView(selection: $selectedPreviewDocumentID) {
                ForEach(documents) { document in
                    previewPage(document)
                        .tag(Optional(document.id))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") {
                        self.selectedPreviewDocumentID = nil
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        removeCurrentlyPreviewedDocument()
                    } label: {
                        Image(systemName: "trash")
                            .font(.app(14, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    @ViewBuilder
    private func locationFields(isFrom: Bool) -> some View {
        let name = isFrom ? $fromName : $toName
        let code = isFrom ? $fromCode : $toCode
        let city = isFrom ? $fromCity : $toCity
        let latitude = isFrom ? $fromLatitude : $toLatitude
        let longitude = isFrom ? $fromLongitude : $toLongitude
        let terminal = isFrom ? $fromTerminal : $toTerminal
        let gate = isFrom ? $fromGate : $toGate
        
        switch travelMode {
        case .flight:
            AirportSearchField(
                title: "Airport",
                name: name,
                code: code,
                city: city,
                latitude: latitude,
                longitude: longitude
            )
            airportCodeField(title: "Airport code", code: code)
            clearableTextField(title: "Terminal", text: terminal, capitalization: .characters)
            clearableTextField(title: "Gate", text: gate, capitalization: .characters)
            
        case .train:
            clearableTextField(title: "Station", text: name)
            stationCodeField(title: "Station code", code: code)
            
        case .drive, .walk:
            clearableTextField(title: "Location", text: name)
        }
    }
    
    private func airportCodeField(title: String, code: Binding<String>) -> some View {
        HStack {
            TextField(title, text: code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .onChange(of: code.wrappedValue) { _, newValue in
                    let cleaned = newValue
                        .uppercased()
                        .filter { $0.isLetter }
                    code.wrappedValue = String(cleaned.prefix(3))
                }
            
            if !code.wrappedValue.isEmpty {
                Button {
                    code.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func stationCodeField(title: String, code: Binding<String>) -> some View {
        HStack {
            TextField(title, text: code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .onChange(of: code.wrappedValue) { _, newValue in
                    let cleaned = newValue
                        .uppercased()
                        .filter { $0.isLetter || $0.isNumber }
                    code.wrappedValue = String(cleaned.prefix(6))
                }
            
            if !code.wrappedValue.isEmpty {
                Button {
                    code.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func clearableTextField(
        title: String,
        text: Binding<String>,
        capitalization: TextInputAutocapitalization? = nil
    ) -> some View {
        HStack {
            TextField(title, text: text)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
            
            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

