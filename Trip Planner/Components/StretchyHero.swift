import SwiftUI

/// Full-bleed hero that keeps a fixed aspect ratio and grows into rubber-band overscroll.
struct StretchyHero<Content: View>: View {
    var aspectRatio: CGFloat = 1
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .global).minY
            let stretch = max(0, minY)
            let scrollFade = minY >= 0 ? 1.0 : max(0.2, 1 + minY / 200)
            
            content()
                .frame(width: geo.size.width, height: geo.size.height + stretch)
                .clipped()
                .overlay {
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.42), location: 0),
                            .init(color: Color.black.opacity(0.10), location: 0.32),
                            .init(color: Color.clear, location: 0.62)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .opacity(scrollFade)
                    .allowsHitTesting(false)
                }
                .offset(y: -stretch)
        }
        .containerRelativeFrame(.horizontal)
        .aspectRatio(aspectRatio, contentMode: .fit)
        .contentShape(Rectangle())
    }
}
