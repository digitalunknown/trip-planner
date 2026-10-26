import SwiftUI
import UIKit

enum PlaceCardMetrics {
    /// Inner padding around the text block inside the card.
    static let textPadding: CGFloat = 12
    /// Gap between masonry items (matches column spacing).
    static let itemSpacing: CGFloat = AppSpacing.columnGap
    /// Approximate padded title + type for masonry balancing.
    static let textBlockEstimate: CGFloat = 70
    /// Clamp so ultra-wide / ultra-tall photos don't break the grid.
    static let minPhotoAspect: CGFloat = 0.72  // tall
    static let maxPhotoAspect: CGFloat = 1.6   // wide
    
    static func clampedPhotoAspect(for image: UIImage) -> CGFloat {
        let raw = image.size.width / max(image.size.height, 1)
        return min(max(raw, minPhotoAspect), maxPhotoAspect)
    }
    
    static func estimatedHeight(for place: Place, columnWidth: CGFloat) -> CGFloat {
        let aspect: CGFloat
        if let data = place.photoData, let image = UIImage(data: data) {
            aspect = clampedPhotoAspect(for: image)
        } else {
            aspect = TripVisualMetrics.coverAspectRatio
        }
        return (columnWidth / aspect) + textBlockEstimate
    }
}

struct PlaceCardView: View {
    let place: Place
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var title: String {
        PlaceNaming.displayTitle(name: place.name, location: place.location)
    }
    
    private var typeLabel: String? {
        place.placeType == .unspecified ? nil : place.placeType.title
    }
    
    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: TripVisualMetrics.coverRadius, style: .continuous)
    }
    
    private var cardStroke: Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.08)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            visual
            details
                .padding(PlaceCardMetrics.textPadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            cardShape.fill(AppDetailSurface.card)
        }
        .overlay {
            cardShape.strokeBorder(cardStroke, lineWidth: 1)
        }
        .clipShape(cardShape)
        .contentShape(cardShape)
    }
    
    private var visual: some View {
        Group {
            if let photoData = place.photoData, let image = UIImage(data: photoData) {
                let aspect = PlaceCardMetrics.clampedPhotoAspect(for: image)
                Color.clear
                    .aspectRatio(aspect, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        FillCroppedImage(image: image)
                    }
                    .clipped()
                    .contentShape(Rectangle())
            } else {
                Color.clear
                    .aspectRatio(TripVisualMetrics.coverAspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay {
                                AppIcon(lucide: place.placeType.mapIconName, size: 24, color: AppColor.textWeak)
                            }
                    }
                    .clipped()
                    .contentShape(Rectangle())
            }
        }
    }
    
    private var details: some View {
        VStack(alignment: .leading, spacing: AppSpacing.stackMicro) {
            Text(title)
                .font(.app(15, weight: .semibold))
                .foregroundStyle(AppColor.textStrong)
                .lineLimit(2)
            
            if let typeLabel {
                Text(typeLabel)
                    .font(.app(13, weight: .medium))
                    .foregroundStyle(AppColor.textWeak)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
    }
}
