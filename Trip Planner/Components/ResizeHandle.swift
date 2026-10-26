import SwiftUI

/// Matches the system bottom-sheet drag indicator (`presentationDragIndicator`).
struct ResizeHandle: View {
    @Environment(\.colorScheme) private var colorScheme
    
    private var grabberColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.35 : 0.2)
    }
    
    var body: some View {
        Capsule(style: .continuous)
            .fill(grabberColor)
            .frame(width: 36, height: 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColor.page)
            .contentShape(Rectangle())
    }
}

/// Colored sheet grabber that replaces the system drag indicator.
struct SheetAccentDragIndicator: View {
    var color: Color
    
    var body: some View {
        Capsule(style: .continuous)
            .fill(color)
            .frame(width: 36, height: 5)
            .padding(.top, 6)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension View {
    /// Hides the system grabber and draws one in `color` (typically `EventAccent.background`).
    func sheetAccentDragIndicator(_ color: Color) -> some View {
        self
            .presentationDragIndicator(.hidden)
            .overlay(alignment: .top) {
                SheetAccentDragIndicator(color: color)
            }
    }
}
