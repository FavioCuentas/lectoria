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
    public let subscriptionService: any SubscriptionService
    public let entitlementService: any FeatureEntitlementService
    public let aiService: any AIService
    public let syncService: any SyncService

    public init(
        modelContainer: ModelContainer,
        authService: (any AuthService)? = nil,
        subscriptionService: (any SubscriptionService)? = nil,
        aiService: (any AIService)? = nil,
        syncService: (any SyncService)? = nil
    ) {
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

        let env = AppEnvironment.current()
        let isFakeConfig = env.supabaseURL.contains("fake") || env.supabaseURL.contains("lectoria.app") || env.supabaseAnonKey.contains("fake")
        
        self.authService = authService ?? SupabaseAuthService(supabaseURL: env.supabaseURL, anonKey: env.supabaseAnonKey)

        let subService: any SubscriptionService
        if isFakeConfig {
            subService = subscriptionService ?? MockSubscriptionService(hasActiveSubscription: true)
        } else {
            subService = subscriptionService ?? StoreKitSubscriptionService(repository: subRepo)
        }
        self.subscriptionService = subService
        
        let entitlement = DefaultFeatureEntitlementService(
            publicationRepository: pubRepo,
            highlightRepository: highlightRepo,
            noteRepository: noteRepo,
            aiUsageRepository: aiRepo,
            subscriptionService: subService
        )
        self.entitlementService = entitlement

        self.importService = ImportService(
            publicationRepository: pubRepo,
            fileStorageService: fileStorage,
            entitlementService: entitlement
        )
        
        if isFakeConfig {
            self.aiService = aiService ?? MockAIService(hasConsentedToAI: true)
        } else {
            self.aiService = aiService ?? SupabaseAIService(supabaseURL: env.supabaseURL, anonKey: env.supabaseAnonKey)
        }
        
        self.syncService = syncService ?? SupabaseSyncService(container: modelContainer, authService: self.authService, supabaseURL: env.supabaseURL, anonKey: env.supabaseAnonKey)
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

    /// Si la biblioteca no contiene ninguna presentación PPTX, crea e importa automáticamente una presentación de prueba de Lectoria.
    public func seedSamplePresentationIfNeeded() async {
        guard let pubs = try? await publicationRepository.fetchAll() else { return }
        let hasPPTX = pubs.contains { $0.publicationType == .pptx }
        guard !hasPPTX else { return }

        let sampleData = SamplePPTXGenerator.createSamplePPTXData()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Presentacion_Demo_Lectoria.pptx")

        do {
            try sampleData.write(to: tempURL)
            _ = try await importService.importPublication(from: tempURL)
            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            print("Error al importar la presentación demo: \(error.localizedDescription)")
        }
    }

    #if DEBUG
    /// Inicializador mock/in-memory para previews de SwiftUI y pruebas rápidas.
    public static var preview: AppDependencies {
        let container = ModelContainerFactory.create(isStoredInMemoryOnly: true)
        return AppDependencies(
            modelContainer: container,
            authService: MockAuthService(),
            subscriptionService: MockSubscriptionService(),
            aiService: MockAIService(),
            syncService: MockSyncService()
        )
    }
    #endif
}
