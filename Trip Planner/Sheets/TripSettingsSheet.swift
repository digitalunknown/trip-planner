import SwiftUI
import MapKit
import UIKit

struct TripSettingsSheet: View {
    struct DocumentItem: Identifiable, Hashable {
        let id: String
        let activityID: UUID
        let activityTitle: String
        let dayLabel: String
        let isIdeas: Bool
        let document: EventDocument
    }
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Binding var name: String
    @Binding var location: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var mapSpan: Double?
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var isDatesSet: Bool
    @Binding var unscheduledDaysCount: Int
    @Binding var coverImageData: Data?
    let tripID: UUID
    @Binding var showParkedIdeas: Bool
    let costItems: [TotalCostsSheet.LineItem]
    let documentItems: [DocumentItem]
    var onApply: () -> Void
    
    /// Local drafts so typing doesn’t rewrite the live trip (and re-render trip detail) every keystroke.
    @State private var draftName: String = ""
    @State private var draftLocation: String = ""
    @State private var draftLatitude: Double?
    @State private var draftLongitude: Double?
    @State private var draftMapSpan: Double?
    @State private var draftStartDate: Date = Date()
    @State private var draftEndDate: Date = Date()
    @State private var draftIsDatesSet: Bool = true
    @State private var draftUnscheduledDaysCount: Int = 1
    @State private var draftShowParkedIdeas: Bool = true
    
    @State private var coverImage: UIImage?
    @State private var pendingCoverImageData: Data?
    @State private var showImagePicker = false
    @State private var showUnsplashPicker = false
    @State private var showTotalCostsSheet = false
    @State private var showActivityDocumentsSheet = false
    
    private var totalCost: Double? {
        guard !costItems.isEmpty else { return nil }
        return costItems.map(\.amount).reduce(0, +)
    }
    
