import SwiftUI

struct FlightCard: View {
    let flight: FlightItem
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardShape: RoundedRectangle { RoundedRectangle(cornerRadius: 16, style: .continuous) }
    private var cardFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.white
    }
    private var cardStroke: Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.08)
    }
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var textSecondary: Color { textPrimary.opacity(colorScheme == .dark ? 0.72 : 0.62) }
    private var separatorColor: Color {
        colorScheme == .dark ? Color.black : Color.black.opacity(0.10)
    }
    private var accentColor: Color { flight.accent.background }
    private var accentForeground: Color { flight.accent.foreground }
    private var connectorColor: Color { accentColor.opacity(colorScheme == .dark ? 0.70 : 0.45) }
    
    /// Same badge size as activity cards (52×52, radius 12, glyph 26).
    private let iconSide: CGFloat = 52
    private var iconCornerRadius: CGFloat { 12 }
    private var iconGlyphSize: CGFloat { 26 }
    private var iconInnerStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.14)
    }
    /// Visual gap between connector and icon badge.
    private let knockoutStroke: CGFloat = 2
    private let connectorWidth: CGFloat = 2
    private let midGap: CGFloat = 1
    private let horizontalPadding: CGFloat = 12
    private let verticalPadding: CGFloat = 12
    
    private var railWidth: CGFloat { iconSide + knockoutStroke * 2 }
    
    var body: some View {
        VStack(spacing: 0) {
            endpointRow(isOrigin: true)
            
            Rectangle()
                .fill(separatorColor)
                .frame(height: midGap)
            
            endpointRow(isOrigin: false)
        }
        .background {
            cardShape.fill(cardFill)
        }
        .overlay {
            cardShape.strokeBorder(cardStroke, lineWidth: 1)
        }
        .clipShape(cardShape)
        .contentShape(cardShape)
    }
    
    private func endpointRow(isOrigin: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Placeholder keeps text indented; icon + line drawn in background
            // so the connector can use the full row height.
            Color.clear
                .frame(width: railWidth, height: iconSide)
            
            endpointDetails(isOrigin: isOrigin)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(alignment: .leading) {
            railBackground(isOrigin: isOrigin)
                .padding(.leading, horizontalPadding)
        }
    }
    
    /// Full-height rail: line runs to the half’s top/bottom edge, with a hard
    /// 2pt stop short of the icon badge.
    private func railBackground(isOrigin: Bool) -> some View {
        GeometryReader { geo in
            let midX = railWidth / 2
            let midY = geo.size.height / 2
            let gap = iconSide / 2 + knockoutStroke
            
            Path { path in
                if isOrigin {
                    // Top half: from just below the icon → bottom edge (mid seam).
                    let y0 = midY + gap
                    if y0 < geo.size.height {
                        path.move(to: CGPoint(x: midX, y: y0))
                        path.addLine(to: CGPoint(x: midX, y: geo.size.height))
                    }
                } else {
                    // Bottom half: from top edge (mid seam) → just above the icon.
                    let y1 = midY - gap
                    if y1 > 0 {
                        path.move(to: CGPoint(x: midX, y: 0))
                        path.addLine(to: CGPoint(x: midX, y: y1))
                    }
                }
            }
            .stroke(
                connectorColor,
                style: StrokeStyle(lineWidth: connectorWidth, lineCap: .butt)
            )
            
            endpointIcon(isOrigin: isOrigin)
                .position(x: midX, y: midY)
        }
        .frame(width: railWidth)
    }
    
    private func endpointIcon(isOrigin: Bool) -> some View {
        let symbol = flight.travelMode.mapEndpointSystemImage(isOrigin: isOrigin)
        let shape = RoundedRectangle(cornerRadius: iconCornerRadius, style: .continuous)
        return ZStack {
            shape
                .fill(accentColor)
            AppIcon(
                systemName: symbol,
                size: iconGlyphSize,
                strokeWidth: 2,
                color: accentForeground
            )
        }
        .frame(width: iconSide, height: iconSide)
        .overlay {
            shape.strokeBorder(iconInnerStroke, lineWidth: 1)
        }
        .frame(width: railWidth, height: railWidth)
        .accessibilityHidden(true)
    }
    
    private func endpointDetails(isOrigin: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(endpointTitle(isOrigin: isOrigin))
                .font(.app(13, weight: .semibold))
                .foregroundStyle(textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            let meta = endpointMeta(isOrigin: isOrigin)
            if !meta.isEmpty {
                Text(meta)
                    .font(.app(13, weight: .regular))
                    .foregroundStyle(textSecondary)
                    .lineLimit(2)
            }
        }
    }
    
    private func endpointTitle(isOrigin: Bool) -> String {
        let name = (isOrigin ? flight.fromName : flight.toName)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let city = (isOrigin ? flight.fromCity : flight.toCity)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let code = (isOrigin ? flight.fromCode : flight.toCode)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch flight.travelMode {
        case .flight:
            if !name.isEmpty { return name }
            if !code.isEmpty { return code.uppercased() }
            if !city.isEmpty { return city }
            return "—"
        case .train, .drive, .walk:
            if !name.isEmpty { return name }
            if !city.isEmpty { return city }
            if !code.isEmpty { return code }
            return "—"
        }
    }
    
    private func endpointMeta(isOrigin: Bool) -> String {
        var parts: [String] = []
        
        if isOrigin {
            parts.append(departureText)
        } else if let arrivalText {
            parts.append(arrivalText)
        }
        
        if flight.travelMode == .flight || flight.travelMode == .train {
            let terminal = (isOrigin ? flight.fromTerminal : flight.toTerminal)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let gate = (isOrigin ? flight.fromGate : flight.toGate)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !terminal.isEmpty {
                let label = terminal.lowercased().hasPrefix("term") ? terminal : "Term \(terminal)"
                parts.append(label)
            }
            if !gate.isEmpty {
                let label = gate.lowercased().hasPrefix("gate") ? gate : "Gate \(gate)"
                parts.append(label)
            }
        }
        
        return parts.joined(separator: "  ·  ")
    }
    
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
}

#if DEBUG
#Preview("Travel cards") {
    let cal = Calendar.current
    let start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
    let end = cal.date(bySettingHour: 11, minute: 30, second: 0, of: Date())!
    
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(
                [
                    FlightItem(
                        fromName: "St. Louis Lambert International Airport",
                        fromTerminal: "A",
                        fromGate: "A21",
                        toName: "Los Angeles International Airport",
                        toTerminal: "A",
                        toGate: "A21",
                        travelMode: .flight,
                        startTime: start,
                        endTime: end
                    ),
                    FlightItem(
                        fromName: "Paris Gare de Lyon",
                        toName: "Nice Ville",
                        travelMode: .train,
                        startTime: start,
                        endTime: end
                    ),
                    FlightItem(
                        fromName: "St. Louis, MO",
                        toName: "Terre Haute, IN",
                        travelMode: .drive,
                        startTime: start,
                        endTime: end
                    ),
                    FlightItem(
                        fromName: "Location 1",
                        toName: "Location 2",
                        travelMode: .walk,
                        startTime: start,
                        endTime: end
                    )
                ],
                id: \.id
            ) { flight in
                VStack(alignment: .leading, spacing: 6) {
                    Text(flight.travelMode.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FlightCard(flight: flight)
                }
            }
        }
        .padding()
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}
#endif
