import Foundation
import StoreKit

// MARK: - SubscriptionService

/// Contrato para interactuar con StoreKit y validar compras en la aplicación.
public protocol SubscriptionService: AnyObject, Sendable {
    /// Indica si el usuario tiene acceso Premium activo.
    var hasActiveSubscription: Bool { get }
    
    /// Entitlement de suscripción activo actualmente.
    var activeEntitlement: SubscriptionEntitlement? { get }
    
    /// Carga la lista de productos disponibles para comprar.
    func loadProducts() async throws -> [StoreKit.Product]
    
    /// Compra un producto específico. Retorna la transacción verificada si es exitosa.
    func purchase(_ product: StoreKit.Product) async throws -> Transaction?
    
    /// Restaura transacciones de compra anteriores.
    func restorePurchases() async throws
}
