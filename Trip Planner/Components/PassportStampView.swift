import SwiftUI
import CoreMotion
import Combine

struct PassportStampView: View {
    let destination: String
    let iconSystemName: String
    let date: Date
    
    var size: CGFloat = 180
    var tint: Color = .primary
    
    @State private var letterWidths: [Int: CGFloat] = [:]
    @StateObject private var motion = TiltMotionManager()
    
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
        let ringRadius = size * 0.43
        let fontSize = max(12, size * 0.075)
        let radius = Double(ringRadius)
        let circumference = 2.0 * Double.pi * radius
        
        // Target a consistent density around the ring.
        let desiredChars = Int((circumference / max(Double(fontSize) * 0.85, 1)).rounded())
        let targetChars = max(60, min(140, desiredChars))
        let text = ringText(targetCharacterCount: targetChars)
        let lettersOffset = Array(text.enumerated())
        
        let tiltX = motion.pitch // up/down
        let tiltY = motion.roll  // left/right
        
        func fetchAngle(at index: Int) -> Angle {
            // Use the measured total width so the ring always fits 360° with no overlap.
            let totalStringWidth = max(letterWidths.values.reduce(0, +), 1)
            // Add a small gap so the first/last characters never collide.
            let gap = max(fontSize * 2.0, 18.0)
            let fullWidth = Double(totalStringWidth + gap)
            
            let totalWidth = letterWidths
                .filter { $0.key <= index }
                .map(\.value)
                .reduce(0, +)
            
            let pct = Double(totalWidth) / max(fullWidth, 1)
            let radians = pct * 2.0 * Double.pi
            return .radians(radians)
        }
        
        let ringLayer = ZStack {
            ForEach(lettersOffset, id: \.offset) { idx, ch in
                VStack(spacing: 0) {
                    Text(String(ch))
                        .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
                        .foregroundStyle(tint.opacity(0.92))
                        .kerning(fontSize * 0.18)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(key: WidthLetterPreferenceKey.self, value: [idx: geo.size.width])
                            }
                        )
                    Spacer(minLength: 0)
                }
                .frame(width: size, height: size)
                .rotationEffect(fetchAngle(at: idx))
            }
            
            // Inner guide ring between icon and text
            Circle()
                .stroke(tint.opacity(0.92), lineWidth: 1)
                .frame(
                    width: max(0, (ringRadius - (fontSize * 0.95)) * 2),
                    height: max(0, (ringRadius - (fontSize * 0.95)) * 2)
                )
        }
        
        let iconLayer =
            Image(systemName: iconSystemName)
                .font(.system(size: size * 0.25, weight: .semibold))
                .foregroundStyle(tint)
        
        return ZStack {
            ringLayer
                .rotation3DEffect(.degrees(Double(tiltX) * 14), axis: (x: 1, y: 0, z: 0))
                .rotation3DEffect(.degrees(Double(tiltY) * 14), axis: (x: 0, y: 1, z: 0))
            
            iconLayer
                .rotation3DEffect(.degrees(Double(tiltX) * 9), axis: (x: 1, y: 0, z: 0))
                .rotation3DEffect(.degrees(Double(tiltY) * 9), axis: (x: 0, y: 1, z: 0))
        }
        .frame(width: size, height: size)
            .onPreferenceChange(WidthLetterPreferenceKey.self) { newWidths in
                if newWidths != letterWidths {
                    letterWidths.merge(newWidths, uniquingKeysWith: { _, new in new })
                }
            }
            .onAppear { motion.start() }
            .onDisappear { motion.stop() }
            .onChange(of: destination) { _, _ in
                letterWidths = [:]
            }
            .onChange(of: date) { _, _ in
                letterWidths = [:]
            }
    }
}

private final class TiltMotionManager: ObservableObject {
    private let manager = CMMotionManager()
    private let queue = OperationQueue()
    
    @Published var roll: CGFloat = 0
    @Published var pitch: CGFloat = 0
    
    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        queue.qualityOfService = .userInteractive
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            // Normalize roughly to [-1, 1] range for UI mapping.
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
    }
}


