import UIKit
import PDFKit

// MARK: - CoverGeneratorError

public enum CoverGeneratorError: LocalizedError, Sendable {
    case failedToRenderPDF
    case failedToSaveCover(String)
    case directoryCreationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .failedToRenderPDF:
            return String(localized: "No se pudo renderizar la primera página del PDF.", comment: "Error message")
        case .failedToSaveCover(let msg):
            return String(localized: "No se pudo guardar la imagen de la portada: \(msg)", comment: "Error message")
        case .directoryCreationFailed(let msg):
            return String(localized: "No se pudo crear el directorio de portadas: \(msg)", comment: "Error message")
        }
    }
}

// MARK: - CoverGenerator

/// Generador encargado de crear portadas físicas (miniatuas de imagen) para los documentos importados.
public final class CoverGenerator: Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Directorio base en `Application Support/Covers/`
    public var coversDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Covers", isDirectory: true)
    }

    /// Asegura la existencia de la carpeta de portadas.
    private func ensureCoversDirectoryExists() throws {
        let directory = coversDirectory
        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                throw CoverGeneratorError.directoryCreationFailed(error.localizedDescription)
            }
        }
    }

    /// Genera y guarda en disco la portada de un documento.
    /// - Parameters:
    ///   - url: URL del archivo origen.
    ///   - type: Tipo de publicación.
    ///   - sha256: Hash único del archivo (se usará como nombre de la portada).
    ///   - metadata: Metadatos extraídos (para dibujar portadas de texto).
    /// - Returns: Ruta de acceso local al archivo de portada creado, o `nil` si no aplica.
    @MainActor
    public func generateCover(
        for url: URL,
        type: PublicationType,
        sha256: String,
        metadata: ExtractedMetadata
    ) throws -> String {
        try ensureCoversDirectoryExists()
        
        let coverFileName = "\(sha256).jpg"
        let destinationURL = coversDirectory.appendingPathComponent(coverFileName)

        // Si ya existe la portada, regresamos la ruta relativa directamente
        if fileManager.fileExists(atPath: destinationURL.path) {
            return coverFileName
        }

        switch type {
        case .pdf:
            try generatePDFCover(from: url, to: destinationURL)
        case .epub, .txt, .markdown, .pastedText:
            try generateTextBasedCover(title: metadata.title, author: metadata.author, to: destinationURL)
        }

        return coverFileName
    }

    // MARK: - Rendering Implementations

    /// Renderiza la página 0 del PDF como una miniatura.
    @MainActor
    private func generatePDFCover(from sourceURL: URL, to destinationURL: URL) throws {
        guard let pdfDoc = PDFDocument(url: sourceURL),
              let page = pdfDoc.page(at: 0) else {
            throw CoverGeneratorError.failedToRenderPDF
        }

        let bounds = page.bounds(for: .mediaBox)
        let targetSize = CGSize(width: 240, height: 320)
        
        let ratio = bounds.width / bounds.height
        let targetWidth = targetSize.height * ratio
        let finalSize = CGSize(width: min(targetWidth, targetSize.width), height: targetSize.height)

        let thumbnail = page.thumbnail(of: finalSize, for: .mediaBox)
        
        guard let data = thumbnail.jpegData(compressionQuality: 0.8) else {
            throw CoverGeneratorError.failedToSaveCover("No se pudo obtener la representación JPEG.")
        }

        do {
            try data.write(to: destinationURL)
        } catch {
            throw CoverGeneratorError.failedToSaveCover(error.localizedDescription)
        }
    }

    /// Dibuja dinámicamente una portada minimalista tipo e-reader para libros electrónicos y texto plano.
    private func generateTextBasedCover(title: String, author: String?, to destinationURL: URL) throws {
        let size = CGSize(width: 240, height: 320)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { ctx in
            // Fondo crema minimalista
            let rect = CGRect(origin: .zero, size: size)
            let creamColor = UIColor(red: 0.965, green: 0.957, blue: 0.941, alpha: 1.0)
            creamColor.setFill()
            ctx.fill(rect)

            // Borde interno sutil
            let borderRect = rect.insetBy(dx: 12, dy: 12)
            let borderPath = UIBezierPath(rect: borderRect)
            UIColor.gray.withAlphaComponent(0.2).setStroke()
            borderPath.lineWidth = 1.0
            borderPath.stroke()

            // Estilos del párrafo
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            // Título principal en Georgia (Serif)
            let titleFont = UIFont(name: "Georgia-Bold", size: 16) ?? UIFont.systemFont(ofSize: 16, weight: .bold)
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0),
                .paragraphStyle: paragraphStyle
            ]

            let titleRect = CGRect(x: 24, y: 70, width: 192, height: 130)
            title.draw(in: titleRect, withAttributes: titleAttrs)

            // Autor en Georgia (Serif, itálica)
            if let author = author, !author.isEmpty {
                let authorFont = UIFont(name: "Georgia-Italic", size: 12) ?? UIFont.systemFont(ofSize: 12)
                let authorAttrs: [NSAttributedString.Key: Any] = [
                    .font: authorFont,
                    .foregroundColor: UIColor.gray,
                    .paragraphStyle: paragraphStyle
                ]
                let authorRect = CGRect(x: 24, y: 210, width: 192, height: 50)
                author.draw(in: authorRect, withAttributes: authorAttrs)
            }
            
            // Marca de agua o logo sutil Lectoria al fondo
            let logoFont = UIFont.systemFont(ofSize: 9, weight: .semibold)
            let logoAttrs: [NSAttributedString.Key: Any] = [
                .font: logoFont,
                .foregroundColor: UIColor.lightGray.withAlphaComponent(0.6),
                .paragraphStyle: paragraphStyle
            ]
            let logoRect = CGRect(x: 24, y: 280, width: 192, height: 20)
            "LECTORIA".draw(in: logoRect, withAttributes: logoAttrs)
        }

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw CoverGeneratorError.failedToSaveCover("No se pudo obtener la representación JPEG.")
        }

        do {
            try data.write(to: destinationURL)
        } catch {
            throw CoverGeneratorError.failedToSaveCover(error.localizedDescription)
        }
    }
}
