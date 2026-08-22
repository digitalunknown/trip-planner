import SwiftUI

/// Matches the system bottom-sheet drag indicator (`presentationDragIndicator`).
struct ResizeHandle: View {
    @Environment(\.colorScheme) private var colorScheme
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: 0x171717) : Color(hex: 0xF0F0F0)
    }
    
    private var grabberColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.35 : 0.2)
    }
    
    var body: some View {
        Capsule(style: .continuous)
            .fill(grabberColor)
            .frame(width: 36, height: 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(backgroundColor)
            .contentShape(Rectangle())
    }
}
