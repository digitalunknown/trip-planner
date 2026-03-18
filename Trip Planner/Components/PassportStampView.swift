import SwiftUI
import Combine
import CoreMotion
import Sticker

struct PassportStampView: View {
    let destination: String
    let iconSystemName: String
    let date: Date
    
    var size: CGFloat = 180
    var tint: Color = .primary
    
    @AppStorage("parallaxEffectsEnabled") private var parallaxEffectsEnabled: Bool = true
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var letterWidths: [Int: CGFloat] = [:]
    @StateObject private var motion = ShineMotionManager()
    
    private struct RingGlyph: Identifiable {
        let id: Int
        let character: Character
        let position: CGPoint
        let rotation: Double
    }
    
    private var normalizedDestination: String {
        let cleaned = destination
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .uppercased()
        return cleaned.isEmpty ? "TRIP" : cleaned
    }
    
    private func ringText(targetCharacterCount: Int) -> String {
        let year = Calendar.current.component(.year, from: date)
        let chunk = "\(normalizedDestination) • \(year) • "
        var s = ""
        while s.count < targetCharacterCount {
            s += chunk
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private struct WidthLetterPreferenceKey: PreferenceKey {
        static var defaultValue: [Int: CGFloat] = [:]
        static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
            value.merge(nextValue(), uniquingKeysWith: { _, new in new })
        }
    }
    
    var body: some View {
        // Larger radius so the ring text sits closer to the sticker edge.
        let ringRadius = size * 0.49
        let fontSize = max(12, size * 0.075)
        let radius = Double(ringRadius)
        let circumference = 2.0 * Double.pi * radius
        let pageBackground: Color = colorScheme == .dark ? Color(hex: 0x0A0A0A) : Color(hex: 0xE0E0E0)
        // In dark mode, use the page background (ink-like). In light mode, use a darker ink so it stays readable.
        let foregroundOnSticker: Color = (colorScheme == .dark
                                          ? pageBackground.opacity(0.96)
                                          : Color(hex: 0x0A0A0A).opacity(0.86))
        
        let desiredChars = Int((circumference / max(Double(fontSize) * 0.85, 1)).rounded())
        let targetChars = max(60, min(140, desiredChars))
        let text = ringText(targetCharacterCount: targetChars)
        let lettersOffset = Array(text.enumerated())
        
        func fetchAngle(at index: Int) -> Angle {
            // Use the measured total width so the ring always fits 360° with no overlap.
            let totalStringWidth = max(letterWidths.values.reduce(0, +), 1)
            // Add spacing between characters to prevent overlaps on curved text
            let characterSpacing = fontSize * 0.35
            let totalSpacing = CGFloat(lettersOffset.count) * characterSpacing
            // Add a gap so the first/last characters never collide.
            let endGap = max(fontSize * 2.5, 20.0)
            let fullWidth = Double(totalStringWidth + totalSpacing + endGap)
            
            let currentCharWidth = letterWidths[index] ?? 0
            let widthBeforeCurrent = letterWidths
                .filter { $0.key < index }
                .map(\.value)
                .reduce(0, +)
            let spacingBeforeCurrent = CGFloat(index) * characterSpacing
            
            // Position at the center of the current character
            let totalWidth = widthBeforeCurrent + spacingBeforeCurrent + (currentCharWidth * 0.5)
            
            let pct = Double(totalWidth) / max(fullWidth, 1)
            let radians = pct * 2.0 * Double.pi
            return .radians(radians)
        }
        
        let ringLayer = ZStack {
            ForEach(lettersOffset, id: \.offset) { idx, ch in
                ZStack {
                    Text(String(ch))
                        .font(.app(fontSize, weight: .semibold))
                        .foregroundStyle(foregroundOnSticker)
                        .kerning(0)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(key: WidthLetterPreferenceKey.self, value: [idx: geo.size.width])
                            }
                        )
                        .offset(y: -ringRadius)
                }
                .frame(width: size, height: size)
                .rotationEffect(fetchAngle(at: idx))
            }
            
            // Inner guide ring between icon and text
            let guideRadius = max(0, ringRadius - (fontSize * 0.95))
            Circle()
                .stroke(foregroundOnSticker.opacity(0.9), lineWidth: 1.5)
                .frame(width: guideRadius * 2, height: guideRadius * 2)
        }
        
        let iconLayer =
            Image(systemName: iconSystemName)
                .font(.app(size * 0.34, weight: .semibold))
                .foregroundStyle(foregroundOnSticker)
        
