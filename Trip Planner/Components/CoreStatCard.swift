import SwiftUI

/// Count-first metric card for core Stats (percentage is secondary).
struct CoreStatCard: View {
    @Environment(\.appAccentColor) private var accentColor
    @Environment(\.colorScheme) private var colorScheme
    
    let title: String
    let iconSystemName: String
    let count: Int
    let total: Int
    var showsProgress: Bool = true
    
    private var dayBackground: Color { colorScheme == .dark ? Color(hex: 0x171717) : Color(hex: 0xF0F0F0) }
    private var columnStroke: Color { colorScheme == .dark ? Color(hex: 0x252525) : Color(hex: 0xFFFFFF) }
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var textSecondary: Color { textPrimary.opacity(colorScheme == .dark ? 0.72 : 0.62) }
    
    private var percent: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
    
    private var percentLabel: String {
        "\(Int((min(max(percent, 0), 1) * 100).rounded()))%"
    }
    
    /// Show % when it helps (any progress, or near a milestone); hide the demoralizing 0%.
    private var shouldShowPercent: Bool {
        guard showsProgress, total > 0 else { return false }
        return count > 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Text(title)
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                AppIcon(systemName: "chevron.right", size: 13, color: textSecondary)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(count)")
                    .font(.appTitle)
                    .foregroundStyle(textPrimary)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                if shouldShowPercent {
                    Text(percentLabel)
                        .font(.appCaption)
                        .foregroundStyle(textSecondary)
                        .contentTransition(.numericText())
                }
                
                Spacer(minLength: 0)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.22), accentColor.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    AppIcon(systemName: iconSystemName, size: 18, color: accentColor)
                }
                .frame(width: 44, height: 44)
            }
            
            if showsProgress, total > 0 {
                GeometryReader { geo in
                    let width = max(geo.size.width, 1)
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(columnStroke)
                        Capsule(style: .continuous)
                            .fill(accentColor)
                            .frame(width: width * min(max(percent, 0), 1))
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(dayBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(columnStroke)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 14)
    }
}

/// Lighter-weight collection row for niche trackers.
struct CollectionStatRow: View {
    @Environment(\.appAccentColor) private var accentColor
    @Environment(\.colorScheme) private var colorScheme
    
    let type: TrackerType
    let visitedCount: Int
    let totalCount: Int
    
    private var dayBackground: Color { colorScheme == .dark ? Color(hex: 0x171717) : Color(hex: 0xF0F0F0) }
    private var columnStroke: Color { colorScheme == .dark ? Color(hex: 0x252525) : Color(hex: 0xFFFFFF) }
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var textSecondary: Color { textPrimary.opacity(colorScheme == .dark ? 0.72 : 0.62) }
    
    private var percent: Double {
        guard totalCount > 0 else { return 0 }
        return Double(visitedCount) / Double(totalCount)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accentColor.opacity(0.14))
                AppIcon(systemName: type.iconSystemName, size: 16, color: accentColor)
            }
            .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(type.title)
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
                Text("\(visitedCount) visited")
                    .font(.appCaption)
                    .foregroundStyle(textSecondary)
            }
            
            Spacer(minLength: 0)
            
            if visitedCount > 0 {
                Text("\(Int((percent * 100).rounded()))%")
                    .font(.appCaption)
                    .foregroundStyle(textSecondary)
            }
            
            AppIcon(systemName: "chevron.right", size: 13, color: textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(dayBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(columnStroke)
        }
    }
}
