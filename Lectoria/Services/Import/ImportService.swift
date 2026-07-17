import Foundation

// MARK: - ImportError

public enum ImportError: LocalizedError, Sendable {
    case duplicateDocument(title: String)
    case unsupportedFormat(extension: String)
    case securityAccessFailed
    case fileAccessFailed(String)
    case metadataExtractionFailed
    case limitExceeded(String)

    public var errorDescription: String? {
        switch self {
        case .duplicateDocument(let title):
            return String(localized: "El documento '\(title)' ya existe en tu biblioteca.", comment: "Error message")
        case .unsupportedFormat(let ext):
            return String(localized: "El formato de archivo .\(ext) no es compatible. Lectoria soporta EPUB, PDF, TXT y Markdown.", comment: "Error message")
        case .securityAccessFailed:
            return String(localized: "No se pudo obtener acceso de seguridad al archivo seleccionado.", comment: "Error message")
        case .fileAccessFailed(let msg):
            return String(localized: "Error al acceder al archivo: \(msg)", comment: "Error message")
        case .metadataExtractionFailed:
            return String(localized: "No se pudieron extraer los metadatos del archivo.", comment: "Error message")
        case .limitExceeded(let msg):
            return msg
        }
    }
}

// MARK: - ImportService

/// Servicio principal para la importación física e indexación de archivos de lectura en la biblioteca local.
public final class ImportService: Sendable {
    private let publicationRepository: any PublicationRepository
    private let fileStorageService: FileStorageService
    private let metadataExtractor: DocumentMetadataExtractor
    private let coverGenerator: CoverGenerator
    private let entitlementService: (any FeatureEntitlementService)?

    public init(
        publicationRepository: any PublicationRepository,
        fileStorageService: FileStorageService = FileStorageService(),
        metadataExtractor: DocumentMetadataExtractor = DocumentMetadataExtractor(),
        coverGenerator: CoverGenerator = CoverGenerator(),
        entitlementService: (any FeatureEntitlementService)? = nil
    ) {
        self.publicationRepository = publicationRepository
        self.fileStorageService = fileStorageService
        self.metadataExtractor = metadataExtractor
        self.coverGenerator = coverGenerator
        self.entitlementService = entitlementService
    }

    /// Importa un archivo a partir de una URL local (puede ser un recurso de seguridad externa de iOS).
    /// - Parameter url: URL de origen del archivo.
    /// - Returns: El registro `PublicationRecord` creado e insertado en la persistencia.
    @MainActor
    public func importPublication(from url: URL) async throws -> PublicationRecord {
        // Validar límite del plan gratuito
        if let entitlementService {
            let canImport = await entitlementService.canPerformAction(.importDocument)
            if !canImport {
                let limits = await entitlementService.getLimits()
                throw ImportError.limitExceeded(String(localized: "Has alcanzado el límite de tu plan gratuito (\(limits.documentsLimit) documentos). Suscríbete a Premium para importar de forma ilimitada.", comment: "Limit exceeded error"))
            }
        }

        // 1. Validar el formato del archivo por su extensión
        let ext = url.pathExtension.lowercased()
        guard let publicationType = PublicationType.from(fileExtension: ext) else {
            throw ImportError.unsupportedFormat(extension: ext)
        }

        // 2. Manejar acceso a recursos seguros (security-scoped resources)
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Crear una ubicación temporal local dentro de nuestro Sandbox para procesar con seguridad
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let uniqueID = UUID().uuidString
        let tempFileURL = tempDirectory.appendingPathComponent("\(uniqueID).\(ext)")

        do {
            if FileManager.default.fileExists(atPath: tempFileURL.path) {
                try? FileManager.default.removeItem(at: tempFileURL)
            }
            try FileManager.default.copyItem(at: url, to: tempFileURL)
        } catch {
            throw ImportError.fileAccessFailed(error.localizedDescription)
        }

        defer {
            // Limpiar el archivo temporal al terminar
            try? FileManager.default.removeItem(at: tempFileURL)
        }

        // 3. Calcular hash SHA-256
        let sha256 = try fileStorageService.calculateSHA256(for: tempFileURL)

        // 4. Buscar duplicados en la base de datos local
        let allPublications = try await publicationRepository.fetchAll()
        if let duplicate = allPublications.first(where: { $0.sha256 == sha256 }) {
            throw ImportError.duplicateDocument(title: duplicate.title)
        }

        // 5. Extraer metadatos básicos (Título y Autor)
        let metadata = metadataExtractor.extract(from: tempFileURL, type: publicationType, originalFileName: url.lastPathComponent)

        // 6. Obtener tamaño físico y generar un nombre local único para el archivo
        let fileSize = try fileStorageService.getFileSize(at: tempFileURL)
        let localFileName = "\(uniqueID).\(ext)"

        // 7. Generar portada o miniatura física
        var coverPath: String?
        do {
            coverPath = try coverGenerator.generateCover(
                for: tempFileURL,
                type: publicationType,
                sha256: sha256,
                metadata: metadata
            )
        } catch {
            // Fallback: Si falla el render de la portada, la importación continúa sin ella.
            coverPath = nil
        }

        // 8. Mover el archivo de la carpeta temporal a la carpeta segura persistente
        let storedURL = try fileStorageService.store(fileAt: tempFileURL, withName: localFileName)

        // 9. Crear el registro en la base de datos local
        var record = PublicationRecord.newImport(
            title: metadata.title,
            author: metadata.author,
            publicationType: publicationType,
            localFileName: localFileName,
            originalFileName: url.lastPathComponent,
            mimeType: publicationType.mimeType,
            fileSize: fileSize,
            sha256: sha256,
            language: metadata.language
        )
        record.coverPath = coverPath

        try await publicationRepository.save(record)

        return record
    }

