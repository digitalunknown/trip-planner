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
    let itineraryText: String
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
    
    private struct ToolbarIcon: View {
        let systemName: String
        
        var body: some View {
            Image(systemName: systemName)
                .font(.app(14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Trip Name", text: $draftName)
                        if !draftName.isEmpty {
                            Button {
                                draftName = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
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
                    Toggle("Set Dates", isOn: $draftIsDatesSet)
                        .tint(appAccentColor)
                    
                    if draftIsDatesSet {
                        DatePicker(
                            "Start date",
                            selection: $draftStartDate,
                            in: Date.distantPast...Date.distantFuture,
                            displayedComponents: .date
                        )
                        
                        DatePicker(
                            "End date",
                            selection: $draftEndDate,
                            in: draftStartDate...Date.distantFuture,
                            displayedComponents: .date
                        )
                    } else {
                        Stepper(value: $draftUnscheduledDaysCount, in: 1...30) {
                            HStack {
                                Text("Number of Days")
                                Spacer()
                                Text("\(draftUnscheduledDaysCount)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if let _ = totalCost {
                        Button {
                            showTotalCostsSheet = true
                        } label: {
                            HStack {
                                Text("Total Cost")
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
                                Text("Documents")
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
                                            Label("Choose from Unsplash", systemImage: "sparkles")
                                        }
                                        
                                        Button {
                                            showImagePicker = true
                                        } label: {
                                            Label("Choose from Photos", systemImage: "photo.on.rectangle")
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
                                Label("Choose from Unsplash", systemImage: "sparkles")
                            }
                            
                            Button {
                                showImagePicker = true
                            } label: {
                                Label("Choose from Photos", systemImage: "photo.on.rectangle")
                            }
                        } label: {
                            HStack {
                                Text("Add Cover Photo")
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Section {
                    Toggle("Show Ideas", isOn: $draftShowParkedIdeas)
                        .tint(appAccentColor)
                } footer: {
                    Text("Include an extra column for ideation not tied to a day")
                }
            }
            .navigationTitle(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Trip" : draftName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        Menu {
                            Button {
                                UIPasteboard.general.string = itineraryText
                                Haptics.bump()
                            } label: {
                                Text("Copy Itinerary")
                            }
                        } label: {
                            ToolbarIcon(systemName: "square.and.arrow.up")
                        }
                        .buttonStyle(.plain)
                        
                        LiquidGlassIconButton(
                            systemName: "checkmark",
                            isEnabled: !(draftName.isEmpty || draftLocation.isEmpty)
                        ) {
                            commitDraftsAndApply()
                        }
                    }
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
