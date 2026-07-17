import Foundation
import SwiftData

// MARK: - PublicationModel

@Model
public final class PublicationModel {
    @Attribute(.unique) public var id: UUID
    public var ownerID: String?
    public var title: String
    public var author: String?
    public var publicationTypeRaw: String
    public var localFileName: String
    public var originalFileName: String?
    public var mimeType: String
    public var fileSize: Int64
    @Attribute(.unique) public var sha256: String
    public var coverPath: String?
    public var language: String?
    public var createdAt: Date
    public var importedAt: Date
    public var lastOpenedAt: Date?
    public var finishedAt: Date?
    public var isFavorite: Bool
    public var isArchived: Bool
    public var isCloudBackedUp: Bool
    public var indexingStatusRaw: String
    public var syncStatusRaw: String
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \ReadingProgressModel.publication)
    public var progressList: [ReadingProgressModel] = []
    
    @Relationship(deleteRule: .cascade, inverse: \BookmarkModel.publication)
    public var bookmarks: [BookmarkModel] = []
    
    @Relationship(deleteRule: .cascade, inverse: \HighlightModel.publication)
    public var highlights: [HighlightModel] = []
    
    @Relationship(deleteRule: .cascade, inverse: \NoteModel.publication)
    public var notes: [NoteModel] = []
    
    @Relationship(deleteRule: .cascade, inverse: \ReadingSessionModel.publication)
    public var readingSessions: [ReadingSessionModel] = []

    public init(
        id: UUID,
        ownerID: String? = nil,
        title: String,
        author: String? = nil,
        publicationTypeRaw: String,
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
        isArchived: Bool = false,
        isCloudBackedUp: Bool = false,
        indexingStatusRaw: String = "pending",
        syncStatusRaw: String = "local"
    ) {
        self.id = id
        self.ownerID = ownerID
        self.title = title
        self.author = author
        self.publicationTypeRaw = publicationTypeRaw
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
        self.isArchived = isArchived
        self.isCloudBackedUp = isCloudBackedUp
        self.indexingStatusRaw = indexingStatusRaw
        self.syncStatusRaw = syncStatusRaw
    }
}

// MARK: - ReadingProgressModel

@Model
public final class ReadingProgressModel {
    @Attribute(.unique) public var id: UUID
    public var publicationID: UUID
    public var locatorJSON: String
    public var percentage: Double
    public var pageNumber: Int?
    public var chapterTitle: String?
    public var updatedAt: Date
    public var deviceID: String
    public var version: Int
    
    // Inverse relationship
    public var publication: PublicationModel?

    public init(
        id: UUID,
        publicationID: UUID,
        locatorJSON: String,
        percentage: Double,
        pageNumber: Int? = nil,
        chapterTitle: String? = nil,
        updatedAt: Date = .now,
        deviceID: String,
        version: Int = 1
    ) {
        self.id = id
        self.publicationID = publicationID
        self.locatorJSON = locatorJSON
        self.percentage = percentage
        self.pageNumber = pageNumber
        self.chapterTitle = chapterTitle
        self.updatedAt = updatedAt
        self.deviceID = deviceID
        self.version = version
    }
}

// MARK: - BookmarkModel

@Model
public final class BookmarkModel {
    @Attribute(.unique) public var id: UUID
    public var publicationID: UUID
    public var anchor: String
    public var title: String?
    public var createdAt: Date
    public var updatedAt: Date
    
    // Inverse relationship
    public var publication: PublicationModel?

