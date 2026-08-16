import SwiftUI
import UIKit

/// Square map pin matching the trip-card map inset (rounded square + white border).
struct SquareMapPinView: View {
    var size: CGFloat = 36
    var image: UIImage? = nil
    var fallbackColor: Color = Color(hex: 0x4DA1F7)
    var fallbackSystemImage: String? = nil
    var borderWidth: CGFloat = 2
    var isSelected: Bool = false
    
    private var cornerRadius: CGFloat { size * (14.0 / 72.0) }
    
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
    
    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                shape
                    .fill(fallbackColor)
                    .frame(width: size, height: size)
                
                if let fallbackSystemImage {
                    Image(systemName: fallbackSystemImage)
                        .font(.app(16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(Color.white.opacity(0.92), lineWidth: isSelected ? borderWidth + 0.5 : borderWidth)
        }
        .shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 4)
        .scaleEffect(isSelected ? 1.08 : 1)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
