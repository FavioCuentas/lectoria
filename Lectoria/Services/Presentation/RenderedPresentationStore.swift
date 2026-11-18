import Foundation
import PDFKit

// MARK: - RenderedPresentationStore

/// Ubicación y validez del PDF generado a partir de una presentación PowerPoint.
///
/// El PDF vive junto al original como `<localFileName>.rendered.pdf` y se escribe una sola vez:
/// los resaltados hechos sobre él dependen de posiciones en la página, así que un PDF válido
/// nunca se regenera.
enum RenderedPresentationStore {
    static let suffix = ".rendered.pdf"

    static func renderedURL(forLocalFileName localFileName: String, in directory: URL) -> URL {
        directory.appendingPathComponent(localFileName + suffix)
    }

    /// `Application Support/Publications`.
    static func publicationsDirectory() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Publications", isDirectory: true)
    }

    /// El PDF solo cuenta como válido si existe, se puede abrir y tiene al menos una página.
    static func validDocument(at url: URL) -> PDFDocument? {
        guard FileManager.default.fileExists(atPath: url.path),
              let document = PDFDocument(url: url),
              document.pageCount > 0 else { return nil }
        return document
    }

    /// Solo `.pptx` se convierte: WebKit no abre `.ppt`, `.key` ni `.odp`, que siguen con QuickLook.
    static func isConvertible(localFileName: String) -> Bool {
        (localFileName as NSString).pathExtension.lowercased() == "pptx"
    }
}
