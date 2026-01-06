//
//  MyTripsView.swift
//  Trip Planner
//
//  Created by Piotr Osmenda on 12/18/25.
//

import SwiftUI
import MapKit

struct MyTripsView: View {
    private enum TripSegment: String, CaseIterable, Identifiable {
        case upcoming = "Upcoming"
        case past = "Past"
        case unscheduled = "Unscheduled"
        var id: String { rawValue }
    }
    
    @Environment(TripStore.self) private var tripStore
    @State private var showingNewTrip = false
    @State private var showingSettings = false
    @State private var navigationPath = NavigationPath()
    @State private var pendingNewTripID: UUID?
    @State private var editingTrip: Trip?
    @State private var tripForImagePicker: Trip?
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var selectedSegment: TripSegment = .upcoming
    @State private var segmentSwitchInFlight: Bool = false
    @State private var tripPendingDelete: Trip?
    
    private func availableSegments(for trips: [Trip]) -> [TripSegment] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let unscheduledCount = trips.filter { !$0.isDatesSet }.count
        let upcomingCount = trips.filter { trip in
            guard trip.isDatesSet else { return false }
            return calendar.startOfDay(for: trip.endDate) >= today
        }.count
        let pastCount = trips.filter { trip in
            guard trip.isDatesSet else { return false }
            return calendar.startOfDay(for: trip.endDate) < today
        }.count
        
