import UIKit

extension Notification.Name {
    static let quickActionCreateNewTrip = Notification.Name("quickActionCreateNewTrip")
    static let openNewTripSheet = Notification.Name("openNewTripSheet")
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.shortcutItems = []
        return true
    }
}



