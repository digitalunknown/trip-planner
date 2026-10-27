import SwiftUI

struct ReminderCard: View {
    let text: String
    @Environment(\.colorScheme) private var colorScheme
    
    private let cornerRadius: CGFloat = 14
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
        .boardCardChrome(cornerRadius: cornerRadius)
    }
}
