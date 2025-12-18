//
//  MyTripsView.swift
//  Trip Planner
//
//  Created by Piotr Osmenda on 12/18/25.
//

import SwiftUI
import MapKit

struct MyTripsView: View {
    @State private var tripStore = TripStore()
    @State private var showingNewTrip = false
    @State private var showingSettings = false
    @State private var navigationPath = NavigationPath()
    @State private var editingTrip: Trip?
    @State private var tripForImagePicker: Trip?
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    
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
            .navigationTitle("My Trips")
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
                    HStack(spacing: 12) {
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
            }
            .sheet(isPresented: $showingNewTrip) {
                NewTripView(tripStore: tripStore)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(item: $editingTrip) { trip in
                if let index = tripStore.trips.firstIndex(where: { $0.id == trip.id }) {
                    EditTripView(trip: Binding(
                        get: { tripStore.trips[index] },
                        set: { newValue in
                            tripStore.trips[index] = newValue
                            tripStore.save()
                        }
                    ))
                }
            }
            .sheet(isPresented: $showImagePicker) {
                TripImagePicker(image: $selectedImage)
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
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Illustration
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
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(tripStore.trips) { trip in
                    Button {
                        navigationPath.append(trip.id)
                    } label: {
                        TripCardView(trip: trip)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            tripForImagePicker = trip
                            showImagePicker = true
                        } label: {
                            Label("Add Image", systemImage: "photo.badge.plus")
                        }
                        
                        Button {
                            editingTrip = trip
                        } label: {
                            Label("Edit Trip", systemImage: "pencil")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            withAnimation {
                                tripStore.deleteTrip(trip)
                            }
                        } label: {
                            Label("Delete Trip", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// Image picker for trip cover
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

// Edit Trip View
struct EditTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var trip: Trip
    
    @State private var name: String = ""
    @State private var destination: String = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var coverImage: UIImage?
    @State private var showImagePicker = false
    
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
                        resultTypes: .address
                    )
                }
                
                Section("Dates") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
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
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveTrip()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty || destination.isEmpty)
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
                startDate = trip.startDate
                endDate = trip.endDate
                if let imageData = trip.coverImageData {
                    coverImage = UIImage(data: imageData)
                }
            }
        }
    }
    
    private func saveTrip() {
        trip.name = name
        trip.destination = destination
        trip.latitude = latitude
        trip.longitude = longitude
        trip.startDate = startDate
        trip.endDate = endDate
        trip.coverImageData = coverImage?.jpegData(compressionQuality: 0.8)
    }
}

#Preview {
    MyTripsView()
}