        // Use a neutral base so the Sticker shader's holographic colors read evenly across the whole circle.
        // (Using a rainbow base tends to look "localized" to one side once blended + shaded.)
        let holographicBase = RadialGradient(
            colors: [
                (colorScheme == .dark ? Color(hex: 0x2A2A2A) : Color(hex: 0xF6F6F6)),
                (colorScheme == .dark ? Color(hex: 0x141414) : Color(hex: 0xDADADA))
            ],
            center: .center,
            startRadius: 0,
            endRadius: max(1, size * 0.65)
        )
        
        // Holographic background layer (fills the full circle).
        let holographicBackground = Circle()
            .fill(holographicBase)
            .frame(width: size, height: size)
            .stickerEffect()
            // Sticker tuning (using the package's supported parameters).
            .stickerScale(3.0)
            .stickerColorIntensity(2.6)
            .stickerContrast(1.05)
            .stickerBlend(0.55)
            .stickerCheckerScale(5.2)
            .stickerCheckerIntensity(1.65)
            .stickerNoiseScale(120)
            .stickerNoiseIntensity(1.25)
            .stickerLightIntensity(0.9)
            .stickerPattern(.diamond)
            // No tilt/3D motion: only a moving shine overlay reacts to device motion.
            .overlay {
                let dx = motion.roll * (size * 0.22)
                let dy = motion.pitch * (size * 0.22)
                let angle = Angle(degrees: Double(motion.roll) * 18.0 + Double(motion.pitch) * -14.0)
                let intensity = min(max(sqrt(motion.roll * motion.roll + motion.pitch * motion.pitch), 0.0), 1.0)
                
                // Build the shine on a larger canvas so shifting it never reveals a square edge.
                let shineSize = size * 1.75
                // Stronger specular peak so the shine reads clearly.
                let peak = 0.75 + 0.55 * intensity
                
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.00), location: 0.0),
                        .init(color: .white.opacity(0.12 * peak), location: 0.32),
                        .init(color: .white.opacity(0.45 * peak), location: 0.45),
                        .init(color: .white.opacity(1.00 * peak), location: 0.50),
                        .init(color: .white.opacity(0.45 * peak), location: 0.55),
                        .init(color: .white.opacity(0.12 * peak), location: 0.68),
                        .init(color: .white.opacity(0.00), location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: shineSize, height: shineSize)
                .rotationEffect(angle)
                .offset(x: dx, y: dy)
                .blur(radius: max(12, size * 0.04))
                .blendMode(.screen)
                .opacity(parallaxEffectsEnabled ? 1.0 : 0.0)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .allowsHitTesting(false)
            }
        
        // Foreground content (kept crisp above the holographic background).
        let stampForeground = ZStack {
            ringLayer
            
            iconLayer
        }
        .frame(width: size, height: size)
        
        let stickerShape = Circle()
        let stickerFill: Color = colorScheme == .dark ? Color.white.opacity(0.06) : Color.white
        
        // Full stamp: holographic background to the edge, crisp content inset so nothing clips.
        let baseStamp = ZStack {
            holographicBackground
            stampForeground
                .scaleEffect(0.88)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .background(stickerShape.fill(stickerFill))
        // Softer shadow in light mode so it doesn't look harsh/clipped.
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.38 : 0.06),
                radius: colorScheme == .dark ? 16 : 28,
                x: 0,
                y: colorScheme == .dark ? 10 : 18)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.03),
                radius: colorScheme == .dark ? 6 : 12,
                x: 0,
                y: colorScheme == .dark ? 3 : 6)
        
        return baseStamp
            .onAppear {
                if parallaxEffectsEnabled {
                    motion.start()
                }
            }
            .onDisappear { motion.stop() }
            .onChange(of: parallaxEffectsEnabled) { _, isEnabled in
                if isEnabled {
                    motion.start()
                } else {
                    motion.stop()
                }
            }
        .onPreferenceChange(WidthLetterPreferenceKey.self) { newWidths in
            if newWidths != letterWidths {
                letterWidths.merge(newWidths, uniquingKeysWith: { _, new in new })
            }
        }
        .onChange(of: destination) { _, _ in
            letterWidths = [:]
        }
        .onChange(of: date) { _, _ in
            letterWidths = [:]
        }
    }
}

private final class ShineMotionManager: ObservableObject {
    private let manager = CMMotionManager()
    private let queue = OperationQueue()
    
    @Published var roll: CGFloat = 0   // left/right
    @Published var pitch: CGFloat = 0  // up/down
    
    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        queue.qualityOfService = .userInteractive
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let r = max(min(motion.attitude.roll / 0.8, 1), -1)
            let p = max(min(motion.attitude.pitch / 0.8, 1), -1)
            DispatchQueue.main.async {
                self.roll = CGFloat(r)
                self.pitch = CGFloat(p)
            }
        }
    }
    
    func stop() {
        manager.stopDeviceMotionUpdates()
        DispatchQueue.main.async {
            self.roll = 0
            self.pitch = 0
        }
    }
}
