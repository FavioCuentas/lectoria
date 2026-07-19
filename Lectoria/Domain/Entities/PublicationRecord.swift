import Foundation

// MARK: - IndexingStatus

/// Estado de indexación del contenido textual de una publicación.
public enum IndexingStatus: String, Codable, Sendable {
    case pending
    case indexing
    case completed
    case failed
    case notApplicable
}

// MARK: - SyncStatus

/// Estado de sincronización con el backend.
public enum SyncStatus: String, Codable, Sendable {
    case local
    case pendingUpload
    case synced
    case pendingDeletion
    case conflict
}

// MARK: - PublicationRecord

/// Representa una publicación almacenada en la biblioteca del usuario.
public struct PublicationRecord: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var ownerID: String?
    public var title: String
    public var author: String?
    public var publicationType: PublicationType
    public var localFileName: String
    public var originalFileName: String?
    public var mimeType: String
    public var fileSize: Int64
    public var sha256: String
    public var coverPath: String?
    public var language: String?
    public var createdAt: Date
    public var importedAt: Date
    public var lastOpenedAt: Date?
    public var finishedAt: Date?
    public var isFavorite: Bool
    public var isPinned: Bool
    public var isArchived: Bool
    public var isCloudBackedUp: Bool
    public var indexingStatus: IndexingStatus
    public var syncStatus: SyncStatus

    // MARK: - Initializer

    public init(
        id: UUID,
        ownerID: String? = nil,
        title: String,
        author: String? = nil,
        publicationType: PublicationType,
        localFileName: String,
        originalFileName: String? = nil,
        mimeType: String,
        fileSize: Int64,
        sha256: String,
        coverPath: String? = nil,
        language: String? = nil,
        createdAt: Date = .now,
        importedAt: Date = .now,
        lastOpenedAt: Date? = nil,
        finishedAt: Date? = nil,
        isFavorite: Bool = false,
        isPinned: Bool = false,
        isArchived: Bool = false,
        isCloudBackedUp: Bool = false,
        indexingStatus: IndexingStatus = .pending,
        syncStatus: SyncStatus = .local
    ) {
        self.id = id
        self.ownerID = ownerID
        self.title = title
        self.author = author
        self.publicationType = publicationType
        self.localFileName = localFileName
        self.originalFileName = originalFileName
        self.mimeType = mimeType
        self.fileSize = fileSize
        self.sha256 = sha256
        self.coverPath = coverPath
        self.language = language
        self.createdAt = createdAt
        self.importedAt = importedAt
        self.lastOpenedAt = lastOpenedAt
        self.finishedAt = finishedAt
        self.isFavorite = isFavorite
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.isCloudBackedUp = isCloudBackedUp
        self.indexingStatus = indexingStatus
        self.syncStatus = syncStatus
    }

    // MARK: - Computed

    /// Indica si el usuario ha comenzado a leer esta publicación.
    public var hasBeenOpened: Bool {
        lastOpenedAt != nil
    }

    /// Indica si la publicación está marcada como terminada.
    public var isFinished: Bool {
        finishedAt != nil
    }

    // MARK: - Factory

    /// Crea un registro con valores por defecto para una nueva importación.
    public static func newImport(
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
            isPinned: false,
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
    public static let previewEPUB = PublicationRecord.newImport(
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

    public static let previewPDF = PublicationRecord.newImport(
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

    public static let previewTXT = PublicationRecord.newImport(
        title: "Notas de investigación",
        publicationType: .txt,
        localFileName: "notas.txt",
        mimeType: "text/plain",
        fileSize: 45_000,
        sha256: "ghi789preview"
    )

    public static let previewMarkdown = PublicationRecord.newImport(
        title: "Guía de estilo del proyecto",
        author: "Equipo de desarrollo",
        publicationType: .markdown,
        localFileName: "guia-estilo.md",
        mimeType: "text/markdown",
        fileSize: 12_000,
        sha256: "jkl012preview"
    )

    public static let previewPastedText = PublicationRecord.newImport(
        title: "Extracto del artículo sobre IA",
        publicationType: .pastedText,
        localFileName: "extracto-ia.txt",
        mimeType: "text/plain",
        fileSize: 3_000,
        sha256: "mno345preview"
    )

    /// Colección de previews diversos.
    public static let previewCollection: [PublicationRecord] = [
        .previewEPUB,
        .previewPDF,
        .previewTXT,
        .previewMarkdown,
        .previewPastedText,
    ]
}
#endif
