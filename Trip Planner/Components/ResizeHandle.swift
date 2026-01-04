import SwiftUI

struct ResizeHandle: View {
    @Environment(\.colorScheme) private var colorScheme
    
    private var backgroundColor: Color { colorScheme == .dark ? Color(hex: 0x0A0A0A) : Color(hex: 0xE0E0E0) }
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(backgroundColor)
                .frame(height: 12)
            
            HStack {
                Spacer()
                Capsule()
                    .fill(Color(.systemGray3))
                    .frame(width: 40, height: 5)
                Spacer()
            }
            .frame(height: 12)
            .background(backgroundColor)
        }
        .contentShape(Rectangle())
    }
}

