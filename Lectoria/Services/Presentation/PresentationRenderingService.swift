import Foundation
import os

private let logger = Logger(subsystem: "com.orvexa.Lectoria", category: "PresentationPDFRendering")

// MARK: - PresentationPDFRendering

/// Pide que exista el PDF buscable de una presentación (ver `PresentationRenderingService`).
@MainActor
public protocol PresentationPDFRendering: AnyObject, Sendable {
    func ensureRendered(localFileName: String, publicationID: UUID) async
}

// MARK: - PresentationRenderingService

/// Decide cuándo convertir un `.pptx` a PDF: tras importarlo o al abrir una presentación sin PDF.
///
/// - Nunca regenera un PDF válido (los resaltados dependen de posiciones en la página).
/// - Una sola conversión a la vez por publicación, y como máximo un intento por sesión de app:
///   si falla, se sigue con QuickLook y se reintenta la próxima vez que se abra la app.
@MainActor
final class PresentationRenderingService: PresentationPDFRendering {
    typealias Convert = @MainActor (_ source: URL, _ expectedSlides: Int, _ destination: URL) async throws -> Void

    private let directory: () -> URL?
    private let convert: Convert
    private let slideCount: (URL) async throws -> Int

    private(set) var attempted: Set<UUID> = []
    /// Conversiones en curso: quien llegue mientras tanto (p. ej. abrir justo tras importar) espera.
    private var inFlight: [UUID: Task<Void, Never>] = [:]

    init(
        directory: @escaping () -> URL? = RenderedPresentationStore.publicationsDirectory,
        convert: @escaping Convert = { source, expected, destination in
            try await PresentationPDFConverter().convert(pptxURL: source, expectedSlideCount: expected, destination: destination)
        },
        slideCount: @escaping (URL) async throws -> Int = { try await PPTXParser.visibleSlides(url: $0).count }
    ) {
        self.directory = directory
        self.convert = convert
        self.slideCount = slideCount
    }

    func ensureRendered(localFileName: String, publicationID: UUID) async {
        guard RenderedPresentationStore.isConvertible(localFileName: localFileName),
              let directory = directory() else { return }
        if let running = inFlight[publicationID] {
            await running.value
            return
        }
        let destination = RenderedPresentationStore.renderedURL(forLocalFileName: localFileName, in: directory)
        guard RenderedPresentationStore.validDocument(at: destination) == nil,
              !attempted.contains(publicationID) else { return }

        attempted.insert(publicationID)
        let source = directory.appendingPathComponent(localFileName)
        let slideCount = self.slideCount
        let convert = self.convert
        let task = Task { @MainActor in
            do {
                let expected = try await slideCount(source)
                try await convert(source, expected, destination)
                logger.info("Presentación convertida a PDF (\(expected) diapositivas)")
            } catch {
                logger.error("No se pudo convertir la presentación a PDF: \(String(describing: error))")
            }
        }
        inFlight[publicationID] = task
        await task.value
        inFlight[publicationID] = nil
    }

}
