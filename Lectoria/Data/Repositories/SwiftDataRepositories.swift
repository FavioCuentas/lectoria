import Foundation
import SwiftData

// MARK: - SwiftDataPublicationRepository

@MainActor
public final class SwiftDataPublicationRepository: PublicationRepository {
    private let container: ModelContainer
    private var context: ModelContext {
        container.mainContext
    }

    public init(container: ModelContainer) {
        self.container = container
    }

    public func fetchAll() async throws -> [PublicationRecord] {
        let descriptor = FetchDescriptor<PublicationModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let models = try context.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetch(id: UUID) async throws -> PublicationRecord? {
        let descriptor = FetchDescriptor<PublicationModel>(
            predicate: #Predicate<PublicationModel> { $0.id == id }
        )
        let models = try context.fetch(descriptor)
        return models.first?.toDomain()
    }

    public func save(_ publication: PublicationRecord) async throws {
        let id = publication.id
        let descriptor = FetchDescriptor<PublicationModel>(
            predicate: #Predicate<PublicationModel> { $0.id == id }
        )
        let existing = try context.fetch(descriptor).first
        
        if let existing {
            existing.ownerID = publication.ownerID
            existing.title = publication.title
            existing.author = publication.author
            existing.publicationTypeRaw = publication.publicationType.rawValue
            existing.localFileName = publication.localFileName
            existing.originalFileName = publication.originalFileName
            existing.mimeType = publication.mimeType
            existing.fileSize = publication.fileSize
            existing.sha256 = publication.sha256
            existing.coverPath = publication.coverPath
            existing.language = publication.language
            existing.lastOpenedAt = publication.lastOpenedAt
            existing.finishedAt = publication.finishedAt
            existing.isFavorite = publication.isFavorite
            existing.isPinned = publication.isPinned
            existing.isArchived = publication.isArchived
            existing.isCloudBackedUp = publication.isCloudBackedUp
            existing.indexingStatusRaw = publication.indexingStatus.rawValue
            existing.syncStatusRaw = publication.syncStatus.rawValue
        } else {
            let model = PublicationModel.fromDomain(publication)
            context.insert(model)
        }
        
        try context.save()
    }

    public func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<PublicationModel>(
            predicate: #Predicate<PublicationModel> { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
            try context.save()
        }
    }
}

// MARK: - SwiftDataBookmarkRepository

@MainActor
public final class SwiftDataBookmarkRepository: BookmarkRepository {
    private let container: ModelContainer
    private var context: ModelContext {
        container.mainContext
    }

    public init(container: ModelContainer) {
        self.container = container
    }

    public func fetch(forPublication publicationID: UUID) async throws -> [Bookmark] {
        let descriptor = FetchDescriptor<BookmarkModel>(
            predicate: #Predicate<BookmarkModel> { $0.publicationID == publicationID },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let models = try context.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetch(id: UUID) async throws -> Bookmark? {
        let descriptor = FetchDescriptor<BookmarkModel>(
            predicate: #Predicate<BookmarkModel> { $0.id == id }
        )
        let models = try context.fetch(descriptor)
        return models.first?.toDomain()
    }

    public func save(_ bookmark: Bookmark) async throws {
        let id = bookmark.id
        let descriptor = FetchDescriptor<BookmarkModel>(
            predicate: #Predicate<BookmarkModel> { $0.id == id }
        )
        let existing = try context.fetch(descriptor).first
        
        if let existing {
            existing.anchor = bookmark.anchor
            existing.title = bookmark.title
            existing.updatedAt = bookmark.updatedAt
        } else {
            let model = BookmarkModel.fromDomain(bookmark)
            
            // Relate with PublicationModel if it exists
            let pubID = bookmark.publicationID
            let pubDescriptor = FetchDescriptor<PublicationModel>(
                predicate: #Predicate<PublicationModel> { $0.id == pubID }
            )
            if let publication = try context.fetch(pubDescriptor).first {
                model.publication = publication
            }
            
            context.insert(model)
        }
        
        try context.save()
    }

    public func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<BookmarkModel>(
            predicate: #Predicate<BookmarkModel> { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
            
            let op = SyncOperationModel(entityType: "bookmark", entityID: id.uuidString, action: "delete", payload: "")
            context.insert(op)
            
            try context.save()
        }
    }
}

// MARK: - SwiftDataHighlightRepository

@MainActor
public final class SwiftDataHighlightRepository: HighlightRepository {
    private let container: ModelContainer
    private var context: ModelContext {
        container.mainContext
    }

    public init(container: ModelContainer) {
        self.container = container
    }

