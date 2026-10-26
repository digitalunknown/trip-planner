import SwiftUI

enum SignInOnboardingPage: Int, CaseIterable, Identifiable {
    case plan
    case ai
    case places
    case explore
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .plan: return "Organize Each Day"
        case .ai: return "Plan with AI"
        case .places: return "Find and Save the Best Places"
        case .explore: return "Explore Real Itineraries and Tips"
        }
    }
    
    var subtitle: String {
        switch self {
        case .plan:
            return "Build itineraries with activities, flights, and checklists."
        case .ai:
            return "Generate a day or a whole trip, and find the best places to add to your board."
        case .places:
            return "Keep restaurants, stays, and ideas ready for the next trip."
        case .explore:
            return "Browse curated trips, then tap into insights and tips from real travelers who know the place."
        }
    }
    
    var overlaysCopyOnVisual: Bool { self == .places }
}

struct SignInOnboardingPager: View {
    @Binding var page: Int
    
    var body: some View {
        TabView(selection: $page) {
            ForEach(SignInOnboardingPage.allCases) { item in
                SignInOnboardingSlide(page: item)
                    .tag(item.rawValue)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(AppDetailSurface.page)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.28), value: page)
    }
}

private struct SignInOnboardingSlide: View {
    let page: SignInOnboardingPage
    
    var body: some View {
        GeometryReader { geo in
            if page.overlaysCopyOnVisual {
                overlaySlide(size: geo.size)
            } else {
                stackedSlide(size: geo.size)
            }
        }
    }
    
    private func stackedSlide(size: CGSize) -> some View {
        let visualBudget = max(180, size.height - 132)
        let scale = min(1, visualBudget / 440, size.width / 360)
        
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            
            visual
                .frame(width: 360, height: 440)
                .clipped()
                .scaleEffect(scale, anchor: .center)
                .frame(width: 360 * scale, height: 440 * scale)
                .clipped()
            
            Spacer(minLength: AppSpacing.md)
            
            copyBlock
            
            Spacer(minLength: 0)
        }
        .frame(width: size.width, height: size.height)
    }
    
    private func overlaySlide(size: CGSize) -> some View {
        ZStack {
            visual
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
            
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [AppColor.page, AppColor.page.opacity(0.72), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 72)
                .allowsHitTesting(false)
                
                Spacer(minLength: 0)
                
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
                .frame(height: 160)
                .allowsHitTesting(false)
                
                copyBlock
                    .padding(.bottom, AppSpacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(AppColor.page)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
    
    private var copyBlock: some View {
        VStack(spacing: AppSpacing.xs) {
            Text(page.title)
                .font(.app(30, weight: .semibold))
                .foregroundStyle(AppColor.textStrong)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(page.subtitle)
                .font(.app(15, weight: .medium))
                .foregroundStyle(AppColor.textWeak)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 36)
    }
    
    @ViewBuilder
    private var visual: some View {
        switch page {
        case .plan:
            SignInHeroAnimation()
        case .ai:
            SignInAIHero()
        case .places:
            SignInPlacesHero()
        case .explore:
            SignInExploreHero()
        }
    }
}

struct SignInOnboardingPageDots: View {
    let count: Int
    let current: Int
    
    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? AppColor.textStrong : AppColor.elevated)
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}

// MARK: - AI slide

private struct SignInAIHero: View {
    @State private var promptText = ""
    @State private var startedAt = Date()
    
    private let prompts = SignInAIPrompt.all
    private let rowHeight: CGFloat = 52
    private let scrollSpeed: CGFloat = 16
    
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            GeometryReader { geo in
                let loopHeight = rowHeight * CGFloat(prompts.count)
                
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    let elapsed = context.date.timeIntervalSince(startedAt)
                    let y = (CGFloat(elapsed) * scrollSpeed)
                        .truncatingRemainder(dividingBy: max(loopHeight, 1))
                    
                    VStack(spacing: 0) {
                        ForEach(0..<2, id: \.self) { copy in
                            ForEach(prompts) { prompt in
                                chip(prompt)
                                    .frame(height: rowHeight)
                                    .id("\(copy)-\(prompt.id)")
                            }
                        }
                    }
                    .offset(y: -y)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                }
                .clipped()
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [AppColor.page, AppColor.page.opacity(0.7), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 56)
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, AppColor.page.opacity(0.75), AppColor.page],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 72)
                    .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            
            AIPromptSingleLineField(
                text: $promptText,
                placeholder: "Plan a weekend in Lisbon…"
            )
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(width: 360, height: 440)
        .clipped()
    }
    
    private func chip(_ prompt: SignInAIPrompt) -> some View {
        HStack(spacing: 14) {
            AppIcon(lucide: prompt.lucide, size: 18, color: AppColor.textStrong)
                .frame(width: 36, height: 36)
                .background(AppColor.elevated, in: Circle())
            
            Text(prompt.title)
                .font(.app(15, weight: .medium))
                .foregroundStyle(AppColor.textStrong)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
        }
    }
}

