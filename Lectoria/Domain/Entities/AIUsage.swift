import Foundation

// MARK: - AIUsage

/// Registra el consumo local de créditos de IA por parte del usuario para llevar la contabilidad offline.
public struct AIUsage: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var userID: String?
    
    /// Tipo de operación realizada (ej. "summarize", "explain", "translate").
    public var operation: String
    
    /// Costo en créditos de la operación.
    public var creditCost: Int
    
    /// Fecha de la petición.
    public var createdAt: Date
    
    /// Identificador opcional de la respuesta en la nube para auditoría.
    public var requestID: String?

    public init(
        id: UUID = UUID(),
        userID: String? = nil,
        operation: String,
        creditCost: Int,
        createdAt: Date = .now,
        requestID: String? = nil
    ) {
        self.id = id
        self.userID = userID
        self.operation = operation
        self.creditCost = creditCost
        self.createdAt = createdAt
        self.requestID = requestID
    }
}
