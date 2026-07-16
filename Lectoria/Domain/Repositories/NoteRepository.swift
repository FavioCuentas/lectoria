import Foundation

// MARK: - NoteRepository

/// Contrato para el acceso y gestión de notas de estudio.
public protocol NoteRepository: Sendable {
    /// Obtiene todas las notas asociadas a un documento.
    func fetch(forPublication publicationID: UUID) async throws -> [Note]

    /// Obtiene una nota específica por su ID.
    func fetch(id: UUID) async throws -> Note?

    /// Obtiene todas las notas del usuario (para la pestaña global de Notas).
    func fetchAll() async throws -> [Note]

    /// Guarda o actualiza una nota.
    func save(_ note: Note) async throws

    /// Elimina una nota por su ID.
    func delete(id: UUID) async throws
}
