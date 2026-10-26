import SwiftUI
import UIKit

/// Shared trip row for search results and Add to Trip.
struct TripResultRow: View {
    let trip: Trip
    var subtitle: String? = nil
    
    private var resolvedSubtitle: String? {
        if let subtitle { return subtitle }
        let destination = trip.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        return destination.isEmpty ? nil : destination
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            thumbnail
            
            VStack(alignment: .leading, spacing: 0) {
                Text(trip.name)
                    .font(.app(15, weight: .medium))
                    .foregroundStyle(AppColor.textStrong)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let resolvedSubtitle {
                    Text(resolvedSubtitle)
                        .font(.app(13, weight: .medium))
                        .foregroundStyle(AppColor.textWeak)
                        .lineLimit(1)
                }
            }
            
            AppIcon(lucide: "chevron-right", size: AppLucide.fieldSize, color: AppColor.textWeak)
        }
        .padding(AppSpacing.fieldPadding)
        .background(AppColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    @ViewBuilder
    private var thumbnail: some View {
        if let data = trip.coverImageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColor.elevated)
                AppIcon(lucide: "backpack", size: 18, color: AppColor.textWeak)
            }
            .frame(width: 52, height: 52)
        }
    }
}
