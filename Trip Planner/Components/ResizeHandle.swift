import SwiftUI

struct ResizeHandle: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(.systemBackground))
                .frame(height: 12)
            
            HStack {
                Spacer()
                Capsule()
                    .fill(Color(.systemGray3))
                    .frame(width: 40, height: 5)
                Spacer()
            }
            .frame(height: 12)
            .background(Color(.systemBackground))
        }
        .contentShape(Rectangle())
    }
}

