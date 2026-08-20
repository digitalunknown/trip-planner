import SwiftUI

/// One-shot Border Beam glow used to highlight AI entry points on first appearance.
struct AIIntroGlowModifier: ViewModifier {
    var lineWidth: CGFloat = 1.5
    var plays: Bool = true
    var cornerRadius: CGFloat = 100 // Capsule-like by default
    
    @State private var active = false
    @State private var didStart = false
    
    func body(content: Content) -> some View {
        content
            .borderBeam(
                active: active,
                cornerRadius: cornerRadius,
                strength: 0.7,
                lineWidth: lineWidth
            )
            .onAppear { startIfNeeded() }
            .onChange(of: plays) { _, _ in startIfNeeded() }
    }
    
    private func startIfNeeded() {
        guard plays, !didStart else { return }
        didStart = true
        active = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            active = false
        }
    }
}

extension View {
    func aiIntroGlow(lineWidth: CGFloat = 1.5, plays: Bool = true, cornerRadius: CGFloat = 100) -> some View {
        modifier(AIIntroGlowModifier(lineWidth: lineWidth, plays: plays, cornerRadius: cornerRadius))
    }
}
