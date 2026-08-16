import SwiftUI

/// One-shot angular gradient glow used to highlight AI entry points on first appearance.
struct AIIntroGlowModifier: ViewModifier {
    var lineWidth: CGFloat = 2.2
    var plays: Bool = true
    
    @State private var active = false
    @State private var rotation: Double = 0
    @State private var pulse = false
    @State private var didStart = false
    
    func body(content: Content) -> some View {
        content
            .overlay {
                Capsule()
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                Color(hex: 0x5AC8FA),
                                Color(hex: 0x7B61FF),
                                Color(hex: 0xFF6BCB),
                                Color(hex: 0x5AC8FA),
                            ],
                            center: .center,
                            angle: .degrees(rotation)
                        ),
                        lineWidth: active ? lineWidth : 0
                    )
                    .opacity(active ? (pulse ? 1 : 0.55) : 0)
                    .allowsHitTesting(false)
            }
            .shadow(
                color: Color(hex: 0x7B61FF).opacity(active ? (pulse ? 0.45 : 0.22) : 0),
                radius: active ? (pulse ? 16 : 9) : 0
            )
            .onAppear { startIfNeeded() }
            .onChange(of: plays) { _, _ in startIfNeeded() }
    }
    
    private func startIfNeeded() {
        guard plays, !didStart else { return }
        didStart = true
        play()
    }
    
    private func play() {
        active = true
        pulse = false
        rotation = 0
        withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
            rotation = 360
        }
        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
            pulse = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            withAnimation(.easeOut(duration: 0.7)) {
                active = false
                pulse = false
            }
        }
    }
}

extension View {
    func aiIntroGlow(lineWidth: CGFloat = 2.2, plays: Bool = true) -> some View {
        modifier(AIIntroGlowModifier(lineWidth: lineWidth, plays: plays))
    }
}
