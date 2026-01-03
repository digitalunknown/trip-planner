import SwiftUI

struct ReminderCard: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "pin.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

