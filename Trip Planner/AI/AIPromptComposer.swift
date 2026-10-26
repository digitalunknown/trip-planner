import SwiftUI

/// Glass prompt field + send control used by the AI sheet and the sign-in splash.
struct AIPromptSingleLineField: View {
    @Binding var text: String
    var placeholder: String
    var onSend: () -> Void = {}
    
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            TextField(placeholder, text: $text)
                .font(.appBody)
                .foregroundStyle(AppColor.textStrong)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit {
                    guard canSend else { return }
                    onSend()
                }
            
            AIPromptSendButton(isEnabled: canSend, action: onSend)
        }
        .padding(.leading, 20)
        .padding(.trailing, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 56)
        .modifier(AIPromptFieldGlassBackground(shape: fieldShape))
        .overlay {
            fieldShape
                .strokeBorder(borderStyle, lineWidth: 1)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
    
    private var borderStyle: some ShapeStyle {
        if isFocused {
            return AnyShapeStyle(Color.primary.opacity(0.55))
        }
        return AnyShapeStyle(Color(.separator).opacity(0.35))
    }
}

struct AIPromptSendButton: View {
    var isEnabled: Bool
    var isProcessing: Bool = false
    var action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            let isActive = isProcessing || isEnabled
            let strongFill = AppColor.textStrong
            let strongGlyph = colorScheme == .dark ? Color(hex: 0x171717) : Color.white
            AppIcon(
                systemName: isProcessing ? "stop.fill" : "arrow.up",
                size: isProcessing ? 13 : 18,
                strokeWidth: 2.25,
                color: isActive ? strongGlyph : Color.secondary,
                filled: isProcessing
            )
            .frame(width: 36, height: 36)
            .background {
                Circle()
                    .fill(isActive ? strongFill : Color(.tertiarySystemFill))
            }
        }
        .buttonStyle(.plain)
        .disabled(!isProcessing && !isEnabled)
        .accessibilityLabel(isProcessing ? "Stop" : "Send")
    }
}

struct AIPromptFieldGlassBackground: ViewModifier {
    let shape: RoundedRectangle
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .clipShape(shape)
        }
    }
}
