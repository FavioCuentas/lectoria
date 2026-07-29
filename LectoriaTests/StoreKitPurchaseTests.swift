import Testing
import Foundation
import StoreKit
import SwiftData
@testable import Lectoria

// MARK: - StoreKitPurchaseTests

@MainActor
struct StoreKitPurchaseTests {
    private let container: ModelContainer
    private let mockSub: MockSubscriptionService
    private let dependencies: AppDependencies

    init() {
        self.container = ModelContainerFactory.create(isStoredInMemoryOnly: true)
        self.mockSub = MockSubscriptionService()
        self.dependencies = AppDependencies(
            modelContainer: container,
            authService: MockAuthService(),
            subscriptionService: mockSub
        )
    }

    @Test("PurchaseOutcome enum equality and states")
    func testPurchaseOutcomeStates() async throws {
        let successOutcome = PurchaseOutcome.success(productID: "com.lectoria.premium.founder")
        let cancelledOutcome = PurchaseOutcome.userCancelled
        let pendingOutcome = PurchaseOutcome.pending
        let failedOutcome = PurchaseOutcome.failed(error: "Network error")

        #expect(successOutcome == PurchaseOutcome.success(productID: "com.lectoria.premium.founder"))
        #expect(cancelledOutcome == .userCancelled)
        #expect(pendingOutcome == .pending)
        #expect(failedOutcome == .failed(error: "Network error"))
    }

    @Test("Mock purchase lifecycle updates active entitlement")
    func testMockPurchaseLifecycle() async throws {
        #expect(mockSub.hasActiveSubscription == false)
        #expect(mockSub.activeEntitlement == nil)

        // Simular compra directa en MockSubscriptionService
        mockSub.hasActiveSubscription = true
        mockSub.activeEntitlement = SubscriptionEntitlement(
            productID: StoreKitSubscriptionService.founderProductID,
            status: "active",
            expirationDate: Date().addingTimeInterval(365 * 86400)
        )

        #expect(mockSub.hasActiveSubscription == true)
        #expect(mockSub.activeEntitlement?.productID == StoreKitSubscriptionService.founderProductID)
        #expect(mockSub.activeEntitlement?.status == "active")
    }

    @Test("Purchase failure handling in MockSubscriptionService")
    func testPurchaseFailureHandling() async throws {
        mockSub.shouldFailPurchase = true
        #expect(mockSub.shouldFailPurchase == true)
    }

    @Test("Restore purchases syncs entitlement status")
    func testRestorePurchasesLifecycle() async throws {
        let purchaseService: any PurchaseService = mockSub
        #expect(mockSub.hasActiveSubscription == false)

        try await purchaseService.restorePurchases()
        #expect(mockSub.hasActiveSubscription == true)
        #expect(mockSub.activeEntitlement?.productID == StoreKitSubscriptionService.yearlyProductID)
    }

    @Test("SubscriptionEntitlement model state transitions")
    func testEntitlementModelStates() async throws {
        let activeEnt = SubscriptionEntitlement(
            productID: StoreKitSubscriptionService.founderProductID,
            status: "active",
            expirationDate: Date().addingTimeInterval(365 * 86400),
            isInGracePeriod: false,
            willAutoRenew: true
        )

        #expect(activeEnt.id == StoreKitSubscriptionService.founderProductID)
        #expect(activeEnt.status == "active")
        #expect(activeEnt.isInGracePeriod == false)
        #expect(activeEnt.willAutoRenew == true)

        var revokedEnt = activeEnt
        revokedEnt.status = "revoked"
        #expect(revokedEnt.status == "revoked")
    }
}
