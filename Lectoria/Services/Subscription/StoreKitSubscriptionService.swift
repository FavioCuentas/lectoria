import Foundation
import StoreKit
import Observation

// MARK: - StoreKitSubscriptionService

/// Implementación concreta de `SubscriptionService` y `PurchaseService` utilizando StoreKit 2 de Apple.
///
/// Monitoriza el estado de las compras, actualiza el estado de la suscripción y
/// persiste localmente el entitlement activo en la base de datos para soporte offline.
@Observable
public final class StoreKitSubscriptionService: SubscriptionService, PurchaseService, @unchecked Sendable {
    public private(set) var hasActiveSubscription: Bool = false
    public private(set) var activeEntitlement: SubscriptionEntitlement? = nil

    private let repository: any SubscriptionRepository
    private var updatesTask: Task<Void, Never>? = nil

    public static let founderProductID = "com.lectoria.premium.founder"
    public static let yearlyProductID = "com.lectoria.premium.yearly"
    public static let lifetimeProductID = "com.lectoria.premium.lifetime"

    private let productIDs = [
        founderProductID,
        yearlyProductID,
        lifetimeProductID
    ]

    public init(repository: any SubscriptionRepository) {
        self.repository = repository

        Task {
            await loadCachedEntitlement()
            await observeTransactionUpdates()
            await refreshCurrentEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// Carga rápida inicial desde la persistencia local de SwiftData
    private func loadCachedEntitlement() async {
        do {
            let entitlements = try await repository.fetchAllEntitlements()
            if let active = entitlements.first(where: { $0.status == "active" }) {
                if let exp = active.expirationDate, exp < Date() {
                    var expired = active
                    expired.status = "expired"
                    try? await repository.saveEntitlement(expired)
                } else {
                    await MainActor.run {
                        self.activeEntitlement = active
                        self.hasActiveSubscription = true
                    }
                }
            }
        } catch {
            print("[StoreKitSubscriptionService] Error al verificar active entitlements: \(error.localizedDescription)")
        }
    }

    /// Escucha transacciones del App Store en tiempo de ejecución (renovaciones, reembolsos, revocaciones)
    public func observeTransactionUpdates() async {
        updatesTask?.cancel()
        updatesTask = Task {
            for await result in Transaction.updates {
                do {
                    let transaction = try checkVerified(result)
                    await refreshCurrentEntitlements()
                    await transaction.finish()
                } catch {
                    print("[StoreKitSubscriptionService] Error al observar transacciones: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Carga productos directamente de StoreKit 2
    public func loadProducts() async throws -> [StoreKit.Product] {
        return try await StoreKit.Product.products(for: productIDs)
    }

    /// Realiza compra de un producto y devuelve `PurchaseOutcome` tipado
    public func purchase(_ product: StoreKit.Product) async throws -> PurchaseOutcome {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await refreshCurrentEntitlements()
            await transaction.finish()
            return .success(productID: transaction.productID)

        case .userCancelled:
            return .userCancelled

        case .pending:
            return .pending

        @unknown default:
            return .failed(error: String(localized: "Respuesta de compra desconocida del sistema.", comment: "Unknown purchase result"))
        }
    }

    /// Método de compatibilidad para `SubscriptionService`
    public func purchase(_ product: StoreKit.Product) async throws -> Transaction? {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await refreshCurrentEntitlements()
            await transaction.finish()
            return transaction
        default:
            return nil
        }
    }

    /// Fuerza la sincronización de transacciones previas con AppStore.sync()
    public func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshCurrentEntitlements()
    }

    /// Escanea entitlements activos y actualiza la persistencia local
    public func refreshCurrentEntitlements() async {
        var foundActive = false
        var activeEnt: SubscriptionEntitlement? = nil

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                if productIDs.contains(transaction.productID) {
                    let isRevoked = transaction.revocationDate != nil
                    let isExpired = transaction.expirationDate.map { $0 < Date() } ?? false

                    let status: String
                    if isRevoked {
                        status = "revoked"
                    } else if isExpired {
                        status = "expired"
                    } else {
                        status = "active"
                    }

                    let entitlement = SubscriptionEntitlement(
                        productID: transaction.productID,
                        status: status,
                        expirationDate: transaction.expirationDate,
                        isInGracePeriod: false,
                        willAutoRenew: true,
                        lastVerifiedAt: Date()
                    )

                    try? await repository.saveEntitlement(entitlement)

                    if status == "active" {
                        foundActive = true
                        activeEnt = entitlement
                    }
                }
            } catch {
                print("[StoreKitSubscriptionService] Error al procesar entitlement de transacción: \(error.localizedDescription)")
            }
        }

        let hasActive = foundActive
        let ent = activeEnt

        await MainActor.run {
            self.hasActiveSubscription = hasActive
            self.activeEntitlement = ent
        }
    }

    /// Verifica la firma criptográfica del resultado de transacción
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
