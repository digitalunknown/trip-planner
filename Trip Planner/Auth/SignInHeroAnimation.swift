import SwiftUI

struct SignInHeroAnimation: View {
    @State private var head = 0
    @State private var didAppear = false
    
    private let cards = SplashStackItem.all
    private let visibleCount = 3
    
    private var visible: [SplashStackItem] {
        (0..<visibleCount).map { cards[(head + $0) % cards.count] }
    }
    
    var body: some View {
        ZStack {
            ForEach(Array(visible.enumerated()), id: \.element.id) { slot, item in
                SplashStackCard(item: item)
                    .offset(x: staggerX(slot), y: staggerY(slot))
                    .rotationEffect(.degrees(staggerAngle(slot)))
                    .zIndex(slot == 1 ? 3 : slot == 2 ? 2 : 1)
                    .opacity(didAppear ? 1 : 0)
                    .transition(
                        .asymmetric(
                            insertion: .offset(y: 170).combined(with: .opacity),
                            removal: .offset(y: -110).combined(with: .opacity)
                        )
                    )
            }
        }
        .frame(width: 360, height: 440)
        .onAppear {
            guard !didAppear else { return }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                didAppear = true
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(1600))
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(2400))
                withAnimation(.spring(response: 0.72, dampingFraction: 0.84)) {
                    head = (head + 1) % cards.count
                }
            }
        }
    }
    
    private func staggerX(_ slot: Int) -> CGFloat {
        switch slot {
        case 0: return -10
        case 2: return 10
        default: return 0
        }
    }
    
    private func staggerY(_ slot: Int) -> CGFloat {
        CGFloat(slot) * 52 - 48
    }
    
    private func staggerAngle(_ slot: Int) -> Double {
        switch slot {
        case 0: return -8
        case 2: return 8
        default: return 0
        }
    }
}

private struct SplashStackCard: View {
    let item: SplashStackItem
    @State private var photoData: Data?
    
    var body: some View {
        Group {
            switch item {
            case .activity(let activity):
                EventCard(event: activity.event(photoData: photoData))
            case .checklist(_, let checklist):
                ChecklistCard(checklist: checklist)
            }
        }
        .frame(width: 312)
        .shadow(color: Color.black.opacity(0.32), radius: 18, y: 12)
        .task(id: item.id) {
            await loadPhotoIfNeeded()
        }
    }
    
    private func loadPhotoIfNeeded() async {
        guard case .activity(let activity) = item, photoData == nil else { return }
        var request = URLRequest(url: activity.photoURL)
        request.timeoutInterval = 8
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else { return }
        photoData = data
    }
}

private enum SplashStackItem: Identifiable, Equatable {
    case activity(SplashActivityItem)
    case checklist(id: Int, checklist: ChecklistItem)
    
    var id: Int {
        switch self {
        case .activity(let item): return item.id
        case .checklist(let id, _): return id
        }
    }
    
    static let all: [SplashStackItem] = [
        .activity(.init(0, "Katz's Delicatessen", "New York, USA", "12:30 PM – 1:45 PM", .restaurant, .tangerine, "https://images.unsplash.com/photo-1551782450-17144efb9c50?w=800&q=80")),
        .activity(.init(1, "Hôtel Costes", "Paris, France", "3:00 PM – 4:00 PM", .hotel, .plum, "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800&q=80")),
        .checklist(id: 2, checklist: .splash("Packing List", [
            ("Passport", true),
            ("Camera", false),
            ("Sunglasses", false),
            ("Chargers", false)
        ])),
        .activity(.init(3, "Colosseum", "Rome, Italy", "9:00 AM – 11:30 AM", .attraction, .mustard, "https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=800&q=80")),
        .activity(.init(4, "Café A Brasileira", "Lisbon, Portugal", "8:15 AM – 9:00 AM", .cafe, .cream, "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=800&q=80")),
        .activity(.init(5, "Fushimi Inari", "Kyoto, Japan", "6:30 AM – 8:30 AM", .attraction, .burgundy, "https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=800&q=80")),
        .activity(.init(6, "Four Seasons", "Bora Bora, French Polynesia", "4:00 PM – 6:00 PM", .hotel, .blush, "https://images.unsplash.com/photo-1439066615861-d1af74d74000?w=800&q=80")),
        .activity(.init(7, "The British Museum", "London, UK", "11:00 AM – 2:00 PM", .museum, .ink, "https://images.unsplash.com/photo-1582555172866-f73bb12a2ab3?w=800&q=80")),
        .activity(.init(8, "Torres del Paine", "Patagonia, Chile", "7:00 AM – 4:00 PM", .hike, .forest, "https://images.unsplash.com/photo-1531761535209-180857e36376?w=800&q=80")),
        .activity(.init(9, "Employees Only", "New York, USA", "8:00 PM – 10:30 PM", .bar, .plum, "https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=800&q=80")),
        .activity(.init(10, "Jemaa el-Fnaa", "Marrakech, Morocco", "5:30 PM – 8:00 PM", .shopping, .tangerine, "https://images.unsplash.com/photo-1489749798305-4fea3ae63d43?w=800&q=80"))
    ]
}

private struct SplashActivityItem: Equatable {
    let id: Int
    let eventID: UUID
    let title: String
    let location: String
    let time: String
    let type: PlaceType
    let accent: EventAccent
    let photoURL: URL
    
    func event(photoData: Data?) -> EventItem {
        EventItem(
            id: eventID,
            title: title,
            description: "",
            time: time,
            location: location,
            latitude: nil,
            longitude: nil,
            icon: type.iconSystemName,
            accent: accent,
            photoData: photoData
        )
    }
    
    init(
        _ id: Int,
        _ title: String,
        _ location: String,
        _ time: String,
        _ type: PlaceType,
        _ accent: EventAccent,
        _ url: String
    ) {
        self.id = id
        self.eventID = UUID()
        self.title = title
        self.location = location
        self.time = time
        self.type = type
        self.accent = accent
        self.photoURL = URL(string: url)!
    }
}

private extension ChecklistItem {
    static func splash(_ title: String, _ rows: [(String, Bool)]) -> ChecklistItem {
        ChecklistItem(
            id: UUID(),
            title: title,
            items: rows.map { ChecklistEntry(id: UUID(), text: $0.0, isDone: $0.1) },
            createdAt: Date()
        )
    }
}

#Preview {
    SignInHeroAnimation()
        .background(AppColor.page)
}
