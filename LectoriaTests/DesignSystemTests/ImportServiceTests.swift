import Testing
import Foundation
import SwiftData
@testable import Lectoria

// MARK: - ImportServiceTests

@MainActor
struct ImportServiceTests {
    private let container: ModelContainer
    private let pubRepo: SwiftDataPublicationRepository
    private let importService: ImportService

    init() {
        self.container = ModelContainerFactory.create(isStoredInMemoryOnly: true)
        let repo = SwiftDataPublicationRepository(container: container)
        self.pubRepo = repo
        self.importService = ImportService(
            publicationRepository: repo
        )
    }

    @Test("Import pasted text successfully")
    func importPastedText() async throws {
        let text = "El coronel destapó el tarro de café y vio que no quedaba más que una cucharadita."
        let title = "El café del coronel"
        
        let record = try await importService.importPastedText(text: text, title: title)
        
        #expect(record.title == "El café del coronel")
        #expect(record.publicationType == .pastedText)
        #expect(record.mimeType == "text/plain")
        #expect(record.fileSize > 0)
        #expect(!record.sha256.isEmpty)
        
        // Verify it was persisted in db
        let all = try await pubRepo.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.id == record.id)
        #expect(all.first?.title == "El café del coronel")
    }

    @Test("Import pasted text duplicates check")
    func importPastedTextDuplicates() async throws {
        let text = "El mar estaba revuelto aquella noche."
        let title = "El mar"
        
        // Import first time
        _ = try await importService.importPastedText(text: text, title: title)
        
        // Import second time (same content, should throw duplicate error)
        await #expect(throws: ImportError.self) {
            _ = try await importService.importPastedText(text: text, title: title)
        }
    }

    @Test("Import file-based txt document")
    func importTxtFile() async throws {
        // Create a temporary TXT file
        let fileContent = "Lector de libros electrónicos nativo para iPhone."
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let tempFileURL = tempDirectory.appendingPathComponent("mi_libro.txt")
        
        try fileContent.write(to: tempFileURL, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: tempFileURL)
        }
        
        let record = try await importService.importPublication(from: tempFileURL)
        
        #expect(record.title == "Mi Libro") // MetadataExtractor sanitizes "mi_libro"
        #expect(record.publicationType == .txt)
        #expect(record.originalFileName == "mi_libro.txt")
        #expect(record.fileSize == Int64(fileContent.utf8.count))
        
        // Verify it's registered in db
        let fetched = try await pubRepo.fetch(id: record.id)
        #expect(fetched != nil)
        #expect(fetched?.title == "Mi Libro")
    }

    @Test("Import unsupported file type throws error")
    func importUnsupportedFormat() async throws {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let tempFileURL = tempDirectory.appendingPathComponent("documento.docx")
        
        try "unsupported".write(to: tempFileURL, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: tempFileURL)
        }
        
        await #expect(throws: ImportError.self) {
            _ = try await importService.importPublication(from: tempFileURL)
        }
    }

    // MARK: - Conversión de presentaciones al importar

    @MainActor final class RenderingSpy: PresentationPDFRendering {
        var requested: [String] = []
        func ensureRendered(localFileName: String, publicationID: UUID) async {
            requested.append(localFileName)
        }
    }

    @Test("Importing a PPTX requests PDF rendering in the background")
    func testImportPPTXRequestsRendering() async throws {
        let spy = RenderingSpy()
        let service = ImportService(publicationRepository: pubRepo, presentationRenderer: spy)
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("deck-\(UUID().uuidString).pptx")
        try SamplePPTXGenerator.createSamplePPTXData().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let record = try await service.importPublication(from: url)
        try await Task.sleep(for: .milliseconds(200))

        #expect(spy.requested == [record.localFileName])
    }

    @Test("Importing a TXT does not request rendering")
    func testImportTXTDoesNotRequestRendering() async throws {
        let spy = RenderingSpy()
        let service = ImportService(publicationRepository: pubRepo, presentationRenderer: spy)
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nota-\(UUID().uuidString).txt")
        try "Texto de prueba \(UUID())".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        _ = try await service.importPublication(from: url)
        try await Task.sleep(for: .milliseconds(200))

        #expect(spy.requested.isEmpty)
    }

    @MainActor final class IndexingSpy: SearchIndexing {
        var requested: [UUID] = []
        func index(publicationID: UUID) async { requested.append(publicationID) }
    }

    @Test("Importing any document requests search indexing")
    func testImportRequestsIndexing() async throws {
        let spy = IndexingSpy()
        let service = ImportService(publicationRepository: pubRepo, searchIndexer: spy)
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("indexar-\(UUID().uuidString).txt")
        try "Texto para indexar \(UUID())".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let record = try await service.importPublication(from: url)
        try await Task.sleep(for: .milliseconds(200))

        #expect(spy.requested == [record.id])
    }
}
