import Foundation

// MARK: - PlanType

/// Define los cuatro tipos de plan/acceso soportados por Lectoria:
/// - `free`: Plan gratuito con límites de documentos, notas, destacados y cuota mensual de IA local.
/// - `premiumAnnual`: Suscripción anual Premium (~USD 5/año) con acceso ilimitado.
/// - `premiumLifetime`: Licencia Premium de por vida (~USD 20 único pago) con acceso ilimitado.
/// - `institutional`: Acceso ilimitado patrocinado por universidades, escuelas u organizaciones educativas.
public enum PlanType: String, Codable, Sendable, CaseIterable, Hashable {
    case free = "free"
    case premiumAnnual = "premium_annual"
    case premiumLifetime = "premium_lifetime"
    case institutional = "institutional"

    public var displayName: String {
        switch self {
        case .free:
            return String(localized: "Plan Gratuito")
        case .premiumAnnual:
            return String(localized: "Premium Anual")
        case .premiumLifetime:
            return String(localized: "Premium De por Vida")
        case .institutional:
            return String(localized: "Acceso Institucional")
        }
    }

    /// Retorna verdadero si el plan concede acceso ilimitado (Premium Anual, De por vida o Institucional).
    public var isUnlimited: Bool {
        switch self {
        case .free:
            return false
        case .premiumAnnual, .premiumLifetime, .institutional:
            return true
        }
    }
}
