import Foundation

// MARK: - EntitlementSource

/// Representa una fuente de autorización activa para el usuario.
public enum EntitlementSource: Sendable, Hashable {
    case lifetime
    case appleSubscription(tier: SubscriptionTier)
    case institutional(licenseID: UUID)
    case institutionalGracePeriod(expirationDate: Date)
    case free

    /// Prioridad cuantitativa de resolución (1 = máxima prioridad).
    public var priority: Int {
        switch self {
        case .lifetime: return 1
        case .appleSubscription: return 2
        case .institutional: return 3
        case .institutionalGracePeriod: return 4
        case .free: return 5
        }
    }

    /// Nivel de suscripción equivalente concedido por esta fuente.
    public var equivalentTier: SubscriptionTier {
        switch self {
        case .lifetime:
            return .lifetime
        case .appleSubscription(let tier):
            return tier
        case .institutional, .institutionalGracePeriod:
            return .institutional
        case .free:
            return .free
        }
    }
}
