import SwiftUI
import UIKit

/// Rounded-square map pin matching card icon badges (52×52, radius 12) with a bottom pointer.
struct SquareMapPinView: View {
    /// Matches activity / travel card icon badge size.
    var size: CGFloat = 52
    var image: UIImage? = nil
    var fallbackColor: Color = Color(hex: 0x4DA1F7)
    var fallbackSystemImage: String? = nil
    /// When set, used for the glyph instead of a darkened `fallbackColor`.
    var glyphColor: Color? = nil
    var borderWidth: CGFloat = 3.5
    var isSelected: Bool = false
    /// Optional count badge (top-trailing), e.g. stacked places.
    var badgeCount: Int? = nil
    
    /// Matches card badge corner radius at the default size.
    private var cornerRadius: CGFloat { size * (12.0 / 52.0) }
    private var iconSize: CGFloat { size * (26.0 / 52.0) }
    private var pointerWidth: CGFloat { size * 0.30 }
    private var pointerHeight: CGFloat { size * 0.18 }
    private var outlineColor: Color { .black }
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var innerStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.14)
    }
    
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
    
    /// Dark tint of the pin fill so icons stay readable on pastel backgrounds.
    private var iconColor: Color {
        if let glyphColor { return glyphColor }
        return Color(UIColor(fallbackColor).darkenedForMapPinIcon())
    }
    
    var body: some View {
        VStack(spacing: -1) {
            ZStack(alignment: .topTrailing) {
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
                            AppIcon(
                                systemName: fallbackSystemImage,
                                size: iconSize,
                                color: iconColor
                            )
                        }
                    }
                }
                .frame(width: size, height: size)
                .clipShape(shape)
                .overlay {
                    shape.strokeBorder(innerStrokeColor, lineWidth: 1)
                }
                .overlay {
                    shape.strokeBorder(
                        outlineColor,
                        lineWidth: isSelected ? borderWidth + 0.5 : borderWidth
                    )
                }
                
                if let badgeCount, badgeCount > 0 {
                    Text("\(min(badgeCount, 99))")
                        .font(.system(size: max(9, size * 0.28), weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: size * 0.42, height: size * 0.42)
                        .background(Circle().fill(outlineColor))
                        .overlay {
                            Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                        }
                        .offset(x: size * 0.12, y: -size * 0.12)
                }
            }
            
            MapPinPointer()
                .fill(outlineColor)
                .frame(width: pointerWidth, height: pointerHeight)
        }
        .scaleEffect(isSelected ? 1.08 : 1)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

/// Downward triangle tip that sits under the pin body.
private struct MapPinPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private extension UIColor {
    /// Mix toward black while keeping hue, for pin glyph contrast on light fills.
    func darkenedForMapPinIcon(towardBlack: CGFloat = 0.62) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return self
        }
        let t = min(max(towardBlack, 0), 1)
        return UIColor(
            red: r * (1 - t),
            green: g * (1 - t),
            blue: b * (1 - t),
            alpha: a
        )
    }
}
