import Foundation

// MARK: - IndexingStatus

/// Estado de indexación del contenido textual de una publicación.
enum IndexingStatus: String, Codable, Sendable {
    case pending
    case indexing
    case completed
    case failed
    case notApplicable
}

// MARK: - SyncStatus

/// Estado de sincronización con el backend.
enum SyncStatus: String, Codable, Sendable {
    case local
    case pendingUpload
    case synced
    case pendingDeletion
    case conflict
}

// MARK: - PublicationRecord

/// Representa una publicación almacenada en la biblioteca del usuario.
///
/// En Fase 0-1 esta entidad es un `struct` simple. En Fase 2 se
/// migrará a un `@Model` de SwiftData manteniendo la misma forma.
struct PublicationRecord: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var ownerID: String?
    var title: String
    var author: String?
    var publicationType: PublicationType
    var localFileName: String
    var originalFileName: String?
    var mimeType: String
    var fileSize: Int64
    var sha256: String
    var coverPath: String?
    var language: String?
    var createdAt: Date
    var importedAt: Date
    var lastOpenedAt: Date?
    var finishedAt: Date?
    var isFavorite: Bool
    var isArchived: Bool
    var isCloudBackedUp: Bool
    var indexingStatus: IndexingStatus
    var syncStatus: SyncStatus

    // MARK: - Computed

    /// Indica si el usuario ha comenzado a leer esta publicación.
    var hasBeenOpened: Bool {
        lastOpenedAt != nil
    }

    /// Indica si la publicación está marcada como terminada.
    var isFinished: Bool {
        finishedAt != nil
    }

    // MARK: - Factory

    /// Crea un registro con valores por defecto para una nueva importación.
    static func newImport(
        title: String,
        author: String? = nil,
        publicationType: PublicationType,
        localFileName: String,
        originalFileName: String? = nil,
        mimeType: String,
        fileSize: Int64,
        sha256: String,
        language: String? = nil
    ) -> PublicationRecord {
        PublicationRecord(
            id: UUID(),
            ownerID: nil,
            title: title,
            author: author,
            publicationType: publicationType,
            localFileName: localFileName,
            originalFileName: originalFileName,
            mimeType: mimeType,
            fileSize: fileSize,
            sha256: sha256,
            coverPath: nil,
            language: language,
            createdAt: .now,
            importedAt: .now,
            lastOpenedAt: nil,
            finishedAt: nil,
            isFavorite: false,
            isArchived: false,
            isCloudBackedUp: false,
            indexingStatus: .pending,
            syncStatus: .local
        )
    }
}

// MARK: - Preview fixtures

#if DEBUG
extension PublicationRecord {
    /// Fixture para previews y tests.
    static let previewEPUB = PublicationRecord.newImport(
        title: "Cien años de soledad",
        author: "Gabriel García Márquez",
        publicationType: .epub,
        localFileName: "cien-anos.epub",
        originalFileName: "Cien años de soledad.epub",
        mimeType: "application/epub+zip",
        fileSize: 2_500_000,
        sha256: "abc123preview",
        language: "es"
    )

    static let previewPDF = PublicationRecord.newImport(
        title: "Apuntes de Física Cuántica",
        author: "Dr. María López",
        publicationType: .pdf,
        localFileName: "fisica-cuantica.pdf",
        originalFileName: "Apuntes Física.pdf",
        mimeType: "application/pdf",
        fileSize: 15_000_000,
        sha256: "def456preview",
        language: "es"
    )

    static let previewTXT = PublicationRecord.newImport(
        title: "Notas de investigación",
        publicationType: .txt,
        localFileName: "notas.txt",
        mimeType: "text/plain",
        fileSize: 45_000,
        sha256: "ghi789preview"
    )

    static let previewMarkdown = PublicationRecord.newImport(
        title: "Guía de estilo del proyecto",
        author: "Equipo de desarrollo",
        publicationType: .markdown,
        localFileName: "guia-estilo.md",
        mimeType: "text/markdown",
        fileSize: 12_000,
        sha256: "jkl012preview"
    )

    static let previewPastedText = PublicationRecord.newImport(
        title: "Extracto del artículo sobre IA",
        publicationType: .pastedText,
        localFileName: "extracto-ia.txt",
        mimeType: "text/plain",
        fileSize: 3_000,
        sha256: "mno345preview"
    )

    /// Colección de previews diversos.
    static let previewCollection: [PublicationRecord] = [
        .previewEPUB,
        .previewPDF,
        .previewTXT,
        .previewMarkdown,
        .previewPastedText,
    ]
}
#endif
