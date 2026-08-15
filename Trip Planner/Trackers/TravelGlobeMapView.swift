import SwiftUI

struct TravelGlobeMapView: View {
    let trips: [Trip]
    var onSelectTrip: ((Trip) -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack(alignment: .top) {
            TravelGlobeCard(
                trips: trips,
                onSelectTrip: onSelectTrip,
                allowsFullInteraction: true,
                showsEmptyCopy: false,
                showsFullGlobe: false,
                showsTopFade: false
            )
            .ignoresSafeArea()
            
            HStack(spacing: 12) {
                LiquidGlassIconButton(systemName: "xmark") { dismiss() }
                
                Spacer(minLength: 0)
                
                Text("Your World")
                    .font(.app(17, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
                
                Spacer(minLength: 0)
                
                // Balance the leading close button so the title stays centered.
                Color.clear
                    .frame(width: 36, height: 36)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
