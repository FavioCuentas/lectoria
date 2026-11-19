import Testing
import Foundation
import SwiftData
@testable import Lectoria

@MainActor
struct SearchIndexingServiceTests {
    private let container = ModelContainerFactory.create(isStoredInMemoryOnly: true)
    private var repository: SwiftDataPublicationRepository { SwiftDataPublicationRepository(container: container) }

    private func makeStore() throws -> SearchIndexStore {
        try SearchIndexStore(url: FileManager.default.temporaryDirectory.appendingPathComponent("svc-\(UUID().uuidString).sqlite"))
    }

    private func record(_ status: IndexingStatus = .pending) -> PublicationRecord {
        var record = PublicationRecord.newImport(
            title: "Doc", publicationType: .txt, localFileName: "\(UUID().uuidString).txt",
            mimeType: "text/plain", fileSize: 1, sha256: UUID().uuidString
        )
        record.indexingStatus = status
        return record
    }

    @Test func testIndexMarksCompletedAndIsSearchable() async throws {
        let store = try makeStore()
        let doc = record()
        try await repository.save(doc)
        let service = SearchIndexingService(store: store, publications: repository) { _ in
            [IndexChunk(locator: "0", label: "Párrafo 1", text: "la ballena")]
        }
        await service.index(publicationID: doc.id)
        #expect(try await repository.fetch(id: doc.id)?.indexingStatus == .completed)
        #expect(try await store.search("ballena").count == 1)
    }

    @Test func testIndexFailureMarksFailed() async throws {
        let store = try makeStore()
        let doc = record()
        try await repository.save(doc)
        struct Boom: Error {}
        let service = SearchIndexingService(store: store, publications: repository) { _ in throw Boom() }
        await service.index(publicationID: doc.id)
        #expect(try await repository.fetch(id: doc.id)?.indexingStatus == .failed)
    }

    @Test func testDeletedDuringIndexingLeavesNoChunks() async throws {
        let store = try makeStore()
        let doc = record()
        let repo = repository
        try await repo.save(doc)
        let service = SearchIndexingService(store: store, publications: repo) { record in
            try await repo.delete(id: record.id)
            return [IndexChunk(locator: "0", label: "P", text: "huérfano")]
        }
        await service.index(publicationID: doc.id)
        #expect(try await store.indexedPublicationIDs().isEmpty)
        #expect(try await repo.fetch(id: doc.id) == nil)
    }

    @Test func testBackfillPicksPendingFailedAndStuckIndexing() async throws {
        let store = try makeStore()
        for status in [IndexingStatus.pending, .failed, .indexing, .completed] {
            try await repository.save(record(status))
        }
        var calls = 0
        let service = SearchIndexingService(store: store, publications: repository, retryLog: freshDefaults()) { _ in
            calls += 1
            return [IndexChunk(locator: "0", label: "P", text: "x")]
        }
        await service.backfill()
        #expect(calls == 3)
        #expect(service.pendingCount == 0)
    }

    @Test func testRemoveDeletesChunks() async throws {
        let store = try makeStore()
        let doc = record()
        try await repository.save(doc)
        let service = SearchIndexingService(store: store, publications: repository) { _ in
            [IndexChunk(locator: "0", label: "P", text: "borrable")]
        }
        await service.index(publicationID: doc.id)
        await service.remove(publicationID: doc.id)
        #expect(try await store.search("borrable").isEmpty)
    }

    private func freshDefaults() -> UserDefaults {
        let name = "indexing-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    /// Un archivo dañado no debe reintentarse en cada arranque: una vez por versión de la app.
    @Test func testFailedDocumentsRetriedOncePerAppVersion() async throws {
        let store = try makeStore()
        try await repository.save(record(.failed))
        let defaults = freshDefaults()
        var calls = 0
        struct Boom: Error {}
        let chunker: SearchIndexingService.Chunker = { _ in calls += 1; throw Boom() }

        await SearchIndexingService(store: store, publications: repository, retryLog: defaults, appVersion: "1.0", chunker: chunker).backfill()
        await SearchIndexingService(store: store, publications: repository, retryLog: defaults, appVersion: "1.0", chunker: chunker).backfill()
        #expect(calls == 1)
        await SearchIndexingService(store: store, publications: repository, retryLog: defaults, appVersion: "1.1", chunker: chunker).backfill()
        #expect(calls == 2)
    }

    /// Los fallidos no cuentan como "Indexando N documentos…".
    @Test func testPendingCountExcludesFailed() async throws {
        let store = try makeStore()
        let doc = record()
        try await repository.save(doc)
        struct Boom: Error {}
        let service = SearchIndexingService(store: store, publications: repository, retryLog: freshDefaults()) { _ in throw Boom() }
        await service.backfill()
        #expect(try await repository.fetch(id: doc.id)?.indexingStatus == .failed)
        #expect(service.pendingCount == 0)
    }

    /// Fragmentos de documentos que ya no existen se limpian al recuperar lo pendiente.
    @Test func testBackfillRemovesOrphanChunks() async throws {
        let store = try makeStore()
        try await store.replace(publicationID: UUID(), chunks: [IndexChunk(locator: "0", label: "P", text: "huérfano")])
        let service = SearchIndexingService(store: store, publications: repository, retryLog: freshDefaults()) { _ in [] }
        await service.backfill()
        #expect(try await store.indexedPublicationIDs().isEmpty)
    }
}
