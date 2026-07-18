import Foundation
import StoreKit
import Observation

// MARK: - StoreKitSubscriptionService

/// Implementación concreta de `SubscriptionService` utilizando StoreKit 2 de Apple.
///
/// Monitoriza el estado de las compras, actualiza el estado de la suscripción y
/// persiste localmente el entitlement activo en la base de datos para soporte offline.
@Observable
public final class StoreKitSubscriptionService: SubscriptionService, @unchecked Sendable {
    public private(set) var hasActiveSubscription: Bool = false
    public private(set) var activeEntitlement: SubscriptionEntitlement? = nil
    
    private let repository: any SubscriptionRepository
    private var updatesTask: Task<Void, Never>? = nil
    
    private let productIDs = [
        "com.lectoria.premium.monthly",
        "com.lectoria.premium.yearly"
    ]
    
    public init(repository: any SubscriptionRepository) {
        self.repository = repository
        
        // Ejecutar carga inicial y observaciones asíncronamente
        Task {
            await loadCachedEntitlement()
            await observeTransactionUpdates()
            await updateSubscriptionStatus()
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
                // Si ya expiró, actualizar estado
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
    
    /// Escucha transacciones del App Store en tiempo de ejecución (ej. renovaciones, compras externas)
    private func observeTransactionUpdates() async {
        updatesTask = Task {
            for await result in Transaction.updates {
                do {
                    let transaction = try checkVerified(result)
                    await updateSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("[StoreKitSubscriptionService] Error al observar transacciones: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Carga productos directamente de StoreKit
    public func loadProducts() async throws -> [StoreKit.Product] {
        return try await StoreKit.Product.products(for: productIDs)
    }
    
    /// Realiza compra de una suscripción
    public func purchase(_ product: StoreKit.Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()
            await transaction.finish()
            return transaction
        case .pending, .userCancelled:
            return nil
        @unknown default:
            return nil
        }
    }
    
    /// Fuerza la sincronización de transacciones previas
    public func restorePurchases() async throws {
        try await AppStore.sync()
        await updateSubscriptionStatus()
    }
    
    /// Escanea entitlements activos y actualiza el estado local
    private func updateSubscriptionStatus() async {
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
                print("[StoreKitSubscriptionService] Error al procesar entitlement de transaccion: \(error.localizedDescription)")
            }
        }
        
        let hasActive = foundActive
        let ent = activeEnt
        
        await MainActor.run {
            self.hasActiveSubscription = hasActive
            self.activeEntitlement = ent
        }
    }
    
    /// Verifica la firma del resultado de transacción
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
