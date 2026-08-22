import CoreGraphics
import SwiftUI

/// App-wide spacing scale (4pt grid) + semantic aliases.
///
/// # Scale (8 tokens)
/// | Token   | pt | Use |
/// |---------|----|-----|
/// | `none`  |  0 | Flush stacks, zero spacers |
/// | `xxs`   |  4 | Micro gaps inside cards / metadata |
/// | `xs`    |  8 | Tight stacks, title→chrome |
/// | `sm`    | 12 | Default card pad, row gaps, page bottom |
/// | `md`    | 16 | Page inset, day-column gap, form rows |
/// | `lg`    | 20 | Section / chrome→content |
/// | `xl`    | 24 | Large section gaps |
/// | `xxl`   | 32 | Hero / auth / sparse layouts |
///
/// # One-off → neighbor (migrate toward these)
/// | Old              | → New      | Notes |
/// |------------------|------------|-------|
/// | 1, 2, 2.5, 3     | `xxs` (4)  | Heatmap 2.5 → 4 |
/// | 5, 6, 7          | `xs`  (8)  | Capsule chip vertical 7→8 |
/// | 9, 10, 11, 14, 15 | `sm` (12)  | Collapse common 10/14 → 12 |
/// | 18               | `md` (16)  | |
/// | 22               | `lg` (20)  | |
/// | 28               | `xl` (24)  | |
/// | 36, 40           | `xxl` (32) | |
/// | 44, 56, 100      | *(review)* | Layout-specific; don’t tokenize yet |
/// | -16              | `-md`      | Form footer optical align |
///
/// Prefer semantic aliases (`pageInset`, `cardPadding`, …) at call sites.
enum AppSpacing {
    // MARK: Scale
    
    static let none: CGFloat = 0
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    
    // MARK: Semantic — pages
    
    /// Horizontal inset for Trips / Places / Profile / Explore homes.
    static let pageInset: CGFloat = md
    /// Space under the large title before chrome or content.
    static let pageTop: CGFloat = xs
    /// Segment / filter chips → main content.
    static let chromeToContent: CGFloat = lg
    /// Bottom padding inside home scroll views.
    static let pageBottom: CGFloat = sm
    
    // MARK: Semantic — cards & stacks
    
    /// Default inner padding for activity / flight / reminder cards.
    static let cardPadding: CGFloat = sm
    /// Gap between day columns on the trip board.
    static let columnGap: CGFloat = md
    /// Default vertical stack gap inside cards / lists.
    static let stackGap: CGFloat = sm
    /// Tight metadata / icon–label stacks.
    static let stackTight: CGFloat = xs
    /// Micro gap (badges, paired glyphs, dense rows).
    static let stackMicro: CGFloat = xxs
    
    // MARK: Semantic — controls
    
    /// Icon → title in capsule buttons (was 5 → nearest `xxs`).
    static let controlIconGap: CGFloat = xxs
    /// Compact chip horizontal / vertical padding.
    static let chipPaddingH: CGFloat = sm
    static let chipPaddingV: CGFloat = xs
    /// Full-width capsule block padding.
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
}
