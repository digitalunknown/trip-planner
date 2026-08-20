import UIKit

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
        application.shortcutItems = []
        return true
    }
    
    private static func applyAppFonts() {
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
        
        UITabBarItem.appearance().setTitleTextAttributes(
            [.font: AppFont.uiFont(size: 10, weight: .medium)],
            for: .normal
        )
        UITabBarItem.appearance().setTitleTextAttributes(
            [.font: AppFont.uiFont(size: 10, weight: .semibold)],
            for: .selected
        )
        
        UIBarButtonItem.appearance().setTitleTextAttributes(
            [.font: AppFont.uiFont(size: 17, weight: .regular)],
            for: .normal
        )
    }
}



