import SwiftUI

struct FlightCard: View {
    let flight: FlightItem
    
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
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                airportTopBlock(
                    code: fromCode,
                    city: flight.fromCity,
                    alignment: .leading
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                
                ZStack {
                    Capsule(style: .continuous)
                        .fill(Color.secondary.opacity(0.25))
                        .frame(height: 3)
                    
                    Image(systemName: "airplane")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(.primary)
                }
                .frame(width: 140)
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
                    .foregroundStyle(.secondary)
                
                Spacer(minLength: 0)
                
                if let flightNumberText {
                    Text(flightNumberText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                } else {
                    Text(" ")
                        .font(.subheadline.weight(.semibold))
                        .hidden()
                }
                
                Spacer(minLength: 0)
                
                if let arrivalText {
                    Text(arrivalText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(" ")
                        .font(.caption)
                        .hidden()
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func airportTopBlock(code: String, city: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(code)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? " " : city)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }
}

