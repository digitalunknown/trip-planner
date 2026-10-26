import SwiftUI
import MapKit
import UIKit
import UniformTypeIdentifiers
import QuickLook

struct NewFlightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.colorScheme) private var colorScheme
    
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
    @Binding var startTime: Date
    @Binding var endTime: Date
    @Binding var cost: Double?
    @Binding var costCurrencyCode: String?
    
    @Binding var selectedDayID: UUID?
    let dayOptions: [DayOption]
    var tripLocationRegion: MKCoordinateRegion? = nil
    
    var isEditing: Bool
    var onSave: () -> Void
    var onDelete: (() -> Void)?
    var accent: EventAccent = .cream
    
    @State private var showCostSheet = false
    @State private var showDocumentImagePicker = false
    @State private var showDocumentCameraPicker = false
    @State private var showDocumentFileImporter = false
    @State private var pendingDocumentImage: UIImage?
    @State private var pendingDocumentCameraImage: UIImage?
    @State private var selectedPreviewDocumentID: UUID?
    @State private var selectedQuickLookDocument: EventDocument?
    
    private var referenceFieldTitle: String? {
        switch travelMode {
        case .flight: return "Flight number"
        case .train: return "Train line / number"
        case .drive: return "Vehicle / route"
        case .walk: return nil
        }
    }
    
    private var referenceFieldIcon: String {
        switch travelMode {
        case .flight: return "tickets-plane"
        case .train: return "train-front"
        case .drive: return "car-front"
        case .walk: return "footprints"
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
                    AppIcon(systemName: "doc.fill", size: 44, color: .secondary)
                    Button("Open File") {
                        selectedQuickLookDocument = document
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
    }
    
    private var selectedDayTitle: String {
        dayOptions.first(where: { $0.id == selectedDayID })?.title ?? ""
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppDetailSurface.page(for: colorScheme)
                    .ignoresSafeArea()
                
                LinearGradient(
                    colors: [
                        accent.background.opacity(0.28),
                        accent.background.opacity(0.12),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 260)
                .ignoresSafeArea(edges: [.top, .horizontal])
                .allowsHitTesting(false)
                
                travelForm
            }
            .navigationTitle("")
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
        .sheetAccentDragIndicator(accent.background)
    }
    
    private var travelForm: some View {
        Form {
            heroSection
            daySection
            if let referenceFieldTitle {
                referenceSection(title: referenceFieldTitle)
            }
            endpointSection(title: "From", isFrom: true)
            endpointSection(title: "To", isFrom: false)
            costSection
            documentsSection
            notesSection
            if isEditing {
                deleteSection
            }
        }
        .scrollContentBackground(.hidden)
        .appFormPageSpacing()
    }
    
    private var heroSection: some View {
        Section {
            Menu {
                ForEach(TravelMode.allCases, id: \.self) { mode in
                    Button {
                        travelMode = mode
                    } label: {
                        if mode == travelMode {
                            Label(mode.title, systemImage: "checkmark")
                        } else {
                            Text(mode.title)
                        }
                    }
                }
            } label: {
                Text(travelMode.title)
                    .font(.appDisplay)
                    .foregroundStyle(AppColor.textStrong)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose travel method")
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    private var daySection: some View {
        Section {
            Menu {
                ForEach(dayOptions) { option in
                    Button {
                        selectedDayID = option.id
                    } label: {
                        if option.id == selectedDayID {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    AppIcon(lucide: "calendar-1", size: AppLucide.fieldSize, color: AppColor.textStrong)
                    Text("Day")
                        .font(.app(15, weight: .medium))
                        .foregroundStyle(AppColor.textStrong)
                    Spacer(minLength: 8)
                    HStack(spacing: 5) {
                        Text(selectedDayTitle)
                            .font(.app(15, weight: .medium))
                            .foregroundStyle(AppColor.textStrong)
                            .lineLimit(1)
                        AppIcon(lucide: "chevrons-up-down", size: AppLucide.fieldSize, color: AppColor.textWeak)
                    }
                }
                .padding(AppSpacing.fieldPadding)
                .background(AppColor.card, in: Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }
    
    private func referenceSection(title: String) -> some View {
        Section {
            clearableTextField(
                title: title,
                text: $flightNumber,
                icon: referenceFieldIcon,
                capitalization: (travelMode == .flight || travelMode == .train) ? .characters : nil
            )
            .padding(AppSpacing.fieldPadding)
            .background(AppColor.card, in: Capsule(style: .continuous))
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    private func endpointSection(title: String, isFrom: Bool) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                AppSectionHeader(title)
                    .padding(.leading, 20)
                
                VStack(spacing: 12) {
                    locationFields(isFrom: isFrom)
                    
                    travelFieldDivider
                    
                    travelFieldRow(lucide: "clock", title: "Time") {
                        DatePicker(
                            "",
                            selection: isFrom ? $startTime : $endTime,
                            in: isFrom ? Date.distantPast...Date.distantFuture : startTime...Date.distantFuture,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .appDatePickerFont()
                        .tint(AppColor.textStrong)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .background(
                    AppColor.card,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    private var costSection: some View {
        Section {
            Button {
                showCostSheet = true
            } label: {
                HStack(spacing: 10) {
                    AppIcon(lucide: "wallet", size: AppLucide.fieldSize, color: AppColor.textStrong)
                    Text("Cost")
                        .font(.app(15, weight: .medium))
                        .foregroundStyle(AppColor.textStrong)
                    Spacer(minLength: 8)
                    Text(CurrencyFormatting.string(for: cost, currencyCode: costCurrencyCode))
                        .font(.app(15, weight: .medium))
                        .foregroundStyle(AppColor.textStrong)
                        .monospacedDigit()
                }
                .padding(AppSpacing.fieldPadding)
                .background(AppColor.card, in: Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }
    
    private var notesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                AppSectionHeader("Notes")
                    .padding(.leading, 20)
                
                TextField("", text: $notes, axis: .vertical)
                    .font(.app(15, weight: .medium))
                    .foregroundStyle(AppColor.textStrong)
                    .lineLimit(3...12)
                    .textInputAutocapitalization(.sentences)
                    .padding(AppSpacing.cardPadding)
                    .frame(minHeight: 100, alignment: .topLeading)
                    .background(
                        AppColor.card,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    private var deleteSection: some View {
        Section {
            Button {
                onDelete?()
                dismiss()
            } label: {
                DetailDualActionButton(
                    lucide: "trash-2",
                    title: "Delete \(travelMode.title)",
                    foreground: .red,
                    fill: Color.red.opacity(colorScheme == .dark ? 0.25 : 0.14)
                )
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }
    
    private func travelFieldRow<Trailing: View>(
        lucide: String,
        title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 8) {
            AppIcon(lucide: lucide, size: AppLucide.fieldSize, color: AppColor.textStrong)
            Text(title)
                .font(.app(15, weight: .medium))
                .foregroundStyle(AppColor.textStrong)
            Spacer(minLength: 8)
            trailing()
        }
    }
    
    private var travelFieldDivider: some View {
        Rectangle()
            .fill(AppColor.textStrong.opacity(0.05))
            .frame(height: 1)
    }

    private var documentsSection: some View {
        Section {
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
                            Label("Upload from Files", appIcon: "folder")
                        }
                        Button {
                            showDocumentImagePicker = true
                        } label: {
                            Label("Upload from Photos", appIcon: "photo.on.rectangle")
                        }
                        Button {
                            showDocumentCameraPicker = true
                        } label: {
                            Label("Take Photo", appIcon: "camera")
                        }
                    } label: {
                        addDocumentCard
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }
        } header: {
            AppSectionHeader("Images & Documents")
        }
        .appDetailFieldBackground()
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
                            .font(.app(17, weight: .semibold))
                            .foregroundStyle(AppColor.textWeak)
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
                .font(.app(15, weight: .semibold))
                .foregroundStyle(AppColor.textWeak)
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
                        AppIcon(systemName: "trash", size: 15, color: .red)
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
                longitude: longitude,
                searchRegion: tripLocationRegion
            )
            travelFieldDivider
            airportCodeField(title: "Airport code", code: code, icon: "hash")
            travelFieldDivider
            clearableTextField(title: "Terminal", text: terminal, icon: "building-2", capitalization: .characters)
            travelFieldDivider
            clearableTextField(title: "Gate", text: gate, icon: "door-open", capitalization: .characters)
            
        case .train:
            LocationSearchField(
                text: name,
                latitude: latitude,
                longitude: longitude,
                resultTypes: [.pointOfInterest, .address],
                searchRegion: tripLocationRegion
            )
            travelFieldDivider
            stationCodeField(title: "Station code", code: code, icon: "hash")
            
        case .drive, .walk:
            LocationSearchField(
                text: name,
                latitude: latitude,
                longitude: longitude,
                resultTypes: [.pointOfInterest, .address],
                searchRegion: tripLocationRegion
            )
        }
    }
    
    private func airportCodeField(title: String, code: Binding<String>, icon: String) -> some View {
        HStack(spacing: 10) {
            AppIcon(lucide: icon, size: AppLucide.fieldSize, color: AppColor.textStrong)
            TextField(title, text: code)
                .font(.app(15, weight: .medium))
                .foregroundStyle(AppColor.textStrong)
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
                    AppIcon(lucide: "circle-x", size: AppLucide.fieldSize, color: AppColor.textWeak)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func stationCodeField(title: String, code: Binding<String>, icon: String) -> some View {
        HStack(spacing: 10) {
            AppIcon(lucide: icon, size: AppLucide.fieldSize, color: AppColor.textStrong)
            TextField(title, text: code)
                .font(.app(15, weight: .medium))
                .foregroundStyle(AppColor.textStrong)
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
                    AppIcon(lucide: "circle-x", size: AppLucide.fieldSize, color: AppColor.textWeak)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func clearableTextField(
        title: String,
        text: Binding<String>,
        icon: String,
        capitalization: TextInputAutocapitalization? = nil
    ) -> some View {
        HStack(spacing: 10) {
            AppIcon(lucide: icon, size: AppLucide.fieldSize, color: AppColor.textStrong)
            TextField(title, text: text)
                .font(.app(15, weight: .medium))
                .foregroundStyle(AppColor.textStrong)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
            
            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                } label: {
                    AppIcon(lucide: "circle-x", size: AppLucide.fieldSize, color: AppColor.textWeak)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

