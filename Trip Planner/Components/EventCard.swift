import SwiftUI
import UIKit

struct EventCard: View {
    let event: EventItem
    @Environment(\.colorScheme) private var colorScheme
    
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var textSecondary: Color { textPrimary.opacity(colorScheme == .dark ? 0.72 : 0.62) }
    private var cardShape: RoundedRectangle { RoundedRectangle(cornerRadius: 16, style: .continuous) }
    
    /// Translucent lift over the day column — clearer than a near-matching solid fill.
    private var cardFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.78)
    }
    
    private var photoImage: UIImage? {
        guard let data = PlaceImageResolver.imageData(from: event) else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let photoImage {
                photoHeader(photoImage)
                
                detailsBlock
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
            } else {
                HStack(alignment: .center, spacing: 10) {
                    iconBadge
                    detailsBlock
                    Spacer(minLength: 0)
                }
                .padding(12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            cardShape
                .fill(cardFill)
        }
        .clipShape(cardShape)
        .contentShape(cardShape)
    }
    
    private func photoHeader(_ image: UIImage) -> some View {
        FixedAspectCover {
            FillCroppedImage(image: image)
        }
    }
    
    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(event.accentColor.opacity(0.18))
            Image(systemName: event.icon)
                .foregroundStyle(event.accentColor)
                .font(.app(20, weight: .regular))
        }
        .frame(width: 52, height: 52)
    }
    
    private var detailsBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title)
                .font(.app(12, weight: .semibold))
                .foregroundStyle(textPrimary)
                .lineLimit(2)
            if !event.location.isEmpty {
                Text(event.location)
                    .font(.appCaption)
                    .foregroundStyle(textSecondary)
                    .lineLimit(1)
            }
            if !event.time.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(event.time)
                    .font(.appCaption)
                    .foregroundStyle(textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
