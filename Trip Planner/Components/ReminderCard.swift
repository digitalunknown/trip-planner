import SwiftUI

struct ReminderCard: View {
    let text: String
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardShape: RoundedRectangle { RoundedRectangle(cornerRadius: 14, style: .continuous) }
    /// Match activity cards: translucent lift over the day column.
    private var cardFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.78)
    }
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "pin.fill")
                .font(.app(15, weight: .semibold))
                .foregroundStyle(textPrimary)
            
            Text(text)
                .font(.app(12, weight: .regular))
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
        .clipShape(cardShape)
        .contentShape(cardShape)
    }
}
