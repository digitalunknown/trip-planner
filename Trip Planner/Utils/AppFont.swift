import CoreText
import SwiftUI
import UIKit

extension Font {
    static func app(_ size: CGFloat, weight: AppFontWeight = .medium) -> Font {
        Font(AppFont.uiFont(size: size, weight: weight))
    }
    
    static var appTitle: Font { .app(30, weight: .semibold) }
    static var appTitle2: Font { .app(17, weight: .semibold) }
    static var appLargeTitle: Font { .app(30, weight: .semibold) }
    /// Activity / sheet display titles.
    static var appDisplay: Font { .app(30, weight: .semibold) }
    static var appHeadline: Font { .app(17, weight: .semibold) }
    static var appBody: Font { .app(15, weight: .medium) }
    static var appCallout: Font { .app(15, weight: .medium) }
    static var appSubheadline: Font { .app(15, weight: .medium) }
    static var appFootnote: Font { .app(13, weight: .medium) }
    static var appCaption: Font { .app(13, weight: .medium) }
}

enum AppFont {
    /// Preferred family name for the bundled Manrope variable font.
    static let familyName = "Manrope"
    /// `wght` variation axis tag (`'wght'`).
    private static let weightAxisTag = 2003265652
    
    static func uiFont(size: CGFloat, weight: AppFontWeight = .medium) -> UIFont {
        if let font = manropeFont(size: size, weight: weight) {
            return font
        }
        return UIFont.systemFont(ofSize: size, weight: weight.uiFontWeight)
    }
    
    /// Resolves Manrope at an explicit weight so UIKit chrome doesn’t fall back to
    /// the variable font’s ExtraLight default.
    private static func manropeFont(size: CGFloat, weight: AppFontWeight) -> UIFont? {
        let variations: [Int: CGFloat] = [weightAxisTag: weight.rawValue]
        let attributes: [UIFontDescriptor.AttributeName: Any] = [
            .family: familyName,
            .size: size,
            kCTFontVariationAttribute as UIFontDescriptor.AttributeName: variations
        ]
        let descriptor = UIFontDescriptor(fontAttributes: attributes)
        let font = UIFont(descriptor: descriptor, size: size)
        guard font.familyName.localizedCaseInsensitiveContains(familyName) else {
            return nil
        }
        return font
    }
}

enum AppFontWeight {
    case regular
    case medium
    case semibold
    case bold
    
    var rawValue: CGFloat {
        switch self {
        case .regular: return 400
        case .medium: return 500
        case .semibold: return 600
        case .bold: return 700
        }
    }
    
    var uiFontWeight: UIFont.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

extension View {
    /// Compact date/time pickers ignore SwiftUI `.font`; restyle the underlying UIDatePicker.
    func appDatePickerFont() -> some View {
        font(.app(15, weight: .medium))
            .environment(\.font, .app(15, weight: .medium))
            .background {
                AppDatePickerFontProbe()
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
    }
    
    /// Keeps compact date buttons at their intrinsic width so they don’t collapse to `9/4/26`.
    func appCompactDateValue() -> some View {
        labelsHidden()
            .fixedSize()
            .datePickerStyle(.compact)
            .appDatePickerFont()
    }
}

private struct AppDatePickerFontProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> AppDatePickerFontView {
        AppDatePickerFontView()
    }
    
    func updateUIView(_ uiView: AppDatePickerFontView, context: Context) {
        uiView.applyIfNeeded()
    }
}

private final class AppDatePickerFontView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) { nil }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyIfNeeded()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        applyIfNeeded()
    }
    
    func applyIfNeeded() {
        var current: UIView? = self
        while let view = current {
            if let picker = view as? UIDatePicker {
                Self.style(picker)
                return
            }
            current = view.superview
        }
    }
    
    private static func style(_ root: UIView) {
        let font = AppFont.uiFont(size: 15, weight: .medium)
        func walk(_ view: UIView) {
            if let label = view as? UILabel {
                label.font = font
            }
            if let field = view as? UITextField {
                field.font = font
            }
            if let button = view as? UIButton {
                button.titleLabel?.font = font
                if var config = button.configuration {
                    config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                        var attrs = incoming
                        attrs.font = font
                        return attrs
                    }
                    button.configuration = config
                }
            }
            view.subviews.forEach(walk)
        }
        walk(root)
    }
}
