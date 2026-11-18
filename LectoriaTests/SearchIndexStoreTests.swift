import Testing
import Foundation
@testable import Lectoria

struct SearchIndexStoreTests {

    private func makeStore() throws -> SearchIndexStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("index-\(UUID().uuidString).sqlite")
        return try SearchIndexStore(url: url)
    }

    @Test func testFTSExpressionQuotesWordsAndPrefixesLast() {
        #expect(SearchQuery.ftsExpression(for: "hola mundo") == "\"hola mundo\"*")
        #expect(SearchQuery.ftsExpression(for: "  ") == nil)
        #expect(SearchQuery.ftsExpression(for: "*-()") == nil)
        #expect(SearchQuery.ftsExpression(for: "a\"b") == "\"a\"\"b\"*")
        #expect(SearchQuery.ftsExpression(for: "  hola   * mundo ") == "\"hola mundo\"*")
    }

    @Test func testSearchIgnoresCaseAndAccents() async throws {
        let store = try makeStore()
        let id = UUID()
        try await store.replace(publicationID: id, chunks: [IndexChunk(locator: "0", label: "Página 1", text: "La CANCIÓN del pirata")])
        let results = try await store.search("cancion")
        #expect(results.map(\.publicationID) == [id])
        #expect(results.first?.hits.first?.snippet.contains("[[CANCIÓN]]") == true)
    }

    @Test func testPrefixMatchesLastWord() async throws {
        let store = try makeStore()
        try await store.replace(publicationID: UUID(), chunks: [IndexChunk(locator: "0", label: "P", text: "el pirata cantaba")])
        #expect(try await store.search("pira").count == 1)
    }

    @Test func testReplaceSwapsChunksAndDeleteRemoves() async throws {
        let store = try makeStore()
        let id = UUID()
        try await store.replace(publicationID: id, chunks: [IndexChunk(locator: "0", label: "P", text: "manzana")])
        try await store.replace(publicationID: id, chunks: [IndexChunk(locator: "0", label: "P", text: "naranja")])
        #expect(try await store.search("manzana").isEmpty)
        #expect(try await store.search("naranja").count == 1)
        try await store.delete(publicationID: id)
        #expect(try await store.search("naranja").isEmpty)
        #expect(try await store.indexedPublicationIDs().isEmpty)
    }

    @Test func testAtMostFiveHitsPerDocumentWithTotalCount() async throws {
        let store = try makeStore()
        let chunks = (0..<8).map { IndexChunk(locator: "\($0)", label: "Página \($0 + 1)", text: "el faro número \($0)") }
        try await store.replace(publicationID: UUID(), chunks: chunks)
        let result = try #require(try await store.search("faro").first)
        #expect(result.hits.count == 5)
        #expect(result.totalMatches == 8)
        #expect(result.hits.map(\.locator) == ["0", "1", "2", "3", "4"])
    }

    @Test func testHostileQueriesNeverThrow() async throws {
        let store = try makeStore()
        try await store.replace(publicationID: UUID(), chunks: [IndexChunk(locator: "0", label: "P", text: "texto normal")])
        for query in ["\"", "*", "-", "NEAR(", "a OR", "(", "col:x", "🙂", "' OR 1=1 --"] {
            _ = try await store.search(query)
        }
    }

    @Test func testCorruptDatabaseIsRecreated() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("corrupt-\(UUID().uuidString).sqlite")
        try Data("garbage that is not sqlite".utf8).write(to: url)
        let store = try SearchIndexStore(url: url)
        #expect(try await store.search("x").isEmpty)
    }

    /// Los lectores buscan la frase literal: el índice debe pedir las palabras juntas y en orden,
    /// o mostraría resultados que al abrirlos dicen "No se encontraron resultados".
    @Test func testMultiWordQueryIsAPhrase() async throws {
        let store = try makeStore()
        let id = UUID()
        try await store.replace(publicationID: id, chunks: [
            IndexChunk(locator: "0", label: "P", text: "la ballena blanca nadaba"),
            IndexChunk(locator: "1", label: "P", text: "blanca era la ballena")
        ])
        let result = try #require(try await store.search("ballena bla").first)
        #expect(result.totalMatches == 1)
        #expect(result.hits.map(\.locator) == ["0"])
    }
}
