import SwiftUI

struct ChecklistCard: View {
    let checklist: ChecklistItem
    
    private var completedText: String {
        let done = checklist.items.filter(\.isDone).count
        return "\(done)/\(checklist.items.count)"
    }
    
    var body: some View {
        let headerColor = Color(hex: 0xF9C842)
        let listBgColor = Color(hex: 0xFAE78B)
        let textColor = Color(hex: 0x523E0E)
        
        let previewItems = Array(checklist.items.prefix(3))
        
        VStack(spacing: 0) {
            ZStack {
                Rectangle()
                    .fill(headerColor)
                
                // 1px dashed stitch divider at bottom
                GeometryReader { geo in
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: geo.size.height - 0.5))
                        p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height - 0.5))
                    }
                    .stroke(
                        Color(hex: 0xC9A239),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [4, 4])
                    )
                }
                
                HStack(alignment: .center, spacing: 6) {
                    AppIcon(systemName: "checklist", size: 15, strokeWidth: 2, color: textColor)
                    
                    Text(checklist.title)
                        .font(.app(13, weight: .semibold))
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                    
                    Spacer(minLength: 0)
                    
                    Text(completedText)
                        .font(.app(13, weight: .semibold))
                        .foregroundStyle(textColor)
                }
                .padding(.leading, 12)
                .padding(.trailing, 16)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            
            let stitchColor = Color(hex: 0xC9A239)
            
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { idx in
                    let text = idx < previewItems.count ? previewItems[idx].text : ""
                    let isDone = idx < previewItems.count ? previewItems[idx].isDone : false
                    let hasItem = idx < previewItems.count
                    
                    HStack(spacing: 12) {
                        AppIcon(
                            lucide: hasItem ? (isDone ? "circle-check-big" : "circle") : "circle",
                            size: 16,
                            color: textColor.opacity(hasItem ? (isDone ? 0.85 : 0.55) : 0.0)
                        )
                        
                        Text(text)
                            .font(.app(13, weight: .regular))
                            .foregroundStyle(textColor)
                            .lineLimit(1)
                            .strikethrough(isDone, color: textColor.opacity(0.6))
                        
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .background(listBgColor)
                    
                    if idx < 2 {
                        Rectangle()
                            .fill(stitchColor.opacity(0.35))
                            .frame(height: 1)
                    }
                }
            }
            .background(listBgColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(textColor.opacity(0.08), lineWidth: 1)
        )
    }
}
