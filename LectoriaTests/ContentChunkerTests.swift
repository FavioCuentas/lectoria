import Testing
import Foundation
@testable import Lectoria

@MainActor
struct ContentChunkerTests {

    /// Copia `data` a `Publications/` con un nombre único y devuelve el registro.
    private func install(_ data: Data, ext: String, type: PublicationType) throws -> (PublicationRecord, URL) {
        let dir = try #require(RenderedPresentationStore.publicationsDirectory())
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = "chunker-\(UUID().uuidString).\(ext)"
        let url = dir.appendingPathComponent(name)
        try data.write(to: url)
        let record = PublicationRecord.newImport(
            title: "Prueba", publicationType: type, localFileName: name,
            mimeType: type.mimeType, fileSize: Int64(data.count), sha256: UUID().uuidString
        )
        return (record, url)
    }

    private func fixture(_ name: String, _ ext: String) throws -> Data {
        let url = try #require(Bundle(for: FixtureBundleToken.self).url(forResource: name, withExtension: ext))
        return try Data(contentsOf: url)
    }

    @Test func testSplitKeepsWordsAndSize() {
        let text = Array(repeating: "palabra", count: 1250).joined(separator: " ") // ~10.000 caracteres
        let chunks = ContentChunker.split(text, locator: "7", label: "Capítulo 7")
        #expect(chunks.count == 3)
        #expect(chunks.allSatisfy { $0.locator == "7" && $0.label == "Capítulo 7" })
        #expect(chunks.allSatisfy { $0.text.count <= ContentChunker.chunkSize + 10 })
        #expect(chunks.allSatisfy { !$0.text.hasPrefix(" ") && $0.text.split(separator: " ").allSatisfy { $0 == "palabra" } })
        #expect(ContentChunker.split("   ", locator: "0", label: "x").isEmpty)
    }

    @Test func testPDFOneChunkPerPage() async throws {
        let (record, url) = try install(PresentationRenderingTests.makePDF(pages: ["uno", "dos"]), ext: "pdf", type: .pdf)
        defer { try? FileManager.default.removeItem(at: url) }
        let chunks = try await ContentChunker.chunks(for: record, fileURL: url)
        #expect(chunks.map(\.label) == ["Página 1", "Página 2"])
        #expect(chunks.map(\.locator) == ["0", "1"])
        #expect(chunks.last?.text.contains("dos") == true)
    }

    @Test func testTextChunksFromBlocks() async throws {
        let text = "Primer párrafo con ballena.\n\nSegundo párrafo.\n\nTercer párrafo con faro."
        let (record, url) = try install(Data(text.utf8), ext: "txt", type: .txt)
        defer { try? FileManager.default.removeItem(at: url) }
        let chunks = try await ContentChunker.chunks(for: record, fileURL: url)
        let all = chunks.map(\.text).joined(separator: " ")
        #expect(all.contains("ballena") && all.contains("Segundo") && all.contains("faro"))
        #expect(chunks.first?.locator == "0")
    }

    @Test func testEPUBChunksPerChapterWithTOCLabels() async throws {
        let (record, url) = try install(try fixture("mini", "epub"), ext: "epub", type: .epub)
        defer { try? FileManager.default.removeItem(at: url) }
        let chunks = try await ContentChunker.chunks(for: record, fileURL: url)
        #expect(chunks.map(\.label) == ["Capítulo uno", "Capítulo dos"])
        #expect(chunks.first?.text.contains("ballena") == true)
        #expect(chunks.last?.text.contains("faro") == true)
        #expect(chunks.last?.locator.hasSuffix("ch2.xhtml") == true)
    }

    @Test func testPPTXWithoutRenderedPDFUsesSlides() async throws {
        let (record, url) = try install(try fixture("three-slides-one-hidden", "pptx"), ext: "pptx", type: .pptx)
        defer { try? FileManager.default.removeItem(at: url) }
        let chunks = try await ContentChunker.chunks(for: record, fileURL: url)
        #expect(chunks.map(\.label) == ["Diapositiva 1", "Diapositiva 2"])
        #expect(chunks.map(\.locator) == ["0", "1"])
        #expect(chunks.first?.text.contains("presupuesto") == true)
    }
}