    public func fetch(forPublication publicationID: UUID) async throws -> [Highlight] {
        let descriptor = FetchDescriptor<HighlightModel>(
            predicate: #Predicate<HighlightModel> { $0.publicationID == publicationID },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let models = try context.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetchAll() async throws -> [Highlight] {
        let descriptor = FetchDescriptor<HighlightModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let models = try context.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetch(id: UUID) async throws -> Highlight? {
        let descriptor = FetchDescriptor<HighlightModel>(
            predicate: #Predicate<HighlightModel> { $0.id == id }
        )
        let models = try context.fetch(descriptor)
        return models.first?.toDomain()
    }

    public func save(_ highlight: Highlight) async throws {
        let id = highlight.id
        let descriptor = FetchDescriptor<HighlightModel>(
            predicate: #Predicate<HighlightModel> { $0.id == id }
        )
        let existing = try context.fetch(descriptor).first
        
        if let existing {
            existing.anchor = highlight.anchor
            existing.selectedText = highlight.selectedText
            existing.contextBefore = highlight.contextBefore
            existing.contextAfter = highlight.contextAfter
            existing.category = highlight.category
            existing.colorToken = highlight.colorToken
            existing.updatedAt = highlight.updatedAt
        } else {
            let model = HighlightModel.fromDomain(highlight)
            
            // Relate with PublicationModel if it exists
            let pubID = highlight.publicationID
            let pubDescriptor = FetchDescriptor<PublicationModel>(
                predicate: #Predicate<PublicationModel> { $0.id == pubID }
            )
            if let publication = try context.fetch(pubDescriptor).first {
                model.publication = publication
            }
            
            context.insert(model)
        }
        
        try context.save()
    }

    public func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<HighlightModel>(
            predicate: #Predicate<HighlightModel> { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
            
            let op = SyncOperationModel(entityType: "highlight", entityID: id.uuidString, action: "delete", payload: "")
            context.insert(op)
            
            try context.save()
        }
    }
}

// MARK: - SwiftDataNoteRepository

@MainActor
public final class SwiftDataNoteRepository: NoteRepository {
    private let container: ModelContainer
    private var context: ModelContext {
        container.mainContext
    }

    public init(container: ModelContainer) {
        self.container = container
    }

    public func fetch(forPublication publicationID: UUID) async throws -> [Note] {
        let descriptor = FetchDescriptor<NoteModel>(
            predicate: #Predicate<NoteModel> { $0.publicationID == publicationID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let models = try context.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetch(id: UUID) async throws -> Note? {
        let descriptor = FetchDescriptor<NoteModel>(
            predicate: #Predicate<NoteModel> { $0.id == id }
        )
        let models = try context.fetch(descriptor)
        return models.first?.toDomain()
    }

    public func fetchAll() async throws -> [Note] {
        let descriptor = FetchDescriptor<NoteModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let models = try context.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func save(_ note: Note) async throws {
        let id = note.id
        let descriptor = FetchDescriptor<NoteModel>(
            predicate: #Predicate<NoteModel> { $0.id == id }
        )
        let existing = try context.fetch(descriptor).first
        
        if let existing {
            existing.highlightID = note.highlightID
            existing.anchor = note.anchor
            existing.body = note.body
            existing.tags = note.tags
            existing.updatedAt = note.updatedAt
        } else {
            let model = NoteModel.fromDomain(note)
            
            // Relate with PublicationModel if it exists
            let pubID = note.publicationID
            let pubDescriptor = FetchDescriptor<PublicationModel>(
                predicate: #Predicate<PublicationModel> { $0.id == pubID }
            )
            if let publication = try context.fetch(pubDescriptor).first {
                model.publication = publication
            }
            
            // Relate with HighlightModel if it exists
            if let highlightID = note.highlightID {
                let highlightDescriptor = FetchDescriptor<HighlightModel>(
                    predicate: #Predicate<HighlightModel> { $0.id == highlightID }
                )
                if let highlight = try context.fetch(highlightDescriptor).first {
                    model.highlight = highlight
                }
            }
            
            context.insert(model)
        }
        
        try context.save()
    }

    public func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<NoteModel>(
            predicate: #Predicate<NoteModel> { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
            
            let op = SyncOperationModel(entityType: "note", entityID: id.uuidString, action: "delete", payload: "")
            context.insert(op)
            
            try context.save()
        }
    }
}

// MARK: - SwiftDataReadingSessionRepository

@MainActor
public final class SwiftDataReadingSessionRepository: ReadingSessionRepository {
    private let container: ModelContainer
    private var context: ModelContext {
        container.mainContext
    }

    public init(container: ModelContainer) {
        self.container = container
    }

