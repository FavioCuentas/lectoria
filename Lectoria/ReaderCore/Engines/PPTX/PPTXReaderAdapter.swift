import Foundation

// MARK: - PPTXReaderAdapter

/// Adaptador del motor de lectura de presentaciones PPTX.
///
/// Convierte las diapositivas extraídas por `PPTXParser` en `TextBlock`s
/// compatibles con la infraestructura existente de `TextReaderView`.
/// Esto permite reutilizar toda la funcionalidad de lectura, notas, IA,
/// destacados, búsqueda y progreso sin crear una vista nueva.
@MainActor
final class PPTXReaderAdapter: PublicationEngine {
    typealias Location = TextLocation

    private(set) var blocks: [TextBlock] = []
    private(set) var slides: [PPTXSlide] = []
    private(set) var fileURL: URL?
    private(set) var record: PublicationRecord?

    init() {}

    /// Abre una publicación PPTX y la convierte en bloques de texto.
    func open(publication record: PublicationRecord) async throws {
        self.record = record

        // Resolver ruta física del documento en el contenedor privado
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(
                domain: "PPTXReaderAdapter",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "No se pudo resolver el directorio Application Support."]
            )
        }
        let fileURL = appSupport.appendingPathComponent("Publications/\(record.localFileName)")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw NSError(
                domain: "PPTXReaderAdapter",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "El archivo no existe en el almacenamiento local."]
            )
        }

        self.fileURL = fileURL

        // Parsear el PPTX
        let parsedSlides = try await PPTXParser.parse(url: fileURL)
        self.slides = parsedSlides

        // Convertir las diapositivas a TextBlocks
        self.blocks = Self.convertToBlocks(slides: parsedSlides)
    }

    /// Cierra el archivo y libera memoria.
    func close() async {
        self.blocks.removeAll()
        self.slides.removeAll()
        self.fileURL = nil
        self.record = nil
    }

    func currentLocation() async -> TextLocation? {
        return nil
    }

    func go(to location: TextLocation) async throws {
        // Enlazado en SwiftUI
    }

    /// Busca texto dentro de los bloques de la presentación.
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

                    // Determinar el nombre de la diapositiva para el contexto
                    let chapterTitle = Self.findSlideTitle(forBlockIndex: block.index, in: currentBlocks)

                    results.append(SearchResult(
                        id: UUID(),
                        text: text,
                        contextBefore: "",
                        contextAfter: "",
                        chapterTitle: chapterTitle,
                        locationData: locationData
                    ))
                }
            }
            return results
        }.value
    }

    /// Obtiene la tabla de contenidos basada en las diapositivas.
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

    // MARK: - Conversion

    /// Convierte un array de `PPTXSlide` en `TextBlock`s estructurados.
    private static func convertToBlocks(slides: [PPTXSlide]) -> [TextBlock] {
        var blocks: [TextBlock] = []
        var index = 0

        for slide in slides {
            // Encabezado de sección: "Diapositiva N"
            let headerText = "Diapositiva \(slide.slideNumber)"
            blocks.append(TextBlock(index: index, type: .heading(text: headerText, level: 1), rawText: headerText))
            index += 1

            // Título de la diapositiva
            if let title = slide.title, !title.isEmpty {
                blocks.append(TextBlock(index: index, type: .heading(text: title, level: 2), rawText: title))
                index += 1
            }

            // Textos del cuerpo
            for bodyText in slide.bodyTexts {
                let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }

                // Detectar si es un elemento de lista (comienza con bullet o guion)
                if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("–") || trimmed.hasPrefix("▪") {
                    blocks.append(TextBlock(index: index, type: .listItem(text: trimmed), rawText: trimmed))
                } else {
                    blocks.append(TextBlock(index: index, type: .paragraph(text: trimmed), rawText: trimmed))
                }
                index += 1
            }

            // Notas del presentador (como cita/blockquote)
            if let notes = slide.speakerNotes, !notes.isEmpty {
                let notesText = "📝 Notas del presentador: \(notes)"
                blocks.append(TextBlock(index: index, type: .blockquote(text: notesText), rawText: notesText))
                index += 1
            }
        }

        // Si no se extrajo nada, agregar un bloque informativo
        if blocks.isEmpty {
            blocks.append(TextBlock(
                index: 0,
                type: .paragraph(text: "No se encontró contenido textual en esta presentación."),
                rawText: "No se encontró contenido textual en esta presentación."
            ))
        }

        return blocks
    }

    /// Encuentra el título de diapositiva más cercano para un bloque dado.
    nonisolated private static func findSlideTitle(forBlockIndex blockIndex: Int, in blocks: [TextBlock]) -> String {
        // Recorrer hacia atrás desde blockIndex para encontrar el heading de nivel 1 más cercano
        for i in stride(from: min(blockIndex, blocks.count - 1), through: 0, by: -1) {
            if case let .heading(text, level) = blocks[i].type, level == 1 {
                return text
            }
        }
        return "Diapositiva"
    }
}
