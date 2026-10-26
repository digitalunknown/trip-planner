import SwiftUI

struct ReminderCard: View {
    let text: String
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardShape: RoundedRectangle { RoundedRectangle(cornerRadius: 14, style: .continuous) }
    /// Match activity cards on the trip board.
    private var cardFill: Color { AppDetailSurface.boardCard }
    private var cardStroke: Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.08)
    }
    private var textPrimary: Color { AppColor.textStrong }
    
    var body: some View {
        HStack(spacing: 6) {
            AppIcon(systemName: "pin.fill", size: 20, strokeWidth: 2, color: textPrimary)
            
            Text(text)
                .font(.app(13, weight: .medium))
                .foregroundStyle(textPrimary)
                .lineLimit(1)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            cardShape
                .fill(cardFill)
        }
        .overlay {
            cardShape.strokeBorder(cardStroke, lineWidth: 1)
        }
        .clipShape(cardShape)
        .contentShape(cardShape)
    }
}
