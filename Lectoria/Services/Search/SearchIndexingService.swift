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
    @ObservationIgnored private let retryLog: UserDefaults
    @ObservationIgnored private let appVersion: String

    /// Publicaciones aún sin indexar (para avisar que pueden faltar resultados).
    /// No incluye las que fallaron: no se están indexando.
    private(set) var pendingCount = 0

    private static let failedRetryKey = "searchIndex.failedRetryVersion"

    init(
        store: SearchIndexStore?,
        publications: any PublicationRepository,
        retryLog: UserDefaults = .standard,
        appVersion: String = SearchIndexingService.currentAppVersion,
        chunker: @escaping Chunker = SearchIndexingService.defaultChunker
    ) {
        self.store = store
        self.publications = publications
        self.retryLog = retryLog
        self.appVersion = appVersion
        self.chunker = chunker
    }

    static var currentAppVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(version)(\(build))"
    }

    static let defaultChunker: Chunker = { record in
        guard let directory = RenderedPresentationStore.publicationsDirectory() else { return [] }
        return try await ContentChunker.chunks(for: record, fileURL: directory.appendingPathComponent(record.localFileName))
    }

    func index(publicationID: UUID) async {
        await index(publicationID: publicationID, refreshCount: true)
    }

    func remove(publicationID: UUID) async {
        try? await store?.delete(publicationID: publicationID)
        await refreshPendingCount()
    }

    /// Indexa, una a una, las publicaciones pendientes o que quedaron a medias (`indexing`)
    /// porque la app se cerró durante el indexado. Las que fallaron se reintentan una sola vez
    /// por versión de la app (un archivo dañado no se reintenta en cada arranque).
    /// También limpia fragmentos de documentos que ya no existen.
    func backfill() async {
        guard let store else { return }
        let all = (try? await publications.fetchAll()) ?? []

        let existing = Set(all.map(\.id))
        if let indexed = try? await store.indexedPublicationIDs() {
            for orphan in indexed.subtracting(existing) {
                try? await store.delete(publicationID: orphan)
            }
        }

        let retryFailed = retryLog.string(forKey: Self.failedRetryKey) != appVersion
        if retryFailed { retryLog.set(appVersion, forKey: Self.failedRetryKey) }
        let todo = all.filter { record in
            switch record.indexingStatus {
            case .completed: false
            case .failed: retryFailed
            default: true
            }
        }

        pendingCount = todo.count
        for record in todo {
            if Task.isCancelled { break }
            await index(publicationID: record.id, refreshCount: false)
            pendingCount = max(0, pendingCount - 1)
            // Ceder el hilo principal entre documentos para que la interfaz siga fluida.
            try? await Task.sleep(for: .milliseconds(50))
        }
        await refreshPendingCount()
    }

    private func index(publicationID: UUID, refreshCount: Bool) async {
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
            // Y si se borró justo mientras se escribía, se quita lo escrito.
            if (try? await publications.fetch(id: publicationID)) == nil {
                try? await store.delete(publicationID: publicationID)
                return
            }
            await setStatus(.completed, for: publicationID)
        } catch {
            logger.error("No se pudo indexar una publicación: \(String(describing: error))")
            await setStatus(.failed, for: publicationID)
        }
        if refreshCount { await refreshPendingCount() }
    }

    // MARK: - Privado

    /// Relee el registro justo antes de guardar para cambiar solo el estado de indexado.
    private func setStatus(_ status: IndexingStatus, for publicationID: UUID) async {
        await PublicationRecordUpdates.update(publicationID, repository: publications) { $0.indexingStatus = status }
    }

    private func refreshPendingCount() async {
        let all = (try? await publications.fetchAll()) ?? []
        pendingCount = all.filter { $0.indexingStatus == .pending || $0.indexingStatus == .indexing }.count
    }
}
