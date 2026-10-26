import SwiftUI

struct PassportView: View {
    @Environment(TripStore.self) private var tripStore
    @Environment(\.colorScheme) private var colorScheme
    
    private let stampWidth: CGFloat = 220
    
    private var pageBackground: Color { AppColor.page }
    private var dotColor: Color { AppColor.divider }
    private var textSecondary: Color { AppColor.textWeak }
    
    private var loggedCities: [String] {
        AchievementsCatalog.loggedCities(from: tripStore.trips)
    }
    
    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()
            DotGridBackground(color: dotColor, spacing: 18, dotDiameter: 2.3)
                .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: AppSpacing.sectionGap) {
                    if loggedCities.isEmpty {
                        VStack(spacing: AppSpacing.sm) {
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
                            VStack(spacing: AppSpacing.sm) {
                                Image(AchievementsCatalog.stampAsset(forCityName: city))
                                    .resizable()
                                    .interpolation(.high)
                                    .scaledToFit()
                                    .frame(width: stampWidth)
                                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 16, y: 10)
                                Text(city)
                                    .font(.app(15, weight: .semibold))
                                    .foregroundStyle(AppColor.textStrong)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
                .padding(.top, AppSpacing.pageTop)
                .padding(.bottom, AppSpacing.pageBottom)
                .padding(.horizontal, AppSpacing.pageInset)
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
