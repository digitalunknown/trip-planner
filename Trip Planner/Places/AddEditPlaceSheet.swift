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
    
    @State private var name: String = ""
    @State private var location: String = ""
    @State private var note: String = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var placeType: PlaceType = .unspecified
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
                Group {
                Section {
                    LocationSearchField(
                        text: $location,
                        latitude: $latitude,
                        longitude: $longitude,
                        searchRegion: nil
                    )
                    .id("add-place-location")
                    
                    Label {
                        HStack {
                            TextField("Name", text: $name)
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
                    .id("add-place-name")
                    
                    Menu {
                        ForEach(PlaceType.allCases) { type in
                            Button {
                                placeType = type
                            } label: {
                                if type == placeType {
                                    Label(type.title, menuIcon: "checkmark")
                                } else {
                                    Text(type.title)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Label("Type", appIcon: "tag", color: .primary, iconTitleSpacing: 4)
                            Spacer(minLength: 8)
                            HStack(spacing: 5) {
                                Text(placeType.title)
                                    .font(.app(15, weight: .medium))
                                    .foregroundStyle(.primary)
                                AppIcon(lucide: "chevrons-up-down", size: AppLucide.fieldSize, color: AppColor.textWeak)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .tint(.primary)
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
                                Label("Choose from Unsplash", appIcon: "sparkles", color: .primary)
                            }
                            
                            Button {
                                showImagePicker = true
                            } label: {
                                Label("Choose from Photos", appIcon: "photo.on.rectangle", color: .primary)
                            }
                        } label: {
                            HStack {
                                Label("Add photo", appIcon: "image-plus", color: .primary)
                                Spacer()
                                AppIcon(lucide: "chevrons-up-down", size: AppLucide.fieldSize, color: AppColor.textWeak)
                            }
                        }
                        .tint(.primary)
                    }
                }
                }
                .appDetailFieldBackground()
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        AppSectionHeader("Notes")
                            .padding(.leading, 20)
                        
                        TextField("", text: $note, axis: .vertical)
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
            .appFormPageSpacing()
            .appDetailFormChrome()
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
        .tint(.primary)
    }
    
    private func loadIfNeeded() {
        guard case .edit(let place) = mode else { return }
        name = place.name
        location = place.location
        note = place.note
        latitude = place.latitude
        longitude = place.longitude
        placeType = place.placeType
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
                longitude: longitude,
                placeType: placeType
            )
            onSave(place)
        case .edit(var place):
            place.name = trimmedName
            place.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
            place.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            place.photoData = photoData
            place.latitude = latitude
            place.longitude = longitude
            place.placeType = placeType
            onSave(place)
        }
        dismiss()
    }
}