    public func fetch(forPublication publicationID: UUID) async throws -> [ReadingSession] {
        let descriptor = FetchDescriptor<ReadingSessionModel>(
            predicate: #Predicate<ReadingSessionModel> { $0.publicationID == publicationID },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let models = try context.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetchAll() async throws -> [ReadingSession] {
        let descriptor = FetchDescriptor<ReadingSessionModel>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let models = try context.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func save(_ session: ReadingSession) async throws {
        let model = ReadingSessionModel.fromDomain(session)
        
        // Relate with PublicationModel if it exists
        let pubID = session.publicationID
        let pubDescriptor = FetchDescriptor<PublicationModel>(
            predicate: #Predicate<PublicationModel> { $0.id == pubID }
        )
        if let publication = try context.fetch(pubDescriptor).first {
            model.publication = publication
        }
        
        context.insert(model)
        try context.save()
    }
}

// MARK: - SwiftDataAIUsageRepository

@MainActor
public final class SwiftDataAIUsageRepository: AIUsageRepository {
    private let container: ModelContainer
    private var context: ModelContext {
        container.mainContext
    }

    public init(container: ModelContainer) {
        self.container = container
    }

    public func fetchAll() async throws -> [AIUsage] {
        let descriptor = FetchDescriptor<AIUsageModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let models = try context.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func save(_ usage: AIUsage) async throws {
        let model = AIUsageModel.fromDomain(usage)
        context.insert(model)
        try context.save()
    }

    public func fetchTotalCreditsUsedToday() async throws -> Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        
        let descriptor = FetchDescriptor<AIUsageModel>(
            predicate: #Predicate<AIUsageModel> { $0.createdAt >= startOfToday }
        )
        let models = try context.fetch(descriptor)
        return models.reduce(0) { $0 + $1.creditCost }
    }
}

// MARK: - SwiftDataSubscriptionRepository

@MainActor
public final class SwiftDataSubscriptionRepository: SubscriptionRepository {
    private let container: ModelContainer
    private var context: ModelContext {
        container.mainContext
    }

    public init(container: ModelContainer) {
        self.container = container
    }

    public func fetchAllEntitlements() async throws -> [SubscriptionEntitlement] {
        let descriptor = FetchDescriptor<SubscriptionEntitlementModel>()
        let models = try context.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    public func fetchEntitlement(productID: String) async throws -> SubscriptionEntitlement? {
        let descriptor = FetchDescriptor<SubscriptionEntitlementModel>(
            predicate: #Predicate<SubscriptionEntitlementModel> { $0.productID == productID }
        )
        let models = try context.fetch(descriptor)
        return models.first?.toDomain()
    }

    public func saveEntitlement(_ entitlement: SubscriptionEntitlement) async throws {
        let productID = entitlement.productID
        let descriptor = FetchDescriptor<SubscriptionEntitlementModel>(
            predicate: #Predicate<SubscriptionEntitlementModel> { $0.productID == productID }
        )
        let existing = try context.fetch(descriptor).first
        
        if let existing {
            existing.status = entitlement.status
            existing.expirationDate = entitlement.expirationDate
            existing.isInGracePeriod = entitlement.isInGracePeriod
            existing.willAutoRenew = entitlement.willAutoRenew
            existing.lastVerifiedAt = entitlement.lastVerifiedAt
        } else {
            let model = SubscriptionEntitlementModel.fromDomain(entitlement)
            context.insert(model)
        }
        
        try context.save()
    }
}

// MARK: - SwiftDataReadingProgressRepository

@MainActor
public final class SwiftDataReadingProgressRepository: ReadingProgressRepository {
    private let container: ModelContainer
    private var context: ModelContext {
        container.mainContext
    }

    public init(container: ModelContainer) {
        self.container = container
    }

    public func fetchProgress(forPublication publicationID: UUID) async throws -> ReadingProgress? {
        let descriptor = FetchDescriptor<ReadingProgressModel>(
            predicate: #Predicate<ReadingProgressModel> { $0.publicationID == publicationID }
        )
        let models = try context.fetch(descriptor)
        return models.first?.toDomain()
    }

    public func saveProgress(_ progress: ReadingProgress) async throws {
        let publicationID = progress.publicationID
        let descriptor = FetchDescriptor<ReadingProgressModel>(
            predicate: #Predicate<ReadingProgressModel> { $0.publicationID == publicationID }
        )
        let existing = try context.fetch(descriptor).first

        if let existing {
            existing.locatorJSON = progress.locatorJSON
            existing.percentage = progress.percentage
            existing.pageNumber = progress.pageNumber
            existing.chapterTitle = progress.chapterTitle
            existing.updatedAt = progress.updatedAt
            existing.deviceID = progress.deviceID
            existing.version = progress.version
        } else {
            let model = ReadingProgressModel.fromDomain(progress)
            let pubDescriptor = FetchDescriptor<PublicationModel>(
                predicate: #Predicate<PublicationModel> { $0.id == publicationID }
            )
            if let pubModel = try context.fetch(pubDescriptor).first {
                model.publication = pubModel
            }
            context.insert(model)
        }

        try context.save()
    }
}

