import Foundation
import StoreKit

// MARK: - PurchaseService

/// Contrato oficial de compra y sincronización con StoreKit 2 según la especificación maestra.
public protocol PurchaseService: Sendable {
    /// Carga los productos de la App Store para los IDs centralizados.
    func loadProducts() async throws -> [Product]

    /// Inicia el flujo de compra de StoreKit 2 para el producto seleccionado.
    func purchase(_ product: Product) async throws -> PurchaseOutcome

    /// Sincroniza y restaura transacciones previas con la App Store (AppStore.sync).
    func restorePurchases() async throws

    /// Actualiza y reconcilia los entitlements activos con las transacciones de StoreKit.
    func refreshCurrentEntitlements() async throws

    /// Inicia la observación asíncrona de Transaction.updates para renovaciones y compras externas.
    func observeTransactionUpdates() async
}
