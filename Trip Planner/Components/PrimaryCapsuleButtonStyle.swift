import SwiftUI

private enum CapsuleButtonMetrics {
    /// Tighter than default `Label` spacing (~8).
    static let iconTitleSpacing: CGFloat = 10
    
    // Compact chips (AI / Open In)
    static let chipFontSize: CGFloat = 13
    static let chipHorizontalPadding: CGFloat = 12
    static let chipVerticalPadding: CGFloat = 8
    
    // Full-width Maps-style footer actions
    static let blockFontSize: CGFloat = 15
    static let blockHorizontalPadding: CGFloat = 16
    static let blockVerticalPadding: CGFloat = 14
}

private struct CapsuleButtonLabelStyle: LabelStyle {
    var centered: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: CapsuleButtonMetrics.iconTitleSpacing) {
            if centered { Spacer(minLength: 0) }
            configuration.icon
            configuration.title
            if centered { Spacer(minLength: 0) }
        }
    }
}

/// Compact tinted CTA (destructive uses `.destructiveCapsule` / `.destructiveCapsuleBlock`).
struct CapsuleTintButtonStyle: ButtonStyle {
    var tint: Color
    var fillsWidth: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(CapsuleButtonLabelStyle(centered: fillsWidth))
            .font(.app(fillsWidth ? CapsuleButtonMetrics.blockFontSize : CapsuleButtonMetrics.chipFontSize, weight: .semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .padding(
                .horizontal,
                fillsWidth ? CapsuleButtonMetrics.blockHorizontalPadding : CapsuleButtonMetrics.chipHorizontalPadding
            )
            .padding(
                .vertical,
                fillsWidth ? CapsuleButtonMetrics.blockVerticalPadding : CapsuleButtonMetrics.chipVerticalPadding
            )
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(colorScheme == .dark ? 0.22 : 0.14))
            )
            .opacity({
                if !isEnabled { return 0.45 }
                return configuration.isPressed ? 0.82 : 1
            }())
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Accent-aware primary capsule (uses `appAccentColor`).
struct PrimaryCapsuleButtonStyle: ButtonStyle {
    var fillsWidth: Bool = false
    @Environment(\.appAccentColor) private var accentColor
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(CapsuleButtonLabelStyle(centered: fillsWidth))
            .font(.app(fillsWidth ? CapsuleButtonMetrics.blockFontSize : 15, weight: .semibold))
            .foregroundStyle(accentColor)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .padding(
                .horizontal,
                fillsWidth ? CapsuleButtonMetrics.blockHorizontalPadding : CapsuleButtonMetrics.blockHorizontalPadding
            )
            .padding(
                .vertical,
                fillsWidth ? CapsuleButtonMetrics.blockVerticalPadding : 11
            )
            .background(
                Capsule(style: .continuous)
                    .fill(accentColor.opacity(colorScheme == .dark ? 0.22 : 0.14))
            )
            .opacity({
                if !isEnabled { return 0.45 }
                return configuration.isPressed ? 0.82 : 1
            }())
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryCapsuleButtonStyle {
    static var primaryCapsule: PrimaryCapsuleButtonStyle { PrimaryCapsuleButtonStyle() }
    static var primaryCapsuleBlock: PrimaryCapsuleButtonStyle { PrimaryCapsuleButtonStyle(fillsWidth: true) }
}

extension ButtonStyle where Self == CapsuleTintButtonStyle {
    static var destructiveCapsule: CapsuleTintButtonStyle {
        CapsuleTintButtonStyle(tint: .red, fillsWidth: false)
    }
    
    static var destructiveCapsuleBlock: CapsuleTintButtonStyle {
        CapsuleTintButtonStyle(tint: .red, fillsWidth: true)
    }
}

/// Neutral secondary capsule.
struct SecondaryCapsuleButtonStyle: ButtonStyle {
    /// Compact AI/Open In chip vs full-width Maps-style footer.
    var fillsWidth: Bool = false
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        let fontSize = fillsWidth ? CapsuleButtonMetrics.blockFontSize : CapsuleButtonMetrics.chipFontSize
        let hPad = fillsWidth ? CapsuleButtonMetrics.blockHorizontalPadding : CapsuleButtonMetrics.chipHorizontalPadding
        let vPad = fillsWidth ? CapsuleButtonMetrics.blockVerticalPadding : CapsuleButtonMetrics.chipVerticalPadding
        
