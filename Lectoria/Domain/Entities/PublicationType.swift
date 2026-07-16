import Foundation

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
        case .epub, .txt, .markdown, .pastedText: true
        case .pdf: true // Solo cuando el PDF contiene capa de texto
        }
    }

    /// Indica si el formato proviene de un archivo importado.
    public var isFileBased: Bool {
        self != .pastedText
    }
}
