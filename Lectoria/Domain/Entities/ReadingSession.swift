import Foundation

// MARK: - ReadingSession

/// Representa una sesión de lectura discreta en el tiempo.
/// Registra cuánto tiempo leyó el usuario y cuánto avanzó.
public struct ReadingSession: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let publicationID: UUID
    
    /// Marca de tiempo de inicio de la sesión.
    public var startedAt: Date
    
    /// Marca de tiempo de fin de la sesión.
    public var endedAt: Date
    
    /// Segundos activos reales dedicados a la lectura durante esta sesión (descontando pausas).
    public var activeSeconds: Int
    
    /// Porcentaje de progreso al iniciar (0.0 a 1.0).
    public var startPercentage: Double
    
    /// Porcentaje de progreso al finalizar (0.0 a 1.0).
    public var endPercentage: Double

    public init(
        id: UUID = UUID(),
        publicationID: UUID,
        startedAt: Date,
        endedAt: Date,
        activeSeconds: Int,
        startPercentage: Double,
        endPercentage: Double
    ) {
        self.id = id
        self.publicationID = publicationID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.activeSeconds = activeSeconds
        self.startPercentage = startPercentage
        self.endPercentage = endPercentage
    }
}
