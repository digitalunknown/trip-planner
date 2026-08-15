import SwiftUI

/// Empty-state globe for Search / Trips / Places: earth base + two drifting cloud layers.
/// Single shared size so every empty state matches.
struct SearchGlobeIllustration: View {
    /// Full composition size (earth + overhanging clouds).
    private let canvasSize: CGFloat = 208
    /// Earth sits inside the canvas so side clouds can reach the left/right edges.
    private let globeSize: CGFloat = 176
    private let cloudWidth: CGFloat = 92
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            // Slow, out-of-phase drifts so the clouds don’t move in lockstep.
            let cloud1X = sin(t * 0.55) * 4
            let cloud2X = sin(t * 0.42 + 1.7) * 5
            
            // Outer tips of each cloud sit on the canvas left/right edges.
            let edgeX = canvasSize / 2
            let leftCloudBaseX = -edgeX + cloudWidth / 2
            let rightCloudBaseX = edgeX - cloudWidth / 2
            
            ZStack {
                Image("illustrations/earth")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: globeSize, height: globeSize)
                
                Image("illustrations/cloud-1")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: cloudWidth)
                    .offset(x: leftCloudBaseX + cloud1X, y: -globeSize * 0.04)
                
                Image("illustrations/cloud-2")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: cloudWidth * 0.92)
                    .offset(x: rightCloudBaseX + cloud2X, y: globeSize * 0.03)
            }
            .frame(width: canvasSize, height: canvasSize)
        }
        .frame(width: canvasSize, height: canvasSize)
        .accessibilityHidden(true)
    }
}
