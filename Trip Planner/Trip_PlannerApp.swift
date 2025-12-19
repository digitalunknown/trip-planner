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
    static func tabSelectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    static func bump() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
}
