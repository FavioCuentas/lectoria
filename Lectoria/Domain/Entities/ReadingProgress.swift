import Foundation

// MARK: - ReadingProgress

/// Representa el progreso detallado de lectura del usuario en una publicación específica.
///
/// Es independiente del formato del libro y registra la última ubicación física,
/// el porcentaje leído y la marca de tiempo de sincronización.
public struct ReadingProgress: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let publicationID: UUID
    
    /// Posición física codificada en JSON (Locator de Readium, página de PDF, etc.).
    public var locatorJSON: String
    
    /// Porcentaje de progreso de lectura (rango de 0.0 a 1.0).
    public var percentage: Double
    
    /// Número de página estimado, si es aplicable.
    public var pageNumber: Int?
    
    /// Título del capítulo actual, si está disponible.
    public var chapterTitle: String?
    
    /// Fecha de la última actualización.
    public var updatedAt: Date
    
    /// Identificador único del dispositivo que generó este progreso.
    public var deviceID: String
    
    /// Versión incremental para resolución de conflictos en la sincronización.
    public var version: Int

    public init(
        id: UUID = UUID(),
        publicationID: UUID,
        locatorJSON: String,
        percentage: Double,
        pageNumber: Int? = nil,
        chapterTitle: String? = nil,
        updatedAt: Date = .now,
        deviceID: String,
        version: Int = 1
    ) {
        self.id = id
        self.publicationID = publicationID
        self.locatorJSON = locatorJSON
        self.percentage = percentage
        self.pageNumber = pageNumber
        self.chapterTitle = chapterTitle
        self.updatedAt = updatedAt
        self.deviceID = deviceID
        self.version = version
    }
}
