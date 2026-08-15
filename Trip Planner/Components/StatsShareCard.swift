import SwiftUI

/// Shareable stamp card — flat artwork (no Metal sticker shader) so `ImageRenderer` exports cleanly.
struct StatsShareCard: View {
    let destination: String
    let date: Date
    
    var size: CGFloat = 220
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var pageBackground: Color { colorScheme == .dark ? Color(hex: 0x0A0A0A) : Color(hex: 0xE8E8E8) }
    private var ink: Color { colorScheme == .dark ? Color(hex: 0x0A0A0A) : Color(hex: 0x111111) }
    
    private var title: String {
        let cleaned = destination
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        return cleaned.isEmpty ? "TRIP" : cleaned
    }
    
    private var dateLabel: String {
        date.formatted(.dateTime.month(.abbreviated).day().year())
    }
    
    var body: some View {
        VStack(spacing: 28) {
            flatStamp
                .frame(width: size, height: size)
            
            VStack(spacing: 6) {
                Text(title)
                    .font(.app(22, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? Color.white : ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                Text(dateLabel)
                    .font(.appSubheadline)
                    .foregroundStyle((colorScheme == .dark ? Color.white : ink).opacity(0.55))
            }
            
            Text("TripStacks")
                .font(.app(13, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle((colorScheme == .dark ? Color.white : ink).opacity(0.4))
                .padding(.top, 8)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 44)
        .frame(width: 390, height: 640)
        .background(pageBackground)
    }
    
    private var flatStamp: some View {
        let ringRadius = size * 0.49
        let fontSize = max(12, size * 0.075)
        let year = Calendar.current.component(.year, from: date)
        let chunk = "\(title) • \(year) • "
        var ring = ""
        while ring.count < 80 { ring += chunk }
        
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            colorScheme == .dark ? Color(hex: 0x2A2A2A) : Color(hex: 0xF6F6F6),
                            colorScheme == .dark ? Color(hex: 0x141414) : Color(hex: 0xDADADA)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.65
                    )
                )
            
            // Simplified ring: two arcs of caption text via overlay labels.
            Text(String(ring.prefix(36)))
                .font(.app(fontSize * 0.85, weight: .semibold))
                .foregroundStyle(ink.opacity(0.85))
                .frame(width: ringRadius * 1.7)
                .offset(y: -ringRadius * 0.78)
            
            Circle()
                .stroke(ink.opacity(0.85), lineWidth: 1.5)
                .frame(width: ringRadius * 1.55, height: ringRadius * 1.55)
            
            Image(systemName: "globe")
                .font(.app(size * 0.3, weight: .semibold))
                .foregroundStyle(ink.opacity(0.9))
        }
        .clipShape(Circle())
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 18, y: 10)
    }
}
