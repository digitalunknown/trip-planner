import SwiftUI

/// Shared page + field-card colors for sheets and pages.
enum AppDetailSurface {
    static let page = AppColor.page
    static let card = AppColor.card
    /// Activity / travel / reminder cards on the trip board.
    static let boardCard = AppColor.elevated
    
    static func page(for colorScheme: ColorScheme) -> Color { page }
    static func card(for colorScheme: ColorScheme) -> Color { card }
}

private struct AppDetailFormChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(AppDetailSurface.page.ignoresSafeArea())
    }
}

private struct AppDetailFieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.listRowBackground(AppDetailSurface.card)
    }
}

extension View {
    /// Place-detail page fill behind a Form (hides the system grouped wash).
    func appDetailFormChrome() -> some View {
        modifier(AppDetailFormChrome())
    }
    
    /// Field-card fill for inset-grouped Form rows.
    func appDetailFieldBackground() -> some View {
        modifier(AppDetailFieldBackground())
    }
}
