import CoreGraphics
import SwiftUI

/// App-wide spacing scale (4pt grid) + semantic aliases.
///
/// Prefer `xxs / xs / sm / md / xl` (4 · 8 · 12 · 16 · 24).
enum AppSpacing {
    // MARK: Scale
    
    static let none: CGFloat = 0
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    /// Alias of `xl` so existing `lg` call sites stay on the 4–24 scale.
    static let lg: CGFloat = 24
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 24
    
    // MARK: Semantic — pages
    
    static let pageInset: CGFloat = md
    static let sectionGap: CGFloat = xl
    static let pageTop: CGFloat = xl
    static let chromeToContent: CGFloat = xl
    static let pageBottom: CGFloat = xl
    
    // MARK: Semantic — cards & stacks
    
    static let cardPadding: CGFloat = md
    /// Padding inside standalone field cards (day, location, cost, checklist rows).
    static let fieldPadding: CGFloat = md
    static let columnGap: CGFloat = md
    static let stackGap: CGFloat = sm
    static let stackTight: CGFloat = xs
    static let stackMicro: CGFloat = xxs
    
    // MARK: Semantic — controls
    
    static let controlIconGap: CGFloat = xs
    static let chipPaddingH: CGFloat = sm
    static let chipPaddingV: CGFloat = xs
    static let blockPaddingH: CGFloat = md
    static let blockPaddingV: CGFloat = sm
}

extension View {
    /// Page chrome insets shared by root home screens.
    func appPageInsets(
        includeTop: Bool = true,
        includeBottom: Bool = true
    ) -> some View {
        self
            .padding(.horizontal, AppSpacing.pageInset)
            .padding(.top, includeTop ? AppSpacing.pageTop : 0)
            .padding(.bottom, includeBottom ? AppSpacing.pageBottom : 0)
    }
    
    /// 24pt section gaps and top/bottom content inset for Form sheets and pages.
    func appFormPageSpacing() -> some View {
        self
            .listSectionSpacing(AppSpacing.sectionGap)
            .contentMargins(.vertical, AppSpacing.pageTop, for: .scrollContent)
    }
}
