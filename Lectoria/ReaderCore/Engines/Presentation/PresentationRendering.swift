import Foundation
import UIKit

// MARK: - PresentationRenderResult

/// Resultado del procesamiento y preparación de una presentación.
public struct PresentationRenderResult: Sendable {
    public let fileURL: URL
    public let slideCount: Int?
    public let title: String?

    public init(fileURL: URL, slideCount: Int? = nil, title: String? = nil) {
        self.fileURL = fileURL
        self.slideCount = slideCount
        self.title = title
    }
}

// MARK: - PresentationRendering Protocol

/// Protocolo de abstracción para motores de renderizado de presentaciones (.ppt y .pptx).
public protocol PresentationRendering: Sendable {
    func canRender(_ url: URL) -> Bool
    func preparePresentation(at url: URL) async throws -> PresentationRenderResult
    func generateThumbnail(at url: URL) async throws -> UIImage
}
