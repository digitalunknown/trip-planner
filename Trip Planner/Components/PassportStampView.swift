import SwiftUI

struct PassportStampView: View {
    let destination: String
    let iconSystemName: String
    let date: Date
    
    var size: CGFloat = 180
    var tint: Color = .primary
    
    @State private var letterWidths: [Int: CGFloat] = [:]
    
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
        
        return ZStack {
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
            
            Image(systemName: iconSystemName)
                .font(.system(size: size * 0.22, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
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

