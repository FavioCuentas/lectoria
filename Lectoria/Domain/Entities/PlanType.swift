import Foundation

// MARK: - PlanType

/// Alias de compatibilidad hacia `SubscriptionTier` para mantener sincronizado el modelo de dominio.
public typealias PlanType = SubscriptionTier

public extension SubscriptionTier {
    static var premiumAnnual: SubscriptionTier { .premiumRegular }
    static var premiumLifetime: SubscriptionTier { .lifetime }
}
