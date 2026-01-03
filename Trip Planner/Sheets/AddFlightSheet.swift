import SwiftUI
import MapKit

struct AddFlightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appAccentColor) private var appAccentColor
    
    @Binding var fromName: String
    @Binding var fromCode: String
    @Binding var fromCity: String
    @Binding var fromLatitude: Double?
    @Binding var fromLongitude: Double?
    @Binding var fromTerminal: String
    @Binding var fromGate: String
    
    @Binding var toName: String
    @Binding var toCode: String
    @Binding var toCity: String
    @Binding var toLatitude: Double?
    @Binding var toLongitude: Double?
    @Binding var toTerminal: String
    @Binding var toGate: String
    
    @Binding var flightNumber: String
    @Binding var notes: String
    @Binding var accent: EventAccent
    @Binding var startTime: Date
    @Binding var endTime: Date
    
    @Binding var selectedDayID: UUID?
    let dayOptions: [DayOption]
    
    var isEditing: Bool
    var onSave: () -> Void
    var onDelete: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Day", selection: $selectedDayID) {
                        ForEach(dayOptions) { option in
                            Text(option.title)
                                .tag(Optional(option.id))
                        }
                    }
                }
                
                Section("Departure") {
                    AirportSearchField(
                        title: "Location",
                        name: $fromName,
                        code: $fromCode,
                        city: $fromCity,
                        latitude: $fromLatitude,
                        longitude: $fromLongitude
                    )
                    airportCodeField(title: "Airport code", code: $fromCode)
                    clearableTextField(title: "Terminal", text: $fromTerminal, capitalization: .characters)
                    clearableTextField(title: "Gate", text: $fromGate, capitalization: .characters)
                    DatePicker("Time", selection: $startTime, displayedComponents: .hourAndMinute)
                }
                
                Section("Arrival") {
                    AirportSearchField(
                        title: "Location",
                        name: $toName,
                        code: $toCode,
                        city: $toCity,
                        latitude: $toLatitude,
                        longitude: $toLongitude
                    )
                    airportCodeField(title: "Airport code", code: $toCode)
                    clearableTextField(title: "Terminal", text: $toTerminal, capitalization: .characters)
                    clearableTextField(title: "Gate", text: $toGate, capitalization: .characters)
                    DatePicker("Time", selection: $endTime, in: startTime..., displayedComponents: .hourAndMinute)
                }
                
                Section("Flight number") {
                    clearableTextField(title: "Flight number", text: $flightNumber, capitalization: .characters)
                }
                
                Section("Visuals") {
                    ColorChips(selection: $accent)
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 90)
                }
                
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            onDelete?()
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Flight")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Flight" : "Add Flight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    LiquidGlassIconButton(
                        systemName: "checkmark",
                        isEnabled: selectedDayID != nil && (!fromName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !toName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    ) {
                        onSave()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if endTime < startTime { endTime = startTime }
            }
            .onChange(of: startTime) { _, newValue in
                if endTime < newValue { endTime = newValue }
            }
        }
        .tint(.primary)
    }
    
    private func airportCodeField(title: String, code: Binding<String>) -> some View {
        HStack {
            TextField(title, text: code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .onChange(of: code.wrappedValue) { _, newValue in
                    let cleaned = newValue
                        .uppercased()
                        .filter { $0.isLetter }
                    code.wrappedValue = String(cleaned.prefix(3))
                }
            
            if !code.wrappedValue.isEmpty {
                Button {
                    code.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func clearableTextField(
        title: String,
        text: Binding<String>,
        capitalization: TextInputAutocapitalization? = nil
    ) -> some View {
        HStack {
            TextField(title, text: text)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
            
            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

