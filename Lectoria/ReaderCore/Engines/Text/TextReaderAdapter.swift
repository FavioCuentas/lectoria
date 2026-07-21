import Foundation

// MARK: - TextReaderAdapter

/// Adaptador del motor de lectura de texto plano y Markdown.
///
/// Implementa `PublicationEngine` usando `TextLocation` como posición.
@MainActor
final class TextReaderAdapter: PublicationEngine {
    typealias Location = TextLocation

    private(set) var blocks: [TextBlock] = []
    private(set) var fileURL: URL?
    private(set) var record: PublicationRecord?

    init() {}

    /// Abre una publicación de texto.
    func open(publication record: PublicationRecord) async throws {
        self.record = record
        
        // Resolver ruta física del documento en el contenedor privado
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(
                domain: "TextReaderAdapter",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "No se pudo resolver el directorio Application Support."]
            )
        }
        let fileURL = appSupport.appendingPathComponent("Publications/\(record.localFileName)")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw NSError(
                domain: "TextReaderAdapter",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "El archivo no existe en el almacenamiento local."]
            )
        }
        
        self.fileURL = fileURL
        
        // Leer el contenido
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let isMarkdown = record.publicationType == .markdown
        
        // Procesar en segundo plano para evitar bloqueos si el archivo es grande
        let parsedBlocks = await Task.detached(priority: .userInitiated) { [content, isMarkdown] in
            return Self.parseText(content, isMarkdown: isMarkdown)
        }.value
        
        self.blocks = parsedBlocks
    }

    /// Cierra el archivo y libera memoria.
    func close() async {
        self.blocks.removeAll()
        self.fileURL = nil
        self.record = nil
    }

    /// La ubicación actual es provista por la vista en tiempo real.
    func currentLocation() async -> TextLocation? {
        return nil
    }

    /// Navegación dirigida por el controlador.
    func go(to location: TextLocation) async throws {
        // Enlazado en SwiftUI
    }

    /// Busca texto dentro de los bloques de la publicación.
    func search(_ query: String) async throws -> [SearchResult] {
        let currentBlocks = blocks
        
        return await Task.detached(priority: .userInitiated) { [currentBlocks] in
            var results: [SearchResult] = []
            let lowerQuery = query.lowercased()
            
            for block in currentBlocks {
                let text = block.rawText
                if text.lowercased().contains(lowerQuery) {
                    let loc = TextLocation(
                        blockIndex: block.index,
                        characterOffset: 0,
                        percentage: Double(block.index) / Double(max(1, currentBlocks.count - 1))
                    )
                    let locationData = (try? JSONEncoder().encode(loc)) ?? Data()
                    
                    results.append(SearchResult(
                        id: UUID(),
                        text: text,
                        contextBefore: "",
                        contextAfter: "",
                        chapterTitle: "Párrafo \(block.index + 1)",
                        locationData: locationData
                    ))
                }
            }
            return results
        }.value
    }

    /// Obtiene el índice de contenidos a partir de los títulos Markdown del documento.
    func tableOfContents() async throws -> [TOCItem] {
        let currentBlocks = blocks
        
        return await Task.detached(priority: .userInitiated) { [currentBlocks] in
            var items: [TOCItem] = []
            
            for block in currentBlocks {
                if case let .heading(text, level) = block.type {
                    let loc = TextLocation(
                        blockIndex: block.index,
                        characterOffset: 0,
                        percentage: Double(block.index) / Double(max(1, currentBlocks.count - 1))
                    )
                    let locationData = (try? JSONEncoder().encode(loc)) ?? Data()
                    
                    items.append(TOCItem(
                        id: UUID(),
                        title: text,
                        level: max(0, level - 1),
                        locationData: locationData,
                        children: []
                    ))
                }
            }
            return items
        }.value
    }
    
    // MARK: - Parser Helper
    /// Parsea el texto y genera una colección estructurada de bloques.
    private nonisolated static func parseText(_ text: String, isMarkdown: Bool) -> [TextBlock] {
        guard isMarkdown else {
            // Texto plano: simplemente dividir por párrafos
            let paragraphs = text.components(separatedBy: "\n")
            var blocks: [TextBlock] = []
            var index = 0
            var currentParagraph = ""
            
            for line in paragraphs {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    if !currentParagraph.isEmpty {
                        blocks.append(TextBlock(id: UUID(), index: index, type: .paragraph(text: currentParagraph), rawText: currentParagraph))
                        currentParagraph = ""
                        index += 1
                    }
                } else {
                    if !currentParagraph.isEmpty {
                        currentParagraph += "\n" + line
                    } else {
                        currentParagraph = line
                    }
                }
            }
            if !currentParagraph.isEmpty {
                blocks.append(TextBlock(id: UUID(), index: index, type: .paragraph(text: currentParagraph), rawText: currentParagraph))
            }
            return blocks
        }
        
        // Parsear Markdown línea por línea
        var blocks: [TextBlock] = []
        let lines = text.components(separatedBy: .newlines)
        var index = 0
        
        var currentLines: [String] = []
        var insideCodeBlock = false
        var codeBlockLanguage: String? = nil
        var currentBlockType: BlockTypeForParser = .paragraph
        
        enum BlockTypeForParser {
            case paragraph
            case blockquote
            case codeBlock
        }
        
        func flush() {
            guard !currentLines.isEmpty else { return }
            let blockText = currentLines.joined(separator: "\n")
            
            let type: TextBlock.BlockType
            switch currentBlockType {
            case .paragraph:
                type = .paragraph(text: blockText)
            case .blockquote:
                type = .blockquote(text: blockText)
            case .codeBlock:
                type = .codeBlock(code: blockText, language: codeBlockLanguage)
            }
            
            blocks.append(TextBlock(id: UUID(), index: index, type: type, rawText: blockText))
            index += 1
            currentLines.removeAll()
            currentBlockType = .paragraph
            codeBlockLanguage = nil
        }
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Código en bloque
            if trimmed.hasPrefix("```") {
                if insideCodeBlock {
                    flush()
                    insideCodeBlock = false
                } else {
                    flush()
                    insideCodeBlock = true
                    currentBlockType = .codeBlock
                    let lang = trimmed.dropFirst(3).trimmingCharacters(in: .whitespacesAndNewlines)
                    codeBlockLanguage = lang.isEmpty ? nil : lang
                }
                continue
            }
            
            if insideCodeBlock {
                currentLines.append(line)
                continue
            }
            
            // Encabezados
            if trimmed.hasPrefix("#") {
                let headingWeight = trimmed.prefix(while: { $0 == "#" }).count
                let remaining = trimmed.dropFirst(headingWeight)
                if remaining.hasPrefix(" ") && headingWeight <= 6 {
                    flush()
                    let headingText = remaining.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
                    blocks.append(TextBlock(id: UUID(), index: index, type: .heading(text: headingText, level: headingWeight), rawText: line))
                    index += 1
                    continue
                }
            }
            
            // Citas (Blockquote)
            if trimmed.hasPrefix(">") {
                if currentBlockType != .blockquote {
                    flush()
                    currentBlockType = .blockquote
                }
                let quoteText = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                currentLines.append(quoteText)
                continue
            }
            
            // Elementos de lista
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flush()
                let itemText = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                blocks.append(TextBlock(id: UUID(), index: index, type: .listItem(text: itemText), rawText: line))
                index += 1
                continue
            }
            
            // Línea vacía actúa como límite de párrafo
            if trimmed.isEmpty {
                flush()
                continue
            }
            
            // Texto regular
            if currentBlockType == .blockquote {
                flush()
            }
            currentLines.append(line)
        }
        
        flush()
        return blocks
    }
}
