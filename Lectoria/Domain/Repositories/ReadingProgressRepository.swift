import Foundation

// MARK: - ReadingProgressRepository

/// Contrato para el acceso y guardado del progreso de lectura.
public protocol ReadingProgressRepository: Sendable {
    /// Obtiene el progreso de lectura de una publicación.
    func fetchProgress(forPublication publicationID: UUID) async throws -> ReadingProgress?

    /// Guarda o actualiza el progreso de lectura.
    func saveProgress(_ progress: ReadingProgress) async throws
}
