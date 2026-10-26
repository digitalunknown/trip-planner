import SwiftUI

/// Shared metrics so single- and paired toolbar icons morph into consistent liquid glass.
enum LiquidGlassToolbarMetrics {
    /// Toolbar glyph box. Keep this at the glyph size so iOS 26 glass padding stays equal on all sides.
    static let iconSide: CGFloat = AppLucide.toolbarSize
    /// Explicit glass overlays (outside toolbars) still need a 40pt circle.
    static let overlaySide: CGFloat = 40
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
            LiquidGlassToolbarIconLabel(
                systemName: systemName,
                side: showsGlassBackground ? LiquidGlassToolbarMetrics.overlaySide : LiquidGlassToolbarMetrics.iconSide
            )
            .modifier(LiquidGlassCircleBackground(enabled: showsGlassBackground))
        }
        .liquidGlassToolbarControl()
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityLabel(accessibilityLabelText ?? systemName)
    }
}

/// Label-only icon for toolbar Buttons / Menus that participate in system liquid glass.
struct LiquidGlassToolbarIconLabel: View {
    let systemName: String
    var side: CGFloat = LiquidGlassToolbarMetrics.iconSide
    
    var body: some View {
        AppIcon(
            systemName: systemName,
            size: AppLucide.toolbarSize,
            color: AppLucide.labelColor
        )
        .frame(width: side, height: side)
        .contentShape(Circle())
        .clipShape(Circle())
    }
}

/// Prefer `ToolbarItemGroup` so iOS 26 clusters items with circular glass highlights.
/// An HStack inside a single `ToolbarItem` stretches those highlights into ovals.
struct LiquidGlassToolbarIconPair<Content: View>: View {
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        HStack(spacing: LiquidGlassToolbarMetrics.pairedSpacing) {
            content()
        }
    }
}

extension View {
    /// Square chrome so iOS 26 morphing highlights stay circular inside a clustered glass capsule.
    func liquidGlassToolbarControl() -> some View {
        self
            .buttonStyle(.plain)
            .tint(.primary)
            .buttonBorderShape(.circle)
            .containerShape(Circle())
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
                    .liquidGlassToolbarControl()
                Button {} label: { LiquidGlassToolbarIconLabel(systemName: "plus") }
                    .liquidGlassToolbarControl()
            }
            .padding(6)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }
    .padding()
}