    /// Importa un bloque de texto plano pegado por el usuario de forma manual.
    /// - Parameters:
    ///   - text: Contenido del texto.
    ///   - title: Título asignado a la publicación.
    /// - Returns: El registro `PublicationRecord` creado.
    @MainActor
    public func importPastedText(text: String, title: String) async throws -> PublicationRecord {
        // Validar límite del plan gratuito
        if let entitlementService {
            let canImport = await entitlementService.canPerformAction(.importDocument)
            if !canImport {
                let limits = await entitlementService.getLimits()
                throw ImportError.limitExceeded(String(localized: "Has alcanzado el límite de tu plan gratuito (\(limits.documentsLimit) documentos). Suscríbete a Premium para importar de forma ilimitada.", comment: "Limit exceeded error"))
            }
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmedTitle.isEmpty ? String(localized: "Texto pegado sin título") : trimmedTitle

        // Guardar el texto en un archivo temporal para procesar hash y tamaño
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let uniqueID = UUID().uuidString
        let tempFileURL = tempDirectory.appendingPathComponent("\(uniqueID).txt")

        do {
            try text.write(to: tempFileURL, atomically: true, encoding: .utf8)
        } catch {
            throw ImportError.fileAccessFailed(error.localizedDescription)
        }

        defer {
            try? FileManager.default.removeItem(at: tempFileURL)
        }

        let sha256 = try fileStorageService.calculateSHA256(for: tempFileURL)

        // Validar duplicado
        let allPublications = try await publicationRepository.fetchAll()
        if let duplicate = allPublications.first(where: { $0.sha256 == sha256 }) {
            throw ImportError.duplicateDocument(title: duplicate.title)
        }

        let fileSize = try fileStorageService.getFileSize(at: tempFileURL)
        let localFileName = "\(uniqueID).txt"

        // Generar una portada bonita para el texto
        let metadata = ExtractedMetadata(title: finalTitle)
        let coverPath = try? coverGenerator.generateCover(
            for: tempFileURL,
            type: .pastedText,
            sha256: sha256,
            metadata: metadata
        )

        // Almacenar el archivo de texto final en Application Support
        _ = try fileStorageService.store(fileAt: tempFileURL, withName: localFileName)

        var record = PublicationRecord.newImport(
            title: finalTitle,
            publicationType: .pastedText,
            localFileName: localFileName,
            mimeType: "text/plain",
            fileSize: fileSize,
            sha256: sha256
        )
        record.coverPath = coverPath

        try await publicationRepository.save(record)

        return record
    }
}
