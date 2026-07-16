import Foundation
import PDFKit

// MARK: - PDFReaderAdapter

/// Adaptador del motor de lectura PDF usando PDFKit de Apple.
@MainActor
final class PDFReaderAdapter: PublicationEngine {
    typealias Location = PDFLocation

    private(set) var document: PDFDocument?
    private(set) var fileURL: URL?

    init() {}

    /// Abre una publicación PDF.
    func open(publication record: PublicationRecord) async throws {
        // Resolver ruta física del documento en el contenedor privado
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let fileURL = appSupport.appendingPathComponent("Publications/\(record.localFileName)")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw NSError(
                domain: "PDFReaderAdapter",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "El archivo no existe en el almacenamiento local."]
            )
        }
        
        self.fileURL = fileURL
        
        // Cargar el documento PDFKit
        guard let doc = PDFDocument(url: fileURL) else {
            throw NSError(
                domain: "PDFReaderAdapter",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "No se pudo inicializar el documento PDF."]
            )
        }
        
        self.document = doc
    }

    /// Cierra el documento y libera memoria.
    func close() async {
        self.document = nil
        self.fileURL = nil
    }

    /// La ubicación actual es provista por el controlador de navegación en tiempo real.
    func currentLocation() async -> PDFLocation? {
        return nil
    }

    /// Navegación dirigida por el controlador.
    func go(to location: PDFLocation) async throws {
        // Se enlazará con la navegación del PDFView en el wrapper.
    }

    /// Realiza una búsqueda dentro del PDF.
    func search(_ query: String) async throws -> [SearchResult] {
        guard let document = document else { return [] }
        
        var results: [SearchResult] = []
        let selections = document.findString(query, withOptions: .caseInsensitive)
        
        for selection in selections {
            guard let page = selection.pages.first else { continue }
            let pageIndex = document.index(for: page)
            let pageNum = pageIndex + 1
            
            let selectedText = selection.string ?? ""
            
            // Ubicación en PDF
            let pdfLocation = PDFLocation(pageIndex: pageIndex, totalPages: document.pageCount, pageLabel: page.label)
            let locationData = (try? JSONEncoder().encode(pdfLocation)) ?? Data()
            
            let chapterTitle = page.label != nil ? "Página \(page.label!)" : "Página \(pageNum)"
            
            results.append(SearchResult(
                text: selectedText,
                contextBefore: "",
                contextAfter: "",
                chapterTitle: chapterTitle,
                locationData: locationData
            ))
        }
        return results
    }

    /// Obtiene la Tabla de Contenidos a partir del esquema outline del PDF.
    func tableOfContents() async throws -> [TOCItem] {
        guard let document = document, let outline = document.outlineRoot else { return [] }
        return mapOutline(outline, document: document)
    }

    // MARK: - Helpers

    /// Mapea recursivamente el outline de PDFKit a TOCItem de Lectoria.
    private func mapOutline(_ outline: PDFOutline, document: PDFDocument) -> [TOCItem] {
        var items: [TOCItem] = []
        
        for i in 0..<outline.numberOfChildren {
            guard let child = outline.child(at: i) else { continue }
            let title = child.label ?? "Sección sin título"
            
            var pageIndex = 0
            if let destination = child.destination, let page = destination.page {
                pageIndex = document.index(for: page)
            } else if let action = child.action as? PDFActionGoTo, let page = action.destination.page {
                pageIndex = document.index(for: page)
            }
            
            let pdfLocation = PDFLocation(pageIndex: pageIndex, totalPages: document.pageCount)
            let locationData = (try? JSONEncoder().encode(pdfLocation)) ?? Data()
            
            let children = mapOutline(child, document: document)
            
            items.append(TOCItem(
                title: title,
                level: 0,
                locationData: locationData,
                children: children
            ))
        }
        
        return items
    }
}
