import SwiftUI

struct PassportView: View {
    @Environment(TripStore.self) private var tripStore
    
    private let passportStampSize: CGFloat = 200
    
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
        .navigationTitle("Passport")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}