private struct SignInAIPrompt: Identifiable {
    let id: Int
    let title: String
    let lucide: String
    
    init(_ id: Int, _ title: String, _ lucide: String) {
        self.id = id
        self.title = title
        self.lucide = lucide
    }
    
    static let all: [SignInAIPrompt] = [
        .init(0, "Plan a 5 day trip to Tokyo", "map"),
        .init(1, "Find the best restaurants in Lisbon", "utensils"),
        .init(2, "Build tomorrow in Kyoto", "calendar"),
        .init(3, "Plan a weekend near you", "map-pin"),
        .init(4, "Plan a 3 day trip to New York", "building-2"),
        .init(5, "A food and drink focused day", "utensils"),
        .init(6, "Plan a 5 day trip to Paris", "landmark"),
        .init(7, "Restaurants near you", "utensils"),
        .init(8, "Plan a 3 day trip to Miami", "umbrella"),
        .init(9, "An adventurous day", "mountain"),
        .init(10, "Plan a 5 day trip to Rome", "landmark"),
        .init(11, "Great stays near you", "hotel"),
        .init(12, "Photography day", "camera"),
        .init(13, "A 3 day adventure in Yellowstone", "tree-palm"),
        .init(14, "Activities near you", "map-pinned"),
        .init(15, "Plan a 3 day trip to Los Angeles", "sun"),
        .init(16, "A day of sightseeing", "binoculars"),
        .init(17, "Plan a 3 day trip to Toronto", "building-2"),
        .init(18, "Fun with kids", "baby"),
        .init(19, "Find the best cafes in Melbourne", "coffee")
    ]
}

// MARK: - Places slide

private struct SignInPlaceItem: Identifiable {
    let id: Int
    let name: String
    let type: PlaceType
    let aspect: CGFloat
    let photoURL: URL?
    
    init(_ id: Int, _ name: String, _ type: PlaceType, _ aspect: CGFloat, _ url: String) {
        self.id = id
        self.name = name
        self.type = type
        self.aspect = min(max(aspect, PlaceCardMetrics.minPhotoAspect), PlaceCardMetrics.maxPhotoAspect)
        self.photoURL = URL(string: url)
    }
    
    static let all: [SignInPlaceItem] = [
        .init(0, "Ichiran Ramen", .restaurant, 0.78, "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=700&q=80"),
        .init(1, "Park Hyatt Tokyo", .hotel, 1.55, "https://images.unsplash.com/photo-1611892440504-42a792e24d32?w=700&q=80"),
        .init(2, "Meiji Jingu", .park, 1.48, "https://images.unsplash.com/photo-1545569341-9eb8b30979d9?w=700&q=80"),
        .init(3, "Fushimi Inari", .attraction, 0.72, "https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=700&q=80"),
        .init(4, "Café A Brasileira", .cafe, 0.86, "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=700&q=80"),
        .init(5, "Employees Only", .bar, 1.6, "https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=700&q=80"),
        .init(6, "Colosseum", .attraction, 0.95, "https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=700&q=80"),
        .init(7, "Four Seasons", .hotel, 1.42, "https://images.unsplash.com/photo-1439066615861-d1af74d74000?w=700&q=80"),
        .init(8, "teamLab Planets", .museum, 0.74, "https://images.unsplash.com/photo-1542051841857-5f90071e7989?w=700&q=80"),
        .init(9, "Bondi Beach", .beach, 1.52, "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=700&q=80")
    ]
}

private struct SignInPlacesHero: View {
    @State private var showItems = false
    
    private let items = SignInPlaceItem.all
    
