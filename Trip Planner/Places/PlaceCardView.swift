import SwiftUI
import UIKit

enum PlaceCardMetrics {
    /// Approximate text block (title + type/badge) for masonry balancing.
    static let textBlockEstimate: CGFloat = 108
    /// Clamp so ultra-wide / ultra-tall photos don't break the grid.
    static let minPhotoAspect: CGFloat = 0.72  // tall
    static let maxPhotoAspect: CGFloat = 1.6   // wide
    
    static func clampedPhotoAspect(for image: UIImage) -> CGFloat {
        let raw = image.size.width / max(image.size.height, 1)
        return min(max(raw, minPhotoAspect), maxPhotoAspect)
    }
    
    static func estimatedHeight(for place: Place, columnWidth: CGFloat) -> CGFloat {
        var height = textBlockEstimate
        if let data = place.photoData, let image = UIImage(data: data) {
            height += columnWidth / clampedPhotoAspect(for: image)
        }
        return height
    }
}

struct PlaceCardView: View {
    let place: Place
    var tripCount: Int = 0
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var dayBackground: Color { colorScheme == .dark ? Color(hex: 0x171717) : Color(hex: 0xF0F0F0) }
    private var columnStroke: Color { colorScheme == .dark ? Color(hex: 0x252525) : Color(hex: 0xFFFFFF) }
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var textSecondary: Color { textPrimary.opacity(colorScheme == .dark ? 0.72 : 0.62) }
    
    private var title: String {
        PlaceNaming.displayTitle(name: place.name, location: place.location)
    }
    
    private var subtitle: String? {
        PlaceNaming.subtitle(location: place.location, title: title)
    }
    
    private var tripBadge: String? {
        PlaceTripMembership.badgeText(tripCount: tripCount)
    }
    
    private var showsType: Bool {
        place.placeType != .unspecified
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let photoData = place.photoData, let image = UIImage(data: photoData) {
                let aspect = PlaceCardMetrics.clampedPhotoAspect(for: image)
                Color.clear
                    .aspectRatio(aspect, contentMode: .fit)
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
                    .contentShape(Rectangle())
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let subtitle {
                    Text(subtitle)
                        .font(.appCaption)
                        .foregroundStyle(textSecondary)
                        .lineLimit(2)
                }
                
                if showsType {
                    HStack(spacing: 5) {
                        AppIcon(systemName: place.placeType.iconSystemName, size: 11, color: textSecondary)
                        Text(place.placeType.title)
                            .font(.app(11, weight: .semibold))
                    }
                    .foregroundStyle(textSecondary)
                    .padding(.top, 1)
                }
                
                if let tripBadge {
                    Text(tripBadge)
                        .font(.app(11, weight: .semibold))
                        .foregroundStyle(textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(columnStroke, in: Capsule(style: .continuous))
                        .padding(.top, 2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .modifier(PlaceCardGlassBackground(fallback: dayBackground))
    }
}

private struct PlaceCardGlassBackground: ViewModifier {
    let fallback: Color
    private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
                .clipShape(shape)
        } else {
            content
                .background(fallback, in: shape)
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 8)
        }
    }
}
