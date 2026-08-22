import MapKit
import SwiftUI
import UIKit

struct EventCard: View {
    let event: EventItem
    /// When true and the event has no photo, load Look Around / map imagery for the cover.
    var loadsAppleMapsCover: Bool = false
    /// Called when an Apple Maps cover is fetched so the trip can persist `photoData`.
    var onResolvedAppleCover: ((Data) -> Void)? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var appleCoverData: Data?
    
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var textSecondary: Color { textPrimary.opacity(colorScheme == .dark ? 0.72 : 0.62) }
    private var cardShape: RoundedRectangle { RoundedRectangle(cornerRadius: 16, style: .continuous) }
    
    /// Lift over the day column — translucent in dark; solid white + stroke in light.
    private var cardFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.white
    }
    
    private var cardStroke: Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.08)
    }
    
    private var displayEvent: EventItem {
        if event.photoData != nil || appleCoverData == nil { return event }
        var copy = event
        copy.photoData = appleCoverData
        return copy
    }
    
    private var photoImage: UIImage? {
        guard let data = PlaceImageResolver.imageData(from: displayEvent) else { return nil }
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
        .overlay {
            cardShape.strokeBorder(cardStroke, lineWidth: 1)
        }
        .clipShape(cardShape)
        .contentShape(cardShape)
        .task(id: event.id) {
            await loadAppleMapsCoverIfNeeded()
        }
    }
    
    private func loadAppleMapsCoverIfNeeded() async {
        guard loadsAppleMapsCover else { return }
        guard event.photoData == nil, appleCoverData == nil else { return }
        
        let mapItem = await ApplePlaceLookup.mapItem(
            name: event.title,
            location: event.location,
            latitude: event.latitude,
            longitude: event.longitude,
            destinationHint: event.location
        )
        let data: Data?
        if let mapItem {
            data = await PlaceAppleImagery.coverJPEG(for: mapItem)
        } else if let latitude = event.latitude,
                  let longitude = event.longitude {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            data = CLLocationCoordinate2DIsValid(coordinate)
                ? await PlaceAppleImagery.coverJPEG(at: coordinate)
                : nil
        } else {
            data = await PlaceAppleImagery.coverJPEG(
                name: event.title,
                location: event.location,
                latitude: event.latitude,
                longitude: event.longitude
            )
        }
        guard let data else { return }
        appleCoverData = data
        onResolvedAppleCover?(data)
    }
    
    private func photoHeader(_ image: UIImage) -> some View {
        FixedAspectCover(aspectRatio: 16.0 / 9.0) {
            FillCroppedImage(image: image)
        }
    }
    
    private var iconBadge: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        let innerStroke = colorScheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.14)
        return ZStack {
            shape.fill(event.accent.background)
            AppIcon(systemName: event.icon, size: 26, strokeWidth: 2, color: event.accent.foreground)
        }
        .frame(width: 52, height: 52)
        .overlay {
            shape.strokeBorder(innerStroke, lineWidth: 1)
        }
    }
    
    private var detailsBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.title)
                .font(.app(13, weight: .semibold))
                .foregroundStyle(textPrimary)
                .lineLimit(2)
            if !event.location.isEmpty {
                Text(event.location)
                    .font(.app(13, weight: .regular))
                    .foregroundStyle(textSecondary)
                    .lineLimit(1)
            }
            if !event.time.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(event.time)
                    .font(.app(13, weight: .regular))
                    .foregroundStyle(textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
