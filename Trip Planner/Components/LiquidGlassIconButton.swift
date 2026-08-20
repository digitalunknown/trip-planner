import SwiftUI

/// Shared metrics so single- and paired toolbar icons morph into consistent liquid glass.
enum LiquidGlassToolbarMetrics {
    /// Visual control size — keeps solo glass circular.
    static let iconSide: CGFloat = 36
    /// Gap between two icons that share one glass capsule.
    static let pairedSpacing: CGFloat = 0
}

/// Icon button sized for navigation-bar liquid glass (circle when alone).
struct LiquidGlassIconButton: View {
    let systemName: String
    var isEnabled: Bool = true
    /// When true, applies an explicit liquid-glass circle (for overlays outside toolbars).
    var showsGlassBackground: Bool = false
    var accessibilityLabelText: String? = nil
    var action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            LiquidGlassToolbarIconLabel(systemName: systemName)
                .modifier(LiquidGlassCircleBackground(enabled: showsGlassBackground))
        }
        .buttonStyle(.plain)
        .tint(.primary)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityLabel(accessibilityLabelText ?? systemName)
    }
}

/// Label-only icon for toolbar Buttons / Menus that participate in system liquid glass.
struct LiquidGlassToolbarIconLabel: View {
    let systemName: String
    
    var body: some View {
        Image(systemName: systemName)
            .font(.app(14, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(.primary)
            .tint(.primary)
            .frame(width: LiquidGlassToolbarMetrics.iconSide, height: LiquidGlassToolbarMetrics.iconSide)
            .contentShape(Rectangle())
    }
}

/// Toolbar controls that should share one liquid-glass capsule with tight, consistent spacing.
struct LiquidGlassToolbarIconPair<Content: View>: View {
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        HStack(spacing: LiquidGlassToolbarMetrics.pairedSpacing) {
            content()
        }
    }
}

private struct LiquidGlassCircleBackground: ViewModifier {
    let enabled: Bool
    
    func body(content: Content) -> some View {
        if !enabled {
            content
        } else if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: Circle())
        } else {
            content
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                }
        }
    }
}

#Preview {
    ZStack {
        Color.orange.opacity(0.35)
        VStack(spacing: 16) {
            LiquidGlassIconButton(systemName: "xmark") {}
            LiquidGlassIconButton(systemName: "xmark", showsGlassBackground: true) {}
            LiquidGlassIconButton(systemName: "checkmark", isEnabled: false) {}
            LiquidGlassToolbarIconPair {
                Button {} label: { LiquidGlassToolbarIconLabel(systemName: "gearshape") }
                    .buttonStyle(.plain)
                Button {} label: { LiquidGlassToolbarIconLabel(systemName: "plus") }
                    .buttonStyle(.plain)
            }
            .padding(6)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }
    .padding()
}
