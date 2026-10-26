import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "explore-content" asset catalog resource namespace.
    enum ExploreContent {

        /// The "explore-content/new-york" asset catalog image resource.
        static let newYork = DeveloperToolsSupport.ImageResource(name: "explore-content/new-york", bundle: resourceBundle)

        /// The "explore-content/paris-museums" asset catalog image resource.
        static let parisMuseums = DeveloperToolsSupport.ImageResource(name: "explore-content/paris-museums", bundle: resourceBundle)

        /// The "explore-content/toronto" asset catalog image resource.
        static let toronto = DeveloperToolsSupport.ImageResource(name: "explore-content/toronto", bundle: resourceBundle)

    }

    /// The "illustrations" asset catalog resource namespace.
    enum Illustrations {

        /// The "illustrations/achievement-level-1" asset catalog image resource.
        static let achievementLevel1 = DeveloperToolsSupport.ImageResource(name: "illustrations/achievement-level-1", bundle: resourceBundle)

        /// The "illustrations/achievement-level-2" asset catalog image resource.
        static let achievementLevel2 = DeveloperToolsSupport.ImageResource(name: "illustrations/achievement-level-2", bundle: resourceBundle)

        /// The "illustrations/achievement-level-3" asset catalog image resource.
        static let achievementLevel3 = DeveloperToolsSupport.ImageResource(name: "illustrations/achievement-level-3", bundle: resourceBundle)

        /// The "illustrations/badge-arches-np" asset catalog image resource.
        static let badgeArchesNp = DeveloperToolsSupport.ImageResource(name: "illustrations/badge-arches-np", bundle: resourceBundle)

        /// The "illustrations/badge-bryce-canyon-np" asset catalog image resource.
        static let badgeBryceCanyonNp = DeveloperToolsSupport.ImageResource(name: "illustrations/badge-bryce-canyon-np", bundle: resourceBundle)

        /// The "illustrations/badge-canyonlands-np" asset catalog image resource.
        static let badgeCanyonlandsNp = DeveloperToolsSupport.ImageResource(name: "illustrations/badge-canyonlands-np", bundle: resourceBundle)

        /// The "illustrations/badge-gateway-np" asset catalog image resource.
        static let badgeGatewayNp = DeveloperToolsSupport.ImageResource(name: "illustrations/badge-gateway-np", bundle: resourceBundle)

        /// The "illustrations/badge-joshua-tree-np" asset catalog image resource.
        static let badgeJoshuaTreeNp = DeveloperToolsSupport.ImageResource(name: "illustrations/badge-joshua-tree-np", bundle: resourceBundle)

        /// The "illustrations/badge-locked" asset catalog image resource.
        static let badgeLocked = DeveloperToolsSupport.ImageResource(name: "illustrations/badge-locked", bundle: resourceBundle)

        /// The "illustrations/badge-national-park" asset catalog image resource.
        static let badgeNationalPark = DeveloperToolsSupport.ImageResource(name: "illustrations/badge-national-park", bundle: resourceBundle)

        /// The "illustrations/cloud-1" asset catalog image resource.
        static let cloud1 = DeveloperToolsSupport.ImageResource(name: "illustrations/cloud-1", bundle: resourceBundle)

        /// The "illustrations/cloud-2" asset catalog image resource.
        static let cloud2 = DeveloperToolsSupport.ImageResource(name: "illustrations/cloud-2", bundle: resourceBundle)

        /// The "illustrations/earth" asset catalog image resource.
        static let earth = DeveloperToolsSupport.ImageResource(name: "illustrations/earth", bundle: resourceBundle)

        /// The "illustrations/stamp-city" asset catalog image resource.
        static let stampCity = DeveloperToolsSupport.ImageResource(name: "illustrations/stamp-city", bundle: resourceBundle)

        /// The "illustrations/stamps-toronto" asset catalog image resource.
        static let stampsToronto = DeveloperToolsSupport.ImageResource(name: "illustrations/stamps-toronto", bundle: resourceBundle)

    }

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "explore-content" asset catalog resource namespace.
    enum ExploreContent {

        /// The "explore-content/new-york" asset catalog image.
        static var newYork: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .ExploreContent.newYork)
#else
            .init()
#endif
        }

        /// The "explore-content/paris-museums" asset catalog image.
        static var parisMuseums: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .ExploreContent.parisMuseums)
#else
            .init()
#endif
        }

        /// The "explore-content/toronto" asset catalog image.
        static var toronto: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .ExploreContent.toronto)
#else
            .init()
#endif
        }

    }

    /// The "illustrations" asset catalog resource namespace.
    enum Illustrations {

        /// The "illustrations/achievement-level-1" asset catalog image.
        static var achievementLevel1: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .Illustrations.achievementLevel1)
#else
            .init()
#endif
        }

        /// The "illustrations/achievement-level-2" asset catalog image.
        static var achievementLevel2: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .Illustrations.achievementLevel2)
#else
            .init()
#endif
        }

        /// The "illustrations/achievement-level-3" asset catalog image.
        static var achievementLevel3: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .Illustrations.achievementLevel3)
#else
            .init()
#endif
        }

        /// The "illustrations/badge-arches-np" asset catalog image.
        static var badgeArchesNp: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .Illustrations.badgeArchesNp)
