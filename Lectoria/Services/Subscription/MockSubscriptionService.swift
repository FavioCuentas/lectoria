import Foundation
import StoreKit
import Observation

// MARK: - MockSubscriptionService

/// Implementación simulada de `SubscriptionService` y `PurchaseService` para pruebas y vistas previas.
@Observable
public final class MockSubscriptionService: SubscriptionService, PurchaseService, @unchecked Sendable {
    public var hasActiveSubscription: Bool = false
    public var activeEntitlement: SubscriptionEntitlement? = nil

    public var mockProducts: [StoreKit.Product] = []
    public var shouldFailPurchase = false

    public init(hasActiveSubscription: Bool = false, activeEntitlement: SubscriptionEntitlement? = nil) {
        self.hasActiveSubscription = hasActiveSubscription
        self.activeEntitlement = activeEntitlement
    }

    public func loadProducts() async throws -> [StoreKit.Product] {
        return mockProducts
    }

    public func purchase(_ product: StoreKit.Product) async throws -> PurchaseOutcome {
        if shouldFailPurchase {
            return .failed(error: "Simulated purchase error")
        }
        hasActiveSubscription = true
        activeEntitlement = SubscriptionEntitlement(
            productID: product.id,
            status: "active",
            expirationDate: product.id.contains("lifetime") ? nil : Calendar.current.date(byAdding: .year, value: 1, to: Date())
        )
        return .success(productID: product.id)
    }

    public func purchase(_ product: StoreKit.Product) async throws -> Transaction? {
        hasActiveSubscription = true
        activeEntitlement = SubscriptionEntitlement(
            productID: product.id,
            status: "active",
            expirationDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())
        )
        return nil
    }

    public func restorePurchases() async throws {
        hasActiveSubscription = true
        activeEntitlement = SubscriptionEntitlement(
            productID: "com.lectoria.premium.yearly",
            status: "active",
            expirationDate: Calendar.current.date(byAdding: .year, value: 1, to: Date())
        )
    }

    public func refreshCurrentEntitlements() async throws {
        // No-op for mock
    }

    public func simulatePremiumSubscription(active: Bool = true) async {
        await MainActor.run {
            self.hasActiveSubscription = active
            self.activeEntitlement = active ? SubscriptionEntitlement(
                productID: "com.lectoria.premium.yearly",
                status: "active",
                expirationDate: Calendar.current.date(byAdding: .year, value: 1, to: Date())
            ) : nil
        }
    }

    public func observeTransactionUpdates() async {
        // No-op for mock
    }
}
