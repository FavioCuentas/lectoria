import Foundation
import UIKit
import CoreGraphics

// MARK: - SlideID

/// Identificador único e inmutable de una diapositiva dentro de una presentación.
public struct SlideID: Hashable, Codable, Sendable, Identifiable {
    public let value: String
    public var id: String { value }

    public init(_ value: String) {
        self.value = value
    }
}

// MARK: - PresentationFormat

/// Formatos de presentación reconocidos por el motor de renderizado de Lectoria.
public enum PresentationFormat: String, Codable, Sendable {
    case pptx
    case ppt
    case pps
    case ppsx
    case key
    case odp
    case pdf

    public init(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "pptx": self = .pptx
        case "ppt": self = .ppt
        case "pps": self = .pps
        case "ppsx": self = .ppsx
        case "key": self = .key
        case "odp": self = .odp
        case "pdf": self = .pdf
        default: self = .pptx
        }
    }
}

// MARK: - PresentationCompatibilityWarning

/// Advertencias de compatibilidad registradas durante la preparación del renderizado.
public enum PresentationCompatibilityWarning: Hashable, Sendable {
    case missingFonts([String])
    case unsupportedMedia
    case animationsIgnored
    case fallbackToRasterImage
}

// MARK: - RenderedSlideDescriptor

/// Descriptor de diapositiva con dimensiones inmutables y relación de aspecto.
public struct RenderedSlideDescriptor: Identifiable, Sendable, Codable {
    public let id: SlideID
    public let index: Int
    public let canvasSize: CGSize
    public let aspectRatio: CGFloat

    public init(id: SlideID, index: Int, canvasSize: CGSize, aspectRatio: CGFloat) {
        self.id = id
        self.index = index
        self.canvasSize = canvasSize
        self.aspectRatio = aspectRatio > 0 ? aspectRatio : (canvasSize.height > 0 ? canvasSize.width / canvasSize.height : 16.0 / 9.0)
    }
}

// MARK: - PresentationRenderManifest

/// Manifiesto completo de renderizado de una presentación.
public struct PresentationRenderManifest: Sendable {
    public let originalURL: URL
    public let derivedURL: URL?
    public let format: PresentationFormat
    public let slideCount: Int
    public let slides: [RenderedSlideDescriptor]
    public let fidelityWarnings: [PresentationCompatibilityWarning]

    public init(
        originalURL: URL,
        derivedURL: URL? = nil,
        format: PresentationFormat,
        slideCount: Int,
        slides: [RenderedSlideDescriptor],
        fidelityWarnings: [PresentationCompatibilityWarning] = []
    ) {
        self.originalURL = originalURL
        self.derivedURL = derivedURL
        self.format = format
        self.slideCount = slideCount
        self.slides = slides
        self.fidelityWarnings = fidelityWarnings
    }
}

// MARK: - PresentationRendering Protocol

/// Contrato del motor de renderizado de presentaciones.
public protocol PresentationRendering: Sendable {
    func supports(_ url: URL) async -> Bool
    func prepare(url: URL) async throws -> PresentationRenderManifest
    func thumbnail(for slideID: SlideID, size: CGSize) async throws -> UIImage
}