#else
            .init()
#endif
        }

        /// The "illustrations/badge-bryce-canyon-np" asset catalog image.
        static var badgeBryceCanyonNp: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .Illustrations.badgeBryceCanyonNp)
#else
            .init()
#endif
        }

        /// The "illustrations/badge-canyonlands-np" asset catalog image.
        static var badgeCanyonlandsNp: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .Illustrations.badgeCanyonlandsNp)
#else
            .init()
#endif
        }

        /// The "illustrations/badge-gateway-np" asset catalog image.
        static var badgeGatewayNp: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .Illustrations.badgeGatewayNp)
#else
            .init()
#endif
        }

        /// The "illustrations/badge-joshua-tree-np" asset catalog image.
        static var badgeJoshuaTreeNp: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .Illustrations.badgeJoshuaTreeNp)
#else
            .init()
#endif
        }

        /// The "illustrations/badge-locked" asset catalog image.
        static var badgeLocked: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .Illustrations.badgeLocked)
#else
            .init()
#endif
        }

        /// The "illustrations/badge-national-park" asset catalog image.
        static var badgeNationalPark: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .Illustrations.badgeNationalPark)
#else
            .init()
#endif
        }

        /// The "illustrations/cloud-1" asset catalog image.
        static var cloud1: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .Illustrations.cloud1)
#else
            .init()
#endif
        }

        /// The "illustrations/cloud-2" asset catalog image.
        static var cloud2: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .Illustrations.cloud2)
#else
            .init()
#endif
        }

        /// The "illustrations/earth" asset catalog image.
        static var earth: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .Illustrations.earth)
#else
            .init()
#endif
        }

        /// The "illustrations/stamp-city" asset catalog image.
        static var stampCity: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .Illustrations.stampCity)
#else
            .init()
#endif
        }

        /// The "illustrations/stamps-toronto" asset catalog image.
        static var stampsToronto: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .Illustrations.stampsToronto)
#else
            .init()
#endif
        }

    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "explore-content" asset catalog resource namespace.
    enum ExploreContent {

        /// The "explore-content/new-york" asset catalog image.
        static var newYork: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .ExploreContent.newYork)
#else
            .init()
#endif
        }

        /// The "explore-content/paris-museums" asset catalog image.
        static var parisMuseums: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .ExploreContent.parisMuseums)
#else
            .init()
#endif
        }

        /// The "explore-content/toronto" asset catalog image.
        static var toronto: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .ExploreContent.toronto)
#else
            .init()
#endif
        }

    }

    /// The "illustrations" asset catalog resource namespace.
    enum Illustrations {

        /// The "illustrations/achievement-level-1" asset catalog image.
        static var achievementLevel1: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .Illustrations.achievementLevel1)
#else
            .init()
#endif
        }

        /// The "illustrations/achievement-level-2" asset catalog image.
        static var achievementLevel2: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .Illustrations.achievementLevel2)
#else
            .init()
#endif
        }

        /// The "illustrations/achievement-level-3" asset catalog image.
        static var achievementLevel3: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .Illustrations.achievementLevel3)
#else
            .init()
#endif
        }

        /// The "illustrations/badge-arches-np" asset catalog image.
        static var badgeArchesNp: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .Illustrations.badgeArchesNp)
#else
            .init()
#endif
        }

        /// The "illustrations/badge-bryce-canyon-np" asset catalog image.
        static var badgeBryceCanyonNp: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .Illustrations.badgeBryceCanyonNp)
#else
            .init()
#endif
        }

        /// The "illustrations/badge-canyonlands-np" asset catalog image.
        static var badgeCanyonlandsNp: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .Illustrations.badgeCanyonlandsNp)
#else
            .init()
#endif
        }

        /// The "illustrations/badge-gateway-np" asset catalog image.
        static var badgeGatewayNp: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .Illustrations.badgeGatewayNp)
#else
            .init()
#endif
        }

        /// The "illustrations/badge-joshua-tree-np" asset catalog image.
        static var badgeJoshuaTreeNp: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .Illustrations.badgeJoshuaTreeNp)
#else
            .init()
#endif
        }

        /// The "illustrations/badge-locked" asset catalog image.
        static var badgeLocked: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .Illustrations.badgeLocked)
#else
            .init()
#endif
        }

        /// The "illustrations/badge-national-park" asset catalog image.
        static var badgeNationalPark: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .Illustrations.badgeNationalPark)
#else
            .init()
#endif
        }

        /// The "illustrations/cloud-1" asset catalog image.
        static var cloud1: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .Illustrations.cloud1)
#else
            .init()
#endif
        }

        /// The "illustrations/cloud-2" asset catalog image.
        static var cloud2: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .Illustrations.cloud2)
#else
            .init()
#endif
        }

        /// The "illustrations/earth" asset catalog image.
        static var earth: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .Illustrations.earth)
#else
            .init()
#endif
        }

        /// The "illustrations/stamp-city" asset catalog image.
        static var stampCity: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .Illustrations.stampCity)
#else
            .init()
#endif
        }

        /// The "illustrations/stamps-toronto" asset catalog image.
        static var stampsToronto: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .Illustrations.stampsToronto)
#else
            .init()
#endif
        }

    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

