import SwiftUI

struct ReminderCard: View {
    let text: String
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardShape: RoundedRectangle { RoundedRectangle(cornerRadius: 14, style: .continuous) }
    /// Match activity cards: translucent in dark; solid white + stroke in light.
    private var cardFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.white
    }
    private var cardStroke: Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.08)
    }
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    
    var body: some View {
        HStack(spacing: 6) {
            AppIcon(systemName: "pin.fill", size: 15, strokeWidth: 2, color: textPrimary)
            
            Text(text)
                .font(.app(13, weight: .regular))
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