        var segs: [TripSegment] = []
        if upcomingCount > 0 { segs.append(.upcoming) }
        if pastCount > 0 { segs.append(.past) }
        if unscheduledCount > 0 { segs.append(.unscheduled) }
        return segs
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if tripStore.trips.isEmpty {
                    emptyStateView
                } else {
                    tripListView
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Trips")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: UUID.self) { tripID in
                if let index = tripStore.trips.firstIndex(where: { $0.id == tripID }) {
                    TripDetailView(trip: Binding(
                        get: { tripStore.trips[index] },
                        set: { newValue in
                            tripStore.trips[index] = newValue
                            tripStore.save()
                        }
                    ))
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .fontWeight(.medium)
                    }
                    
                    Button {
                        showingNewTrip = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.medium)
                    }
                }
            }
            .sheet(isPresented: $showingNewTrip) {
                NewTripView(tripStore: tripStore) { newTripID in
                    pendingNewTripID = newTripID
                }
                .tint(.primary)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .tint(.primary)
            }
            .sheet(item: $editingTrip) { trip in
                if let index = tripStore.trips.firstIndex(where: { $0.id == trip.id }) {
                    EditTripView(
                        trip: Binding(
                            get: { tripStore.trips[index] },
                            set: { newValue in
                                tripStore.trips[index] = newValue
                                tripStore.save()
                            }
                        ),
                        onDelete: {
                            withAnimation {
                                tripStore.deleteTrip(trip)
                            }
                        }
                    )
                    .tint(.primary)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                TripImagePicker(image: $selectedImage)
                    .tint(.primary)
            }
            .alert(
                "Delete Trip",
                isPresented: Binding(
                    get: { tripPendingDelete != nil },
                    set: { if !$0 { tripPendingDelete = nil } }
                ),
                presenting: tripPendingDelete
            ) { trip in
                Button("Delete Trip", role: .destructive) {
                    withAnimation {
                        tripStore.deleteTrip(trip)
                    }
                    tripPendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    tripPendingDelete = nil
                }
            } message: { _ in
                Text("Are you sure you want to delete this trip? This action cannot be undone.")
            }
            .onChange(of: selectedImage) { _, newImage in
                if let image = newImage,
                   let tripToUpdate = tripForImagePicker,
                   let index = tripStore.trips.firstIndex(where: { $0.id == tripToUpdate.id }) {
                    tripStore.trips[index].coverImageData = image.jpegData(compressionQuality: 0.8)
                    tripStore.save()
                    selectedImage = nil
                    tripForImagePicker = nil
                }
            }
            .onChange(of: showingNewTrip) { _, isPresented in
                if !isPresented, let id = pendingNewTripID {
                    pendingNewTripID = nil
                    navigationPath.append(id)
                }
            }
        }
        .tint(.primary)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)
                
                Image(systemName: "airplane.departure")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text("No Trips Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Start planning your next adventure!\nTap the button below to create your first trip.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button {
                showingNewTrip = true
            } label: {
                Text("Create Trip")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var tripListView: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let segments = availableSegments(for: tripStore.trips)
        let effectiveSegment = segments.contains(selectedSegment) ? selectedSegment : (segments.first ?? .upcoming)
        
        let filteredTrips: [Trip] = tripStore.trips
            .filter { trip in
                switch effectiveSegment {
                case .upcoming:
                    guard trip.isDatesSet else { return false }
                    let end = calendar.startOfDay(for: trip.endDate)
                    return end >= today
                case .past:
                    guard trip.isDatesSet else { return false }
                    let end = calendar.startOfDay(for: trip.endDate)
                    return end < today
                case .unscheduled:
                    return !trip.isDatesSet
                }
            }
            .sorted { a, b in
                switch effectiveSegment {
                case .upcoming:
                    return a.startDate < b.startDate
                case .past:
                    return a.startDate > b.startDate
                case .unscheduled:
                    // Best-effort "newest first" without a createdAt field.
                    return a.id.uuidString > b.id.uuidString
                }
            }
        
        let groupedTrips = Dictionary(grouping: filteredTrips) { trip in
            Calendar.current.component(.year, from: trip.startDate)
        }
        let sortedYears = groupedTrips.keys.sorted(by: { a, b in
            switch selectedSegment {
            case .upcoming, .unscheduled:
                return a < b
            case .past:
                return a > b
            }
        })
        
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 20, pinnedViews: []) {
                    Color.clear
                        .frame(height: 1)
                        .id("top")
                    
                    if segments.count > 1 {
                        Picker("", selection: $selectedSegment) {
                            ForEach(segments) { seg in
                                Text(seg.rawValue).tag(seg)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.top, 4)
                        .padding(.bottom, 6)
                        .zIndex(10)
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            TapGesture().onEnded {
                                segmentSwitchInFlight = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    segmentSwitchInFlight = false
                                }
                            }
                        )
                    }
                
                    if filteredTrips.isEmpty {
                        ContentUnavailableView(
                            selectedSegment == .past ? "No Past Trips" : (selectedSegment == .unscheduled ? "No Unscheduled Trips" : "No Upcoming Trips"),
                            systemImage: selectedSegment == .past ? "clock.arrow.circlepath" : (selectedSegment == .unscheduled ? "square.and.pencil" : "calendar"),
                            description: Text(selectedSegment == .past ? "Trips you’ve completed will show up here." : (selectedSegment == .unscheduled ? "Trips without dates will show up here." : "Trips that are coming up (or in progress) will show up here."))
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 36)
                    } else {
                        if selectedSegment == .unscheduled {
                            ForEach(filteredTrips) { trip in
                                Button {
                                    navigationPath.append(trip.id)
                                } label: {
                                    TripCardView(trip: trip)
                                }
                                .buttonStyle(.plain)
                                .allowsHitTesting(!segmentSwitchInFlight)
                                .contextMenu {
                                    Button {
                                        navigationPath.append(trip.id)
                                    } label: {
                                        Label("View Trip", systemImage: "arrow.right.circle")
                                    }
                                    
                                    Divider()
                                    
                                    Button {
                                        tripForImagePicker = trip
                                        showImagePicker = true
                                    } label: {
                                        Label("Add Cover Image", systemImage: "photo.badge.plus")
                                    }
                                    
                                    Button {
                                        editingTrip = trip
                                    } label: {
                                        Label("Edit Trip", systemImage: "pencil")
                                    }
                                    
                                    Divider()
                                    
                                    Button(role: .destructive) {
                                        tripPendingDelete = trip
                                    } label: {
                                        Label("Delete Trip", systemImage: "trash")
                                    }
                                }
                            }
                        } else {
                            ForEach(sortedYears, id: \.self) { year in
                                Section {
                                    let tripsForYear = (groupedTrips[year] ?? []).sorted { a, b in
                                        switch selectedSegment {
                                        case .upcoming:
                                            return a.startDate < b.startDate
                                        case .past:
                                            return a.startDate > b.startDate
                                        case .unscheduled:
                                            return a.id.uuidString > b.id.uuidString
                                        }
                                    }
                                    
                                    ForEach(tripsForYear) { trip in
                                    Button {
                                        navigationPath.append(trip.id)
                                    } label: {
                                        TripCardView(trip: trip)
                                    }
                                    .buttonStyle(.plain)
                                    .allowsHitTesting(!segmentSwitchInFlight)
                                    .contextMenu {
                                        Button {
                                            navigationPath.append(trip.id)
                                        } label: {
                                            Label("View Trip", systemImage: "arrow.right.circle")
                                        }
                                        
                                        Divider()
                                        
                                        Button {
                                            tripForImagePicker = trip
                                            showImagePicker = true
                                        } label: {
                                            Label("Add Cover Image", systemImage: "photo.badge.plus")
                                        }
                                        
                                        Button {
                                            editingTrip = trip
                                        } label: {
                                            Label("Edit Trip", systemImage: "pencil")
                                        }
                                        
                                        Divider()
                                        
                                        Button(role: .destructive) {
                                            tripPendingDelete = trip
                                        } label: {
                                            Label("Delete Trip", systemImage: "trash")
                                        }
                                    }
                                }
                            } header: {
                                HStack {
                                    Text(String(year))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.top, year == sortedYears.first ? 0 : 8)
                            }
                        }
                        }
                    }
                    
                    Spacer(minLength: 12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .onAppear {
                if !segments.contains(selectedSegment), let first = segments.first {
                    selectedSegment = first
                }
            }
            .onChange(of: tripStore.trips) { _, _ in
                let updated = availableSegments(for: tripStore.trips)
                if !updated.contains(selectedSegment), let first = updated.first {
                    selectedSegment = first
                }
            }
            .onChange(of: selectedSegment) { _, _ in
                Haptics.bump()
                segmentSwitchInFlight = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withTransaction(Transaction(animation: nil)) {
                        proxy.scrollTo("top", anchor: .top)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                        segmentSwitchInFlight = false
                    }
                }
            }
        }
    }
}

