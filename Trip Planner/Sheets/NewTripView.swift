import SwiftUI
import MapKit

struct NewTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    var tripStore: TripStore
    var onCreated: (UUID) -> Void = { _ in }
    
    @State private var name = ""
    @State private var destination = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var mapSpan: Double?
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(86400 * 4) // 5 days total
    @State private var isDatesSet: Bool = true
    @State private var unscheduledDaysCount: Int = 5
    @State private var coverImage: UIImage?
    @State private var pendingCoverImageData: Data?
    @State private var pendingCoverAttributionName: String?
    @State private var showImagePicker = false
    @State private var showUnsplashPicker = false
    @State private var showParkedIdeas: Bool = false
    
    var isValid: Bool {
        guard !name.isEmpty && !destination.isEmpty else { return false }
        if isDatesSet {
            return endDate >= startDate
        }
        return unscheduledDaysCount >= 1
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label {
                        HStack {
                            TextField("Trip Name", text: $name)
                            if !name.isEmpty {
                                Button {
                                    name = ""
                                } label: {
                                    AppIcon(systemName: "xmark.circle.fill", size: 16, color: .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } icon: {
                        AppIcon(lucide: "type", size: AppLucide.chromeSize, color: .primary)
                    }
                    LocationSearchField(
                        text: $destination,
                        latitude: $latitude,
                        longitude: $longitude,
                        mapSpan: $mapSpan,
                        resultTypes: .address
                    )
                }
                
                Section {
                    Toggle(isOn: $isDatesSet) {
                        Label("Set Dates", appIcon: "calendar-range", color: .primary)
                    }
                    .tint(appAccentColor)
                    
                    if isDatesSet {
                        DatePicker(
                            selection: $startDate,
                            in: Date.distantPast...Date.distantFuture,
                            displayedComponents: .date
                        ) {
                            Label("Start date", appIcon: "calendar", color: .primary)
                        }
                        
                        DatePicker(
                            selection: $endDate,
                            in: startDate...Date.distantFuture,
                            displayedComponents: .date
                        ) {
                            Label("End date", appIcon: "calendar-days", color: .primary)
                        }
                    } else {
                        Stepper(value: $unscheduledDaysCount, in: 1...30) {
                            HStack {
                                Label("Number of Days", appIcon: "hash", color: .primary)
                                Spacer()
                                Text("\(unscheduledDaysCount)")
                                    .foregroundStyle(.secondary)
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
                                            Label("Choose from Unsplash", appIcon: "sparkles", color: .primary)
                                        }
                                        
                                        Button {
                                            showImagePicker = true
                                        } label: {
                                            Label("Choose from Photos", appIcon: "photo.on.rectangle", color: .primary)
                                        }
                                    } label: {
                                        Color.clear
                                    }
                                    .buttonStyle(.plain)
                                }
                            
                            Button {
                                coverImage = nil
                                pendingCoverImageData = nil
                                pendingCoverAttributionName = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.appTitle)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.7))
                                    .shadow(radius: 2)
                            }
                            .buttonStyle(.plain)
                            .padding(12)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    } else {
                        Menu {
                            Button {
                                showUnsplashPicker = true
                            } label: {
                                Label("Choose from Unsplash", appIcon: "sparkles", color: .primary)
                            }
                            
                            Button {
                                showImagePicker = true
                            } label: {
                                Label("Choose from Photos", appIcon: "photo.on.rectangle", color: .primary)
                            }
                        } label: {
                            HStack {
                                Label("Add Cover Photo", appIcon: "image-plus", color: .primary)
                                Spacer()
                                AppIcon(systemName: "chevron.up.chevron.down", size: 14, color: .secondary)
                            }
                        }
                    }
                }
                
                Section {
                    Toggle(isOn: $showParkedIdeas) {
                        Label("Show Ideas", appIcon: "lightbulb", color: .primary)
                    }
                    .tint(appAccentColor)
                } footer: {
                    Text("Include an extra column for ideation not tied to a day")
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    LiquidGlassIconButton(systemName: "checkmark", isEnabled: isValid) {
                        let days: [TripDay] = {
                            guard !isDatesSet else { return [] }
                            let base = Calendar.current.startOfDay(for: Date())
                            return (0..<max(1, unscheduledDaysCount)).map { idx in
                                let d = Calendar.current.date(byAdding: .day, value: idx, to: base) ?? base
                                return TripDay(
                                    id: UUID(),
                                    date: d,
                                    events: [],
                                    reminders: [],
                                    checklists: [],
                                    flights: [],
                                    label: "Day \(idx + 1)",
                                    order: idx + 1,
                                    weatherIcon: "cloud.sun.fill",
                                    temperatureF: 72
                                )
                            }
                        }()
                        
                        let coverData = pendingCoverImageData ?? coverImage?.jpegData(compressionQuality: 0.8)
                        
                        let newTrip = Trip(
                            name: name,
                            destination: destination,
                            startDate: startDate,
                            endDate: endDate,
                            latitude: latitude,
                            longitude: longitude,
                            mapSpan: mapSpan,
                            isDatesSet: isDatesSet,
                            unscheduledDaysCount: unscheduledDaysCount,
                            days: days,
                            coverImageData: coverData,
                            showParkedIdeas: showParkedIdeas,
                            parkedIdeas: []
                        )
                        tripStore.addTrip(newTrip)
                        
                        // If no cover photo was chosen, automatically pick one from Unsplash.
                        if coverData == nil {
                            let tripID = newTrip.id
                            let query = destination.trimmingCharacters(in: .whitespacesAndNewlines)
                            Task.detached(priority: .utility) {
                                guard !query.isEmpty else { return }
                                
                                let client = UnsplashAPIClient()
                                guard let response = try? await client.searchPhotos(query: query, page: 1, perPage: 1),
                                      let photo = response.results.first,
                                      let urlString = photo.urls.regular ?? photo.urls.small,
                                      let url = URL(string: urlString) else { return }
                                
                                if let dl = photo.download_location {
                                    try? await client.trackDownload(downloadLocation: dl)
                                }
                                
                                guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
                                
                                await MainActor.run {
                                    guard let index = tripStore.trips.firstIndex(where: { $0.id == tripID }) else { return }
                                    // Don't overwrite if the user picked something meanwhile.
                                    guard tripStore.trips[index].coverImageData == nil else { return }
                                    var updated = tripStore.trips[index]
                                    updated.coverImageData = data
                                    tripStore.trips[index] = updated
                                    TripCoverAttribution.setName(photo.user.name, for: tripID)
                                    tripStore.save()
                                }
                            }
                        } else if let name = pendingCoverAttributionName {
                            TripCoverAttribution.setName(name, for: newTrip.id)
                        } else {
                            TripCoverAttribution.clear(for: newTrip.id)
                        }
                        onCreated(newTrip.id)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                TripImagePicker(image: Binding(
                    get: { coverImage },
                    set: { newImage in
                        coverImage = newImage
                        pendingCoverImageData = newImage?.jpegData(compressionQuality: 0.8)
                        pendingCoverAttributionName = nil
                    }
                ))
                    .tint(.primary)
            }
            .sheet(isPresented: $showUnsplashPicker) {
                UnsplashCoverPickerSheet(initialQuery: destination) { selection in
                    pendingCoverImageData = selection.imageData
                    coverImage = UIImage(data: selection.imageData)
                    pendingCoverAttributionName = selection.photographerName
                }
                .presentationDetents([.large])
                .tint(.primary)
            }
            .onChange(of: startDate) { _, newValue in
                if isDatesSet, endDate < newValue {
                    endDate = newValue
                }
            }
        }
        .tint(.primary)
    }
}

#Preview {
    NewTripView(tripStore: TripStore())
}

