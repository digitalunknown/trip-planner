import SwiftUI

struct SignInHeroAnimation: View {
    @State private var showItems = false
    @State private var showExtraItems = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appAccentColor) private var appAccentColor
    
    private var dayBackground: Color { colorScheme == .dark ? Color(hex: 0x171717) : Color(hex: 0xF0F0F0) }
    private var columnStroke: Color { colorScheme == .dark ? Color(hex: 0x252525) : Color(hex: 0xFFFFFF) }
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var textSecondary: Color { textPrimary.opacity(colorScheme == .dark ? 0.72 : 0.62) }
    
    var body: some View {
        ZStack {
            // Day Column Container
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mon, Aug 15")
                        .font(.app(17, weight: .semibold))
                        .foregroundStyle(textPrimary)
                    Text("Day 1 of 5")
                        .font(.appCaption)
                        .foregroundStyle(textSecondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(showItems ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(1.4), value: showItems)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        // Reminder
                        ReminderCard(text: "Book museum tickets")
                            .opacity(showItems ? 1 : 0)
                            .offset(y: showItems ? 0 : -50)
                            .blur(radius: showItems ? 0 : 10)
                            .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: showItems)
                        
                        // Checklist
                        ChecklistCard(checklist: ChecklistItem(
                            id: UUID(),
                            title: "Packing List",
                            items: [
                                ChecklistEntry(id: UUID(), text: "Passport", isDone: true),
                                ChecklistEntry(id: UUID(), text: "Camera", isDone: false),
                                ChecklistEntry(id: UUID(), text: "Sunglasses", isDone: false)
                            ],
                            createdAt: Date()
                        ))
                        .opacity(showItems ? 1 : 0)
                        .offset(x: showItems ? 0 : -80)
                        .blur(radius: showItems ? 0 : 10)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.6), value: showItems)
                        
                        // Flight
                        FlightCard(flight: FlightItem(
                            id: UUID(),
                            fromName: "San Francisco Int'l",
                            fromCode: "SFO",
                            fromCity: "San Francisco",
                            fromLatitude: nil,
                            fromLongitude: nil,
                            fromTerminal: "",
                            fromGate: "",
                            toName: "Charles de Gaulle",
                            toCode: "CDG",
                            toCity: "Paris",
                            toLatitude: nil,
                            toLongitude: nil,
                            toTerminal: "",
                            toGate: "",
                            flightNumber: "AF83",
                            notes: "",
                            accent: .purple,
                            startTime: Date(),
                            endTime: Date().addingTimeInterval(36000)
                        ))
                        .opacity(showItems ? 1 : 0)
                        .offset(x: showItems ? 0 : 80)
                        .blur(radius: showItems ? 0 : 10)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(1.0), value: showItems)
                        
                        // Activity 1
                        EventCard(event: EventItem(
                            id: UUID(),
                            title: "Eiffel Tower",
                            description: "",
                            time: "9:00 AM - 11:00 AM",
                            location: "Paris, France",
                            latitude: nil,
                            longitude: nil,
                            icon: "building.2.fill",
                            accent: .purple,
                            photoData: nil,
                            rating: 0
                        ))
                        .opacity(showItems ? 1 : 0)
                        .offset(y: showItems ? 0 : 50)
                        .blur(radius: showItems ? 0 : 10)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(1.4), value: showItems)
                        
                        // Activity 2 - flies in from bottom
                        EventCard(event: EventItem(
                            id: UUID(),
                            title: "Louvre Museum",
                            description: "",
                            time: "2:00 PM - 5:00 PM",
                            location: "Paris, France",
                            latitude: nil,
                            longitude: nil,
                            icon: "paintpalette.fill",
                            accent: .purple,
                            photoData: nil,
                            rating: 0
                        ))
                        .opacity(showExtraItems ? 1 : 0)
                        .offset(y: showExtraItems ? 0 : 80)
                        .blur(radius: showExtraItems ? 0 : 12)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: showExtraItems)
                        
                        // Activity 3 - flies in from bottom
                        EventCard(event: EventItem(
                            id: UUID(),
                            title: "Seine River Cruise",
                            description: "",
                            time: "7:00 PM - 9:00 PM",
                            location: "Paris, France",
                            latitude: nil,
                            longitude: nil,
                            icon: "ferry.fill",
                            accent: .purple,
                            photoData: nil,
                            rating: 0
                        ))
                        .opacity(showExtraItems ? 1 : 0)
                        .offset(y: showExtraItems ? 0 : 80)
                        .blur(radius: showExtraItems ? 0 : 12)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.35), value: showExtraItems)
                        
                        Spacer(minLength: 20)
                    }
                    .padding(14)
                }
            }
            .frame(width: 300, height: 420)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(dayBackground)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(columnStroke, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 14)
            .scaleEffect(showItems ? 1 : 0.9)
            .opacity(showItems ? 1 : 0)
            .animation(.spring(response: 0.8, dampingFraction: 0.7), value: showItems)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showItems = true
                
                // Trigger extra items to fly in
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                    showExtraItems = true
                }
            }
        }
    }
}

#Preview {
    SignInHeroAnimation()
        .padding()
}
