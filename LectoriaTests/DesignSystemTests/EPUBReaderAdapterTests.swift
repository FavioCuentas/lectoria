import Testing
import Foundation
import SwiftData
import ReadiumShared
@testable import Lectoria

// MARK: - EPUBReaderAdapterTests

@MainActor
struct EPUBReaderAdapterTests {
    
    @Test("EPUBLocation Codable serialization and deserialization roundtrip")
    func locationCodableRoundtrip() throws {
        let locator = Locator(
            href: AnyURL(string: "http://example.com/chapter1.html")!,
            mediaType: .html,
            title: "Capítulo I",
            locations: Locator.Locations(totalProgression: 0.25)
        )
        let location = EPUBLocation(locator: locator)
        
        // Codificar
        let data = try JSONEncoder().encode(location)
        
        // Decodificar
        let decoded = try JSONDecoder().decode(EPUBLocation.self, from: data)
        
        // Verificar igualdad e integridad de datos
        #expect(decoded.locator.href.string == "http://example.com/chapter1.html")
        #expect(decoded.locator.title == "Capítulo I")
        #expect(decoded.locator.locations.totalProgression == 0.25)
    }

    @Test("ReadingProgressRepository save and fetch operations in SwiftData")
    func progressRepositoryOperations() async throws {
        let container = ModelContainerFactory.create(isStoredInMemoryOnly: true)
        let progressRepo = SwiftDataReadingProgressRepository(container: container)
        
        let publicationID = UUID()
        let progress = ReadingProgress(
            publicationID: publicationID,
            locatorJSON: "{\"href\":\"http://example.com/chap1.html\",\"type\":\"text/html\"}",
            percentage: 0.45,
            chapterTitle: "Introducción",
            deviceID: "TestDevice"
        )
        
        // Guardar progreso
        try await progressRepo.saveProgress(progress)
        
        // Consultar progreso
        let fetched = try await progressRepo.fetchProgress(forPublication: publicationID)
        
        #expect(fetched != nil)
        #expect(fetched?.percentage == 0.45)
        #expect(fetched?.chapterTitle == "Introducción")
        #expect(fetched?.locatorJSON.contains("chap1") == true)
        #expect(fetched?.deviceID == "TestDevice")
    }

    @Test("EPUBReaderAdapter throws correct error for non-existent book file")
    func openNonExistentBook() async throws {
        let adapter = EPUBReaderAdapter()
        let record = PublicationRecord.newImport(
            title: "El Quijote",
            author: "Miguel de Cervantes",
            publicationType: .epub,
            localFileName: "quijote_inexistente.epub",
            mimeType: "application/epub+zip",
            fileSize: 1024,
            sha256: "fake_sha256"
        )
        
        // Intentar abrir el libro debe fallar con error debido a que el archivo físico no existe
        await #expect(throws: Error.self) {
            try await adapter.open(publication: record)
        }
    }
}
