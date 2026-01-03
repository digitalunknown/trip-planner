import SwiftUI
import MapKit
import UIKit

struct TripSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    @Binding var name: String
    @Binding var location: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var mapSpan: Double?
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var coverImageData: Data?
    @Binding var showParkedIdeas: Bool
    var onApply: () -> Void
    
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
                        text: $location,
                        latitude: $latitude,
                        longitude: $longitude,
                        mapSpan: $mapSpan,
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
                
                Section {
                    Toggle("Show Parked Ideas", isOn: $showParkedIdeas)
                        .tint(appAccentColor)
                } header: {
                    Text("Options")
                } footer: {
                    Text("An extra space for ideation")
                }
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
                        isEnabled: !(name.isEmpty || location.isEmpty)
                    ) {
                        coverImageData = coverImage?.jpegData(compressionQuality: 0.8)
                        onApply()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $coverImage)
                    .tint(.primary)
            }
            .onAppear {
                if let imageData = coverImageData {
                    coverImage = UIImage(data: imageData)
                }
            }
            .onChange(of: startDate) { _, newValue in
                if endDate < newValue {
                    endDate = newValue
                }
            }
        }
    }
}

