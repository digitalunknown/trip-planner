import CoreGraphics

/// Shared spacing for Trips / Places / Profile home screens under the large title.
enum RootHomeMetrics {
    /// Horizontal page inset.
    static let horizontalInset: CGFloat = 16
    /// Space under the large title before the first page content or chrome.
    static let topInset: CGFloat = 8
    /// Space between page chrome (segment / filter chips) and the main content below.
    static let chromeToContent: CGFloat = 20
    /// Bottom padding inside the main scroll view.
    static let bottomInset: CGFloat = 12
}
