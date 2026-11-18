import Foundation
import StoreKit
import Observation
import os

private let logger = Logger(subsystem: "com.orvexa.Lectoria", category: "Subscription")

// MARK: - StoreKitSubscriptionService

/// Implementación concreta de `SubscriptionService` y `PurchaseService` utilizando StoreKit 2 de Apple.
///
/// Monitoriza el estado de las compras, actualiza el estado de la suscripción y
/// persiste localmente el entitlement activo en la base de datos para soporte offline.
@Observable
public final class StoreKitSubscriptionService: SubscriptionService, PurchaseService, @unchecked Sendable {
    /// Estado real reportado por StoreKit 2.
    private var storeHasActiveSubscription: Bool = false
    private var storeActiveEntitlement: SubscriptionEntitlement? = nil

    /// Devuelve el email de la sesión actual; se usa para conceder acceso de cortesía.
    private let currentEmailProvider: (@Sendable () -> String?)?

    /// Cuentas con Premium de por vida concedido manualmente (cuentas de prueba del equipo).
    /// Solo aplica a sesiones autenticadas (OTP/Google/Apple verifican la propiedad del email).
    static let complimentaryLifetimeEmails: Set<String> = [
        "faviocuentas@yahoo.com"
    ]

    /// `true` si la sesión actual pertenece a una cuenta de cortesía de por vida.
    private var hasComplimentaryLifetime: Bool {
        guard let email = currentEmailProvider?()?.trimmingCharacters(in: .whitespaces).lowercased() else { return false }
        return Self.complimentaryLifetimeEmails.contains(email)
    }

    public var hasActiveSubscription: Bool {
        storeHasActiveSubscription || hasComplimentaryLifetime
    }

    public var activeEntitlement: SubscriptionEntitlement? {
        if let storeActiveEntitlement { return storeActiveEntitlement }
        guard hasComplimentaryLifetime else { return nil }
        return SubscriptionEntitlement(
            productID: Self.lifetimeProductID,
            status: "active",
            expirationDate: nil
        )
    }

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

    public init(
        repository: any SubscriptionRepository,
        currentEmailProvider: (@Sendable () -> String?)? = nil
    ) {
        self.repository = repository
        self.currentEmailProvider = currentEmailProvider

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
                        self.storeActiveEntitlement = active
                        self.storeHasActiveSubscription = true
                    }
                }
            }
        } catch {
            logger.error("[StoreKitSubscriptionService] Error al verificar active entitlements: \(error.localizedDescription)")
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
                    logger.error("[StoreKitSubscriptionService] Error al observar transacciones: \(error.localizedDescription)")
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
                logger.error("[StoreKitSubscriptionService] Error al procesar entitlement de transacción: \(error.localizedDescription)")
            }
        }

        let hasActive = foundActive
        let ent = activeEnt

        await MainActor.run {
            self.storeHasActiveSubscription = hasActive
            self.storeActiveEntitlement = ent
        }
    }

    /// Simula o conmuta el estado Premium en tiempo de desarrollo/simulador
    public func simulatePremiumSubscription(active: Bool = true) async {
        let entitlement = SubscriptionEntitlement(
            productID: active ? Self.yearlyProductID : "free",
            status: active ? "active" : "expired",
            expirationDate: active ? Date().addingTimeInterval(365 * 24 * 3600) : Date().addingTimeInterval(-3600),
            isInGracePeriod: false,
            willAutoRenew: active,
            lastVerifiedAt: Date()
        )
        try? await repository.saveEntitlement(entitlement)
        await MainActor.run {
            self.storeHasActiveSubscription = active
            self.storeActiveEntitlement = active ? entitlement : nil
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
