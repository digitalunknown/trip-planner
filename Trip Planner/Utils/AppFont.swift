import SwiftUI
import UIKit

extension Font {
    static func app(_ size: CGFloat, weight: AppFontWeight = .regular) -> Font {
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: "Inter",
            .size: size,
            kCTFontVariationAttribute as UIFontDescriptor.AttributeName: [
                2003265652: weight.rawValue
            ]
        ])
        return Font(UIFont(descriptor: descriptor, size: size))
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

enum AppFontWeight {
    case regular
    case semibold
    
    var rawValue: CGFloat {
        switch self {
        case .regular: return 400
        case .semibold: return 600
        }
    }
}
