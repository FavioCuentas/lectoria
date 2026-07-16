import Foundation

// MARK: - Note

/// Representa una nota de texto que el usuario puede redactar.
/// Puede estar asociada a un subrayado específico (`Highlight`) o existir como anotación general del libro.
public struct Note: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let publicationID: UUID
    
    /// ID del subrayado asociado, si corresponde.
    public var highlightID: UUID?
    
    /// Posición física codificada si es una anotación referenciada al libro.
    public var anchor: String?
    
    /// Contenido redactado de la nota.
    public var body: String
    
    /// Etiquetas personalizadas asignadas a la nota para facilitar su búsqueda.
    public var tags: [String]
    
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        publicationID: UUID,
        highlightID: UUID? = nil,
        anchor: String? = nil,
        body: String,
        tags: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.publicationID = publicationID
        self.highlightID = highlightID
        self.anchor = anchor
        self.body = body
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
