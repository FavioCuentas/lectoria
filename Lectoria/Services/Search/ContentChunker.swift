import Foundation
import PDFKit
@preconcurrency import ReadiumShared

// MARK: - ContentChunker

/// Extrae el texto de un documento en fragmentos para el índice de búsqueda global.
///
/// Cada fragmento lleva un `locator` que el lector sabe usar para acotar su propia búsqueda:
/// índice de página (PDF y presentaciones), `href` del capítulo (EPUB) o índice del primer
/// bloque (texto).
@MainActor
enum ContentChunker {
    /// Tamaño aproximado de cada fragmento, en caracteres.
    nonisolated static let chunkSize = 4000

    static func chunks(for record: PublicationRecord, fileURL: URL) async throws -> [IndexChunk] {
        switch record.publicationType {
        case .pdf:
            return try await pdfChunks(at: fileURL, label: { "Página \($0 + 1)" })
        case .txt, .markdown, .pastedText:
            return try await textChunks(for: record)
        case .epub:
            return try await epubChunks(for: record)
        case .pptx:
            return try await presentationChunks(at: fileURL)
        }
    }

    /// Divide `text` en trozos de unos `chunkSize` caracteres sin cortar palabras.
    nonisolated static func split(_ text: String, locator: String, label: String) -> [IndexChunk] {
        var chunks: [IndexChunk] = []
        var current = ""
        for word in text.split(whereSeparator: { $0.isWhitespace }) {
            if !current.isEmpty, current.count + 1 + word.count > chunkSize {
                chunks.append(IndexChunk(locator: locator, label: label, text: current))
                current = ""
            }
            current += current.isEmpty ? String(word) : " " + word
        }
        if !current.isEmpty {
            chunks.append(IndexChunk(locator: locator, label: label, text: current))
        }
        return chunks
    }

    // MARK: - Formatos

    /// Una página por fragmento. El texto se extrae fuera del hilo principal.
    private static func pdfChunks(at url: URL, label: @escaping @Sendable (Int) -> String) async throws -> [IndexChunk] {
        try await Task.detached(priority: .utility) {
            guard let document = PDFDocument(url: url) else { throw CocoaError(.fileReadCorruptFile) }
            return (0..<document.pageCount).flatMap { index -> [IndexChunk] in
                let text = document.page(at: index)?.string ?? ""
                return split(text, locator: "\(index)", label: label(index))
            }
        }.value
    }

    /// Bloques agrupados en trozos; el `locator` es el índice del primer bloque del trozo.
    private static func textChunks(for record: PublicationRecord) async throws -> [IndexChunk] {
        let adapter = TextReaderAdapter()
        try await adapter.open(publication: record)
        var chunks: [IndexChunk] = []
        var current = ""
        var firstBlock = 0
        func flush() {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                chunks.append(IndexChunk(locator: "\(firstBlock)", label: "Párrafo \(firstBlock + 1)", text: trimmed))
            }
            current = ""
        }
        for block in adapter.blocks {
            if current.isEmpty { firstBlock = block.index }
            current += block.rawText + "\n"
            if current.count >= chunkSize { flush() }
        }
        flush()
        return chunks
    }

    /// Un fragmento por capítulo del orden de lectura, con el título del índice del libro.
    private static func epubChunks(for record: PublicationRecord) async throws -> [IndexChunk] {
        let adapter = EPUBReaderAdapter()
        try await adapter.open(publication: record)
        guard let publication = adapter.publication,
              let iterator = publication.content(from: nil)?.iterator() else { return [] }

        let toc = flatten((try? await publication.tableOfContents().get()) ?? [])
        var order: [String] = []
        var textByHref: [String: String] = [:]
        while let element = try await iterator.next() {
            guard let textual = element as? TextualContentElement,
                  let text = textual.text, !text.isEmpty else { continue }
            let href = InitialSearchKey.normalizedHref(element.locator.href.string)
            if textByHref[href] == nil { order.append(href) }
            textByHref[href, default: ""] += text + "\n"
        }

        return order.enumerated().flatMap { index, href -> [IndexChunk] in
            let label = tocTitle(for: href, in: toc) ?? "Capítulo \(index + 1)"
            return split(textByHref[href] ?? "", locator: href, label: label)
        }
    }

    /// Diapositivas: desde el PDF convertido si ya existe; si no, desde el texto del `.pptx`.
    /// En ambos casos el `locator` es el índice de diapositiva = página del PDF.
    private static func presentationChunks(at url: URL) async throws -> [IndexChunk] {
        let rendered = RenderedPresentationStore.renderedURL(
            forLocalFileName: url.lastPathComponent, in: url.deletingLastPathComponent()
        )
        if RenderedPresentationStore.validDocument(at: rendered) != nil {
            return try await pdfChunks(at: rendered, label: { "Diapositiva \($0 + 1)" })
        }
        let slides = try await PPTXParser.visibleSlides(url: url)
        return slides.enumerated().flatMap { index, slide -> [IndexChunk] in
            let text = ([slide.title].compactMap { $0 } + slide.bodyTexts).joined(separator: "\n")
            return split(text, locator: "\(index)", label: "Diapositiva \(index + 1)")
        }
    }

    // MARK: - Índice del EPUB

    private static func flatten(_ links: [Link]) -> [Link] {
        links.flatMap { [$0] + flatten($0.children) }
    }

    private static func tocTitle(for href: String, in toc: [Link]) -> String? {
        toc.first { link in
            let target = InitialSearchKey.normalizedHref(link.url().string)
            return target == href || href.hasSuffix("/" + target) || target.hasSuffix("/" + href)
        }?.title
    }
}

// MARK: - InitialSearchKey

/// Normalización compartida de los `locator` de capítulo (EPUB) entre el índice y el lector.
enum InitialSearchKey {
    /// `"OEBPS/ch2.xhtml#p3"` → `"OEBPS/ch2.xhtml"`.
    static func normalizedHref(_ href: String) -> String {
        href.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? href
    }
}
