import Foundation

// MARK: - SubscriptionTier

/// Nivel de acceso comercial de Lectoría según la especificación maestra:
/// - `free`: Gratuito (máx. 5 docs activos, EPUB/TXT/pegado, 10 IA/mes, 1 dispositivo).
/// - `premiumFounder`: Premium Fundador ($5/año, primeros 1.000 compradores).
/// - `premiumRegular`: Premium Regular ($9.99/año).
/// - `lifetime`: Licencia de por vida ($20 pago único, primeros 250 compradores).
/// - `institutional`: Licencia institucional patrocinada por universidad/organización.
public enum SubscriptionTier: String, Codable, Sendable, CaseIterable, Hashable {
    case free = "free"
    case premiumFounder = "premium_founder"
    case premiumRegular = "premium_regular"
    case lifetime = "lifetime"
    case institutional = "institutional"

    public var displayName: String {
        switch self {
        case .free:
            return String(localized: "Lectoría Free", comment: "Subscription tier display name")
        case .premiumFounder:
            return String(localized: "Premium Fundador", comment: "Subscription tier display name")
        case .premiumRegular:
            return String(localized: "Premium Regular", comment: "Subscription tier display name")
        case .lifetime:
            return String(localized: "Lectoría Lifetime", comment: "Subscription tier display name")
        case .institutional:
            return String(localized: "Lectoría Institucional", comment: "Subscription tier display name")
        }
    }

    /// Retorna verdadero si el nivel otorga acceso ilimitado a funciones de lectura y anotación.
    public var isUnlimited: Bool {
        switch self {
        case .free:
            return false
        case .premiumFounder, .premiumRegular, .lifetime, .institutional:
            return true
        }
    }
}
