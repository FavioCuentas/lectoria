import Foundation

// MARK: - ReadingSessionRepository

/// Contrato para el acceso y registro de sesiones de lectura.
@MainActor
public protocol ReadingSessionRepository: Sendable {
    /// Obtiene todas las sesiones de lectura de un libro en particular.
    func fetch(forPublication publicationID: UUID) async throws -> [ReadingSession]

    /// Obtiene todas las sesiones de lectura registradas.
    func fetchAll() async throws -> [ReadingSession]

    /// Registra una nueva sesión de lectura.
    func save(_ session: ReadingSession) async throws
}
