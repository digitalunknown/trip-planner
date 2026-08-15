import SwiftUI

struct LiquidGlassIconButton: View {
    let systemName: String
    var isEnabled: Bool = true
    /// When true, applies an explicit liquid-glass circle (for overlays outside toolbars).
    var showsGlassBackground: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: systemName)
                .font(.app(14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
                .modifier(LiquidGlassCircleBackground(enabled: showsGlassBackground))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
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
        }
    }
    .padding()
}
