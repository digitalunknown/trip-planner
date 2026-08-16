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
        application.shortcutItems = []
        return true
    }
}



