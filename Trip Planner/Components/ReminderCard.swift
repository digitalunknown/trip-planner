import SwiftUI

struct ReminderCard: View {
    let text: String
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardBackground: Color { colorScheme == .dark ? Color(hex: 0x222222) : Color(hex: 0xFFFEF9) }
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var textSecondary: Color { textPrimary.opacity(colorScheme == .dark ? 0.72 : 0.62) }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "pin.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(textPrimary)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(textPrimary)
                .lineLimit(1)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

