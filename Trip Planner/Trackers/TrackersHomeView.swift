import SwiftUI

struct TrackersHomeView: View {
    @StateObject private var store = TrackerStore()
    @State private var showStatsSettings = false
    @State private var showCompletedTrips = false
    @State private var isShowingPassport = false
    @State private var passportPageIndex: Int = 0
    @State private var isPagingPassport: Bool = false
    @State private var presentedTracker: TrackerType?
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.colorScheme) private var colorScheme
    @Environment(TripStore.self) private var tripStore
    @AppStorage("hiddenStats") private var hiddenStatsRaw: String = ""
    
    private var dayBackground: Color { colorScheme == .dark ? Color(hex: 0x171717) : Color(hex: 0xF0F0F0) }
    private var columnStroke: Color { colorScheme == .dark ? Color(hex: 0x252525) : Color(hex: 0xFFFFFF) }
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var textSecondary: Color { textPrimary.opacity(colorScheme == .dark ? 0.72 : 0.62) }
    private var inactivePageDotColor: Color { colorScheme == .dark ? columnStroke : Color(.systemGray3) }
    
    private let passportStampSize: CGFloat = 220
    
    private var completedTrips: [Trip] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return tripStore.trips
            .filter { trip in
                guard trip.isDatesSet else { return false }
                let end = calendar.startOfDay(for: trip.endDate)
                return end < today
            }
            .sorted { $0.endDate > $1.endDate }
    }
    
    private var hiddenStats: Set<String> {
        Set(hiddenStatsRaw.split(separator: "|").map { String($0) }.filter { !$0.isEmpty })
    }
    
    private func statID(for tracker: TrackerType) -> String { "tracker:\(tracker.rawValue)" }
    
    private func isStatHidden(_ id: String) -> Bool { hiddenStats.contains(id) }
    
    private func setStatHidden(_ id: String, _ hidden: Bool) {
        var set = hiddenStats
        if hidden {
            set.insert(id)
        } else {
            set.remove(id)
        }
        hiddenStatsRaw = set.sorted().joined(separator: "|")
    }

    var body: some View {
        SwiftUI.ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 12) {
                if !completedTrips.isEmpty {
                    passportCard
                        .contextMenu {
                            Button {
                                isShowingPassport = true
                            } label: {
                                Label("View", systemImage: "arrow.right.circle")
                            }
                        }
                }
                
                let columns: [GridItem] = [
                    GridItem(.flexible(), spacing: 12, alignment: .top),
                    GridItem(.flexible(), spacing: 12, alignment: .top)
                ]
                
                LazyVGrid(columns: columns, spacing: 12) {
                    if !isStatHidden("tripsTaken") {
                        tripsTakenCard
                            .contextMenu {
                                Button {
                                    setStatHidden("tripsTaken", true)
                                } label: {
                                    Label("Hide", systemImage: "eye.slash")
                                }
                            }
                    }
                    
                    ForEach(TrackerType.allCases) { type in
                        if !isStatHidden(statID(for: type)) {
                            Button {
                                presentedTracker = type
                            } label: {
                                TrackerRowCard(
                                    type: type,
                                    visitedCount: store.visitedCount(in: type),
                                    totalCount: TrackerData.items(for: type).count
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    presentedTracker = type
                                } label: {
                                    Label("View", systemImage: "arrow.right.circle")
                                }
                                
                                Button {
                                    setStatHidden(statID(for: type), true)
                                } label: {
                                    Label("Hide", systemImage: "eye.slash")
                                }
                            }
                        }
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
                    showStatsSettings = true
                } label: {
                    Image(systemName: "switch.2")
                        .fontWeight(.medium)
                }
            }
        }
        .sheet(item: $presentedTracker) { type in
            NavigationStack {
                TrackerDetailView(type: type, store: store)
                    .navigationTitle(type.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            LiquidGlassIconButton(systemName: "xmark") { presentedTracker = nil }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isShowingPassport) {
            NavigationStack {
                PassportView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            LiquidGlassIconButton(systemName: "xmark") { isShowingPassport = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showStatsSettings) {
            NavigationStack {
                Form {
                    Toggle("Logged Trips", isOn: Binding(
                        get: { !isStatHidden("tripsTaken") },
                        set: { setStatHidden("tripsTaken", !$0) }
                    ))
                    .tint(appAccentColor)
                    
                    ForEach(TrackerType.allCases) { type in
                        Toggle(type.title, isOn: Binding(
                            get: { !isStatHidden(statID(for: type)) },
                            set: { setStatHidden(statID(for: type), !$0) }
                        ))
                        .tint(appAccentColor)
                    }
                }
                .navigationTitle("Edit Stats")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        LiquidGlassIconButton(systemName: "xmark") { showStatsSettings = false }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        LiquidGlassIconButton(systemName: "checkmark") { showStatsSettings = false }
                    }
                }
            }
            .tint(appAccentColor)
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCompletedTrips) {
            NavigationStack {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 16) {
                        ForEach(completedTrips) { trip in
                            TripCardView(trip: trip)
                        }
                    }
                    .padding(16)
                }
                .navigationTitle("Logged Trips")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        LiquidGlassIconButton(systemName: "xmark") { showCompletedTrips = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            // Stamps are no longer hideable; clean up any stale hidden flag.
            if isStatHidden("stamps") {
                setStatHidden("stamps", false)
            }
        }
    }
    
    private var tripsTakenCard: some View {
        let tripsTaken = completedTrips.count
        let totalBars = 16
        let filled = min(tripsTaken, totalBars)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Logged Trips")
                        .font(.app(15, weight: .semibold))
                        .foregroundStyle(textPrimary)
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
                        .font(.app(20, weight: .semibold))
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
                .font(.appTitle2)
                .foregroundStyle(textPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.9)
            
            HStack(spacing: 4) {
                ForEach(0..<totalBars, id: \.self) { idx in
                    Capsule(style: .continuous)
                        .fill(idx < filled ? appAccentColor : columnStroke)
                        .frame(height: 28)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: filled)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
                Text("Stamps")
                    .font(.appHeadline)
                    .foregroundStyle(textPrimary)
                
                Spacer(minLength: 0)
                
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(textSecondary)
            }
            
            if completedTrips.isEmpty {
                Text("Complete a trip to earn your first stamp.")
                    .font(.appSubheadline)
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
                        // Give the stamp's shadow room so it doesn't clip at the bottom.
                        .padding(.top, 6)
                        .padding(.bottom, 30)
                        .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // Taller frame + no clipping so the shadow can render fully.
                .frame(height: passportStampSize + 84)
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
                if trips.count > 1 {
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

