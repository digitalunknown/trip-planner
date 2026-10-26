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
    @State private var addPlaceholders: Bool = false
    
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
                Group {
                Section {
                    Label {
                        HStack {
                            TextField("Trip name", text: $name)
                            if !name.isEmpty {
                                Button {
                                    name = ""
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
                        text: $destination,
                        latitude: $latitude,
                        longitude: $longitude,
                        mapSpan: $mapSpan,
                        resultTypes: .address
                    )
                }
                
                Section {
                    Toggle(isOn: $isDatesSet) {
                        Label("Set dates", appIcon: "calendar-plus", color: .primary)
                    }
                    .tint(appAccentColor)
                    
                    if isDatesSet {
                        HStack {
                            Label("Start date", appIcon: "calendar", color: .primary)
                            Spacer(minLength: AppSpacing.xs)
                            DatePicker(
                                "",
                                selection: $startDate,
                                in: Date.distantPast...Date.distantFuture,
                                displayedComponents: .date
                            )
                            .appCompactDateValue()
                            .accessibilityLabel("Start date")
                        }
                        
                        HStack {
                            Label("End date", appIcon: "calendar", color: .primary)
                            Spacer(minLength: AppSpacing.xs)
                            DatePicker(
                                "",
                                selection: $endDate,
                                in: startDate...Date.distantFuture,
                                displayedComponents: .date
                            )
                            .appCompactDateValue()
                            .accessibilityLabel("End date")
                        }
                    } else {
                        Stepper(value: $unscheduledDaysCount, in: 1...30) {
                            HStack {
                                Label("Number of days", appIcon: "hash", color: .primary)
                                Spacer()
                                Text("\(unscheduledDaysCount)")
                                    .font(.app(15, weight: .medium))
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
                                Label("Add cover photo", appIcon: "image-plus", color: .primary)
                                Spacer()
                                AppIcon(lucide: "chevrons-up-down", size: AppLucide.fieldSize, color: AppColor.textWeak)
                            }
                        }
                    }
                }
                
                Section {
                    Toggle(isOn: $showParkedIdeas) {
                        Label("Add extra ideas column", appIcon: "lightbulb", color: .primary)
                    }
                    .tint(appAccentColor)
                    
                    Toggle(isOn: $addPlaceholders) {
                        Label("Add placeholders", appIcon: "square-dashed-text", color: .primary)
                    }
                    .tint(appAccentColor)
                } footer: {
                    Text("The ideas column is not tied to a day and can be used to store activities on the side. Add placeholders starts the trip with a Packing checklist, a flight on the first and last day, and breakfast, lunch, and dinner on every day.")
                }
                }
                .appDetailFieldBackground()
            }
            .appFormPageSpacing()
            .appDetailFormChrome()
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    LiquidGlassIconButton(systemName: "checkmark", isEnabled: isValid) {
                        let days = makeInitialDays()
                        
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
    
    private func makeInitialDays() -> [TripDay] {
        let calendar = Calendar.current
        let dayCount: Int
        let base: Date
        if isDatesSet {
            let start = calendar.startOfDay(for: startDate)
            let end = calendar.startOfDay(for: max(endDate, startDate))
            dayCount = max(1, (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
            base = start
        } else {
            dayCount = max(1, unscheduledDaysCount)
            base = calendar.startOfDay(for: Date())
        }
        
        guard addPlaceholders || !isDatesSet else { return [] }
        
        let accent = EventAccent.allCases.randomElement() ?? .cream
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        
        func clock(hour: Int, minute: Int, on day: Date) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        
        func mealTime(startHour: Int, endHour: Int, on day: Date) -> String {
            let start = clock(hour: startHour, minute: 0, on: day)
            let end = clock(hour: endHour, minute: 0, on: day)
            return "\(timeFormatter.string(from: start)) - \(timeFormatter.string(from: end))"
        }
        
        func meal(title: String, icon: String, startHour: Int, endHour: Int, on day: Date) -> EventItem {
            EventItem(
                title: title,
                description: "",
                time: mealTime(startHour: startHour, endHour: endHour, on: day),
                location: "",
                latitude: nil,
                longitude: nil,
                icon: icon,
                accent: accent,
                photoData: nil
            )
        }
        
        return (0..<dayCount).map { idx in
            let date = calendar.date(byAdding: .day, value: idx, to: base) ?? base
            var events: [EventItem] = []
            var checklists: [ChecklistItem] = []
            var flights: [FlightItem] = []
            
            if addPlaceholders {
                events = [
                    meal(title: "Breakfast", icon: "coffee", startHour: 8, endHour: 9, on: date),
                    meal(title: "Lunch", icon: "utensils", startHour: 12, endHour: 13, on: date),
                    meal(title: "Dinner", icon: "utensils", startHour: 19, endHour: 20, on: date)
                ]
                if idx == 0 {
                    checklists.append(
                        ChecklistItem(
                            id: UUID(),
                            title: "Packing",
                            items: (1...5).map { index in
                                ChecklistEntry(id: UUID(), text: "Item \(index)", isDone: false)
                            },
                            createdAt: Date()
                        )
                    )
                    flights.append(
                        FlightItem(
                            accent: accent,
                            startTime: clock(hour: 9, minute: 0, on: date),
                            endTime: clock(hour: 11, minute: 0, on: date)
                        )
                    )
                }
                if idx == dayCount - 1 {
                    flights.append(
                        FlightItem(
                            accent: accent,
                            startTime: clock(hour: 16, minute: 0, on: date),
                            endTime: clock(hour: 18, minute: 0, on: date)
                        )
                    )
                }
            }
            
            return TripDay(
                id: UUID(),
                date: date,
                events: events,
                reminders: [],
                checklists: checklists,
                flights: flights,
                label: "Day \(idx + 1)",
                order: idx + 1,
                weatherIcon: "cloud.sun.fill",
                temperatureF: 72
            )
        }
    }
}

#Preview {
    NewTripView(tripStore: TripStore())
}

