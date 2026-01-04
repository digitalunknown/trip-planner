import SwiftUI

struct PassportView: View {
    @State private var tripStore = TripStore()
    
    private var completedTrips: [Trip] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return tripStore.trips
            .filter { trip in
                let end = calendar.startOfDay(for: trip.endDate)
                return end < today
            }
            .sorted { $0.endDate < $1.endDate }
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 18) {
                ForEach(completedTrips) { trip in
                    PassportStampView(
                        destination: trip.destination,
                        iconSystemName: "airplane",
                        date: trip.endDate,
                        size: 180,
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

