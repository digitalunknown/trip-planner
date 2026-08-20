import SwiftUI
import Observation

/// Shared chrome flags for the root tab experience (e.g. hide tab AI accessory in pushed detail).
@Observable
final class RootTabChrome {
    private var aiAccessorySuppressCount = 0
    
    var suppressBottomAIAccessory: Bool {
        aiAccessorySuppressCount > 0
    }
    
    /// Plays the AI glow on tab accessories once per process lifetime.
    var hasPlayedAIAccessoryGlow = false
    
    func beginSuppressingAIAccessory() {
        aiAccessorySuppressCount += 1
    }
    
    func endSuppressingAIAccessory() {
        aiAccessorySuppressCount = max(0, aiAccessorySuppressCount - 1)
    }
    
    func consumeAIAccessoryGlowIfNeeded() -> Bool {
        guard !hasPlayedAIAccessoryGlow else { return false }
        hasPlayedAIAccessoryGlow = true
        return true
    }
}

/// Liquid-glass AI entry control — used in the tab bar accessory and as a floating overlay.
struct AITabBarAccessory: View {
    enum Chrome {
        /// System `tabViewBottomAccessory` already draws liquid glass.
        case systemTabAccessory
        /// Standalone floating capsule (e.g. over trip day columns).
        case floatingCapsule
    }
    
    let title: String
    var chrome: Chrome = .systemTabAccessory
    let action: () -> Void
    
    @Environment(RootTabChrome.self) private var tabChrome
    @State private var shouldPlayGlow = false
    
    var body: some View {
        Group {
            if #available(iOS 26.0, *), chrome == .systemTabAccessory {
                SystemAITabAccessoryLabel(title: title, action: action)
                    .aiIntroGlow(plays: shouldPlayGlow)
            } else {
                floatingLabel
                    .aiIntroGlow(plays: shouldPlayGlow)
            }
        }
        .onAppear {
            if tabChrome.consumeAIAccessoryGlowIfNeeded() {
                shouldPlayGlow = true
            }
        }
    }
    
    private var floatingLabel: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.app(15, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .modifier(AIFloatingCapsuleGlass())
        .accessibilityLabel(title)
    }
}

@available(iOS 26.0, *)
private struct SystemAITabAccessoryLabel: View {
    let title: String
    let action: () -> Void
    
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: placement == .inline ? 14 : 15, weight: .semibold))
                Text(title)
                    .font(.app(placement == .inline ? 14 : 15, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, placement == .inline ? 2 : 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct AIFloatingCapsuleGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: Capsule())
        } else {
            content
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
        }
    }
}
