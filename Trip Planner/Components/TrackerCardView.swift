import SwiftUI

struct TrackerProgressBar: View {
    @Environment(\.appAccentColor) private var accentColor
    
    let percent: Double
    let visitedCount: Int
    let totalCount: Int
    let totalBars: Int
    let barHeight: CGFloat
    let unfilledColor: Color
    let useLargeTitle: Bool
    
    init(
        percent: Double,
        visitedCount: Int,
        totalCount: Int,
        totalBars: Int = 30,
        barHeight: CGFloat = 36,
        unfilledColor: Color = Color.secondary.opacity(0.25),
        useLargeTitle: Bool = false
    ) {
        self.percent = percent
        self.visitedCount = visitedCount
        self.totalCount = totalCount
        self.totalBars = totalBars
        self.barHeight = barHeight
        self.unfilledColor = unfilledColor
        self.useLargeTitle = useLargeTitle
    }
    
    var body: some View {
        let clamped = min(max(percent, 0), 1)
        let pct = Int((clamped * 100).rounded())
        let filled = Int((Double(totalBars) * clamped).rounded())
        
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(visitedCount)/\(totalCount)")
                    .font(useLargeTitle ? .appLargeTitle : .appTitle2)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                
                Text("\(pct)%")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                Spacer()
            }
            .animation(.easeInOut(duration: 0.22), value: pct)
            .animation(.easeInOut(duration: 0.22), value: visitedCount)
            
            HStack(spacing: 4) {
                ForEach(0..<totalBars, id: \.self) { idx in
                    Capsule(style: .continuous)
                        .fill(idx < filled ? accentColor : unfilledColor)
                        .frame(height: barHeight)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: filled)
        }
    }
}

struct TrackerRowCard: View {
    @Environment(\.appAccentColor) private var accentColor
    @Environment(\.colorScheme) private var colorScheme
    
    let type: TrackerType
    let visitedCount: Int
    let totalCount: Int
    
    private var dayBackground: Color { colorScheme == .dark ? Color(hex: 0x171717) : Color(hex: 0xF0F0F0) }
    private var columnStroke: Color { colorScheme == .dark ? Color(hex: 0x252525) : Color(hex: 0xFFFFFF) }
    private var unfilledBarColor: Color { colorScheme == .dark ? Color(hex: 0x2A2A2E) : Color(hex: 0xD4D4D8) }
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var textSecondary: Color { textPrimary.opacity(colorScheme == .dark ? 0.72 : 0.62) }
    
    private var percent: Double {
        guard totalCount > 0 else { return 0 }
        return Double(visitedCount) / Double(totalCount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.title)
                        .font(.app(15, weight: .semibold))
                        .foregroundStyle(textPrimary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 0)
                
                Image(systemName: "chevron.right")
                    .font(.app(13, weight: .semibold))
                    .foregroundStyle(textSecondary)
            }
            
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accentColor.opacity(0.18))
                    
                    Image(systemName: type.iconSystemName)
                        .font(.app(20, weight: .regular))
                        .foregroundStyle(accentColor)
                }
                .frame(width: 52, height: 52)
                Spacer(minLength: 0)
            }
            
            TrackerProgressBar(
                percent: percent,
                visitedCount: visitedCount,
                totalCount: totalCount,
                totalBars: 16,
                barHeight: 28,
                unfilledColor: unfilledBarColor
            )
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .modifier(TrackerRowGlassBackground(fallback: dayBackground, stroke: columnStroke))
    }
}

private struct TrackerRowGlassBackground: ViewModifier {
    let fallback: Color
    let stroke: Color
    
    private let cornerRadius: CGFloat = 20
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        } else {
            content
                .background(fallback, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(stroke)
                }
                .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 14)
        }
    }
}

struct TrackerCardView: View {
    @Environment(\.appAccentColor) private var accentColor
    
    let type: TrackerType
    let visitedCount: Int
    let totalCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accentColor.opacity(0.18))
                    .frame(width: 52, height: 52)

                Image(systemName: type.iconSystemName)
                    .font(.app(20, weight: .regular))
                    .foregroundStyle(accentColor)
            }

            Text(type.title)
                .font(.app(15, weight: .semibold))
                .foregroundStyle(.primary)

            Text("Visited \(visitedCount)/\(totalCount)")
                .font(.appCaption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct TrackerItemCard: View {
    @Environment(\.appAccentColor) private var accentColor
    @Environment(\.colorScheme) private var colorScheme
    
    let title: String
    let subtitle: String?
    let isVisited: Bool
    let iconSystemName: String
    
    private var dayBackground: Color { colorScheme == .dark ? Color(hex: 0x171717) : Color(hex: 0xF0F0F0) }
    private var columnStroke: Color { colorScheme == .dark ? Color(hex: 0x252525) : Color(hex: 0xFFFFFF) }
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var textSecondary: Color { textPrimary.opacity(colorScheme == .dark ? 0.72 : 0.62) }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isVisited ? accentColor.opacity(0.18) : Color.secondary.opacity(0.10))

                Image(systemName: iconSystemName)
                    .font(.app(20, weight: .regular))
                    .foregroundStyle(isVisited ? accentColor : .secondary)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(textPrimary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.appCaption)
                        .foregroundStyle(textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: isVisited ? "checkmark.square.fill" : "square")
                .font(.app(20, weight: .regular))
                .foregroundStyle(isVisited ? accentColor : Color.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(dayBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accentColor.opacity(isVisited ? 0.14 : 0.0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(columnStroke)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isVisited ? accentColor.opacity(0.28) : Color.clear, lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        TrackerCardView(type: .countries, visitedCount: 12, totalCount: 195)
        TrackerItemCard(title: "Arizona", subtitle: "United States", isVisited: true, iconSystemName: "map.fill")
    }
    .padding()
}

