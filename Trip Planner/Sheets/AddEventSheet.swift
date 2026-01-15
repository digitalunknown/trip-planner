import SwiftUI
import MapKit
import UIKit

struct AddEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Binding var title: String
    @Binding var location: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var description: String
    @Binding var icon: String
    @Binding var accent: EventAccent
    @Binding var startTime: Date
    @Binding var endTime: Date
    @Binding var photo: UIImage?
    @Binding var selectedDayID: UUID?
    let dayOptions: [DayOption]
    let tripLocationRegion: MKCoordinateRegion?
    var onAdd: () -> Void
    var onDelete: (() -> Void)?
    var isEditing: Bool = false
    
    @State private var showImagePicker = false
    @State private var hasEndTime = false
    
    private var googleMapsURL: URL? {
        let loc = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !loc.isEmpty else { return nil }
        
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = t.isEmpty ? loc : "\(t) \(loc)"
        
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
    
    private var durationString: String? {
        let interval = endTime.timeIntervalSince(startTime)
        guard interval > 0 else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = interval >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .short
        return formatter.string(from: interval)
    }

    private let iconOptions: [String] = [
        "mappin.and.ellipse",
        
        "fork.knife",
        "cup.and.saucer.fill",
        "mug.fill",
        "wineglass.fill",
        
        "airplane",
        "car.fill",
        "bus.fill",
        "tram.fill",
        "train.side.front.car",
        "ferry.fill",
        "bicycle",
        "figure.walk",
        
        "cart.fill",
        "bag.fill",
        "duffle.bag.fill",
        "creditcard.fill",
        
        "bed.double.fill",
        "house.fill",
        "building.2.fill",
        "mountain.2.fill",
        "water.waves",
        "leaf.fill",
        "sun.max.fill",
        "sunrise",
        "sunset",
        "beach.umbrella.fill",
        "camera.fill",
        "ticket.fill",
        "theatermasks.fill",
        "movieclapper",
        "figure.hiking",
        "dumbbell.fill",
        "trophy.fill",
        "building.columns.fill",
        "airpods.max",
        "stroller.fill",
        "drone.fill",
        "sunglasses.fill",
        "shoe.fill",
        "tshirt.fill",
        "jacket.fill"
    ]
    
    private func deleteEvent() {
        onDelete?()
        dismiss()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Activity Name", text: $title)
                        if !title.isEmpty {
                            Button {
                                title = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    LocationSearchField(
                        text: $location,
                        latitude: $latitude,
                        longitude: $longitude,
                        searchRegion: tripLocationRegion
                    )
                }

                Section("Timing") {
                    Picker("Day", selection: $selectedDayID) {
                        ForEach(dayOptions) { option in
                            Text(option.title)
                                .tag(Optional(option.id))
                        }
                    }
                    DatePicker("From", selection: $startTime, displayedComponents: .hourAndMinute)
                    
                    Toggle("Add end time", isOn: $hasEndTime)
                        .tint(appAccentColor)
                        .onChange(of: hasEndTime) { _, newValue in
                            if !newValue {
                                endTime = startTime
                            } else if endTime <= startTime {
                                endTime = startTime.addingTimeInterval(60 * 60)
                            }
                        }
                    
                    if hasEndTime {
                        DatePicker("To", selection: $endTime, in: startTime..., displayedComponents: .hourAndMinute)
                    }
                    if let durationText = durationString {
                        Text("Duration: \(durationText)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Visuals") {
                    if let photoImage = photo {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: photoImage)
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
                                photo = nil
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
                                Text("Add Image")
                                Spacer()
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ColorChips(selection: $accent)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Icon")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        IconCarousel(
                            items: iconOptions,
                            selection: $icon,
                            accentColor: accent.color
                        )
                    }
                }
                
                Section("Notes") {
                    TextField("Notes", text: $description, axis: .vertical)
                        .lineLimit(3...12)
                        .textInputAutocapitalization(.sentences)
                }
                
                if isEditing {
                    if let url = googleMapsURL {
                        Section {
                            Link(destination: url) {
                                HStack {
                                    Label("Open in Google Maps", systemImage: "map")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    
                    Section {
                        Button(role: .destructive) {
                            deleteEvent()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Activity")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Activity" : "Add Activity")
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
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $photo)
                    .tint(.primary)
            }
            .onAppear {
                if isEditing {
                    hasEndTime = endTime > startTime
                } else {
                    hasEndTime = false
                    endTime = startTime
                }
            }
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
            .onChange(of: photo) { _, _ in if isEditing { onAdd() } }
            .onChange(of: startTime) { _, _ in if isEditing { onAdd() } }
            .onChange(of: endTime) { _, _ in if isEditing { onAdd() } }
            .onChange(of: selectedDayID) { _, _ in if isEditing { onAdd() } }
        }
    }
}

