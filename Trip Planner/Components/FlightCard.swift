import SwiftUI

struct FlightCard: View {
    let flight: FlightItem
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardBackground: Color { colorScheme == .dark ? Color(hex: 0x222222) : Color(hex: 0xFFFEF9) }
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var textSecondary: Color { textPrimary.opacity(colorScheme == .dark ? 0.72 : 0.62) }
    private var iconColor: Color { flight.accent.color }
    
    private var fromCode: String { endpointPrimaryText(code: flight.fromCode, name: flight.fromName, city: flight.fromCity) }
    private var toCode: String { endpointPrimaryText(code: flight.toCode, name: flight.toName, city: flight.toCity) }
    
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
    
    private var referenceText: String? {
        let t = flight.flightNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : (flight.travelMode == .drive || flight.travelMode == .walk ? t : t.uppercased())
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                airportTopBlock(
                    code: fromCode,
                    city: endpointSecondaryText(name: flight.fromName, city: flight.fromCity),
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
                    
                    Image(systemName: flight.travelMode.systemImageName)
                        .font(.app(20, weight: .regular))
                        .foregroundStyle(iconColor)
                        .scaleEffect(x: flight.travelMode == .drive ? -1 : 1, y: 1)
                }
                .frame(width: 110)
                .layoutPriority(0)
                
                airportTopBlock(
                    code: toCode,
                    city: endpointSecondaryText(name: flight.toName, city: flight.toCity),
                    alignment: .trailing
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
                .layoutPriority(1)
            }
            
            ZStack {
                HStack(alignment: .lastTextBaseline) {
                    Text(departureText)
                        .font(.appCaption)
                        .foregroundStyle(textSecondary)
                    
                    Spacer(minLength: 0)
                    
                    if let arrivalText {
                        Text(arrivalText)
                            .font(.appCaption)
                            .foregroundStyle(textSecondary)
                    } else {
                        Text(" ")
                            .font(.appCaption)
                            .hidden()
                    }
                }
                
                Group {
                    if let referenceText {
                        Text(referenceText)
                            .font(.app(12, weight: .semibold))
                            .foregroundStyle(textPrimary)
                    } else {
                        Text(flight.travelMode.title)
                            .font(.app(12, weight: .semibold))
                            .foregroundStyle(textPrimary.opacity(0.82))
                    }
                }
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 56)
            }
        }
        .frame(minHeight: 52, alignment: .center)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func endpointPrimaryText(code: String, name: String, city: String) -> String {
        if flight.travelMode == .flight {
            let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if !normalizedCode.isEmpty {
                return normalizedCode
            }
            return "—"
        }
        let cityText = city.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cityText.isEmpty { return cityText }
        let nameText = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return nameText.isEmpty ? "—" : nameText
    }
    
    private func endpointSecondaryText(name: String, city: String) -> String {
        if flight.travelMode == .flight {
            return city
        }
        let cityText = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameText = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cityText.isEmpty && !nameText.isEmpty && cityText.caseInsensitiveCompare(nameText) != .orderedSame {
            return nameText
        }
        return ""
    }
    
    private func airportTopBlock(code: String, city: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(code)
                .font(flight.travelMode == .flight ? .app(20, weight: .semibold) : .app(12, weight: .semibold))
                .foregroundStyle(textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            let secondary = city.trimmingCharacters(in: .whitespacesAndNewlines)
            if !secondary.isEmpty {
                Text(secondary)
                    .font(.appCaption)
                    .foregroundStyle(textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }
}

