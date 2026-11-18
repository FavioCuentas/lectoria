import Foundation
import Observation
import os

private let logger = Logger(subsystem: "com.orvexa.Lectoria", category: "SearchIndexing")

// MARK: - SearchIndexing

/// Pide indexar una publicación para la búsqueda global (usado por `ImportService`).
@MainActor
public protocol SearchIndexing: AnyObject, Sendable {
    func index(publicationID: UUID) async
}

// MARK: - SearchIndexingService

/// Mantiene al día el índice de la búsqueda global y el `indexingStatus` de cada publicación:
/// indexa tras importar, recupera lo pendiente al abrir la app y borra al eliminar.
@MainActor
@Observable
final class SearchIndexingService: SearchIndexing {
    typealias Chunker = @MainActor (PublicationRecord) async throws -> [IndexChunk]

    @ObservationIgnored private let store: SearchIndexStore?
    @ObservationIgnored private let publications: any PublicationRepository
    @ObservationIgnored private let chunker: Chunker

    /// Publicaciones aún sin indexar (para avisar que pueden faltar resultados).
    private(set) var pendingCount = 0

    init(
        store: SearchIndexStore?,
        publications: any PublicationRepository,
        chunker: @escaping Chunker = SearchIndexingService.defaultChunker
    ) {
        self.store = store
        self.publications = publications
        self.chunker = chunker
    }

    static let defaultChunker: Chunker = { record in
        guard let directory = RenderedPresentationStore.publicationsDirectory() else { return [] }
        return try await ContentChunker.chunks(for: record, fileURL: directory.appendingPathComponent(record.localFileName))
    }

    func index(publicationID: UUID) async {
        guard let store, let record = try? await publications.fetch(id: publicationID) else { return }
        await setStatus(.indexing, for: publicationID)
        do {
            let chunks = try await chunker(record)
            // Si se borró mientras se extraía el texto, no se deja nada en el índice.
            guard (try? await publications.fetch(id: publicationID)) != nil else {
                try? await store.delete(publicationID: publicationID)
                return
            }
            try await store.replace(publicationID: publicationID, chunks: chunks)
            await setStatus(.completed, for: publicationID)
        } catch {
            logger.error("No se pudo indexar una publicación: \(String(describing: error))")
            await setStatus(.failed, for: publicationID)
        }
    }

    func remove(publicationID: UUID) async {
        try? await store?.delete(publicationID: publicationID)
        await refreshPendingCount()
    }

    /// Indexa, una a una, las publicaciones pendientes, fallidas o que quedaron a medias
    /// (`indexing`) porque la app se cerró durante el indexado.
    func backfill() async {
        guard store != nil else { return }
        let all = (try? await publications.fetchAll()) ?? []
        let todo = all.filter { $0.indexingStatus != .completed }
        pendingCount = todo.count
        for record in todo {
            if Task.isCancelled { break }
            await index(publicationID: record.id)
        }
        await refreshPendingCount()
    }

    // MARK: - Privado

    /// Relee el registro justo antes de guardar para cambiar solo el estado de indexado.
    private func setStatus(_ status: IndexingStatus, for publicationID: UUID) async {
        guard var fresh = try? await publications.fetch(id: publicationID) else { return }
        fresh.indexingStatus = status
        try? await publications.save(fresh)
        await refreshPendingCount()
    }

    private func refreshPendingCount() async {
        let all = (try? await publications.fetchAll()) ?? []
        pendingCount = all.filter { $0.indexingStatus != .completed }.count
    }
}