    public init(
        id: UUID,
        publicationID: UUID,
        anchor: String,
        title: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.publicationID = publicationID
        self.anchor = anchor
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - HighlightModel

@Model
public final class HighlightModel {
    @Attribute(.unique) public var id: UUID
    public var publicationID: UUID
    public var anchor: String
    public var selectedText: String
    public var contextBefore: String?
    public var contextAfter: String?
    public var category: String?
    public var colorToken: String
    public var createdAt: Date
    public var updatedAt: Date
    
    // Inverse relationship
    public var publication: PublicationModel?
    
    // Related note relationship (Note has a direct pointer too)
    @Relationship(deleteRule: .nullify, inverse: \NoteModel.highlight)
    public var notes: [NoteModel] = []

    public init(
        id: UUID,
        publicationID: UUID,
        anchor: String,
        selectedText: String,
        contextBefore: String? = nil,
        contextAfter: String? = nil,
        category: String? = nil,
        colorToken: String = "yellow",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.publicationID = publicationID
        self.anchor = anchor
        self.selectedText = selectedText
        self.contextBefore = contextBefore
        self.contextAfter = contextAfter
        self.category = category
        self.colorToken = colorToken
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - NoteModel

@Model
public final class NoteModel {
    @Attribute(.unique) public var id: UUID
    public var publicationID: UUID
    public var highlightID: UUID?
    public var anchor: String?
    public var body: String
    public var tags: [String]
    public var createdAt: Date
    public var updatedAt: Date
    
    // Inverse relationships
    public var publication: PublicationModel?
    public var highlight: HighlightModel?

    public init(
        id: UUID,
        publicationID: UUID,
        highlightID: UUID? = nil,
        anchor: String? = nil,
        body: String,
        tags: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.publicationID = publicationID
        self.highlightID = highlightID
        self.anchor = anchor
        self.body = body
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - ReadingSessionModel

@Model
public final class ReadingSessionModel {
    @Attribute(.unique) public var id: UUID
    public var publicationID: UUID
    public var startedAt: Date
    public var endedAt: Date
    public var activeSeconds: Int
    public var startPercentage: Double
    public var endPercentage: Double
    
    // Inverse relationship
    public var publication: PublicationModel?

    public init(
        id: UUID,
        publicationID: UUID,
        startedAt: Date,
        endedAt: Date,
        activeSeconds: Int,
        startPercentage: Double,
        endPercentage: Double
    ) {
        self.id = id
        self.publicationID = publicationID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.activeSeconds = activeSeconds
        self.startPercentage = startPercentage
        self.endPercentage = endPercentage
    }
}

// MARK: - AIUsageModel

@Model
public final class AIUsageModel {
    @Attribute(.unique) public var id: UUID
    public var userID: String?
    public var operation: String
    public var creditCost: Int
    public var createdAt: Date
    public var requestID: String?

    public init(
        id: UUID,
        userID: String? = nil,
        operation: String,
        creditCost: Int,
        createdAt: Date = .now,
        requestID: String? = nil
    ) {
        self.id = id
        self.userID = userID
        self.operation = operation
        self.creditCost = creditCost
        self.createdAt = createdAt
        self.requestID = requestID
    }
}

// MARK: - SubscriptionEntitlementModel

@Model
public final class SubscriptionEntitlementModel {
    @Attribute(.unique) public var productID: String
    public var status: String
    public var expirationDate: Date?
    public var isInGracePeriod: Bool
    public var willAutoRenew: Bool
    public var lastVerifiedAt: Date

    public init(
        productID: String,
        status: String,
        expirationDate: Date? = nil,
        isInGracePeriod: Bool = false,
        willAutoRenew: Bool = true,
        lastVerifiedAt: Date = .now
    ) {
        self.productID = productID
        self.status = status
        self.expirationDate = expirationDate
        self.isInGracePeriod = isInGracePeriod
        self.willAutoRenew = willAutoRenew
        self.lastVerifiedAt = lastVerifiedAt
    }
}

// MARK: - SyncOperationModel

@Model
public final class SyncOperationModel {
    @Attribute(.unique) public var id: UUID
    public var entityType: String
    public var entityID: String
    public var action: String
    public var payload: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        entityType: String,
        entityID: String,
        action: String,
        payload: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.entityType = entityType
        self.entityID = entityID
        self.action = action
        self.payload = payload
        self.createdAt = createdAt
    }
}

// MARK: - Domain Mapping Extensions

extension PublicationModel {
    public func toDomain() -> PublicationRecord {
        PublicationRecord(
            id: id,
            ownerID: ownerID,
            title: title,
            author: author,
            publicationType: PublicationType(rawValue: publicationTypeRaw) ?? .txt,
            localFileName: localFileName,
            originalFileName: originalFileName,
            mimeType: mimeType,
            fileSize: fileSize,
            sha256: sha256,
            coverPath: coverPath,
            language: language,
            createdAt: createdAt,
            importedAt: importedAt,
            lastOpenedAt: lastOpenedAt,
            finishedAt: finishedAt,
            isFavorite: isFavorite,
            isArchived: isArchived,
            isCloudBackedUp: isCloudBackedUp,
            indexingStatus: IndexingStatus(rawValue: indexingStatusRaw) ?? .pending,
            syncStatus: SyncStatus(rawValue: syncStatusRaw) ?? .local
        )
    }

    public static func fromDomain(_ domain: PublicationRecord) -> PublicationModel {
        PublicationModel(
            id: domain.id,
            ownerID: domain.ownerID,
            title: domain.title,
            author: domain.author,
            publicationTypeRaw: domain.publicationType.rawValue,
            localFileName: domain.localFileName,
            originalFileName: domain.originalFileName,
            mimeType: domain.mimeType,
            fileSize: domain.fileSize,
            sha256: domain.sha256,
            coverPath: domain.coverPath,
            language: domain.language,
            createdAt: domain.createdAt,
            importedAt: domain.importedAt,
            lastOpenedAt: domain.lastOpenedAt,
            finishedAt: domain.finishedAt,
            isFavorite: domain.isFavorite,
            isArchived: domain.isArchived,
            isCloudBackedUp: domain.isCloudBackedUp,
            indexingStatusRaw: domain.indexingStatus.rawValue,
            syncStatusRaw: domain.syncStatus.rawValue
        )
    }
}

extension ReadingProgressModel {
    public func toDomain() -> ReadingProgress {
        ReadingProgress(
            id: id,
            publicationID: publicationID,
            locatorJSON: locatorJSON,
            percentage: percentage,
            pageNumber: pageNumber,
            chapterTitle: chapterTitle,
            updatedAt: updatedAt,
            deviceID: deviceID,
            version: version
        )
    }

    public static func fromDomain(_ domain: ReadingProgress) -> ReadingProgressModel {
        ReadingProgressModel(
            id: domain.id,
            publicationID: domain.publicationID,
            locatorJSON: domain.locatorJSON,
            percentage: domain.percentage,
            pageNumber: domain.pageNumber,
            chapterTitle: domain.chapterTitle,
            updatedAt: domain.updatedAt,
            deviceID: domain.deviceID,
            version: domain.version
        )
    }
}

extension BookmarkModel {
    public func toDomain() -> Bookmark {
        Bookmark(
            id: id,
            publicationID: publicationID,
            anchor: anchor,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    public static func fromDomain(_ domain: Bookmark) -> BookmarkModel {
        BookmarkModel(
            id: domain.id,
            publicationID: domain.publicationID,
            anchor: domain.anchor,
            title: domain.title,
            createdAt: domain.createdAt,
            updatedAt: domain.updatedAt
        )
    }
}

extension HighlightModel {
    public func toDomain() -> Highlight {
        Highlight(
            id: id,
            publicationID: publicationID,
            anchor: anchor,
            selectedText: selectedText,
            contextBefore: contextBefore,
            contextAfter: contextAfter,
            category: category,
            colorToken: colorToken,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    public static func fromDomain(_ domain: Highlight) -> HighlightModel {
        HighlightModel(
            id: domain.id,
            publicationID: domain.publicationID,
            anchor: domain.anchor,
            selectedText: domain.selectedText,
            contextBefore: domain.contextBefore,
            contextAfter: domain.contextAfter,
            category: domain.category,
            colorToken: domain.colorToken,
            createdAt: domain.createdAt,
            updatedAt: domain.updatedAt
        )
    }
}

extension NoteModel {
    public func toDomain() -> Note {
        Note(
            id: id,
            publicationID: publicationID,
            highlightID: highlightID,
            anchor: anchor,
            body: body,
            tags: tags,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    public static func fromDomain(_ domain: Note) -> NoteModel {
        NoteModel(
            id: domain.id,
            publicationID: domain.publicationID,
            highlightID: domain.highlightID,
            anchor: domain.anchor,
            body: domain.body,
            tags: domain.tags,
            createdAt: domain.createdAt,
            updatedAt: domain.updatedAt
        )
    }
}

extension ReadingSessionModel {
    public func toDomain() -> ReadingSession {
        ReadingSession(
            id: id,
            publicationID: publicationID,
            startedAt: startedAt,
            endedAt: endedAt,
            activeSeconds: activeSeconds,
            startPercentage: startPercentage,
            endPercentage: endPercentage
        )
    }

    public static func fromDomain(_ domain: ReadingSession) -> ReadingSessionModel {
        ReadingSessionModel(
            id: domain.id,
            publicationID: domain.publicationID,
            startedAt: domain.startedAt,
            endedAt: domain.endedAt,
            activeSeconds: domain.activeSeconds,
            startPercentage: domain.startPercentage,
            endPercentage: domain.endPercentage
        )
    }
}

extension AIUsageModel {
    public func toDomain() -> AIUsage {
        AIUsage(
            id: id,
            userID: userID,
            operation: operation,
            creditCost: creditCost,
            createdAt: createdAt,
            requestID: requestID
        )
    }

    public static func fromDomain(_ domain: AIUsage) -> AIUsageModel {
        AIUsageModel(
            id: domain.id,
            userID: domain.userID,
            operation: domain.operation,
            creditCost: domain.creditCost,
            createdAt: domain.createdAt,
            requestID: domain.requestID
        )
    }
}

extension SubscriptionEntitlementModel {
    public func toDomain() -> SubscriptionEntitlement {
        SubscriptionEntitlement(
            productID: productID,
            status: status,
            expirationDate: expirationDate,
            isInGracePeriod: isInGracePeriod,
            willAutoRenew: willAutoRenew,
            lastVerifiedAt: lastVerifiedAt
        )
    }

    public static func fromDomain(_ domain: SubscriptionEntitlement) -> SubscriptionEntitlementModel {
        SubscriptionEntitlementModel(
            productID: domain.productID,
            status: domain.status,
            expirationDate: domain.expirationDate,
            isInGracePeriod: domain.isInGracePeriod,
            willAutoRenew: domain.willAutoRenew,
            lastVerifiedAt: domain.lastVerifiedAt
        )
    }
}
