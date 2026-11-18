import Testing
import Foundation
import SwiftData
@testable import Lectoria
@preconcurrency import ReadiumShared

@MainActor
struct GlobalSearchServiceTests {
    private let container = ModelContainerFactory.create(isStoredInMemoryOnly: true)

    private func makeStore() throws -> SearchIndexStore {
        try SearchIndexStore(url: FileManager.default.temporaryDirectory.appendingPathComponent("global-\(UUID().uuidString).sqlite"))
    }

    private func publication(_ title: String, author: String? = nil) -> PublicationRecord {
        PublicationRecord.newImport(
            title: title, author: author, publicationType: .epub, localFileName: "\(UUID().uuidString).epub",
            mimeType: "application/epub+zip", fileSize: 1, sha256: UUID().uuidString
        )
    }

    @Test func testFindsTitlesContentAndNotes() async throws {
        let store = try makeStore()
        let moby = publication("Moby Dick", author: "Melville")
        try await SwiftDataPublicationRepository(container: container).save(moby)
        try await store.replace(publicationID: moby.id, chunks: [IndexChunk(locator: "ch1.xhtml", label: "Capítulo uno", text: "la ballena blanca")])
        try await SwiftDataNoteRepository(container: container).save(Note(publicationID: moby.id, body: "ballena favorita"))
        try await SwiftDataHighlightRepository(container: container).save(Highlight(publicationID: moby.id, anchor: "{}", selectedText: "una ballena"))

        let service = GlobalSearchService(store: store, container: container)
        let results = await service.search("ballena", publications: [moby])
        #expect(results.titleMatches.isEmpty)
        #expect(results.documents.map(\.publicationID) == [moby.id])
        #expect(results.documents.first?.hits.count == 1)
        #expect(results.annotations.count == 2)
        #expect(Set(results.annotations.map { $0.kind }) == Set([AnnotationHit.Kind.note, .highlight]))

        let byAuthor = await service.search("melville", publications: [moby])
        #expect(byAuthor.titleMatches == [moby.id])
    }

    @Test func testIgnoresAccentsInTitlesAndNotes() async throws {
        let book = publication("Canción de hielo")
        let service = GlobalSearchService(store: try makeStore(), container: container)
        #expect(await service.search("cancion", publications: [book]).titleMatches == [book.id])
    }

    @Test func testDropsHitsOfDeletedPublications() async throws {
        let store = try makeStore()
        try await store.replace(publicationID: UUID(), chunks: [IndexChunk(locator: "0", label: "Página 1", text: "fantasma")])
        let service = GlobalSearchService(store: store, container: container)
        #expect(await service.search("fantasma", publications: []).documents.isEmpty)
    }

    @Test func testEmptyQueryReturnsEmpty() async throws {
        let service = GlobalSearchService(store: try makeStore(), container: container)
        #expect(await service.search("   ", publications: [publication("Algo")]).isEmpty)
    }

    /// Los destacados de EPUB guardan el localizador de Readium tal cual (`jsonString`).
    @Test func testEPUBAnchorFromReadiumLocatorJSON() throws {
        let locator = Locator(href: try #require(AnyURL(string: "OEBPS/ch2.xhtml")), mediaType: .xhtml, title: "Capítulo dos")
        let anchor = try locator.jsonString()
        let location = try #require(ReaderAnchor.epubLocation(from: anchor))
        #expect(location.locator.href.string == "OEBPS/ch2.xhtml")
        #expect(ReaderAnchor.epubLocation(from: "no es json") == nil)
        #expect(ReaderAnchor.epubLocation(from: nil) == nil)
    }

    /// Las notas de EPUB no guardan anchor propio: usan el de su destacado.
    @Test func testNoteWithoutAnchorUsesItsHighlightAnchor() async throws {
        let book = publication("Libro")
        try await SwiftDataPublicationRepository(container: container).save(book)
        let highlight = Highlight(publicationID: book.id, anchor: "{\"href\":\"ch1.xhtml\"}", selectedText: "texto")
        try await SwiftDataHighlightRepository(container: container).save(highlight)
        try await SwiftDataNoteRepository(container: container).save(Note(publicationID: book.id, highlightID: highlight.id, body: "comentario único"))

        let service = GlobalSearchService(store: try makeStore(), container: container)
        let note = try #require(await service.search("único", publications: [book]).annotations.first)
        #expect(note.anchor == highlight.anchor)
    }
}
