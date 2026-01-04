import SwiftUI

struct FlightCard: View {
    let flight: FlightItem
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardBackground: Color { colorScheme == .dark ? Color(hex: 0x222222) : Color(hex: 0xFFFEF9) }
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var textSecondary: Color { textPrimary.opacity(colorScheme == .dark ? 0.72 : 0.62) }
    private var iconColor: Color { flight.accent.color }
    
    private var fromCode: String { flight.fromCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().isEmpty ? "—" : flight.fromCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
    private var toCode: String { flight.toCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().isEmpty ? "—" : flight.toCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
    
    private var departureText: String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: flight.startTime)
    }
    
    private var arrivalText: String? {
        guard flight.hasEndTime else { return nil }
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: flight.endTime)
    }
    
    private var flightNumberText: String? {
        let t = flight.flightNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t.uppercased()
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                airportTopBlock(
                    code: fromCode,
                    city: flight.fromCity,
                    alignment: .leading
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                
                ZStack {
                    HStack(spacing: 0) {
                        Circle()
                            .fill(iconColor)
                            .frame(width: 9, height: 9)
                            .overlay(
                                Circle()
                                    .stroke(cardBackground, lineWidth: 2)
                            )
                        
                        Capsule(style: .continuous)
                            .fill(iconColor.opacity(0.25))
                            .frame(height: 3)
                            .frame(maxWidth: .infinity)
                        
                        Circle()
                            .fill(iconColor)
                            .frame(width: 9, height: 9)
                            .overlay(
                                Circle()
                                    .stroke(cardBackground, lineWidth: 2)
                            )
                    }
                    
                    Image(systemName: "airplane")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(iconColor)
                }
                .frame(width: 110)
                .layoutPriority(0)
                
                airportTopBlock(
                    code: toCode,
                    city: flight.toCity,
                    alignment: .trailing
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
                .layoutPriority(1)
            }
            
            HStack(alignment: .lastTextBaseline) {
                Text(departureText)
                    .font(.caption)
                    .foregroundStyle(textSecondary)
                
                Spacer(minLength: 0)
                
                if let flightNumberText {
                    Text(flightNumberText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(textPrimary)
                } else {
                    Text(" ")
                        .font(.subheadline.weight(.semibold))
                        .hidden()
                }
                
                Spacer(minLength: 0)
                
                if let arrivalText {
                    Text(arrivalText)
                        .font(.caption)
                        .foregroundStyle(textSecondary)
                } else {
                    Text(" ")
                        .font(.caption)
                        .hidden()
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func airportTopBlock(code: String, city: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(code)
                .font(.title3.weight(.bold))
                .foregroundStyle(textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? " " : city)
                .font(.caption)
                .foregroundStyle(textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }
}

