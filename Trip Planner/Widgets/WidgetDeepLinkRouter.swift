import Foundation
import Observation

@Observable
final class WidgetDeepLinkRouter {
    var destination: WidgetDeepLink?
    
    func consume() -> WidgetDeepLink? {
        let value = destination
        destination = nil
        return value
    }
}
