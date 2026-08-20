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
    /// PostScript / family name for the bundled Manrope variable font.
    static let familyName = "Manrope"
    /// `wght` variation axis tag.
    private static let weightAxisTag: Int = 2003265652
    
    static func uiFont(size: CGFloat, weight: AppFontWeight = .regular) -> UIFont {
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: familyName,
            .size: size,
            kCTFontVariationAttribute as UIFontDescriptor.AttributeName: [
                weightAxisTag: weight.rawValue
            ]
        ])
        return UIFont(descriptor: descriptor, size: size)
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
}
