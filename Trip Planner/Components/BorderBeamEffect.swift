import SwiftUI

/// Traveling border-beam glow matching [Border Beam](https://beam.jakubantalik.com) (Rotate · Colorful).
/// Drawn with inset `strokeBorder` so the beam sits on top of solid fills, inside the corner radius.
struct BorderBeamEffect: View {
    var cornerRadius: CGFloat = 24
    var active: Bool = true
    var strength: Double = 0.7
    var duration: Double = 1.96
    var lineWidth: CGFloat = 2
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var opacity: Double = 0
    @State private var hueOffset: Double = -30
    @State private var didStartHue = false
    
    private var isDark: Bool { colorScheme == .dark }
    
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: !active && opacity < 0.01)) { timeline in
            let angle = rotationAngle(date: timeline.date)
            let gradient = AngularGradient(
                gradient: makeBeamGradient(),
                center: .center,
                angle: .degrees(angle)
            )
            
            ZStack {
                // Soft bloom — inset so it never sits behind the solid fill.
                shape
                    .strokeBorder(gradient, lineWidth: lineWidth * 5)
                    .blur(radius: 5)
                    .opacity(isDark ? 0.85 : 0.55)
                
                shape
                    .strokeBorder(gradient, lineWidth: lineWidth * 2.5)
                    .blur(radius: 2)
                    .opacity(isDark ? 0.7 : 0.45)
                
                // Crisp traveling beam on the border.
                shape
                    .strokeBorder(gradient, lineWidth: lineWidth)
                    .opacity(isDark ? 0.95 : 0.8)
            }
        }
        .compositingGroup()
        .clipShape(shape)
        .opacity(opacity * strength)
        .hueRotation(.degrees(hueOffset))
        .allowsHitTesting(false)
        .onAppear { syncActive(active, animated: false) }
        .onChange(of: active) { _, newValue in syncActive(newValue, animated: true) }
    }
    
    private func syncActive(_ isActive: Bool, animated: Bool) {
        let duration = isActive ? 0.6 : 0.5
        let apply = {
            opacity = isActive ? 1 : 0
        }
        if animated {
            withAnimation(isActive ? .easeOut(duration: duration) : .easeIn(duration: duration), apply)
        } else {
            apply()
        }
        guard isActive, !didStartHue else { return }
        didStartHue = true
        withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
            hueOffset = 30
        }
    }
    
    /// Beam window: dead zone → tail → bright head → fade (matches border-beam CSS mask).
    private func makeBeamGradient() -> Gradient {
        let colors = colorfulStops
        let n = colors.count
        var stops: [Gradient.Stop] = [
            .init(color: .clear, location: 0.00),
            .init(color: .clear, location: 0.30),
        ]
        
        for i in 0..<n {
            let t = Double(i) / Double(max(n - 1, 1))
            let loc = 0.30 + t * 0.50
            let envelope = beamEnvelope(at: loc)
            stops.append(.init(color: colors[i].opacity(envelope), location: loc))
        }
        
        let spark = isDark ? Color.white.opacity(0.70) : Color.black.opacity(0.35)
        stops.append(.init(color: spark.opacity(beamEnvelope(at: 0.66)), location: 0.66))
        stops.append(.init(color: .clear, location: 0.95))
        stops.append(.init(color: .clear, location: 1.00))
        
        return Gradient(stops: stops.sorted { $0.location < $1.location })
    }
    
    private func beamEnvelope(at loc: Double) -> Double {
        let tailStart = 0.30, tailEnd = 0.52
        let headEnd = 0.80, fadeEnd = 0.95
        let peakOpacity = 0.90
        let peakBump = 0.10
        
        if loc <= tailStart { return 0 }
        if loc <= tailEnd {
            let t = (loc - tailStart) / (tailEnd - tailStart)
            return t * t * peakOpacity
        }
        if loc <= headEnd {
            let t = (loc - tailEnd) / (headEnd - tailEnd)
            return peakOpacity + sin(t * .pi) * peakBump
        }
        if loc <= fadeEnd {
            let t = (loc - headEnd) / (fadeEnd - headEnd)
            return (1 - t) * peakOpacity
        }
        return 0
    }
    
    private func rotationAngle(date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate
        let phase = t.truncatingRemainder(dividingBy: duration)
        return (phase / duration) * 360
    }
    
    private var colorfulStops: [Color] {
        if isDark {
            return [
                Color(red: 255 / 255, green: 50 / 255, blue: 100 / 255),
                Color(red: 255 / 255, green: 120 / 255, blue: 40 / 255),
                Color(red: 50 / 255, green: 200 / 255, blue: 80 / 255),
                Color(red: 30 / 255, green: 185 / 255, blue: 170 / 255),
                Color(red: 40 / 255, green: 140 / 255, blue: 255 / 255),
                Color(red: 100 / 255, green: 70 / 255, blue: 255 / 255),
                Color(red: 240 / 255, green: 50 / 255, blue: 180 / 255),
            ]
        }
        return [
            Color(red: 200 / 255, green: 20 / 255, blue: 70 / 255),
            Color(red: 200 / 255, green: 90 / 255, blue: 10 / 255),
            Color(red: 20 / 255, green: 140 / 255, blue: 50 / 255),
            Color(red: 10 / 255, green: 140 / 255, blue: 130 / 255),
            Color(red: 20 / 255, green: 90 / 255, blue: 200 / 255),
            Color(red: 60 / 255, green: 30 / 255, blue: 180 / 255),
            Color(red: 170 / 255, green: 10 / 255, blue: 130 / 255),
        ]
    }
}

extension View {
    /// Overlay a Border Beam traveling glow (Rotate · Colorful · ~70% strength).
    func borderBeam(
        active: Bool,
        cornerRadius: CGFloat = 24,
        strength: Double = 0.7,
        lineWidth: CGFloat = 2
    ) -> some View {
        overlay {
            BorderBeamEffect(
                cornerRadius: cornerRadius,
                active: active,
                strength: strength,
                lineWidth: lineWidth
            )
        }
    }
}
