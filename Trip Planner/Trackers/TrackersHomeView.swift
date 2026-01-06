import SwiftUI

struct TrackersHomeView: View {
    @StateObject private var store = TrackerStore()
    @State private var showComingSoon = false
    @State private var isShowingPassport = false
    @State private var passportPageIndex: Int = 0
    @State private var isPagingPassport: Bool = false
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.colorScheme) private var colorScheme
    @Environment(TripStore.self) private var tripStore
    
    private var dayBackground: Color { colorScheme == .dark ? Color(hex: 0x171717) : Color(hex: 0xF0F0F0) }
    private var columnStroke: Color { colorScheme == .dark ? Color(hex: 0x252525) : Color(hex: 0xFFFFFF) }
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var textSecondary: Color { textPrimary.opacity(colorScheme == .dark ? 0.72 : 0.62) }
    private var inactivePageDotColor: Color { colorScheme == .dark ? columnStroke : Color(.systemGray3) }
    
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
                    tripsTakenCard
                    
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
        .background(Color(.systemGroupedBackground))
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
    
    private var tripsTakenCard: some View {
        let tripsTaken = completedTrips.count
        let totalBars = 16
        let filled = min(tripsTaken, totalBars)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trips Taken")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(textPrimary)
                        .lineLimit(1)
                    
                    Text("Logged in this app")
                        .font(.caption)
                        .foregroundStyle(textSecondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 0)
            }
            
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [appAccentColor.opacity(0.22), appAccentColor.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Image(systemName: "suitcase.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [appAccentColor, appAccentColor.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(width: 58, height: 58)
                
                Spacer(minLength: 0)
            }
            
            Text("\(tripsTaken)")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(textPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.9)
            
            HStack(spacing: 4) {
                ForEach(0..<totalBars, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(idx < filled ? appAccentColor : columnStroke)
                        .frame(height: 28)
                }
            }
            .padding(.bottom, 6)
            .animation(.easeInOut(duration: 0.25), value: filled)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .background(dayBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(columnStroke)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 14)
    }
    
    private var passportCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stamps")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(textPrimary)
                    Text("You’ve completed \(completedTrips.count) \(completedTrips.count == 1 ? "trip" : "trips")")
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
                let trips = Array(completedTrips.prefix(12))
                
                TabView(selection: $passportPageIndex) {
                    ForEach(Array(trips.enumerated()), id: \.element.id) { idx, trip in
                        PassportStampView(
                            destination: trip.destination,
                            iconSystemName: "globe",
                            date: trip.endDate,
                            size: passportStampSize,
                            tint: .primary
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding(.top, 6)
                        .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: passportStampSize + 18)
                .padding(.top, 2)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { _ in isPagingPassport = true }
                        .onEnded { _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                isPagingPassport = false
                            }
                        }
                )
                
                HStack(spacing: 7) {
                    ForEach(0..<trips.count, id: \.self) { idx in
                        Capsule(style: .continuous)
                            .fill(idx == passportPageIndex ? textPrimary : inactivePageDotColor)
                            .frame(width: idx == passportPageIndex ? 16 : 7, height: 7)
                            .animation(.easeInOut(duration: 0.18), value: passportPageIndex)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(dayBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(columnStroke)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 14)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture {
            guard !isPagingPassport else { return }
            isShowingPassport = true
        }
    }
}

