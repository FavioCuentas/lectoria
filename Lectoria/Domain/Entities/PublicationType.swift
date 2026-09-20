import Foundation
import UniformTypeIdentifiers

// MARK: - PublicationType

/// Tipos de publicación soportados por Lectoria.
///
/// Cada caso representa un formato de archivo que la aplicación puede
/// importar, almacenar y renderizar. La arquitectura permite añadir
/// nuevos formatos mediante adaptadores sin modificar el código existente.
public enum PublicationType: String, Codable, Sendable, CaseIterable, Identifiable {
    case epub
    case pdf
    case txt
    case markdown
    case pastedText
    case pptx

    public var id: String { rawValue }

    // MARK: - Display

    /// Nombre legible para la interfaz.
    public var displayName: String {
        switch self {
        case .epub: String(localized: "EPUB", comment: "Publication type name")
        case .pdf: String(localized: "PDF", comment: "Publication type name")
        case .txt: String(localized: "Texto", comment: "Publication type name for plain text")
        case .markdown: String(localized: "Markdown", comment: "Publication type name")
        case .pastedText: String(localized: "Texto pegado", comment: "Publication type name for pasted text")
        case .pptx: String(localized: "Presentación", comment: "Publication type name for PowerPoint")
        }
    }

    /// Icono SF Symbol representativo.
    public var systemImage: String {
        switch self {
        case .epub: "book"
        case .pdf: "doc.richtext"
        case .txt: "doc.text"
        case .markdown: "text.document"
        case .pastedText: "doc.on.clipboard"
        case .pptx: "rectangle.on.rectangle.angled"
        }
    }

    /// Formato normalizado y privado para la telemetría de analítica.
    public var analyticsFormat: String {
        switch self {
        case .epub: "epub"
        case .pdf: "pdf"
        case .txt: "txt"
        case .markdown: "markdown"
        case .pastedText: "pasted_text"
        case .pptx: "pptx"
        }
    }

    // MARK: - File metadata

    /// Extensiones de archivo asociadas (sin punto).
    public var fileExtensions: [String] {
        switch self {
        case .epub: ["epub"]
        case .pdf: ["pdf"]
        case .txt: ["txt", "text"]
        case .markdown: ["md", "markdown"]
        case .pastedText: []
        case .pptx: ["pptx", "ppt", "pps", "ppsx", "key", "odp"]
        }
    }

    /// Tipos UniformTypeIdentifiers (UTType) correspondientes.
    public var supportedUTTypes: [UTType] {
        switch self {
        case .epub:
            [UTType(filenameExtension: "epub")].compactMap { $0 }
        case .pdf:
            [.pdf]
        case .txt:
            [.plainText]
        case .markdown:
            [UTType(filenameExtension: "md"), UTType(filenameExtension: "markdown")].compactMap { $0 }
        case .pastedText:
            []
        case .pptx:
            [
                UTType(filenameExtension: "pptx"),
                UTType(filenameExtension: "ppt"),
                UTType(filenameExtension: "pps"),
                UTType(filenameExtension: "ppsx"),
                UTType(filenameExtension: "key"),
                UTType(filenameExtension: "odp"),
                UTType.presentation
            ].compactMap { $0 }
        }
    }

    /// MIME type principal.
    public var mimeType: String {
        switch self {
        case .epub: "application/epub+zip"
        case .pdf: "application/pdf"
        case .txt: "text/plain"
        case .markdown: "text/markdown"
        case .pastedText: "text/plain"
        case .pptx: "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        }
    }

    /// Determina el tipo de publicación a partir de la extensión de archivo.
    /// - Parameter fileExtension: Extensión sin punto, case-insensitive.
    /// - Returns: El tipo correspondiente, o `nil` si no se reconoce.
    public static func from(fileExtension: String) -> PublicationType? {
        let ext = fileExtension.lowercased()
        return allCases.first { $0.fileExtensions.contains(ext) }
    }

    /// Indica si el formato soporta anotaciones de texto (destacados y notas).
    public var supportsTextAnnotations: Bool {
        switch self {
        case .epub, .txt, .markdown, .pastedText, .pptx: true
        case .pdf: true // Solo cuando el PDF contiene capa de texto
        }
    }

    /// Indica si el formato proviene de un archivo importado.
    public var isFileBased: Bool {
        self != .pastedText
    }
}
