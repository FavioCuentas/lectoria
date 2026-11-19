import Testing
import Foundation
@testable import Lectoria

@MainActor
struct PublicationRecordUpdatesTests {
    /// Marcar favorito desde una copia vieja no debe pisar el estado de indexado más reciente.
    @Test func testUpdateChangesOnlyRequestedFieldOnStoredRecord() async throws {
        let repo = SwiftDataPublicationRepository(container: ModelContainerFactory.create(isStoredInMemoryOnly: true))
        let stale = PublicationRecord.newImport(title: "Doc", publicationType: .pdf, localFileName: "a.pdf",
                                                mimeType: "x", fileSize: 1, sha256: UUID().uuidString)
        try await repo.save(stale)
        var indexed = stale
        indexed.indexingStatus = .completed
        try await repo.save(indexed)

        await PublicationRecordUpdates.update(stale.id, repository: repo) { $0.isFavorite = true }

        let stored = try #require(try await repo.fetch(id: stale.id))
        #expect(stored.isFavorite)
        #expect(stored.indexingStatus == .completed)
    }
}
