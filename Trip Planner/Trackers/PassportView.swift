import SwiftUI

struct PassportView: View {
    @Environment(TripStore.self) private var tripStore
    @Environment(\.colorScheme) private var colorScheme
    
    private let stampWidth: CGFloat = 220
    
    private var pageBackground: Color { colorScheme == .dark ? Color(hex: 0x0A0A0A) : Color(hex: 0xE0E0E0) }
    private var dotColor: Color { colorScheme == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.08) }
    private var textSecondary: Color {
        (colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717))
            .opacity(colorScheme == .dark ? 0.72 : 0.62)
    }
    
    private var loggedCities: [String] {
        AchievementsCatalog.loggedCities(from: tripStore.trips)
    }
    
    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()
            DotGridBackground(color: dotColor, spacing: 18, dotDiameter: 2.3)
                .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 28) {
                    if loggedCities.isEmpty {
                        VStack(spacing: 12) {
                            Image(AchievementsCatalog.cityStampAsset)
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                                .frame(width: stampWidth)
                                .opacity(0.45)
                            Text("Complete a trip to earn your first city stamp.")
                                .font(.appCallout)
                                .foregroundStyle(textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 24)
                    } else {
                        ForEach(loggedCities, id: \.self) { city in
                            VStack(spacing: 10) {
                                Image(AchievementsCatalog.cityStampAsset)
                                    .resizable()
                                    .interpolation(.high)
                                    .scaledToFit()
                                    .frame(width: stampWidth)
                                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 16, y: 10)
                                Text(city)
                                    .font(.app(15, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 56)
                .padding(.horizontal, 16)
            }
        }
        .navigationTitle("Stamps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

private struct DotGridBackground: View {
    let color: Color
    let spacing: CGFloat
    let dotDiameter: CGFloat
    
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let r = dotDiameter / 2
            
            var y: CGFloat = spacing / 2
            while y <= size.height + spacing {
                var x: CGFloat = spacing / 2
                while x <= size.width + spacing {
                    path.addEllipse(in: CGRect(x: x - r, y: y - r, width: dotDiameter, height: dotDiameter))
                    x += spacing
                }
                y += spacing
            }
            
            context.fill(path, with: .color(color))
        }
        .allowsHitTesting(false)
    }
}
