import Foundation

// MARK: - SubscriptionRepository

/// Contrato para el control del estado y validez de las suscripciones.
@MainActor
public protocol SubscriptionRepository: Sendable {
    /// Obtiene todos los entitlements de suscripción locales.
    func fetchAllEntitlements() async throws -> [SubscriptionEntitlement]

    /// Obtiene un entitlement de suscripción por su Product ID.
    func fetchEntitlement(productID: String) async throws -> SubscriptionEntitlement?

    /// Guarda o actualiza un entitlement de suscripción.
    func saveEntitlement(_ entitlement: SubscriptionEntitlement) async throws
}
