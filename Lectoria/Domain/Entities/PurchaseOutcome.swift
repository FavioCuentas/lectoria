import Foundation

// MARK: - PurchaseOutcome

/// Resultado tipado de una transacción de compra procesada con StoreKit 2.
public enum PurchaseOutcome: Equatable, Sendable {
    case success(productID: String)
    case userCancelled
    case pending
    case failed(error: String)
}
