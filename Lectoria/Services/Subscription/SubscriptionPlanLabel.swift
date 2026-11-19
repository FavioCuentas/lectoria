import Foundation

// MARK: - SubscriptionPlanLabel

/// Nombre del plan que se muestra en Perfil, según el producto comprado.
enum SubscriptionPlanLabel {
    static func text(isPremium: Bool, productID: String?) -> String {
        guard isPremium else { return String(localized: "Gratuito", comment: "Profile: free plan") }
        switch productID {
        case "com.lectoria.premium.founder":
            return String(localized: "Premium Fundador", comment: "Profile: founder plan")
        case "com.lectoria.premium.yearly":
            return String(localized: "Premium anual", comment: "Profile: yearly plan")
        case "com.lectoria.premium.lifetime":
            return String(localized: "Premium de por vida", comment: "Profile: lifetime plan")
        default:
            return String(localized: "Premium", comment: "Profile: premium plan")
        }
    }
}