        configuration.label
            .labelStyle(CapsuleButtonLabelStyle(centered: fillsWidth))
            .font(.app(fontSize, weight: fillsWidth ? .semibold : .medium))
            .foregroundStyle(AppColor.textStrong)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .padding(.horizontal, hPad)
            .padding(.vertical, vPad)
            .background(
                Capsule(style: .continuous)
                    .fill(AppDetailSurface.card)
            )
            .opacity({
                if !isEnabled { return 0.45 }
                return configuration.isPressed ? 0.82 : 1
            }())
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == SecondaryCapsuleButtonStyle {
    /// Compact chip (Open In, AI-style).
    static var secondaryCapsule: SecondaryCapsuleButtonStyle { SecondaryCapsuleButtonStyle(fillsWidth: false) }
    /// Full-width Maps-style footer action.
    static var secondaryCapsuleBlock: SecondaryCapsuleButtonStyle { SecondaryCapsuleButtonStyle(fillsWidth: true) }
}

/// Label chrome for `Menu` (and similar) that should match the primary capsule.
struct PrimaryCapsuleLabel: View {
    let title: String
    var systemImage: String? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appAccentColor) private var accentColor
    
    var body: some View {
        HStack(spacing: CapsuleButtonMetrics.iconTitleSpacing) {
            if let systemImage {
                AppIcon(
                    systemName: systemImage,
                    size: CapsuleButtonMetrics.blockFontSize,
                    strokeWidth: 2
                )
            }
            Text(title)
                .font(.app(CapsuleButtonMetrics.blockFontSize, weight: .semibold))
        }
        .foregroundStyle(accentColor)
        .padding(.horizontal, CapsuleButtonMetrics.blockHorizontalPadding)
        .padding(.vertical, 11)
        .background(
            Capsule(style: .continuous)
                .fill(accentColor.opacity(colorScheme == .dark ? 0.22 : 0.14))
        )
        .contentShape(Capsule(style: .continuous))
    }
}

enum DetailDualActionMetrics {
    static let buttonGap: CGFloat = 10
    static let buttonRadius: CGFloat = 20
    static let iconTitleGap: CGFloat = 5
    static let iconSize: CGFloat = 24
}

/// Compact icon-only footer pill (copy / save / delete on detail sheets).
struct DetailIconPillButton: View {
    let lucide: String
    var iconColor: Color = AppColor.textStrong
    var fill: Color = AppColor.elevated
    var isEnabled: Bool = true
    let accessibilityLabel: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            AppIcon(lucide: lucide, size: AppLucide.fieldSize, color: iconColor)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.vertical, AppSpacing.md)
                .background(fill, in: Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct DetailToastBanner: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.app(15, weight: .medium))
            .foregroundStyle(AppColor.textStrong)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColor.elevated, in: Capsule(style: .continuous))
            .padding(.bottom, AppSpacing.xl)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

/// Icon-above-label footer action used on place and activity detail.
struct DetailDualActionButton: View {
    let lucide: String
    let title: String
    let foreground: Color
    let fill: Color
    
    var body: some View {
        VStack(spacing: DetailDualActionMetrics.iconTitleGap) {
            AppIcon(lucide: lucide, size: DetailDualActionMetrics.iconSize, color: foreground)
            Text(title)
                .font(.app(15, weight: .semibold))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .padding(.leading, 10)
        .padding(.trailing, 15)
        .background(
            fill,
            in: RoundedRectangle(cornerRadius: DetailDualActionMetrics.buttonRadius, style: .continuous)
        )
    }
}

/// Marks a Form row as a full-width footer action matching inset-grouped field cards.
struct DetailActionRowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .listRowInsets(EdgeInsets(top: 3, leading: 0, bottom: 3, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

extension View {
    func detailActionRow() -> some View {
        modifier(DetailActionRowModifier())
    }
}

/// Shared Form footer: each action is its own row so width matches field cards.
struct DetailActionButtonStack<Content: View>: View {
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        Section {
            content()
        }
        .listRowSpacing(6)
        // Match default Form section spacing (was 10 — too tight vs Notes / Cost / Documents).
        .listSectionSpacing(AppSpacing.sectionGap)
    }
}
