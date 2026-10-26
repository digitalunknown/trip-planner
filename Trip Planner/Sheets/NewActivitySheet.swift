import SwiftUI
import MapKit
import UIKit
import UniformTypeIdentifiers
import QuickLook

struct NewActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @Binding var title: String
    @Binding var location: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var description: String
    @Binding var icon: String
    @Binding var accent: EventAccent
    @Binding var startTime: Date
    @Binding var endTime: Date
    @Binding var documents: [EventDocument]
    @Binding var cost: Double?
    @Binding var costCurrencyCode: String?
    @Binding var selectedDayID: UUID?
    let dayOptions: [DayOption]
    let tripLocationRegion: MKCoordinateRegion?
    var onAdd: () -> Void
    var onDelete: (() -> Void)?
    var onAddToPlaces: (() -> Void)?
    /// When the icon picker confirms with “Apply to all”, recolor every trip item.
    var onApplyAccentToAll: ((EventAccent) -> Void)?
    var isEditing: Bool = false
    /// True when this activity is already linked in Places (sourceEventID).
    var isAlreadyInPlaces: Bool = false
    
    init(
        title: Binding<String>,
        location: Binding<String>,
        latitude: Binding<Double?>,
        longitude: Binding<Double?>,
        description: Binding<String>,
        icon: Binding<String>,
        accent: Binding<EventAccent>,
        startTime: Binding<Date>,
        endTime: Binding<Date>,
        documents: Binding<[EventDocument]>,
        cost: Binding<Double?>,
        costCurrencyCode: Binding<String?>,
        selectedDayID: Binding<UUID?>,
        dayOptions: [DayOption],
        tripLocationRegion: MKCoordinateRegion?,
        onAdd: @escaping () -> Void,
        onDelete: (() -> Void)? = nil,
        onAddToPlaces: (() -> Void)? = nil,
        onApplyAccentToAll: ((EventAccent) -> Void)? = nil,
        isEditing: Bool = false,
        isAlreadyInPlaces: Bool = false
    ) {
        self._title = title
        self._location = location
        self._latitude = latitude
        self._longitude = longitude
        self._description = description
        self._icon = icon
        self._accent = accent
        self._startTime = startTime
        self._endTime = endTime
        self._documents = documents
        self._cost = cost
        self._costCurrencyCode = costCurrencyCode
        self._selectedDayID = selectedDayID
        self.dayOptions = dayOptions
        self.tripLocationRegion = tripLocationRegion
        self.onAdd = onAdd
        self.onDelete = onDelete
        self.onAddToPlaces = onAddToPlaces
        self.onApplyAccentToAll = onApplyAccentToAll
        self.isEditing = isEditing
        self.isAlreadyInPlaces = isAlreadyInPlaces
    }
    @State private var showDocumentImagePicker = false
    @State private var showDocumentCameraPicker = false
    @State private var showDocumentFileImporter = false
    @State private var hasEndTime = false
    @State private var showCostSheet = false
    @State private var showIconPickerSheet = false
    @State private var pendingDocumentImage: UIImage?
    @State private var pendingDocumentCameraImage: UIImage?
    @State private var selectedPreviewDocumentID: UUID?
    @State private var selectedQuickLookDocument: EventDocument?
    @State private var draftIcon: String = ""
    @State private var draftAccent: EventAccent = .blush
    @State private var appleMapItem: MKMapItem?
    @State private var selectedAppleMapItem: MKMapItem?
    @State private var isLoadingApplePlace = false
    @State private var showDeleteConfirm = false
    @State private var showSavedToPlacesToast = false
    @State private var savedToPlacesToastHideTask: Task<Void, Never>?
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isNotesFocused: Bool
    
    private var placeLookupKey: String {
        let loc = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let lat = latitude.map { String($0) } ?? ""
        let lon = longitude.map { String($0) } ?? ""
        return "\(loc)|\(lat)|\(lon)"
    }
    
    private var canAddToPlaces: Bool {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let loc = location.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty || !loc.isEmpty
    }
    
    private var googleMapsURL: URL? {
        let loc = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !loc.isEmpty else { return nil }
        // Always use the location/address only (not the activity title) so results are accurate.
        let query = loc
        
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "www.google.com"
        comps.path = "/maps/search/"
        comps.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: query)
        ]
        return comps.url
    }
    
    private var appleMapsURL: URL? {
        let loc = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !loc.isEmpty else { return nil }

        var comps = URLComponents()
        // Use Apple Maps deep link. Keep query to the *destination only* (not the activity title),
        // otherwise results can become ambiguous (e.g. “Check in…” + hotel name).
        comps.scheme = "maps"
        comps.host = ""
        comps.path = "/"
        
        var items: [URLQueryItem] = [
            URLQueryItem(name: "q", value: loc)
        ]
        if let lat = latitude, let lon = longitude {
            items.append(URLQueryItem(name: "ll", value: "\(lat),\(lon)"))
        }
        comps.queryItems = items
        return comps.url
    }
    
    private var uberURL: URL? {
        let loc = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !loc.isEmpty else { return nil }
        
        var comps = URLComponents()
        comps.scheme = "uber"
        comps.host = ""
        comps.path = "/"
        
        var items: [URLQueryItem] = [
            URLQueryItem(name: "action", value: "setPickup")
        ]
        
        if let lat = latitude, let lon = longitude {
            items.append(URLQueryItem(name: "dropoff[latitude]", value: String(lat)))
            items.append(URLQueryItem(name: "dropoff[longitude]", value: String(lon)))
        }
        items.append(URLQueryItem(name: "dropoff[formatted_address]", value: loc))
        
        comps.queryItems = items
        return comps.url
    }
    
    private var lyftURL: URL? {
        let loc = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !loc.isEmpty else { return nil }
        
        var comps = URLComponents()
        comps.scheme = "lyft"
        comps.host = "ridetype"
        comps.queryItems = [
            URLQueryItem(name: "id", value: "lyft"),
            URLQueryItem(name: "destination[formatted_address]", value: loc)
        ]
        if let lat = latitude, let lon = longitude {
            comps.queryItems?.append(URLQueryItem(name: "destination[latitude]", value: String(lat)))
            comps.queryItems?.append(URLQueryItem(name: "destination[longitude]", value: String(lon)))
        }
        return comps.url
    }
    
    private var selectedDayTitle: String {
        dayOptions.first(where: { $0.id == selectedDayID })?.title ?? ""
    }
    
    private var durationString: String? {
        let interval = endTime.timeIntervalSince(startTime)
        guard interval > 0 else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = interval >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .short
        return formatter.string(from: interval)
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
            if isEditing { onAdd() }
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
                preferredFileName: "Photo-\(Date().timeIntervalSince1970).jpg"
            )
            documents.append(saved)
            if isEditing { onAdd() }
        } catch {
            return
        }
    }
    
    private func removeDocument(_ document: EventDocument) {
        documents.removeAll { $0.id == document.id }
        ActivityDocumentStore.delete(document: document)
        if isEditing { onAdd() }
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
        if isEditing { onAdd() }
    }
    
    private var currentPreviewDocument: EventDocument? {
        guard let selectedPreviewDocumentID else { return nil }
        return documents.first(where: { $0.id == selectedPreviewDocumentID })
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

    private let iconOptions: [String] = [
        "mappin.and.ellipse",
        "globe",
        
        "fork.knife",
        "carrot.fill",
        "coffee",
        "takeoutbag.and.cup.and.straw.fill",
        "wineglass.fill",
        "waterbottle",
        "apple",
        "beef",
        "beer",
        "bottle-wine",
        "cake",
        "chef-hat",
        "cooking-pot",
        "croissant",
        "cup-soda",
        "donut",
        "egg-fried",
        "hamburger",
        "ice-cream-cone",
        "pizza",
        "popcorn",
        
        "airplane",
        "suitcase.fill",
        "car.fill",
        "tram.fill",
        "train.side.front.car",
        "ferry.fill",
        "scooter",
        "motorcycle.fill",
        "truck.box.fill",
        "fuelpump.fill",
        "bicycle",
        "figure.walk",
        "baggage-claim",
        "bus",
        "cable-car",
        "car-front",
        "caravan",
        "circle-parking",
        "drone",
        "ev-charger",
        "helicopter",
        "kayak",
        "plane-landing",
        "plane-takeoff",
        "sailboat",
        "tickets-plane",
        
        "cart.fill",
        "bag.fill",
        "duffle.bag.fill",
        "creditcard.fill",
        "gift.fill",
        "tag.fill",
        
        "bed.double.fill",
        "house.fill",
        "building.2.fill",
        "tent.fill",
        "mountain.2.fill",
        "water.waves",
        "leaf.fill",
        "sun.max.fill",
        "sunrise",
        "sunset",
        "beach.umbrella.fill",
        "cloud.sun.rain.fill",
        "cloud.rain.fill",
        "cloud.snow.fill",
        "cloud.bolt.rain.fill",
        "wind",
        "tent-tree",
        "tree-palm",
        "flower",
        "camera.fill",
        "ticket.fill",
        "theatermasks.fill",
        "movieclapper",
        "gamecontroller.fill",
        "figure.hiking",
        "dumbbell.fill",
        "trophy.fill",
        "heart.fill",
        "palette",
        "pencil-ruler",
        "building.columns.fill",
        "airpods.max",
        "stroller.fill",
        "sunglasses.fill",
        "shoe.fill",
        "tshirt.fill",
        "jacket.fill"
    ]
    
    private func deleteEvent() {
        onDelete?()
        dismiss()
    }
    
    private func addToPlaces() {
        onAddToPlaces?()
        Haptics.bump()
        showSavedToPlacesToast = true
        savedToPlacesToastHideTask?.cancel()
        savedToPlacesToastHideTask = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            showSavedToPlacesToast = false
        }
    }
    
    @ViewBuilder
    private func openInButton(title: String, lucide: String, url: URL?) -> some View {
        Button {
            if let url {
                openURL(url)
            }
        } label: {
            HStack(spacing: 10) {
                AppIcon(lucide: lucide, size: AppLucide.fieldSize, color: AppColor.textStrong)
                Text(title)
                    .font(.app(13, weight: .medium))
                    .foregroundStyle(AppColor.textStrong)
            }
        }
        .buttonStyle(.secondaryCapsule)
        .disabled(url == nil)
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
                            Label("Upload from Files", menuIcon: "folder")
                        }
                        Button {
                            showDocumentImagePicker = true
                        } label: {
                            Label("Upload from Photos", menuIcon: "photo.on.rectangle")
                        }
                        Button {
                            showDocumentCameraPicker = true
                        } label: {
                            Label("Take Photo", menuIcon: "camera")
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
    
    private var activityActionButtons: some View {
        Section {
            HStack(spacing: AppSpacing.xs) {
                DetailIconPillButton(
                    lucide: "map-pin-plus",
                    isEnabled: !isAlreadyInPlaces && canAddToPlaces && onAddToPlaces != nil,
                    accessibilityLabel: isAlreadyInPlaces ? "Saved to Places" : "Save to Places"
                ) {
                    addToPlaces()
                }
                
                if isEditing {
                    DetailIconPillButton(
                        lucide: "trash-2",
                        iconColor: AppColor.destructive,
                        fill: AppColor.destructive.opacity(colorScheme == .dark ? 0.25 : 0.14),
                        accessibilityLabel: "Delete Activity"
                    ) {
                        showDeleteConfirm = true
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
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
    
    private var titleHeaderSection: some View {
        Section {
            VStack(spacing: 12) {
                Button {
                    draftIcon = icon
                    draftAccent = accent
                    showIconPickerSheet = true
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(accent.background)
                        AppIcon(systemName: icon, size: 52, color: accent.foreground)
                    }
                    .frame(width: 112, height: 112)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Choose icon and color")
                
                TextField(
                    "",
                    text: $title,
                    prompt: Text("Activity")
                        .font(.appDisplay)
                        .foregroundStyle(AppColor.textWeak),
                    axis: .vertical
                )
                .font(.appDisplay)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColor.textStrong)
                .tint(AppColor.textStrong) // caret color
                .focused($isTitleFocused)
                .lineLimit(1...3)
                .scrollDisabled(true)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 18)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)
    }
    
    private var timingSection: some View {
        Section {
            VStack(spacing: 12) {
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
                    activityFieldRow(lucide: "calendar-1", title: "Day") {
                        HStack(spacing: 8) {
                            Text(selectedDayTitle)
                                .font(.app(15, weight: .medium))
                                .foregroundStyle(AppColor.textStrong)
                                .lineLimit(1)
                            AppIcon(lucide: "chevrons-up-down", size: AppLucide.fieldSize, color: AppColor.textWeak)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                activityFieldDivider
                
                activityFieldRow(lucide: "clock", title: "From") {
                    DatePicker(
                        "",
                        selection: $startTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .appDatePickerFont()
                    .tint(AppColor.textStrong)
                }
                
                activityFieldDivider
                
                activityFieldRow(lucide: "clock-plus", title: "Add end time") {
                    Toggle("", isOn: $hasEndTime)
                        .labelsHidden()
                        .tint(appAccentColor)
                }
                .onChange(of: hasEndTime) { _, newValue in
                    if !newValue {
                        endTime = startTime
                    } else if endTime <= startTime {
                        endTime = startTime.addingTimeInterval(60 * 60)
                    }
                }
                
                if hasEndTime {
                    activityFieldDivider
                    
                    activityFieldRow(lucide: "clock-arrow-down", title: "To") {
                        DatePicker(
                            "",
                            selection: $endTime,
                            in: startTime...,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .appDatePickerFont()
                        .tint(AppColor.textStrong)
                    }
                }
                
                if let durationText = durationString {
                    activityFieldDivider
                    Text("Duration: \(durationText)")
                        .font(.app(13, weight: .medium))
                        .foregroundStyle(AppColor.textWeak)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .background(
                AppColor.card,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }
    
    private func activityFieldRow<Trailing: View>(
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
    
    private var activityFieldDivider: some View {
        Rectangle()
            .fill(AppColor.textStrong.opacity(0.05))
            .frame(height: 1)
    }
    
    @ViewBuilder
    private var applePlaceInfoSection: some View {
        if location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            EmptyView()
        } else if isLoadingApplePlace, appleMapItem == nil {
            Section {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Looking up place info…")
                        .foregroundStyle(.secondary)
                }
            }
            .appDetailFieldBackground()
        } else if let appleMapItem {
            ApplePlaceContactSection(
                mapItem: appleMapItem,
                fallbackTitle: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? location
                    : title,
                selectedMapItem: $selectedAppleMapItem
            )
        }
    }
    
    @MainActor
    private func loadApplePlaceInfo() async {
        let loc = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !loc.isEmpty else {
            appleMapItem = nil
            isLoadingApplePlace = false
            return
        }
        
        isLoadingApplePlace = true
        let item = await ApplePlaceLookup.mapItem(
            name: title,
            location: location,
            latitude: latitude,
            longitude: longitude,
            regionHint: tripLocationRegion
        )
        appleMapItem = item
        isLoadingApplePlace = false
    }
    
    private var activityForm: some View {
        Form {
            titleHeaderSection
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    LocationSearchField(
                        text: $location,
                        latitude: $latitude,
                        longitude: $longitude,
                        searchRegion: tripLocationRegion
                    )
                    .padding(AppSpacing.fieldPadding)
                    .background(
                        AppColor.card,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                    
                    if isEditing, !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                openInButton(title: "Google Maps", lucide: "map", url: googleMapsURL)
                                openInButton(title: "Apple Maps", lucide: "map", url: appleMapsURL)
                                openInButton(title: "Lyft", lucide: "car-front", url: lyftURL)
                                openInButton(title: "Uber", lucide: "car-front", url: uberURL)
                            }
                        }
                        .scrollClipDisabled()
                        .foregroundStyle(AppColor.textStrong)
                    }
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            
            applePlaceInfoSection
            
            ExpertTipsMatchingSection(
                query: ExpertTipQuery(
                    title: title,
                    location: location,
                    latitude: latitude,
                    longitude: longitude
                )
            )
            
            timingSection
            
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
            
            documentsSection
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    AppSectionHeader("Notes")
                        .padding(.leading, 20)
                    
                    TextField("", text: $description, axis: .vertical)
                        .font(.app(15, weight: .medium))
                        .foregroundStyle(AppColor.textStrong)
                        .lineLimit(3...12)
                        .textInputAutocapitalization(.sentences)
                        .focused($isNotesFocused)
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
            
            activityActionButtons
        }
        .scrollContentBackground(.hidden)
        .appFormPageSpacing()
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
                        AppIcon(systemName: "trash", size: 16, color: .red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var contentStack: some View {
        ZStack(alignment: .top) {
            // Keep a true grouped page behind inset sections so white cards
            // stay visible in light mode (scroll background is hidden for the accent wash).
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
            
            activityForm
        }
    }
    
    private func applySheetAndAlertModifiers<V: View>(to view: V) -> some View {
        view
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
            .sheet(isPresented: $showIconPickerSheet) {
                IconAndColorPickerSheet(
                    icon: $draftIcon,
                    accent: $draftAccent,
                    iconOptions: iconOptions,
                    onCancel: { showIconPickerSheet = false },
                    onDone: { applyColorToAll in
                        icon = draftIcon
                        accent = draftAccent
                        showIconPickerSheet = false
                        if applyColorToAll {
                            onApplyAccentToAll?(draftAccent)
                        }
                    }
                )
                .presentationDetents([.large])
                .tint(.primary)
            }
    }

    var body: some View {
        applySheetAndAlertModifiers(to:
            NavigationStack {
                contentStack
            .navigationTitle({
                ""
            }())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    LiquidGlassIconButton(systemName: "checkmark") {
                        onAdd()
                        dismiss()
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if showSavedToPlacesToast {
                    DetailToastBanner(text: "Saved to places")
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showSavedToPlacesToast)
            .alert("Delete Activity", isPresented: $showDeleteConfirm) {
                Button("Delete Activity", role: .destructive) {
                    deleteEvent()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this activity? This action cannot be undone.")
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                if isNotesFocused {
                    Color.clear.frame(height: 36)
                }
            }
            .onAppear {
                if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isTitleFocused = true
                    }
                }
                if isEditing {
                    hasEndTime = endTime > startTime
                } else {
                    hasEndTime = false
                    endTime = startTime
                }
            }
            .task(id: placeLookupKey) {
                await loadApplePlaceInfo()
            }
            .applePlaceCardSheet(item: $selectedAppleMapItem)
            .onChange(of: hasEndTime) { _, newValue in
                if !newValue {
                    endTime = startTime
                } else if endTime <= startTime {
                    endTime = startTime.addingTimeInterval(60 * 60)
                }
            }
            .onChange(of: startTime) { _, newValue in
                if !hasEndTime {
                    endTime = newValue
                }
            }
            .onChange(of: title) { _, _ in if isEditing { onAdd() } }
            .onChange(of: location) { _, _ in if isEditing { onAdd() } }
            .onChange(of: description) { _, _ in if isEditing { onAdd() } }
            .onChange(of: icon) { _, _ in if isEditing { onAdd() } }
            .onChange(of: accent) { _, _ in if isEditing { onAdd() } }
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
            .onChange(of: documents) { _, _ in if isEditing { onAdd() } }
            .onChange(of: startTime) { _, _ in if isEditing { onAdd() } }
            .onChange(of: endTime) { _, _ in if isEditing { onAdd() } }
            .onChange(of: cost) { _, _ in if isEditing { onAdd() } }
            .onChange(of: selectedDayID) { _, _ in if isEditing { onAdd() } }
        }
        )
        .sheetAccentDragIndicator(accent.background)
    }
}

private struct IconAndColorPickerSheet: View {
    @Environment(\.appAccentColor) private var appAccentColor
    
    @Binding var icon: String
    @Binding var accent: EventAccent
    let iconOptions: [String]
    let onCancel: () -> Void
    let onDone: (_ applyColorToAll: Bool) -> Void
    
    @State private var applyColorToAll = true
    
    private let gridSpacing: CGFloat = 12
    private let columnsCount: Int = 6
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: columnsCount)
    }
    
    private let tileHeight: CGFloat = 48
    
    private var colorOptions: [EventAccent] {
        EventAccent.allCases
    }
    
    private struct IconCategory: Identifiable {
        let title: String
        let symbols: [String]
        var id: String { title }
    }
    
    private var iconCategories: [IconCategory] {
        let all = iconOptions
        var used = Set<String>()
        
        func cat(_ title: String, _ symbols: [String]) -> IconCategory {
            for s in symbols { used.insert(s) }
            return IconCategory(title: title, symbols: symbols.filter { all.contains($0) })
        }
        
        var categories: [IconCategory] = []
        
        categories.append(cat("Places", [
            "mappin.and.ellipse",
            "bed.double.fill",
            "house.fill",
            "building.2.fill",
            "building.columns.fill",
            "tent.fill"
        ]))
        
        categories.append(cat("Transportation", [
            "airplane",
            "plane-takeoff",
            "plane-landing",
            "tickets-plane",
            "baggage-claim",
            "car-front",
            "car.fill",
            "caravan",
            "circle-parking",
            "ev-charger",
            "fuelpump.fill",
            "motorcycle.fill",
            "scooter",
            "truck.box.fill",
            "bus",
            "tram.fill",
            "cable-car",
            "train.side.front.car",
            "ferry.fill",
            "sailboat",
            "kayak",
            "helicopter",
            "drone",
            "bicycle",
            "figure.walk"
        ]))
        
        categories.append(cat("Food & Drink", [
            "fork.knife",
            "chef-hat",
            "cooking-pot",
            "carrot.fill",
            "apple",
            "beef",
            "egg-fried",
            "pizza",
            "hamburger",
            "croissant",
            "donut",
            "cake",
            "ice-cream-cone",
            "popcorn",
            "coffee",
            "cup-soda",
            "beer",
            "bottle-wine",
            "wineglass.fill",
            "takeoutbag.and.cup.and.straw.fill",
            "waterbottle"
        ]))
        
        categories.append(cat("Nature", [
            "mountain.2.fill",
            "water.waves",
            "leaf.fill",
            "flower",
            "tree-palm",
            "tent-tree",
            "sun.max.fill",
            "sunrise",
            "sunset",
            "beach.umbrella.fill",
            "cloud.sun.rain.fill",
            "cloud.rain.fill",
            "cloud.snow.fill",
            "cloud.bolt.rain.fill",
            "wind"
        ]))
        
        categories.append(cat("Shopping", [
            "cart.fill",
            "bag.fill",
            "duffle.bag.fill",
            "creditcard.fill",
            "gift.fill",
            "tag.fill"
        ]))
        
        categories.append(cat("Entertainment", [
            "camera.fill",
            "ticket.fill",
            "theatermasks.fill",
            "movieclapper",
            "airpods.max",
            "gamecontroller.fill"
        ]))
        
        categories.append(cat("Lifestyle", [
            "figure.hiking",
            "dumbbell.fill",
            "trophy.fill",
            "heart.fill",
            "palette",
            "pencil-ruler"
        ]))
        
        // Remove any empty categories (in case icons list changes).
        return categories.filter { !$0.symbols.isEmpty }
    }
    
    private func iconGrid(for symbols: [String]) -> some View {
        LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
            ForEach(symbols, id: \.self) { symbol in
                Button {
                    icon = symbol
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(accent.background)
                            .overlay {
                                if icon == symbol {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.primary, lineWidth: 2.5)
                                }
                            }
                        
                        AppIcon(
                            systemName: symbol,
                            size: 24,
                            color: accent.foreground.opacity(icon == symbol ? 1.0 : 0.78)
                        )
                    }
                    .frame(height: tileHeight)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Icon")
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Group {
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
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(option.background)
                                        AppIcon(
                                            lucide: "paintbrush-vertical",
                                            size: 20,
                                            color: option.foreground
                                        )
                                    }
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
                        
                        Toggle(isOn: $applyColorToAll) {
                            Label("Apply to all", appIcon: "paintbrush", color: .primary)
                        }
                        .tint(appAccentColor)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(iconCategories) { category in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(category.title)
                                        .font(.appFootnote)
                                        .foregroundStyle(.secondary)
                                    
                                    iconGrid(for: category.symbols)
                                }
                            }
                        }
                    }
                }
                }
                .appDetailFieldBackground()
            }
            .appFormPageSpacing()
            .appDetailFormChrome()
            .navigationTitle("Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { onCancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    LiquidGlassIconButton(systemName: "checkmark") { onDone(applyColorToAll) }
                }
            }
        }
        .tint(.primary)
        .onAppear {
            applyColorToAll = true
        }
    }
}

private struct EventVisualsSectionHeader: ViewModifier {
    let isEditing: Bool
    
    func body(content: Content) -> some View {
        Section { content }
    }
}

