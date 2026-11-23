import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.orvexa.Lectoria", category: "App")

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
    /// Convierte presentaciones PPTX a PDF buscable (tras importar o al abrir).
    let presentationRenderingService: PresentationRenderingService
    /// Índice de contenido de la búsqueda global (`nil` si no se pudo abrir la base).
    let searchIndexStore: SearchIndexStore?
    /// Mantiene el índice de la búsqueda global al día.
    let searchIndexingService: SearchIndexingService
    /// Copia de seguridad automática de anotaciones y progreso (Perfil muestra su estado).
    let autoBackup: AutoBackupCoordinator
    public let authService: any AuthService
    public let subscriptionService: any SubscriptionService
    public let entitlementService: any EntitlementService
    public let aiService: any AIService
    public let syncService: any SyncService
    public let analyticsService: any AnalyticsService
    public let institutionService: any InstitutionService

    public init(
        modelContainer: ModelContainer,
        authService: (any AuthService)? = nil,
        institutionService: (any InstitutionService)? = nil,
        subscriptionService: (any SubscriptionService)? = nil,
        aiService: (any AIService)? = nil,
        syncService: (any SyncService)? = nil,
        analyticsService: (any AnalyticsService)? = nil
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

        if let institutionService {
            self.institutionService = institutionService
        } else if isFakeConfig {
            self.institutionService = MockInstitutionService()
        } else {
            self.institutionService = SupabaseInstitutionService(supabaseURL: env.supabaseURL, anonKey: env.supabaseAnonKey)
        }

        let subService: any SubscriptionService
        if isFakeConfig {
            subService = subscriptionService ?? MockSubscriptionService(hasActiveSubscription: true)
        } else {
            let auth = self.authService
            subService = subscriptionService ?? StoreKitSubscriptionService(
                repository: subRepo,
                currentEmailProvider: { auth.currentUser?.email }
            )
        }
        self.subscriptionService = subService
        
        let entitlement = EntitlementManager(
            publicationRepository: pubRepo,
            highlightRepository: highlightRepo,
            noteRepository: noteRepo,
            aiUsageRepository: aiRepo,
            subscriptionService: subService,
            authService: self.authService
        )
        self.entitlementService = entitlement

        self.analyticsService = analyticsService ?? SupabaseAnalyticsService(
            container: modelContainer,
            authService: self.authService,
            supabaseURL: env.supabaseURL,
            anonKey: env.supabaseAnonKey
        )

        // Las vistas usan versiones que registran en el panel cuándo se crea un resaltado,
        // nota o marcador. EntitlementManager sigue con los repositorios base (solo cuenta).
        self.bookmarkRepository = AnalyticsBookmarkRepository(base: bookmarkRepo, analytics: self.analyticsService)
        self.highlightRepository = AnalyticsHighlightRepository(base: highlightRepo, analytics: self.analyticsService)
        self.noteRepository = AnalyticsNoteRepository(base: noteRepo, analytics: self.analyticsService)

        let indexStore = try? SearchIndexStore(url: SearchIndexStore.defaultURL())
        self.searchIndexStore = indexStore
        let indexingService = SearchIndexingService(store: indexStore, publications: pubRepo)
        self.searchIndexingService = indexingService
        let renderingService = PresentationRenderingService()
        self.presentationRenderingService = renderingService
        self.importService = ImportService(
            publicationRepository: pubRepo,
            fileStorageService: fileStorage,
            entitlementService: entitlement,
            analyticsService: self.analyticsService,
            presentationRenderer: renderingService,
            searchIndexer: indexingService
        )
        
        self.aiService = aiService ?? LocalDeviceAIService()
        
        self.syncService = syncService ?? SupabaseSyncService(container: modelContainer, authService: self.authService, supabaseURL: env.supabaseURL, anonKey: env.supabaseAnonKey)
        let auth = self.authService
        self.autoBackup = AutoBackupCoordinator(sync: self.syncService, isSignedIn: { auth.currentUser != nil })
    }

    /// Migra idempotentemente todas las publicaciones locales, anotaciones, progresos y consumos de IA de invitado al nuevo ID de usuario registrado.
    public func migrateGuestData(to userID: String) async {
        guard !userID.isEmpty else { return }

        // 1. Migrar publicaciones huérfanas de invitado
        if let pubs = try? await publicationRepository.fetchAll() {
            for pub in pubs {
                if pub.ownerID == nil {
                    await PublicationRecordUpdates.update(pub.id, repository: publicationRepository) { $0.ownerID = userID }
                }
            }
        }

        // 2. Migrar consumos de IA huérfanos
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
            logger.error("Error al importar la presentación demo: \(error.localizedDescription)")
        }

        await ensureCoversExistIfNeeded()
    }

    /// Asegura que todas las publicaciones tengan una miniatura/portada válida de 1ª página en disco.
    public func ensureCoversExistIfNeeded() async {
        guard let pubs = try? await publicationRepository.fetchAll() else { return }
        let coverGen = CoverGenerator()

        for pub in pubs {
            let docURL = fileStorageService.publicationsDirectory.appendingPathComponent(pub.localFileName)
            if FileManager.default.fileExists(atPath: docURL.path) {
                let metadata = ExtractedMetadata(title: pub.title, author: pub.author)
                if let newCoverPath = try? await coverGen.generateCover(
                    for: docURL,
                    type: pub.publicationType,
                    sha256: pub.sha256,
                    metadata: metadata,
                    force: true
                ) {
                    await PublicationRecordUpdates.update(pub.id, repository: publicationRepository) { $0.coverPath = newCoverPath }
                }
            }
        }
    }

    /// Inicializador mock/in-memory para previews de SwiftUI y pruebas rápidas.
    public static var preview: AppDependencies {
        let container = ModelContainerFactory.create(isStoredInMemoryOnly: true)
        return AppDependencies(
            modelContainer: container,
            authService: MockAuthService(),
            institutionService: MockInstitutionService(),
            subscriptionService: MockSubscriptionService(),
            aiService: MockAIService(),
            syncService: MockSyncService(),
            analyticsService: MockAnalyticsService()
        )
    }
}
