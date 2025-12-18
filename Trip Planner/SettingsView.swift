//
//  SettingsView.swift
//  Trip Planner
//
//  Created by Piotr Osmenda on 12/18/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    Label("Notifications", systemImage: "bell")
                    Label("Appearance", systemImage: "paintbrush")
                    Label("Default Calendar", systemImage: "calendar")
                }
                
                Section("Data") {
                    Label("Export Trips", systemImage: "square.and.arrow.up")
                    Label("Import Trips", systemImage: "square.and.arrow.down")
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}

