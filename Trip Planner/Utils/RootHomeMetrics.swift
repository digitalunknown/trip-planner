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

extension View {
    /// Home-tab large title. On iOS 26 the system title is Bold; this uses the
    /// same Manrope semibold 34pt the nav bar appearance applies on older iOS.
    func appRootNavigationTitle(_ title: String) -> some View {
        modifier(RootNavigationTitle(title: title))
    }
}

private struct RootNavigationTitle: ViewModifier {
    let title: String
    
    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .modifier(RootLargeTitleToolbar(title: title))
    }
}

private struct RootLargeTitleToolbar: ViewModifier {
    let title: String
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.toolbar {
                ToolbarItem(placement: .largeTitle) {
                    Text(title)
                        .font(.app(34, weight: .semibold))
                        .foregroundStyle(AppColor.textStrong)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            content
        }
    }
}
