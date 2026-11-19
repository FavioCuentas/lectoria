import Testing
import Foundation
@testable import Lectoria

struct InkStoreTests {
    private func makeStore() -> (InkStore, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("InkStoreTests-\(UUID().uuidString)")
        return (InkStore(directory: directory), directory)
    }

    @Test func testRoundTripPerPage() async throws {
        let (store, _) = makeStore()
        let id = UUID()
        try await store.save(Data([1, 2, 3]), page: 0, publicationID: id)
        try await store.save(Data([9]), page: 3, publicationID: id)
        let drawings = await store.drawings(for: id)
        #expect(drawings == [0: Data([1, 2, 3]), 3: Data([9])])
    }

    @Test func testNilRemovesPage() async throws {
        let (store, _) = makeStore()
        let id = UUID()
        try await store.save(Data([1]), page: 0, publicationID: id)
        try await store.save(Data([2]), page: 1, publicationID: id)
        try await store.save(nil, page: 0, publicationID: id)
        try await store.save(Data(), page: 1, publicationID: id)
        #expect(await store.drawings(for: id).isEmpty)
    }

    @Test func testDeleteRemovesFile() async throws {
        let (store, directory) = makeStore()
        let id = UUID()
        try await store.save(Data([1]), page: 0, publicationID: id)
        await store.delete(publicationID: id)
        #expect(await store.drawings(for: id).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("\(id.uuidString).json").path))
    }

    @Test func testCorruptFileReturnsEmpty() async throws {
        let (store, directory) = makeStore()
        let id = UUID()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("no es json".utf8).write(to: directory.appendingPathComponent("\(id.uuidString).json"))
        #expect(await store.drawings(for: id).isEmpty)
        // Se puede seguir guardando encima.
        try await store.save(Data([4]), page: 2, publicationID: id)
        #expect(await store.drawings(for: id) == [2: Data([4])])
    }

    @Test func testDocumentsAreIsolated() async throws {
        let (store, _) = makeStore()
        let first = UUID(), second = UUID()
        try await store.save(Data([1]), page: 0, publicationID: first)
        #expect(await store.drawings(for: second).isEmpty)
    }
}
