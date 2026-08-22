import SwiftUI

struct ParkedIdeasColumn: View {
    let items: [EventItem]
    let columnWidth: CGFloat
    let columnHeight: CGFloat
    let onTap: (EventItem) -> Void
    let onDuplicate: (EventItem) -> Void
    let onDelete: (EventItem) -> Void
    let onAdd: () -> Void
    let onMoveLeftToLastDay: ((EventItem) -> Void)?
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var dayBackground: Color { colorScheme == .dark ? Color(hex: 0x171717) : Color(hex: 0xF0F0F0) }
    private var columnStroke: Color { colorScheme == .dark ? Color(hex: 0x252525) : Color(hex: 0xD0D0D6) }
    private var textPrimary: Color { colorScheme == .dark ? Color(hex: 0xEFEFF2) : Color(hex: 0x171717) }
    private var textSecondary: Color { textPrimary.opacity(colorScheme == .dark ? 0.72 : 0.62) }
    private var highlightStrokeColor: Color { colorScheme == .dark ? Color(hex: 0x5A5A5A) : Color(hex: 0xA8A8B0) }
    private var highlightFillColor: Color { colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.04) }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ideas")
                    .font(.app(17, weight: .semibold))
                    .foregroundStyle(textPrimary)
                Text("Not tied to a day")
                    .font(.appCaption)
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
                                        Label("Move Left", appIcon: "square.arrow.left")
                                    }
                                }
                                Divider()
                                Button {
                                    onTap(event)
                                } label: {
                                    Label("Edit Activity", appIcon: "square.and.pencil")
                                }
                                
                                Button {
                                    onDuplicate(event)
                                } label: {
                                    Label("Duplicate Activity", appIcon: "doc.on.doc")
                                }
                                
                                Button(role: .destructive) {
                                    onDelete(event)
                                } label: {
                                    Label("Delete Activity", appIcon: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: max(columnWidth, 0), height: max(columnHeight, 0), alignment: .top)
        .modifier(DayColumnGlassChrome(
            isCurrentDay: false,
            dayBackground: dayBackground,
            columnStroke: columnStroke,
            highlightStrokeColor: highlightStrokeColor,
            highlightFillColor: highlightFillColor
        ))
    }
}
