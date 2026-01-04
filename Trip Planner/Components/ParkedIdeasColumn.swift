import SwiftUI

struct ParkedIdeasColumn: View {
    let items: [EventItem]
    let columnWidth: CGFloat
    let columnHeight: CGFloat
    let onTap: (EventItem) -> Void
    let onDelete: (EventItem) -> Void
    let onAdd: () -> Void
    let onMoveLeftToLastDay: ((EventItem) -> Void)?
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var columnBackground: Color { colorScheme == .dark ? Color(hex: 0x171717) : Color(hex: 0xF0F0F0) }
    private var columnStroke: Color { colorScheme == .dark ? Color(hex: 0x252525) : Color(hex: 0xFFFFFF) }
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var textSecondary: Color { textPrimary.opacity(colorScheme == .dark ? 0.72 : 0.62) }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Parked Ideas")
                    .font(.headline)
                    .foregroundStyle(textPrimary)
                Text("Not tied to a day")
                    .font(.caption)
                    .foregroundStyle(textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items.sorted(by: { $0.startTimeMinutes < $1.startTimeMinutes })) { event in
                        EventCard(event: event)
                            .onTapGesture { onTap(event) }
                            .contextMenu {
                                if let moveLeft = onMoveLeftToLastDay {
                                    Button {
                                        moveLeft(event)
                                    } label: {
                                        Label("Move Left", systemImage: "arrow.left")
                                    }
                                }
                                Divider()
                                Button {
                                    onTap(event)
                                } label: {
                                    Label("Edit Activity", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    onDelete(event)
                                } label: {
                                    Label("Delete Activity", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: columnWidth, height: columnHeight)
        .background(columnBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(columnStroke, lineWidth: 1)
        )
    }
}

