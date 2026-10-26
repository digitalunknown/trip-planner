import SwiftUI

/// Consolidated dark-first palette. Light counterparts are placeholders until the light spec.
enum AppColor {
    /// Page / sheet wash. Dark `#0A0A0A`.
    static let page = Color.adaptive(light: 0xF4F5F5, dark: 0x0A0A0A)
    /// Field / grouped card. Dark `#171717`.
    static let card = Color.adaptive(light: 0xFFFFFF, dark: 0x171717)
    /// Nested control / board card. Dark `#262626`.
    static let elevated = Color.adaptive(light: 0xFFFFFF, dark: 0x262626)
    
    /// Primary copy. Dark `#F4F5F5`.
    static let textStrong = Color.adaptive(light: 0x0A0A0A, dark: 0xF4F5F5)
    /// Secondary copy — solid grey, not faded primary. `#8A8A8A`.
    static let textWeak = Color(hex: 0x8A8A8A)
    
    /// Hairline between rows. Solid, not white-at-opacity.
    static let divider = Color.adaptive(light: 0xE8E8E8, dark: 0x2A2A2A)
    
    /// App / interactive accent (toggles, links).
    static let accent = Color(hex: 0xFF8B00)
    /// TripStacks+ wordmark — accent into warm gold.
    static var plusGradient: LinearGradient {
        LinearGradient(
            colors: [accent, Color(hex: 0xFFD27A)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    /// Expert-tips purple.
    static let expert = Color(hex: 0xB2A1FF)
    static let destructive = Color(hex: 0xFF0000)
}

extension ShapeStyle where Self == Color {
    static var appStrong: Color { AppColor.textStrong }
    static var appWeak: Color { AppColor.textWeak }
}