struct TripImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: TripImagePicker
        
        init(_ parent: TripImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct EditTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Binding var trip: Trip
    var onDelete: () -> Void
    
    @State private var name: String = ""
    @State private var destination: String = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var mapSpan: Double?
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var isDatesSet: Bool = true
    @State private var unscheduledDaysCount: Int = 5
    @State private var coverImage: UIImage?
    @State private var showImagePicker = false
    @State private var showDeleteConfirmation = false
    @State private var showParkedIdeas: Bool = false
    @State private var originalIsDatesSet: Bool = true
    @State private var originalDaysSnapshot: [TripDay] = []
    @State private var showConvertDatesDropAlert: Bool = false
    @State private var pendingDroppedCounts: (activities: Int, reminders: Int, checklists: Int, flights: Int) = (0, 0, 0, 0)
    
    private var isValid: Bool {
        guard !(name.isEmpty || destination.isEmpty) else { return false }
        if isDatesSet {
            return endDate >= startDate
        }
        return unscheduledDaysCount >= 1
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    HStack {
                        TextField("Trip Name", text: $name)
                        if !name.isEmpty {
                            Button {
                                name = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    LocationSearchField(
                        text: $destination,
                        latitude: $latitude,
                        longitude: $longitude,
                        mapSpan: $mapSpan,
                        resultTypes: .address
                    )
                }
                
                Section("Dates") {
                    Toggle("Set Dates", isOn: $isDatesSet)
                        .tint(appAccentColor)
                    
                    if isDatesSet {
                        DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                    } else {
                        Stepper(value: $unscheduledDaysCount, in: 1...30) {
                            HStack {
                                Text("Number of Days")
                                Spacer()
                                Text("\(unscheduledDaysCount)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Section("Cover Image") {
                    if let img = coverImage {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    showImagePicker = true
                                }
                            
                            Button {
                                coverImage = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.7))
                                    .shadow(radius: 2)
                            }
                            .buttonStyle(.plain)
                            .padding(12)
                        }
                    } else {
                        Button {
                            showImagePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                Text("Add Cover Image")
                                Spacer()
                            }
                        }
                    }
                }
                
                Section {
                    Toggle("Show Parked Ideas", isOn: $showParkedIdeas)
                        .tint(appAccentColor)
                } header: {
                    Text("Options")
                } footer: {
                    Text("An extra space for ideation")
                }
                
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Trip")
                            Spacer()
                        }
                    }
                }
            }
            .confirmationDialog("Delete Trip", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this trip? This action cannot be undone.")
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    LiquidGlassIconButton(
                        systemName: "checkmark",
                        isEnabled: isValid
                    ) {
                        attemptSaveTrip()
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                TripImagePicker(image: $coverImage)
            }
            .onAppear {
                name = trip.name
                destination = trip.destination
                latitude = trip.latitude
                longitude = trip.longitude
                mapSpan = trip.mapSpan
                startDate = trip.startDate
                endDate = trip.endDate
                isDatesSet = trip.isDatesSet
                unscheduledDaysCount = trip.unscheduledDaysCount
                showParkedIdeas = trip.showParkedIdeas
                originalIsDatesSet = trip.isDatesSet
                originalDaysSnapshot = trip.days
                if let imageData = trip.coverImageData {
                    coverImage = UIImage(data: imageData)
                }
            }
            .onChange(of: startDate) { _, newValue in
                if isDatesSet, endDate < newValue {
                    endDate = newValue
                }
            }
            .presentationDetents([.large])
        }
        .alert("Shorter date range", isPresented: $showConvertDatesDropAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove & Convert", role: .destructive) {
                saveTrip(applyDropOnConvert: true)
                dismiss()
            }
        } message: {
            Text("This date range is shorter and will remove items from days that no longer fit.\n\n\(pendingDroppedCounts.activities) activities, \(pendingDroppedCounts.reminders) reminders, \(pendingDroppedCounts.checklists) checklists, \(pendingDroppedCounts.flights) flights.")
        }
    }
    
    private func attemptSaveTrip() {
        // Conversion: unscheduled -> scheduled (map by day index).
        if originalIsDatesSet == false, isDatesSet {
            let calendar = Calendar.current
            let totalDays = max(1, (calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1)
            
            if originalDaysSnapshot.count > totalDays {
                let dropped = originalDaysSnapshot.suffix(from: totalDays)
                let activities = dropped.map { $0.events.count }.reduce(0, +)
                let reminders = dropped.map { $0.reminders.count }.reduce(0, +)
                let checklists = dropped.map { $0.checklists.count }.reduce(0, +)
                let flights = dropped.map { $0.flights.count }.reduce(0, +)
                pendingDroppedCounts = (activities, reminders, checklists, flights)
                showConvertDatesDropAlert = true
                return
            }
        }
        
        saveTrip(applyDropOnConvert: false)
        dismiss()
    }
    
    private func saveTrip(applyDropOnConvert: Bool) {
        trip.name = name
        trip.destination = destination
        trip.latitude = latitude
        trip.longitude = longitude
        trip.mapSpan = mapSpan
        trip.startDate = startDate
        trip.endDate = endDate
        trip.isDatesSet = isDatesSet
        trip.unscheduledDaysCount = max(1, unscheduledDaysCount)
        trip.coverImageData = coverImage?.jpegData(compressionQuality: 0.8)
        trip.showParkedIdeas = showParkedIdeas
        
        if originalIsDatesSet == false, isDatesSet {
            let calendar = Calendar.current
            let totalDays = max(1, (calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1)
            let oldDays = applyDropOnConvert ? Array(originalDaysSnapshot.prefix(totalDays)) : originalDaysSnapshot
            
            var newDays: [TripDay] = []
            newDays.reserveCapacity(totalDays)
            
            for offset in 0..<totalDays {
                let date = calendar.date(byAdding: .day, value: offset, to: startDate) ?? startDate
                if offset < oldDays.count {
                    let existing = oldDays[offset]
                    let updated = TripDay(
                        id: existing.id,
                        date: date,
                        events: existing.events,
                        reminders: existing.reminders,
                        checklists: existing.checklists,
                        flights: existing.flights,
                        label: "Day \(offset + 1)",
                        order: offset + 1,
                        weatherIcon: existing.weatherIcon,
                        temperatureF: existing.temperatureF
                    )
                    newDays.append(updated)
                } else {
                    let emptyDay = TripDay(
                        id: UUID(),
                        date: date,
                        events: [],
                        reminders: [],
                        checklists: [],
                        flights: [],
                        label: "Day \(offset + 1)",
                        order: offset + 1,
                        weatherIcon: "cloud.sun.fill",
                        temperatureF: 72
                    )
                    newDays.append(emptyDay)
                }
            }
            
            trip.days = newDays
        }
    }
}

#Preview {
    Group {
        MyTripsView()
    }
    .environment(TripStore())
}

