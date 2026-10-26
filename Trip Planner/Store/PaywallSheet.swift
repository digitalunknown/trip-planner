import StoreKit
import SwiftUI

private let paywallPhotoURLs: [URL] = [
    "https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=800&q=80",
    "https://images.unsplash.com/photo-1523906834658-6e24ef2386f9?w=800&q=80",
    "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80",
    "https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=800&q=80",
    "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=800&q=80",
    "https://images.unsplash.com/photo-1516483638261-f4dbaf036963?w=800&q=80"
].compactMap(URL.init(string:))

struct PaywallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PremiumStore.self) private var premium
    
    private let photoURLs = paywallPhotoURLs
    
    /// Matches the large-sheet curve (~38–40) minus the 8pt inset so tiles sit concentrically.
    private let photoRadius: CGFloat = 32
    private let photoGap: CGFloat = 8
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let photoHeight = geo.size.height * 0.56
                ZStack(alignment: .top) {
                    AppColor.page.ignoresSafeArea()
                    
                    photoGrid
                        .frame(height: photoHeight)
                        .overlay {
                            AppColor.page.opacity(0.42)
                                .allowsHitTesting(false)
                        }
                        .overlay(alignment: .bottom) {
                            LinearGradient(
                                colors: [
                                    .clear,
                                    AppColor.page.opacity(0.55),
                                    AppColor.page.opacity(0.92),
                                    AppColor.page
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 220)
                            .allowsHitTesting(false)
                        }
                        .ignoresSafeArea(edges: .top)
                    
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        
                        VStack(spacing: AppSpacing.md) {
                            headline
                            planCard
                            trustRow
                            continueButton
                            legal
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.bottom, AppSpacing.md)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Restore") {
                        Task { await premium.restore() }
                    }
                    .font(.app(15, weight: .medium))
                    .foregroundStyle(AppColor.textStrong)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .environment(\.font, .app(15, weight: .medium))
        }
        .tint(AppColor.textStrong)
        .preferredColorScheme(.dark)
        .presentationBackground(AppColor.page)
        .task {
            await premium.refresh()
        }
        .onChange(of: premium.isPremium) { _, isPremium in
            if isPremium { dismiss() }
        }
    }
    
    private var photoGrid: some View {
        GeometryReader { geo in
            let h = geo.size.height
            HStack(alignment: .top, spacing: photoGap) {
                VStack(spacing: photoGap) {
                    photo(at: 0)
                        .frame(height: h * 0.62)
                    photo(at: 1)
                        .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: photoGap) {
                    photo(at: 2)
                        .frame(height: h * 0.36)
                    photo(at: 3)
                        .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: photoGap) {
                    photo(at: 4)
                        .frame(maxHeight: .infinity)
                    photo(at: 5)
                        .frame(height: h * 0.44)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .padding(.horizontal, photoGap)
        .padding(.top, photoGap)
    }
    
    private func photo(at index: Int) -> some View {
        let url = photoURLs.indices.contains(index) ? photoURLs[index] : nil
        return PaywallPhotoTile(url: url, cornerRadius: photoRadius)
    }
    
    private var headline: some View {
        VStack(spacing: AppSpacing.xs) {
            Text("TripStacks+")
                .font(.app(17, weight: .bold))
                .foregroundStyle(
                    AppColor.plusGradient
                )
            Text("Plan without limits")
                .font(.app(30, weight: .semibold))
                .foregroundStyle(AppColor.textStrong)
                .multilineTextAlignment(.center)
                .lineSpacing(-4)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Text("Unlimited AI trip planning and place finding, plus local insights from real travelers")
                .font(.app(15, weight: .medium))
                .foregroundStyle(AppColor.textStrong)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var displayPrice: String {
        premium.monthlyProduct?.displayPrice ?? "$1.99"
    }
    
    private var planCard: some View {
        HStack(spacing: AppSpacing.sm) {
            AppIcon(lucide: "circle-check-big", size: AppLucide.fieldSize, color: AppColor.accent)
            
            VStack(alignment: .leading, spacing: 0) {
                Text("\(displayPrice) monthly")
                    .font(.app(17, weight: .semibold))
                    .foregroundStyle(AppColor.textStrong)
                Text("Special launch price ends soon")
                    .font(.app(13, weight: .medium))
                    .foregroundStyle(AppColor.textWeak)
            }
            
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .background(AppColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(AppColor.accent, lineWidth: 1.5)
        }
    }
    
    private var trustRow: some View {
        HStack(spacing: 6) {
            AppIcon(lucide: "shield-check", size: 16, color: AppColor.textWeak)
            Text("Secured with the App Store. Cancel anytime.")
                .font(.app(13, weight: .medium))
                .foregroundStyle(AppColor.textWeak)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var continueButton: some View {
        Button {
            guard let product = premium.monthlyProduct ?? premium.offeredProducts.first else { return }
            Task { await premium.purchase(product) }
        } label: {
            Text(premium.isPurchasing ? "Purchasing…" : "Unlock TripStacks+")
                .font(.app(17, weight: .semibold))
                .foregroundStyle(AppColor.page)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColor.textStrong, in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(premium.isPurchasing ? 0.7 : 1)
    }
    
    private var legal: some View {
        Link("Terms of Use and Privacy Policy", destination: PremiumProductID.appleEULA)
            .font(.app(13, weight: .medium))
            .foregroundStyle(AppColor.textWeak)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }
}

private struct PaywallPhotoTile: View {
    let url: URL?
    let cornerRadius: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            Group {
                if let url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        default:
                            AppColor.elevated
                                .frame(width: geo.size.width, height: geo.size.height)
                        }
                    }
                } else {
                    AppColor.elevated
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
