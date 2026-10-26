import UIKit
import CoreText

extension Notification.Name {
    static let quickActionCreateNewTrip = Notification.Name("quickActionCreateNewTrip")
    static let openNewTripSheet = Notification.Name("openNewTripSheet")
    static let openAICreateTrip = Notification.Name("openAICreateTrip")
    static let openAIFindPlaces = Notification.Name("openAIFindPlaces")
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Self.applyAppFonts()
        Task { @MainActor in
            AppLucide.applySearchBarChrome()
        }
        application.shortcutItems = []
        return true
    }
    
    private static func applyAppFonts() {
        // Ensure the bundled variable font is registered even if Info.plist path drifts.
        if let url = Bundle.main.url(forResource: "Manrope-VariableFont_wght", withExtension: "ttf")
            ?? Bundle.main.url(forResource: "Manrope-VariableFont_wght", withExtension: "ttf", subdirectory: "Fonts") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        
        if #available(iOS 26.0, *) {
            // iOS 26 large titles are drawn in the glass nav bar. Pinning
            // `scrollEdgeAppearance` (or an opaque background) makes some tabs
            // keep Manrope semibold while others fall back to the system Bold title.
            let nav = UINavigationBarAppearance()
            nav.configureWithTransparentBackground()
            nav.titleTextAttributes = [
                .font: AppFont.uiFont(size: 17, weight: .semibold)
            ]
            nav.largeTitleTextAttributes = [
                .font: AppFont.uiFont(size: 34, weight: .semibold)
            ]
            let navBar = UINavigationBar.appearance()
            navBar.standardAppearance = nav
            navBar.compactAppearance = nav
        } else {
            let nav = UINavigationBarAppearance()
            nav.configureWithDefaultBackground()
            nav.titleTextAttributes = [
                .font: AppFont.uiFont(size: 17, weight: .semibold)
            ]
            nav.largeTitleTextAttributes = [
                .font: AppFont.uiFont(size: 34, weight: .semibold)
            ]
            
            let navBar = UINavigationBar.appearance()
            navBar.standardAppearance = nav
            navBar.compactAppearance = nav
            navBar.scrollEdgeAppearance = nav
            navBar.compactScrollEdgeAppearance = nav
        }
        
        UITabBarItem.appearance().setTitleTextAttributes(
            [.font: AppFont.uiFont(size: 10, weight: .medium)],
            for: .normal
        )
        UITabBarItem.appearance().setTitleTextAttributes(
            [.font: AppFont.uiFont(size: 10, weight: .semibold)],
            for: .selected
        )
        
        UIBarButtonItem.appearance().setTitleTextAttributes(
            [.font: AppFont.uiFont(size: 17, weight: .medium)],
            for: .normal
        )
        
        let pickerFont = AppFont.uiFont(size: 15, weight: .medium)
        UILabel.appearance(whenContainedInInstancesOf: [UIDatePicker.self]).font = pickerFont
        UIDatePicker.appearance().tintColor = UIColor.label
    }
}



