//
//  NewTripView.swift
//  Trip Planner
//
//  Created by Piotr Osmenda on 12/18/25.
//

import SwiftUI
import MapKit

struct NewTripView: View {
    @Environment(\.dismiss) private var dismiss
    var tripStore: TripStore
    var onCreated: (UUID) -> Void = { _ in }
    
    @State private var name = ""
    @State private var destination = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var mapSpan: Double?
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(86400 * 4) // 5 days total
    @State private var coverImage: UIImage?
    @State private var showImagePicker = false
    
    var isValid: Bool {
        !name.isEmpty && !destination.isEmpty && endDate >= startDate
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
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        let newTrip = Trip(
                            name: name,
                            destination: destination,
                            startDate: startDate,
                            endDate: endDate,
                            latitude: latitude,
                            longitude: longitude,
                            mapSpan: mapSpan,
                            coverImageData: coverImage?.jpegData(compressionQuality: 0.8)
                        )
                        tripStore.addTrip(newTrip)
                        onCreated(newTrip.id)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                TripImagePicker(image: $coverImage)
                    .tint(.primary)
            }
        }
    }
}

#Preview {
    NewTripView(tripStore: TripStore())
}

