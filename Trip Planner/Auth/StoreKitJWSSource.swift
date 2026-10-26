import Foundation
import StoreKit

/// Resolves the current StoreKit 2 transaction JWS for TripStacks+ when available.
enum StoreKitJWSSource {
    static func currentPremiumTransactionJWS() async -> String? {
        for await result in Transaction.currentEntitlements {
            guard let tx = try? PremiumStore.checked(result) else { continue }
            if PremiumProductID.all.contains(tx.productID) {
                // Prefer the most recent matching entitlement.
                return tx.jwsRepresentation
            }
        }
        return nil
    }
}

