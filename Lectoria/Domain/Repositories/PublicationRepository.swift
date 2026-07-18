import Foundation

// MARK: - PublicationRepository

/// Contrato para el acceso a publicaciones almacenadas.
///
/// Las implementaciones concretas (SwiftData en Fase 2, mock para tests)
/// deben conformar este protocolo. La capa de Features depende únicamente
/// de esta abstracción, nunca de una implementación concreta.
@MainActor
public protocol PublicationRepository: Sendable {
    /// Obtiene todas las publicaciones del usuario.
    func fetchAll() async throws -> [PublicationRecord]

    /// Obtiene una publicación por su identificador.
    func fetch(id: UUID) async throws -> PublicationRecord?

    /// Guarda o actualiza una publicación.
    func save(_ publication: PublicationRecord) async throws

    /// Elimina una publicación por su identificador.
    func delete(id: UUID) async throws
}
