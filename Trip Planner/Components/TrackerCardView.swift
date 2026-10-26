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
        unfilledColor: Color = AppColor.elevated,
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
        
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                Text("\(visitedCount)/\(totalCount)")
                    .font(useLargeTitle ? .appLargeTitle : .appTitle2)
                    .foregroundStyle(AppColor.textStrong)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                
                Text("\(pct)%")
                    .font(.appCaption)
                    .foregroundStyle(AppColor.textWeak)
                    .contentTransition(.numericText())
                Spacer()
            }
            .animation(.easeInOut(duration: 0.22), value: pct)
            .animation(.easeInOut(duration: 0.22), value: visitedCount)
            
            HStack(spacing: AppSpacing.xxs) {
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
    
    let type: TrackerType
    let visitedCount: Int
    let totalCount: Int
    
    private var unfilledBarColor: Color { AppColor.elevated }
    private var textPrimary: Color { AppColor.textStrong }
    private var textSecondary: Color { AppColor.textWeak }
    
    private var percent: Double {
        guard totalCount > 0 else { return 0 }
        return Double(visitedCount) / Double(totalCount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top, spacing: AppSpacing.xs) {
                Text(type.title)
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
                
                AppIcon(systemName: "chevron.right", size: AppLucide.compactSize, color: textSecondary)
            }
            
            HStack(spacing: AppSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accentColor.opacity(0.18))
                    
                    AppIcon(systemName: type.iconSystemName, size: 20, color: accentColor)
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
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            AppColor.card,
            in: RoundedRectangle(cornerRadius: TripVisualMetrics.coverRadius, style: .continuous)
        )
    }
}

struct TrackerCardView: View {
    @Environment(\.appAccentColor) private var accentColor
    
    let type: TrackerType
    let visitedCount: Int
    let totalCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accentColor.opacity(0.18))
                    .frame(width: 52, height: 52)

                AppIcon(systemName: type.iconSystemName, size: 20, color: accentColor)
            }

            Text(type.title)
                .font(.app(15, weight: .semibold))
                .foregroundStyle(AppColor.textStrong)

            Text("Visited \(visitedCount)/\(totalCount)")
                .font(.appCaption)
                .foregroundStyle(AppColor.textWeak)

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .background(
            AppColor.card,
            in: RoundedRectangle(cornerRadius: TripVisualMetrics.coverRadius, style: .continuous)
        )
    }
}

struct TrackerItemCard: View {
    let title: String
    let subtitle: String?
    let isVisited: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            AppIcon(
                lucide: isVisited ? "circle-check-big" : "circle",
                size: AppLucide.fieldSize,
                color: isVisited ? AppColor.textStrong : AppColor.textWeak
            )

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.app(15, weight: .medium))
                    .foregroundStyle(isVisited ? AppColor.textStrong : AppColor.textWeak)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.app(13, weight: .medium))
                        .foregroundStyle(AppColor.textWeak)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.fieldPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (isVisited ? AppColor.elevated : AppColor.card),
            in: Capsule(style: .continuous)
        )
        .contentShape(Capsule(style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityValue(isVisited ? "Visited" : "Not visited")
    }
}

#Preview {
    VStack(spacing: 12) {
        TrackerCardView(type: .countries, visitedCount: 12, totalCount: 195)
        TrackerItemCard(title: "Arizona", subtitle: "United States", isVisited: true)
    }
    .padding()
}

