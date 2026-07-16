import Testing
import Foundation
import SwiftData
@testable import Lectoria

// MARK: - TextReaderAdapterTests

@MainActor
struct TextReaderAdapterTests {
    
    @Test("TextLocation Codable serialization and deserialization roundtrip")
    func textLocationCodableRoundtrip() throws {
        let location = TextLocation(blockIndex: 5, characterOffset: 12, percentage: 0.35)
        
        // Codificar
        let data = try JSONEncoder().encode(location)
        
        // Decodificar
        let decoded = try JSONDecoder().decode(TextLocation.self, from: data)
        
        // Verificar
        #expect(decoded.blockIndex == 5)
        #expect(decoded.characterOffset == 12)
        #expect(decoded.percentage == 0.35)
    }

    @Test("TextReaderAdapter correctly parses plain TXT into paragraph blocks")
    func parseTxtToBlocks() async throws {
        let adapter = TextReaderAdapter()
        let txtContent = """
        Este es el primer párrafo.
        
        Este es el segundo párrafo, el cual tiene
        múltiples líneas de texto.
        
        Tercer párrafo final.
        """
        
        // Guardar el archivo directamente en la carpeta de Publicaciones del simulador
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let publicationsURL = appSupport.appendingPathComponent("Publications")
        try? FileManager.default.createDirectory(at: publicationsURL, withIntermediateDirectories: true)
        
        let localFileName = "temp_test_txt.txt"
        let destURL = publicationsURL.appendingPathComponent(localFileName)
        try txtContent.write(to: destURL, atomically: true, encoding: .utf8)
        
        let record = PublicationRecord.newImport(
            title: "Test TXT",
            publicationType: .txt,
            localFileName: localFileName,
            mimeType: "text/plain",
            fileSize: Int64(txtContent.utf8.count),
            sha256: "fake_sha256_txt"
        )
        
        try await adapter.open(publication: record)
        
        #expect(adapter.blocks.count == 3)
        #expect(adapter.blocks[0].rawText == "Este es el primer párrafo.")
        #expect(adapter.blocks[2].rawText == "Tercer párrafo final.")
        
        // Limpiar
        try? FileManager.default.removeItem(at: destURL)
    }

    @Test("TextReaderAdapter parses Markdown headings, quotes, lists, and code blocks")
    func parseMarkdownToBlocks() async throws {
        let adapter = TextReaderAdapter()
        let mdContent = """
        # Título Principal
        
        Este es un párrafo de introducción.
        
        > Esto es una cita célebre.
        
        - Elemento 1 de la lista
        - Elemento 2 de la lista
        
        ```swift
        let x = 10
        print(x)
        ```
        """
        
        // Guardar el archivo directamente en la carpeta de Publicaciones del simulador
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let publicationsURL = appSupport.appendingPathComponent("Publications")
        try? FileManager.default.createDirectory(at: publicationsURL, withIntermediateDirectories: true)
        
        let localFileName = "temp_test_md.md"
        let destURL = publicationsURL.appendingPathComponent(localFileName)
        try mdContent.write(to: destURL, atomically: true, encoding: .utf8)
        
        let record = PublicationRecord.newImport(
            title: "Test MD",
            publicationType: .markdown,
            localFileName: localFileName,
            mimeType: "text/markdown",
            fileSize: Int64(mdContent.utf8.count),
            sha256: "fake_sha256_md"
        )
        
        try await adapter.open(publication: record)
        
        // Esperamos:
        // 1. Heading (level 1)
        // 2. Paragraph
        // 3. Blockquote
        // 4. ListItem (1)
        // 5. ListItem (2)
        // 6. CodeBlock
        #expect(adapter.blocks.count == 6)
        
        if case let .heading(text, level) = adapter.blocks[0].type {
            #expect(text == "Título Principal")
            #expect(level == 1)
        } else {
            Issue.record("El primer bloque debería ser un Heading")
        }
        
        if case let .blockquote(text) = adapter.blocks[2].type {
            #expect(text == "Esto es una cita célebre.")
        } else {
            Issue.record("El tercer bloque debería ser un Blockquote")
        }
        
        if case let .listItem(text) = adapter.blocks[3].type {
            #expect(text == "Elemento 1 de la lista")
        } else {
            Issue.record("El cuarto bloque debería ser un ListItem")
        }
        
        if case let .codeBlock(code, language) = adapter.blocks[5].type {
            #expect(code == "let x = 10\nprint(x)")
            #expect(language == "swift")
        } else {
            Issue.record("El sexto bloque debería ser un CodeBlock")
        }
        
        // Limpiar
        try? FileManager.default.removeItem(at: destURL)
    }
}
