import Foundation

// MARK: - HighlightRepository

/// Contrato para el acceso y gestión de subrayados.
@MainActor
public protocol HighlightRepository: Sendable {
    /// Obtiene todos los subrayados asociados a un documento.
    func fetch(forPublication publicationID: UUID) async throws -> [Highlight]

    /// Obtiene todos los subrayados del usuario (para la pestaña global de Notas).
    func fetchAll() async throws -> [Highlight]

    /// Obtiene un subrayado específico por su ID único.
    func fetch(id: UUID) async throws -> Highlight?

    /// Guarda o actualiza un subrayado.
    func save(_ highlight: Highlight) async throws

    /// Elimina un subrayado por su ID.
    func delete(id: UUID) async throws
}
