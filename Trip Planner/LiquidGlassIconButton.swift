import SwiftUI

struct LiquidGlassIconButton: View {
    let systemName: String
    var isEnabled: Bool = true
    var action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            // Important: don't add an extra visible circle layer.
            // Sheets already sit on Apple's "liquid glass" (material) navigation bar,
            // so we render the icon only and keep a circular hit target.
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

#Preview {
    VStack(spacing: 16) {
        LiquidGlassIconButton(systemName: "xmark") {}
        LiquidGlassIconButton(systemName: "checkmark", isEnabled: false) {}
    }
    .padding()
}

