import SwiftUI

struct TrackersHomeView: View {
    @StateObject private var store = TrackerStore()
    @State private var showComingSoon = false
    @State private var isShowingPassport = false
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.colorScheme) private var colorScheme
    @Environment(TripStore.self) private var tripStore
    
    private var dayBackground: Color { colorScheme == .dark ? Color(hex: 0x171717) : Color(hex: 0xF0F0F0) }
    private var columnStroke: Color { colorScheme == .dark ? Color(hex: 0x252525) : Color(hex: 0xFFFFFF) }
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var textSecondary: Color { textPrimary.opacity(colorScheme == .dark ? 0.72 : 0.62) }
    
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
        SwiftUI.ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 12) {
                passportCard
                
                let columns: [GridItem] = [
                    GridItem(.flexible(), spacing: 12, alignment: .top),
                    GridItem(.flexible(), spacing: 12, alignment: .top)
                ]
                
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(TrackerType.allCases) { type in
                        NavigationLink(value: type) {
                            TrackerRowCard(
                                type: type,
                                visitedCount: store.visitedCount(in: type),
                                totalCount: TrackerData.items(for: type).count
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showComingSoon = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.medium)
                }
            }
        }
        .navigationDestination(for: TrackerType.self) { type in
            TrackerDetailView(type: type, store: store)
        }
        .navigationDestination(isPresented: $isShowingPassport) {
            PassportView()
        }
        .sheet(isPresented: $showComingSoon) {
            NavigationStack {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Coming Soon")
                        .font(.title2.weight(.bold))
                    Text("Custom trackers are coming soon.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
                .navigationTitle("Add Tracker")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        LiquidGlassIconButton(systemName: "xmark") { showComingSoon = false }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        LiquidGlassIconButton(systemName: "checkmark") { showComingSoon = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    private var passportCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Passport")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(textPrimary)
                    Text("Stamps from completed trips")
                        .font(.caption)
                        .foregroundStyle(textSecondary)
                }
                
                Spacer(minLength: 0)
                
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(textSecondary)
            }
            
            if completedTrips.isEmpty {
                Text("Complete a trip to earn your first stamp.")
                    .font(.subheadline)
                    .foregroundStyle(textSecondary)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                TabView {
                    ForEach(Array(completedTrips.prefix(12))) { trip in
                        PassportStampView(
                            destination: trip.destination,
                            iconSystemName: "globe",
                            date: trip.endDate,
                            size: passportStampSize,
                            tint: .primary
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding(.top, 6)
                        .padding(.bottom, 48)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: passportStampSize + 92)
                .padding(.top, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(dayBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(columnStroke)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            isShowingPassport = true
        }
    }
}

