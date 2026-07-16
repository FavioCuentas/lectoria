import Testing
import Foundation
import SwiftData
import PDFKit
@testable import Lectoria

// MARK: - PDFReaderAdapterTests

@MainActor
struct PDFReaderAdapterTests {
    
    @Test("PDFLocation Codable serialization and deserialization roundtrip")
    func pdfLocationCodableRoundtrip() throws {
        let location = PDFLocation(pageIndex: 3, totalPages: 120, pageLabel: "IV")
        
        // Codificar
        let data = try JSONEncoder().encode(location)
        
        // Decodificar
        let decoded = try JSONDecoder().decode(PDFLocation.self, from: data)
        
        // Verificar igualdad e integridad de datos
        #expect(decoded.pageIndex == 3)
        #expect(decoded.totalPages == 120)
        #expect(decoded.pageLabel == "IV")
    }

    @Test("PDFReaderAdapter throws correct error for non-existent PDF file")
    func openNonExistentPDFBook() async throws {
        let adapter = PDFReaderAdapter()
        let record = PublicationRecord.newImport(
            title: "Física Cuántica Apuntes",
            publicationType: .pdf,
            localFileName: "fisica_inexistente.pdf",
            mimeType: "application/pdf",
            fileSize: 1024,
            sha256: "fake_sha256"
        )
        
        // Intentar abrir el PDF debe fallar debido a que el archivo físico no existe
        await #expect(throws: Error.self) {
            try await adapter.open(publication: record)
        }
    }
}
