import SwiftUI
import MapKit
import UIKit

struct AddEditPlaceSheet: View {
    enum Mode {
        case add
        case edit(Place)
    }
    
    let mode: Mode
    var onSave: (Place) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    
    @State private var name: String = ""
    @State private var location: String = ""
    @State private var note: String = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var photoImage: UIImage?
    @State private var showUnsplashPicker = false
    @State private var showImagePicker = false
    
    private var navigationTitle: String {
        switch mode {
        case .add: return "New Place"
        case .edit: return "Edit Place"
        }
    }
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var unsplashQuery: String {
        let loc = location.trimmingCharacters(in: .whitespacesAndNewlines)
        if !loc.isEmpty { return loc }
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    LocationSearchField(
                        text: $location,
                        latitude: $latitude,
                        longitude: $longitude,
                        searchRegion: nil
                    )
                }
                
                Section {
                    if let img = photoImage {
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
                                photoImage = nil
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
                                Text("Add Photo")
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Section {
                    TextField("Notes", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    LiquidGlassIconButton(systemName: "checkmark", isEnabled: canSave) {
                        save()
                    }
                }
            }
            .onAppear(perform: loadIfNeeded)
            .sheet(isPresented: $showImagePicker) {
                TripImagePicker(image: $photoImage)
                    .tint(.primary)
            }
            .sheet(isPresented: $showUnsplashPicker) {
                UnsplashCoverPickerSheet(initialQuery: unsplashQuery) { selection in
                    photoImage = UIImage(data: selection.imageData)
                }
                .presentationDetents([.large])
                .tint(.primary)
            }
        }
        .tint(appAccentColor)
    }
    
    private func loadIfNeeded() {
        guard case .edit(let place) = mode else { return }
        name = place.name
        location = place.location
        note = place.note
        latitude = place.latitude
        longitude = place.longitude
        if let data = place.photoData {
            photoImage = UIImage(data: data)
        }
    }
    
    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let photoData = photoImage?.jpegData(compressionQuality: 0.8)
        
        switch mode {
        case .add:
            let place = Place(
                name: trimmedName,
                location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                photoData: photoData,
                latitude: latitude,
                longitude: longitude
            )
            onSave(place)
        case .edit(var place):
            place.name = trimmedName
            place.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
            place.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            place.photoData = photoData
            place.latitude = latitude
            place.longitude = longitude
            onSave(place)
        }
        dismiss()
    }
}
