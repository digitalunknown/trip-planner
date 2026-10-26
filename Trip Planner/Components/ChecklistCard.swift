import SwiftUI

struct ChecklistCard: View {
    let checklist: ChecklistItem
    
    private enum Palette {
        static let header = Color(hex: 0xF6A800)
        static let list = Color(hex: 0xFED353)
        static let border = Color(hex: 0xFED353)
        static let rowDivider = Color(hex: 0xF5C536)
        static let ink = Color(hex: 0x0A0A0A)
        static let stitch = Color(hex: 0x0A0A0A).opacity(0.5)
    }
    
    private let iconSize: CGFloat = 20
    private let headerHorizontalInset: CGFloat = 15
    private let headerVerticalInset: CGFloat = 12
    private let rowHorizontalInset: CGFloat = 12
    private let rowVerticalInset: CGFloat = 8
    private let rowIconGap: CGFloat = 8
    private let cornerRadius: CGFloat = 20
    private let previewLimit = 4
    private let stitchWidth: CGFloat = 1.5
    
    private var completedText: String {
        let done = checklist.items.filter(\.isDone).count
        return "\(done)/\(checklist.items.count)"
    }
    
    private var previewRows: [(id: String, text: String, isDone: Bool)] {
        if checklist.items.isEmpty {
            return (0..<previewLimit).map { ("empty-\($0)", "", false) }
        }
        return Array(checklist.items.prefix(previewLimit)).map {
            ($0.id.uuidString, $0.text, $0.isDone)
        }
    }
    
    var body: some View {
        let rows = previewRows
        
        VStack(spacing: 0) {
            header
            
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { idx, item in
                    itemRow(text: item.text, isDone: item.isDone)
                    
                    if idx < rows.count - 1 {
                        Rectangle()
                            .fill(Palette.rowDivider)
                            .frame(height: 1)
                    }
                }
            }
            .background(Palette.list)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Palette.border, lineWidth: 1)
        )
    }
    
    private var header: some View {
        HStack(spacing: 7) {
            AppIcon(lucide: "list-checks", size: iconSize, color: Palette.ink)
            
            Text(checklist.title)
                .font(.app(13, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            
            Spacer(minLength: 0)
            
            Text(completedText)
                .font(.app(13, weight: .semibold))
                .foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, headerHorizontalInset)
        .padding(.vertical, headerVerticalInset)
        .frame(maxWidth: .infinity)
        .background(Palette.header)
        .overlay(alignment: .bottom) {
            GeometryReader { geo in
                Path { path in
                    let y = geo.size.height - stitchWidth / 2
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
                .stroke(
                    Palette.stitch,
                    style: StrokeStyle(lineWidth: stitchWidth, lineCap: .round, dash: [4, 4])
                )
            }
            .frame(height: stitchWidth)
            .allowsHitTesting(false)
        }
    }
    
    private func itemRow(text: String, isDone: Bool) -> some View {
        HStack(spacing: rowIconGap) {
            AppIcon(
                lucide: isDone ? "circle-check-big" : "circle",
                size: iconSize,
                color: Palette.ink
            )
            
            Text(text)
                .font(.app(13, weight: .medium))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, rowHorizontalInset)
        .padding(.vertical, rowVerticalInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.list)
    }
}
