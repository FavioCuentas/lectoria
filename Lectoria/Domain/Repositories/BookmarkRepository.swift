import Foundation

// MARK: - BookmarkRepository

/// Contrato para el acceso y gestión de marcadores en base de datos.
public protocol BookmarkRepository: Sendable {
    /// Obtiene todos los marcadores asociados a un documento.
    func fetch(forPublication publicationID: UUID) async throws -> [Bookmark]

    /// Obtiene un marcador por su ID único.
    func fetch(id: UUID) async throws -> Bookmark?

    /// Guarda o actualiza un marcador.
    func save(_ bookmark: Bookmark) async throws

    /// Elimina un marcador por su ID único.
    func delete(id: UUID) async throws
}
