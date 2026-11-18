import Foundation

// MARK: - PresentationOpenRoute

/// Cómo abrir una presentación: los `.pptx` se convierten a PDF y se leen con el lector de PDF
/// (búsqueda, resaltados, notas y progreso). El resto se sigue mostrando con QuickLook.
enum PresentationOpenRoute: Equatable {
    /// Abrir el PDF convertido (`localFileName` relativo a `Publications/`) en el lector de PDF.
    case pdf(localFileName: String)
    /// Aún no hay PDF válido: convertir primero.
    case convert
    /// Vista de presentación de siempre (QuickLook).
    case presentation

    static func decide(localFileName: String, directory: URL?) -> PresentationOpenRoute {
        guard RenderedPresentationStore.isConvertible(localFileName: localFileName),
              let directory else { return .presentation }
        let rendered = RenderedPresentationStore.renderedURL(forLocalFileName: localFileName, in: directory)
        guard RenderedPresentationStore.validDocument(at: rendered) != nil else { return .convert }
        return .pdf(localFileName: rendered.lastPathComponent)
    }
}
