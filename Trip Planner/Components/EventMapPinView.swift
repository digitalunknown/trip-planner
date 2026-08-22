import SwiftUI

/// Map annotation pin using stored activity photos only.
/// Does not fetch Look Around / map snapshots (that OOM'd trips with many pins).
struct EventMapPinView: View {
    let event: EventItem
    var fallbackColor: Color? = nil
    
    private var pinFill: Color { fallbackColor ?? event.accent.background }
    private var pinGlyph: Color { event.accent.foreground }
    
    var body: some View {
        SquareMapPinView(
            image: MapPinImageCache.image(for: event),
            fallbackColor: pinFill,
            fallbackSystemImage: event.icon,
            glyphColor: pinGlyph
        )
    }
}
