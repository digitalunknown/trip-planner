import Foundation
import Observation
import StoreKit

enum PremiumProductID {
    static let monthly = "digitalunknown.TripStacks.premium.monthly"
    static let yearly = "digitalunknown.TripStacks.premium.yearly"
    static let all: [String] = [monthly, yearly]
    
    static let appleEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

@MainActor
@Observable
final class PremiumStore {
    var products: [Product] = []
    var isPremium = false
    var isPurchasing = false
    var isLoadingProducts = false
    var errorMessage: String?
    
    var monthlyProduct: Product? {
        products.first { $0.id == PremiumProductID.monthly }
    }
    
    var yearlyProduct: Product? {
        products.first { $0.id == PremiumProductID.yearly }
    }
    
    /// Monthly is the current offer; yearly still unlocks if already purchased.
    var offeredProducts: [Product] {
        [monthlyProduct, yearlyProduct].compactMap { $0 }
    }
    
    private var updatesTask: Task<Void, Never>?
    
    init() {
        updatesTask = listenForTransactions()
        Task { await refresh() }
    }
    
    func refresh() async {
        await loadProducts()
        await updateEntitlements()
    }
    
    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: Set(PremiumProductID.all))
            products = loaded.sorted { lhs, rhs in
                if lhs.id == PremiumProductID.yearly { return true }
                if rhs.id == PremiumProductID.yearly { return false }
                return lhs.price < rhs.price
            }
            if loaded.isEmpty {
                errorMessage = "Subscriptions aren’t available yet. Add the StoreKit configuration in the scheme, or create TripStacks+ in App Store Connect."
            } else {
                errorMessage = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func purchase(_ product: Product) async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.checked(verification)
                await transaction.finish()
                await updateEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func restore() async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await updateEntitlements()
            if !isPremium {
                errorMessage = "No TripStacks+ subscription found for this Apple ID."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func updateEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.checked(result) else { continue }
            if PremiumProductID.all.contains(transaction.productID) {
                entitled = true
                break
            }
        }
        isPremium = entitled
    }
    
    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let transaction = try? Self.checked(result) else { continue }
                await transaction.finish()
                await self?.updateEntitlements()
            }
        }
    }
    
    private static func checked<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
