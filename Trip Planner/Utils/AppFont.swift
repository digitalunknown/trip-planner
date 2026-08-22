import CoreText
import SwiftUI
import UIKit

extension Font {
    static func app(_ size: CGFloat, weight: AppFontWeight = .regular) -> Font {
        Font(AppFont.uiFont(size: size, weight: weight))
    }
    
    static var appTitle: Font { .app(28, weight: .semibold) }
    static var appTitle2: Font { .app(22, weight: .semibold) }
    static var appLargeTitle: Font { .app(34, weight: .semibold) }
    static var appHeadline: Font { .app(17, weight: .semibold) }
    static var appBody: Font { .app(17, weight: .regular) }
    static var appCallout: Font { .app(16, weight: .regular) }
    static var appSubheadline: Font { .app(15, weight: .regular) }
    static var appFootnote: Font { .app(13, weight: .regular) }
    static var appCaption: Font { .app(12, weight: .regular) }
}

enum AppFont {
    /// Preferred family name for the bundled Manrope variable font.
    static let familyName = "Manrope"
    /// `wght` variation axis tag (`'wght'`).
    private static let weightAxisTag = 2003265652
    
    static func uiFont(size: CGFloat, weight: AppFontWeight = .regular) -> UIFont {
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