    private var totalCostSummaryText: String {
        let grouped = Dictionary(grouping: costItems, by: \.currencyCode)
            .mapValues { $0.map(\.amount).reduce(0, +) }
        
        let sorted = grouped
            .map { (currencyCode: $0.key, total: $0.value) }
            .sorted { $0.currencyCode < $1.currencyCode }
        
        guard !sorted.isEmpty else { return "" }
        if sorted.count == 1, let first = sorted.first {
            return "\(CurrencyFormatting.string(for: first.total, currencyCode: first.currencyCode)) \(first.currencyCode)"
        }
        
        let shown = Array(sorted.prefix(2))
        let parts = shown.map { "\((CurrencyFormatting.string(for: $0.total, currencyCode: $0.currencyCode))) \($0.currencyCode)" }
        let extra = sorted.count - shown.count
        if extra > 0 {
            return parts.joined(separator: " • ") + " • +\(extra)"
        }
        return parts.joined(separator: " • ")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Group {
                Section {
                    Label {
                        HStack {
                            TextField("Trip name", text: $draftName)
                            if !draftName.isEmpty {
                                Button {
                                    draftName = ""
                                } label: {
                                    AppIcon(lucide: "circle-x", size: AppLucide.fieldSize, color: AppColor.textWeak)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } icon: {
                        AppIcon(lucide: "type", size: AppLucide.chromeSize, color: .primary)
                    }
                    LocationSearchField(
                        text: $draftLocation,
                        latitude: $draftLatitude,
                        longitude: $draftLongitude,
                        mapSpan: $draftMapSpan,
                        resultTypes: .address
                    )
                }

                Section {
                    Toggle(isOn: $draftIsDatesSet) {
                        Label("Set dates", appIcon: "calendar-plus")
                    }
                    .tint(appAccentColor)
                    
                    if draftIsDatesSet {
                        HStack {
                            Label("Start date", appIcon: "calendar")
                            Spacer(minLength: AppSpacing.xs)
                            DatePicker(
                                "",
                                selection: $draftStartDate,
                                in: Date.distantPast...Date.distantFuture,
                                displayedComponents: .date
                            )
                            .appCompactDateValue()
                            .accessibilityLabel("Start date")
                        }
                        
                        HStack {
                            Label("End date", appIcon: "calendar")
                            Spacer(minLength: AppSpacing.xs)
                            DatePicker(
                                "",
                                selection: $draftEndDate,
                                in: draftStartDate...Date.distantFuture,
                                displayedComponents: .date
                            )
                            .appCompactDateValue()
                            .accessibilityLabel("End date")
                        }
                    } else {
                        Stepper(value: $draftUnscheduledDaysCount, in: 1...30) {
                            HStack {
                                Label("Number of days", appIcon: "hash")
                                Spacer()
                                Text("\(draftUnscheduledDaysCount)")
                                    .font(.app(15, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if let _ = totalCost {
                        Button {
                            showTotalCostsSheet = true
                        } label: {
                            HStack {
                                Label("Total cost", appIcon: "wallet")
                                Spacer()
                                Text(totalCostSummaryText)
                                    .foregroundStyle(.primary)
                                    .monospacedDigit()
                            }
                        }
                    }
                    
                    if !documentItems.isEmpty {
                        Button {
                            showActivityDocumentsSheet = true
                        } label: {
                            HStack {
                                Label("Documents", appIcon: "files")
                                Spacer()
                                Text("\(documentItems.count)")
                                    .foregroundStyle(.primary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                
                Section {
                    if let img = coverImage {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipped()
                                .contentShape(Rectangle())
                                .overlay {
                                    Menu {
                                        Button {
                                            showUnsplashPicker = true
                                        } label: {
                                            Label("Choose from Unsplash", menuIcon: "sparkles")
                                        }
                                        
                                        Button {
                                            showImagePicker = true
                                        } label: {
                                            Label("Choose from Photos", menuIcon: "photo.on.rectangle")
                                        }
                                    } label: {
                                        Color.clear
                                    }
                                    .buttonStyle(.plain)
                                }
                            
                            LiquidGlassIconButton(systemName: "xmark", showsGlassBackground: true) {
                                coverImage = nil
                                pendingCoverImageData = nil
                                TripCoverAttribution.clear(for: tripID)
                            }
                            .padding(12)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    } else {
                        Menu {
                            Button {
                                showUnsplashPicker = true
                            } label: {
                                Label("Choose from Unsplash", menuIcon: "sparkles")
                            }
                            
                            Button {
                                showImagePicker = true
                            } label: {
                                Label("Choose from Photos", menuIcon: "photo.on.rectangle")
                            }
                        } label: {
                            HStack {
                                Text("Add cover photo")
                                Spacer()
                                AppIcon(lucide: "chevrons-up-down", size: AppLucide.fieldSize, color: AppColor.textWeak)
                            }
                        }
                    }
                }
                
                Section {
                    Toggle(isOn: $draftShowParkedIdeas) {
                        Label("Add extra ideas column", appIcon: "lightbulb")
                    }
                    .tint(appAccentColor)
                } footer: {
                    Text("The ideas column is not tied to a day and can be used to store activities on the side.")
                }
                }
                .appDetailFieldBackground()
            }
            .appFormPageSpacing()
            .appDetailFormChrome()
            .navigationTitle("Trip Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        commitDraftsAndApply()
                    } label: {
                        LiquidGlassToolbarIconLabel(systemName: "checkmark")
                    }
                    .liquidGlassToolbarControl()
                    .disabled(draftName.isEmpty || draftLocation.isEmpty)
                    .opacity(draftName.isEmpty || draftLocation.isEmpty ? 0.45 : 1)
                    .accessibilityLabel("Done")
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: Binding(
                    get: { coverImage },
                    set: { newImage in
                        coverImage = newImage
                        pendingCoverImageData = newImage?.jpegData(compressionQuality: 0.8)
                        TripCoverAttribution.clear(for: tripID)
                    }
                ))
                    .tint(.primary)
            }
            .sheet(isPresented: $showUnsplashPicker) {
                UnsplashCoverPickerSheet(initialQuery: draftLocation) { selection in
                    pendingCoverImageData = selection.imageData
                    coverImage = UIImage(data: selection.imageData)
                    TripCoverAttribution.setName(selection.photographerName, for: tripID)
                }
                .presentationDetents([.large])
                .tint(.primary)
            }
            .sheet(isPresented: $showTotalCostsSheet) {
                TotalCostsSheet(items: costItems)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showActivityDocumentsSheet) {
                ActivityDocumentsSheet(items: documentItems)
                    .presentationDetents([.medium, .large])
                    .tint(.primary)
            }
            .onAppear {
                loadDraftsFromBindings()
            }
            .onChange(of: draftStartDate) { _, newValue in
                if draftIsDatesSet, draftEndDate < newValue {
                    draftEndDate = newValue
                }
            }
        }
    }
    
    private func loadDraftsFromBindings() {
        draftName = name
        draftLocation = location
        draftLatitude = latitude
        draftLongitude = longitude
        draftMapSpan = mapSpan
        draftStartDate = startDate
        draftEndDate = endDate
        draftIsDatesSet = isDatesSet
        draftUnscheduledDaysCount = unscheduledDaysCount
        draftShowParkedIdeas = showParkedIdeas
        
        if let imageData = coverImageData {
            coverImage = UIImage(data: imageData)
            pendingCoverImageData = imageData
        } else {
            coverImage = nil
            pendingCoverImageData = nil
        }
    }
    
    private func commitDraftsAndApply() {
        name = draftName
        location = draftLocation
        latitude = draftLatitude
        longitude = draftLongitude
        mapSpan = draftMapSpan
        startDate = draftStartDate
        endDate = draftEndDate
        isDatesSet = draftIsDatesSet
        unscheduledDaysCount = draftUnscheduledDaysCount
        showParkedIdeas = draftShowParkedIdeas
        coverImageData = pendingCoverImageData ?? coverImage?.jpegData(compressionQuality: 0.8)
        onApply()
        dismiss()
    }
}
