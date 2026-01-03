import SwiftUI
import UIKit

struct EventCard: View {
    let event: EventItem

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let photoData = event.photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(event.accentColor.opacity(0.18))
                        Image(systemName: event.icon)
                            .foregroundStyle(event.accentColor)
                            .font(.title3)
                    }
                    .frame(width: 52, height: 52)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                if !event.location.isEmpty {
                    Text(event.location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !event.time.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(event.time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

