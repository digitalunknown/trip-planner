//
//  Trip_PlannerApp.swift
//  Trip Planner
//
//  Created by Piotr Osmenda on 12/16/25.
//

import SwiftUI
import UIKit

@main
struct Trip_PlannerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

enum Haptics {
    private static var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: "hapticsEnabled") == nil { return true }
        return UserDefaults.standard.bool(forKey: "hapticsEnabled")
    }
    
    static func tabSelectionChanged() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: 1.0)
    }
    
    static func bump() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
}
