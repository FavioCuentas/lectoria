import Foundation
import StoreKit
import Observation

// MARK: - MockSubscriptionService

/// Implementación simulada de `SubscriptionService` para pruebas y vistas previas.
@Observable
public final class MockSubscriptionService: SubscriptionService, @unchecked Sendable {
    public var hasActiveSubscription: Bool = false
    public var activeEntitlement: SubscriptionEntitlement? = nil
    
    public var mockProducts: [StoreKit.Product] = []
    
    public init(hasActiveSubscription: Bool = false, activeEntitlement: SubscriptionEntitlement? = nil) {
        self.hasActiveSubscription = hasActiveSubscription
        self.activeEntitlement = activeEntitlement
    }
    
    public func loadProducts() async throws -> [StoreKit.Product] {
        return mockProducts
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
            productID: "com.lectoria.premium.monthly",
            status: "active",
            expirationDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())
        )
    }
}
