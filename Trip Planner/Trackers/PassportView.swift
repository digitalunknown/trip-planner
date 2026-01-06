import SwiftUI

struct PassportView: View {
    @Environment(TripStore.self) private var tripStore
    @Environment(\.colorScheme) private var colorScheme
    
    private let passportStampSize: CGFloat = 200
    
    private var pageBackground: Color { colorScheme == .dark ? Color(hex: 0x0A0A0A) : Color(hex: 0xE0E0E0) }
    
    private var completedTrips: [Trip] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return tripStore.trips
            .filter { trip in
                let end = calendar.startOfDay(for: trip.endDate)
                return end < today
            }
            .sorted { $0.endDate > $1.endDate }
    }
    
    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 28) {
                    ForEach(completedTrips) { trip in
                        PassportStampView(
                            destination: trip.destination,
                            iconSystemName: "globe",
                            date: trip.endDate,
                            size: passportStampSize,
                            tint: .primary
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
            }
        }
        .navigationTitle("Stamps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}


