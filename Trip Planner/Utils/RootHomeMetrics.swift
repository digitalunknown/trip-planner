import CoreGraphics
import SwiftUI

/// Shared spacing for Trips / Places / Profile home screens under the large title.
/// Aliases `AppSpacing` semantic tokens — prefer `AppSpacing` for new code.
enum RootHomeMetrics {
    /// Horizontal page inset.
    static let horizontalInset: CGFloat = AppSpacing.pageInset
    /// Space under the large title before the first page content or chrome.
    static let topInset: CGFloat = AppSpacing.pageTop
    /// Space between page chrome (segment / filter chips) and the main content below.
    static let chromeToContent: CGFloat = AppSpacing.chromeToContent
    /// Bottom padding inside the main scroll view.
    static let bottomInset: CGFloat = AppSpacing.pageBottom
}

/// Multi-line page title (Manrope large title). Use an empty `.navigationTitle`
/// when the top bar should stay clear of a duplicate truncated title.
struct PageWrappingTitle: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.appLargeTitle)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .lineSpacing(-12)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(title)
    }
}
