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
    public let readingProgressRepository: any ReadingProgressRepository

    // Servicios
    public let fileStorageService: FileStorageService
    public let importService: ImportService
    public let authService: any AuthService

    public init(modelContainer: ModelContainer, authService: (any AuthService)? = nil) {
        // Inicializar repositorios persistentes usando SwiftData
        let pubRepo = SwiftDataPublicationRepository(container: modelContainer)
        let bookmarkRepo = SwiftDataBookmarkRepository(container: modelContainer)
        let highlightRepo = SwiftDataHighlightRepository(container: modelContainer)
        let noteRepo = SwiftDataNoteRepository(container: modelContainer)
        let sessionRepo = SwiftDataReadingSessionRepository(container: modelContainer)
        let aiRepo = SwiftDataAIUsageRepository(container: modelContainer)
        let subRepo = SwiftDataSubscriptionRepository(container: modelContainer)
        let progressRepo = SwiftDataReadingProgressRepository(container: modelContainer)

        self.publicationRepository = pubRepo
        self.bookmarkRepository = bookmarkRepo
        self.highlightRepository = highlightRepo
        self.noteRepository = noteRepo
        self.readingSessionRepository = sessionRepo
        self.aiUsageRepository = aiRepo
        self.subscriptionRepository = subRepo
        self.readingProgressRepository = progressRepo

        // Inicializar servicios
        let fileStorage = FileStorageService()
        self.fileStorageService = fileStorage

        self.importService = ImportService(
            publicationRepository: pubRepo,
            fileStorageService: fileStorage
        )
        
        let env = AppEnvironment.current()
        self.authService = authService ?? SupabaseAuthService(supabaseURL: env.supabaseURL, anonKey: env.supabaseAnonKey)
    }

    /// Migra todas las publicaciones locales y consumos de IA huérfanos (de invitado) al nuevo ID de usuario.
    public func migrateGuestData(to userID: String) async {
        if let pubs = try? await publicationRepository.fetchAll() {
            for var pub in pubs {
                if pub.ownerID == nil {
                    pub.ownerID = userID
                    try? await publicationRepository.save(pub)
                }
            }
        }

        if let usages = try? await aiUsageRepository.fetchAll() {
            for var usage in usages {
                if usage.userID == nil {
                    usage.userID = userID
                    try? await aiUsageRepository.save(usage)
                }
            }
        }
    }

    #if DEBUG
    /// Inicializador mock/in-memory para previews de SwiftUI y pruebas rápidas.
    public static var preview: AppDependencies {
        let container = ModelContainerFactory.create(isStoredInMemoryOnly: true)
        return AppDependencies(modelContainer: container, authService: MockAuthService())
    }
    #endif
}
