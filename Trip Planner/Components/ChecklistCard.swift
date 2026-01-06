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
        let lineColor = Color(hex: 0xF9D767)
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
                
                HStack(alignment: .firstTextBaseline) {
                    Text(checklist.title)
                        .font(.subheadline.weight(.semibold)) // match event card title style
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(completedText)
                        .font(.subheadline.weight(.semibold)) // match event card title style
                        .foregroundStyle(textColor)
                }
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { idx in
                    let text = idx < previewItems.count ? previewItems[idx].text : ""
                    let isDone = idx < previewItems.count ? previewItems[idx].isDone : false
                    
                    ZStack {
                        Rectangle()
                            .fill(listBgColor)
                        
                        HStack(spacing: 6) {
                            if idx < previewItems.count {
                                Image(systemName: isDone ? "checkmark.square.fill" : "square")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(textColor.opacity(isDone ? 0.85 : 0.55))
                            } else {
                                Image(systemName: "square")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(textColor.opacity(0.0))
                            }
                            
                            Text(text)
                                .font(.subheadline)
                                .foregroundStyle(textColor)
                                .lineLimit(1)
                                .strikethrough(isDone, color: textColor.opacity(0.6))
                            
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    
                    if idx < 2 {
                        Rectangle()
                            .fill(lineColor)
                            .frame(height: 1)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(textColor.opacity(0.08), lineWidth: 1)
        )
    }
}

