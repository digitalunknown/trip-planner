import Foundation
import StoreKit

/// Resolves the current StoreKit 2 transaction JWS for TripStacks+ when available.
enum StoreKitJWSSource {
    static func currentPremiumTransactionJWS() async -> String? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            if PremiumProductID.all.contains(tx.productID) {
                // Prefer the most recent matching entitlement.
                return result.jwsRepresentation
            }
        }
        return nil
    }
}
