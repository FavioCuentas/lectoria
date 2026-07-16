import Foundation
import SwiftData

// MARK: - AppDependencies

/// Contenedor centralizado para la inyección de dependencias de la aplicación.
///
/// Gestiona la inicialización de repositorios persistentes con SwiftData
/// y servicios compartidos. Se inyecta en el environment raíz de la app.
@Observable
@MainActor
public final class AppDependencies {
    // Repositorios
    public let publicationRepository: any PublicationRepository
    public let bookmarkRepository: any BookmarkRepository
    public let highlightRepository: any HighlightRepository
    public let noteRepository: any NoteRepository
    public let readingSessionRepository: any ReadingSessionRepository
    public let aiUsageRepository: any AIUsageRepository
    public let subscriptionRepository: any SubscriptionRepository

    // Servicios
    public let fileStorageService: FileStorageService
    public let importService: ImportService

    public init(modelContainer: ModelContainer) {
        // Inicializar repositorios persistentes usando SwiftData
        let pubRepo = SwiftDataPublicationRepository(container: modelContainer)
        let bookmarkRepo = SwiftDataBookmarkRepository(container: modelContainer)
        let highlightRepo = SwiftDataHighlightRepository(container: modelContainer)
        let noteRepo = SwiftDataNoteRepository(container: modelContainer)
        let sessionRepo = SwiftDataReadingSessionRepository(container: modelContainer)
        let aiRepo = SwiftDataAIUsageRepository(container: modelContainer)
        let subRepo = SwiftDataSubscriptionRepository(container: modelContainer)

        self.publicationRepository = pubRepo
        self.bookmarkRepository = bookmarkRepo
        self.highlightRepository = highlightRepo
        self.noteRepository = noteRepo
        self.readingSessionRepository = sessionRepo
        self.aiUsageRepository = aiRepo
        self.subscriptionRepository = subRepo

        // Inicializar servicios
        let fileStorage = FileStorageService()
        self.fileStorageService = fileStorage

        self.importService = ImportService(
            publicationRepository: pubRepo,
            fileStorageService: fileStorage
        )
    }

    #if DEBUG
    /// Inicializador mock/in-memory para previews de SwiftUI y pruebas rápidas.
    public static var preview: AppDependencies {
        let container = ModelContainerFactory.create(isStoredInMemoryOnly: true)
        return AppDependencies(modelContainer: container)
    }
    #endif
}
