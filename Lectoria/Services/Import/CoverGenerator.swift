import UIKit
import PDFKit
import QuickLookThumbnailing

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
public final class CoverGenerator: @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Directorio base en `Application Support/Covers/`
    public var coversDirectory: URL {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Covers", isDirectory: true)
        }
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
    ///   - force: Si es `true`, reemplaza la portada en disco si ya existía.
    /// - Returns: Ruta de acceso local al archivo de portada creado, o `nil` si no aplica.
    @MainActor
    public func generateCover(
        for url: URL,
        type: PublicationType,
        sha256: String,
        metadata: ExtractedMetadata,
        force: Bool = false
    ) async throws -> String {
        try ensureCoversDirectoryExists()
        
        let coverFileName = "\(sha256).jpg"
        let destinationURL = coversDirectory.appendingPathComponent(coverFileName)

        // Si ya existe la portada y no es forzada, regresamos la ruta relativa directamente
        if !force && fileManager.fileExists(atPath: destinationURL.path) {
            return coverFileName
        }

        switch type {
        case .pdf:
            try generatePDFCover(from: url, to: destinationURL)
        case .epub, .txt, .markdown, .pastedText:
            try generateTextBasedCover(from: url, title: metadata.title, author: metadata.author, to: destinationURL)
        case .pptx:
            try await generatePresentationCover(from: url, title: metadata.title, author: metadata.author, to: destinationURL)
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

    /// Dibuja dinámicamente una portada basada en el contenido real de la primera página del documento (con imagen o texto).
    @MainActor
    private func generateTextBasedCover(
        from sourceURL: URL,
        title: String,
        author: String?,
        to destinationURL: URL
    ) throws {
        // Intentar leer el texto inicial de la primera página del documento
        let rawContent = (try? String(contentsOf: sourceURL, encoding: .utf8)) ??
                         (try? String(contentsOf: sourceURL, encoding: .ascii)) ?? ""

        // Limpiar el texto omitiendo líneas de encabezados repetidas (# Título)
        let lines = rawContent.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !String($0).hasPrefix("#") && !$0.isEmpty }

        let previewText = lines.prefix(12).joined(separator: "\n\n")

        // Buscar si hay una imagen local en markdown o ruta
        var inlineImage: UIImage? = nil
        if let match = rawContent.range(of: #"!\[.*?\]\((.*?)\)"#, options: .regularExpression) {
            let imagePath = String(rawContent[match])
                .components(separatedBy: "(").last?
                .replacingOccurrences(of: ")", with: "") ?? ""
            let imgURL = sourceURL.deletingLastPathComponent().appendingPathComponent(imagePath)
            if FileManager.default.fileExists(atPath: imgURL.path) {
                inlineImage = UIImage(contentsOfFile: imgURL.path)
            }
        }

        let size = CGSize(width: 240, height: 320)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { ctx in
            // Fondo crema estilo e-reader / página de libro premium
            let rect = CGRect(origin: .zero, size: size)
            let creamColor = UIColor(red: 0.965, green: 0.957, blue: 0.941, alpha: 1.0)
            creamColor.setFill()
            ctx.fill(rect)

            // Borde interno sutil (margen de página)
            let borderRect = rect.insetBy(dx: 10, dy: 10)
            let borderPath = UIBezierPath(roundedRect: borderRect, cornerRadius: 4)
            UIColor.gray.withAlphaComponent(0.18).setStroke()
            borderPath.lineWidth = 1.0
            borderPath.stroke()

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            // 1. Título principal
            let titleFont = UIFont(name: "Georgia-Bold", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .bold)
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0),
                .paragraphStyle: paragraphStyle
            ]

            let titleRect = CGRect(x: 18, y: 22, width: 204, height: 42)
            title.draw(in: titleRect, withAttributes: titleAttrs)

            // 2. Autor (si existe)
            var currentY: CGFloat = 66
            if let author = author, !author.isEmpty {
                let authorFont = UIFont(name: "Georgia-Italic", size: 11) ?? UIFont.systemFont(ofSize: 11)
                let authorAttrs: [NSAttributedString.Key: Any] = [
                    .font: authorFont,
                    .foregroundColor: UIColor.darkGray,
                    .paragraphStyle: paragraphStyle
                ]
                let authorRect = CGRect(x: 18, y: currentY, width: 204, height: 18)
                author.draw(in: authorRect, withAttributes: authorAttrs)
                currentY += 22
            }

            // Separador horizontal sutil
            let separatorPath = UIBezierPath()
            separatorPath.move(to: CGPoint(x: 40, y: currentY))
            separatorPath.addLine(to: CGPoint(x: 200, y: currentY))
            UIColor.lightGray.withAlphaComponent(0.4).setStroke()
            separatorPath.lineWidth = 0.5
            separatorPath.stroke()
            currentY += 10

            // 3. Dibujar Imagen de la primera página (si existe) o Extracto de Texto
            if let img = inlineImage {
                let imgRect = CGRect(x: 24, y: currentY, width: 192, height: 140)
                img.draw(in: imgRect)
            } else if !previewText.isEmpty {
                let bodyParagraphStyle = NSMutableParagraphStyle()
                bodyParagraphStyle.alignment = .left
                bodyParagraphStyle.lineSpacing = 3
                bodyParagraphStyle.lineBreakMode = .byTruncatingTail

                let bodyFont = UIFont(name: "Georgia", size: 10) ?? UIFont.systemFont(ofSize: 10)
                let bodyAttrs: [NSAttributedString.Key: Any] = [
                    .font: bodyFont,
                    .foregroundColor: UIColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1.0),
                    .paragraphStyle: bodyParagraphStyle
                ]

                let availableHeight = 280 - currentY
                let bodyRect = CGRect(x: 20, y: currentY, width: 200, height: availableHeight)
                previewText.draw(in: bodyRect, withAttributes: bodyAttrs)
            } else {
                // Si no hay texto extraído (ej. EPUB o binario), mostrar diseño elegante de primera página
                let bodyParagraphStyle = NSMutableParagraphStyle()
                bodyParagraphStyle.alignment = .center

                let bodyFont = UIFont(name: "Georgia-Italic", size: 11) ?? UIFont.systemFont(ofSize: 11)
                let bodyAttrs: [NSAttributedString.Key: Any] = [
                    .font: bodyFont,
                    .foregroundColor: UIColor.gray,
                    .paragraphStyle: bodyParagraphStyle
                ]
                let placeholderRect = CGRect(x: 20, y: currentY + 40, width: 200, height: 60)
                "Primera página del documento".draw(in: placeholderRect, withAttributes: bodyAttrs)
            }

            // Marca Lectoria al pie
            let logoFont = UIFont.systemFont(ofSize: 8, weight: .semibold)
            let logoAttrs: [NSAttributedString.Key: Any] = [
                .font: logoFont,
                .foregroundColor: UIColor.lightGray.withAlphaComponent(0.6),
                .paragraphStyle: paragraphStyle
            ]
            let logoRect = CGRect(x: 24, y: 295, width: 192, height: 15)
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

    /// Genera la portada real de una presentación (.ppt / .pptx) usando `QLThumbnailGenerator`,
    /// o recurre al dibujo dinámico como fallback en caso de error.
    @MainActor
    private func generatePresentationCover(from sourceURL: URL, title: String, author: String?, to destinationURL: URL) async throws {
        let size = CGSize(width: 240, height: 320)
        let scale = UITraitCollection.current.displayScale
        let request = QLThumbnailGenerator.Request(fileAt: sourceURL, size: size, scale: scale, representationTypes: .thumbnail)

        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            let image = representation.uiImage
            if let data = image.jpegData(compressionQuality: 0.8) {
                try data.write(to: destinationURL)
                return
            }
        } catch {
            print("[CoverGenerator] QLThumbnailGenerator no pudo generar miniatura para \(sourceURL.lastPathComponent): \(error.localizedDescription). Usando portada sintética.")
        }

        // Fallback a portada sintética
        try drawSyntheticPresentationCover(title: title, author: author, to: destinationURL)
    }

    /// Dibuja dinámicamente una portada con estética de diapositiva/presentación para archivos PPTX como fallback.
    @MainActor
    private func drawSyntheticPresentationCover(title: String, author: String?, to destinationURL: URL) throws {
        let size = CGSize(width: 240, height: 320)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { ctx in
            // Fondo color terracota/PowerPoint premium
            let rect = CGRect(origin: .zero, size: size)
            let slideColor = UIColor(red: 0.85, green: 0.35, blue: 0.22, alpha: 1.0)
            slideColor.setFill()
            ctx.fill(rect)

            // Tarjeta interna blanca/crema que simula una diapositiva
            let innerRect = CGRect(x: 16, y: 40, width: 208, height: 180)
            let path = UIBezierPath(roundedRect: innerRect, cornerRadius: 4)
            UIColor.white.setFill()
            path.fill()
            
            // Sombra sutil de la diapositiva
            UIColor.black.withAlphaComponent(0.15).setStroke()
            path.lineWidth = 1.0
            path.stroke()

            // Estilos del párrafo
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            // Título de la presentación dentro de la tarjeta
            let titleFont = UIFont(name: "HelveticaNeue-Bold", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .bold)
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0),
                .paragraphStyle: paragraphStyle
            ]
            let titleRect = innerRect.insetBy(dx: 12, dy: 24)
            title.draw(in: titleRect, withAttributes: titleAttrs)

            // Autor y "PRESENTACIÓN" abajo
            let typeFont = UIFont.systemFont(ofSize: 10, weight: .bold)
            let typeAttrs: [NSAttributedString.Key: Any] = [
                .font: typeFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.8),
                .paragraphStyle: paragraphStyle
            ]
            let typeRect = CGRect(x: 24, y: 240, width: 192, height: 16)
            "PRESENTACIÓN".draw(in: typeRect, withAttributes: typeAttrs)

            if let author = author, !author.isEmpty {
                let authorFont = UIFont.systemFont(ofSize: 11, weight: .medium)
                let authorAttrs: [NSAttributedString.Key: Any] = [
                    .font: authorFont,
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: paragraphStyle
                ]
                let authorRect = CGRect(x: 24, y: 260, width: 192, height: 30)
                author.draw(in: authorRect, withAttributes: authorAttrs)
            }

            // Marca Lectoria
            let logoFont = UIFont.systemFont(ofSize: 8, weight: .semibold)
            let logoAttrs: [NSAttributedString.Key: Any] = [
                .font: logoFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.6),
                .paragraphStyle: paragraphStyle
            ]
            let logoRect = CGRect(x: 24, y: 295, width: 192, height: 15)
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
