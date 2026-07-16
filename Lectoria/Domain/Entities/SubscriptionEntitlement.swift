import Foundation

// MARK: - SubscriptionEntitlement

/// Define el estado actual de un beneficio o acceso premium del usuario derivado de una suscripción.
public struct SubscriptionEntitlement: Identifiable, Codable, Sendable, Hashable {
    public var id: String { productID }
    
    public let productID: String
    
    /// Estado del beneficio (ej. "active", "expired", "revoked").
    public var status: String
    
    /// Fecha de expiración de la suscripción (nil si es ilimitado o no aplica).
    public var expirationDate: Date?
    
    /// Indica si el usuario está en periodo de gracia para resolver problemas de pago.
    public var isInGracePeriod: Bool
    
    /// Indica si la suscripción se renovará automáticamente al expirar.
    public var willAutoRenew: Bool
    
    /// Última fecha en que se verificó localmente el recibo de compra.
    public var lastVerifiedAt: Date

    public init(
        productID: String,
        status: String,
        expirationDate: Date? = nil,
        isInGracePeriod: Bool = false,
        willAutoRenew: Bool = true,
        lastVerifiedAt: Date = .now
    ) {
        self.productID = productID
        self.status = status
        self.expirationDate = expirationDate
        self.isInGracePeriod = isInGracePeriod
        self.willAutoRenew = willAutoRenew
        self.lastVerifiedAt = lastVerifiedAt
    }
}
