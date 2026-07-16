import Foundation

// MARK: - Bookmark

/// Representa un marcador explícito creado por el usuario en una posición del libro.
public struct Bookmark: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let publicationID: UUID
    
    /// Posición física codificada (Locator de Readium, página de PDF, etc.).
    public var anchor: String
    
    /// Título opcional o nota descriptiva asignada por el usuario o extraída del capítulo.
    public var title: String?
    
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        publicationID: UUID,
        anchor: String,
        title: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.publicationID = publicationID
        self.anchor = anchor
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
