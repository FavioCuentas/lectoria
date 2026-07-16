import Foundation
import PDFKit

// MARK: - ExtractedMetadata

public struct ExtractedMetadata: Sendable {
    public let title: String
    public let author: String?
    public let language: String?

    public init(title: String, author: String? = nil, language: String? = nil) {
        self.title = title
        self.author = author
        self.language = language
    }
}

// MARK: - DocumentMetadataExtractor

/// Clase encargada de leer los archivos importados para extraer metadatos básicos como título, autor e idioma.
public final class DocumentMetadataExtractor: Sendable {
    public init() {}

    /// Extrae metadatos del archivo ubicado en la URL dada según su tipo.
    /// - Parameters:
    ///   - url: URL local del archivo.
    ///   - type: Tipo de publicación de Lectoria.
    ///   - originalFileName: Nombre de archivo original si el archivo fue renombrado temporalmente.
    /// - Returns: Una estructura `ExtractedMetadata` con los datos obtenidos o valores por defecto.
    public func extract(from url: URL, type: PublicationType, originalFileName: String? = nil) -> ExtractedMetadata {
        // Título por defecto basado en el nombre del archivo original o el actual
        let fallbackName = originalFileName ?? url.lastPathComponent
        let defaultTitle = URL(fileURLWithPath: fallbackName).deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized
        
        switch type {
        case .pdf:
            guard let pdfDoc = PDFDocument(url: url) else {
                return ExtractedMetadata(title: defaultTitle)
            }
            
            let attributes = pdfDoc.documentAttributes ?? [:]
            let titleAttr = attributes[PDFDocumentAttribute.titleAttribute] as? String
            let authorAttr = attributes[PDFDocumentAttribute.authorAttribute] as? String
            
            let title = titleAttr?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let author = authorAttr?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return ExtractedMetadata(
                title: title.isEmpty ? defaultTitle : title,
                author: author?.isEmpty == true ? nil : author
            )
            
        case .epub:
            // En Fase 2 (sin Readium ni unzipper nativo) usamos el nombre de archivo.
            // Esto se mejorará en la Fase 3 con la lectura del manifest XML (.opf) de Readium.
            return ExtractedMetadata(title: defaultTitle)
            
        case .txt, .markdown:
            do {
                // Intentamos leer el archivo como UTF-8
                let content = try String(contentsOf: url, encoding: .utf8)
                
                if type == .markdown {
                    // En Markdown, buscamos el primer encabezado H1 (# Título)
                    let lines = content.components(separatedBy: .newlines)
                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.hasPrefix("#") {
                            // Validar que sea un H1 y no H2 (##)
                            let h1Content = trimmed.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.hasPrefix("##") && !h1Content.isEmpty {
                                return ExtractedMetadata(title: String(h1Content))
                            }
                        }
                    }
                }
                
                // Si no se encuentra encabezado o es TXT, usamos el defaultTitle
                return ExtractedMetadata(title: defaultTitle)
            } catch {
                // Si falla la codificación, regresamos el fallback
                return ExtractedMetadata(title: defaultTitle)
            }
            
        case .pastedText:
            return ExtractedMetadata(title: String(localized: "Texto pegado", comment: "Title for pasted text"))
        }
    }
}