    var body: some View {
        GeometryReader { geo in
            let columnWidth = max(
                (geo.size.width - RootHomeMetrics.horizontalInset * 2 - PlaceCardMetrics.itemSpacing) / 2,
                140
            )
            let columns = masonryColumns(columnWidth: columnWidth)
            
            HStack(alignment: .top, spacing: PlaceCardMetrics.itemSpacing) {
                masonryColumn(columns.left, columnWidth: columnWidth, delay: 0)
                masonryColumn(columns.right, columnWidth: columnWidth, delay: 0.06)
            }
            .padding(.horizontal, RootHomeMetrics.horizontalInset)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                showItems = true
            }
        }
    }
    
    private func masonryColumn(_ items: [SignInPlaceItem], columnWidth: CGFloat, delay: Double) -> some View {
        VStack(spacing: PlaceCardMetrics.itemSpacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                placeCard(item, columnWidth: columnWidth)
                    .opacity(showItems ? 1 : 0)
                    .offset(y: showItems ? 0 : 24)
                    .animation(
                        .spring(response: 0.8, dampingFraction: 0.78)
                            .delay(delay + 0.045 * Double(index)),
                        value: showItems
                    )
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .top)
    }
    
    private func masonryColumns(columnWidth: CGFloat) -> (left: [SignInPlaceItem], right: [SignInPlaceItem]) {
        var left: [SignInPlaceItem] = []
        var right: [SignInPlaceItem] = []
        var leftHeight: CGFloat = 0
        var rightHeight: CGFloat = 0
        
        for item in items {
            let estimate = (columnWidth / item.aspect) + PlaceCardMetrics.textBlockEstimate
            if leftHeight <= rightHeight {
                left.append(item)
                leftHeight += estimate + PlaceCardMetrics.itemSpacing
            } else {
                right.append(item)
                rightHeight += estimate + PlaceCardMetrics.itemSpacing
            }
        }
        return (left, right)
    }
    
    private func placeCard(_ item: SignInPlaceItem, columnWidth: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: TripVisualMetrics.coverRadius, style: .continuous)
        let photoHeight = columnWidth / item.aspect
        return VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(width: columnWidth, height: photoHeight)
                .overlay {
                    SplashRemotePhoto(url: item.photoURL, lucide: item.type.mapIconName)
                }
                .clipped()
                .contentShape(Rectangle())
            
            VStack(alignment: .leading, spacing: AppSpacing.stackMicro) {
                Text(item.name)
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(AppColor.textStrong)
                    .lineLimit(2)
                Text(item.type.title)
                    .font(.app(13, weight: .medium))
                    .foregroundStyle(AppColor.textWeak)
                    .lineLimit(1)
            }
            .padding(PlaceCardMetrics.textPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(AppDetailSurface.card))
        .clipShape(shape)
    }
}

// MARK: - Explore slide

private struct SignInExploreHero: View {
    @State private var showItems = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            exploreCard
                .opacity(showItems ? 1 : 0)
                .offset(y: showItems ? 0 : 24)
            
            insightsCard
                .opacity(showItems ? 1 : 0)
                .offset(y: showItems ? 0 : 36)
        }
        .frame(width: 300)
        .frame(width: 360, height: 440, alignment: .center)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.78)) {
                    showItems = true
                }
            }
        }
    }
    
    private var exploreCard: some View {
        let imageShape = RoundedRectangle(cornerRadius: TripVisualMetrics.coverRadius, style: .continuous)
        return VStack(alignment: .leading, spacing: TripVisualMetrics.imageToTextGap) {
            Color.clear
                .aspectRatio(TripVisualMetrics.coverAspectRatio, contentMode: .fit)
                .overlay {
                    SplashRemotePhoto(
                        url: URL(string: "https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800&q=80"),
                        lucide: "map-pinned"
                    )
                }
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, AppColor.page.opacity(0.55), AppColor.page],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 80)
                    .opacity(showItems ? 1 : 0)
                    .animation(.easeOut(duration: 0.55).delay(0.18), value: showItems)
                }
                .overlay(alignment: .topTrailing) {
                    CoverOverlayBadge(lucide: "star", text: "Staff pick", style: .muted)
                        .padding(TripVisualMetrics.overlayInset)
                }
                .clipShape(imageShape)
            
            VStack(alignment: .leading, spacing: AppSpacing.stackMicro) {
                Text("A Long Weekend in Tokyo")
                    .font(.app(17, weight: .semibold))
                    .foregroundStyle(AppColor.textStrong)
                    .lineLimit(2)
                Text("Tokyo · 12 places")
                    .font(.app(13, weight: .medium))
                    .foregroundStyle(AppColor.textWeak)
                    .lineLimit(1)
            }
        }
    }
    
    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: 10) {
                AppIcon(lucide: "user-star", size: AppLucide.fieldSize, color: AppColor.expert)
                Text("Local insights")
                    .font(.app(15, weight: .medium))
                    .foregroundStyle(AppColor.expert)
            }
            
            Text("Skip the main shrine gate after 4pm — locals use the south entrance when the path is quieter.")
                .font(.app(15, weight: .medium))
                .foregroundStyle(AppColor.textStrong)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPadding)
        .background(
            AppColor.card,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .expertTipOutlineShine(cornerRadius: 20)
    }
}

private struct SplashRemotePhoto: View {
    let url: URL?
    let lucide: String
    
    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
            default:
                AppColor.elevated
                    .overlay {
                        AppIcon(lucide: lucide, size: 22, color: AppColor.textWeak)
                    }
            }
        }
    }
}
