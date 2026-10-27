import SwiftUI

/// Shared background + subtle stroke for trip-board cards (activities, flights, reminders).
/// - Dark mode: adds a soft 1pt white hairline to distinguish cards from the day column glass.
/// - Light mode: matches existing 1pt shadowed black stroke.
struct BoardCardChrome: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    
    private var strokeColor: Color { Color.black.opacity(0.08) } // light mode only
    
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                shape.fill(AppDetailSurface.boardCard)
            }
            .overlay {
                Group {
                    if colorScheme == .light {
                        shape.strokeBorder(strokeColor, lineWidth: 1)
                    }
                }
            }
            .clipShape(shape)
            .contentShape(shape)
    }
}

extension View {
    func boardCardChrome(cornerRadius: CGFloat) -> some View {
        modifier(BoardCardChrome(cornerRadius: cornerRadius))
    }
}

