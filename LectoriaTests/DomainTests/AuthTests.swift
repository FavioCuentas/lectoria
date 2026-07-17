import Testing
import Foundation
import SwiftData
@testable import Lectoria

// MARK: - AuthTests

@MainActor
struct AuthTests {
    private let container: ModelContainer
    private let dependencies: AppDependencies
    private let mockAuth: MockAuthService

    init() {
        // Inicializar contenedor in-memory para base de datos de test
        let schema = Schema([
            PublicationModel.self,
            BookmarkModel.self,
            HighlightModel.self,
            NoteModel.self,
            ReadingProgressModel.self,
            ReadingSessionModel.self,
            AIUsageModel.self,
            SubscriptionEntitlementModel.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        self.container = try! ModelContainer(for: schema, configurations: config)
        
        // Inicializar dependencias del negocio con el mock de autenticación
        self.mockAuth = MockAuthService()
        self.dependencies = AppDependencies(modelContainer: container, authService: mockAuth)
    }

    @Test("Sign in with Apple and sign out lifecycle")
    func signInAndSignOutLifecycle() async throws {
        #expect(dependencies.authService.currentUser == nil)
        #expect(dependencies.authService.sessionToken == nil)

        // 1. Iniciar sesión
        try await dependencies.authService.signInWithApple(
            identityToken: "dummy_apple_jwt",
            email: "test@lectoria.app",
            fullName: "Juan Pérez"
        )

        let user = dependencies.authService.currentUser
        #expect(user != nil)
        #expect(user?.email == "test@lectoria.app")
        #expect(user?.fullName == "Juan Pérez")
        #expect(dependencies.authService.sessionToken == "mock_session_token_xyz")

        // 2. Cerrar sesión
        try await dependencies.authService.signOut()
        #expect(dependencies.authService.currentUser == nil)
        #expect(dependencies.authService.sessionToken == nil)
    }

    @Test("Guest data migration to logged-in user account")
    func guestDataMigration() async throws {
        let pubRepo = dependencies.publicationRepository
        let aiRepo = dependencies.aiUsageRepository

        // 1. Guardar publicaciones y consumos locales sin dueño (invitado)
        let guestPub = PublicationRecord(
            id: UUID(),
            ownerID: nil, // Invitado
            title: "Libro de Invitado",
            author: "Autor Anónimo",
            publicationType: .epub,
            localFileName: "guest_book.epub",
            mimeType: "application/epub+zip",
            fileSize: 1024,
            sha256: "dummy_sha"
        )
        try await pubRepo.save(guestPub)

        let guestAIUsage = AIUsage(
            id: UUID(),
            userID: nil, // Invitado
            operation: "explicar",
            creditCost: 1
        )
        try await aiRepo.save(guestAIUsage)

        // Verificar estado inicial en la base de datos
        let initialPubs = try await pubRepo.fetchAll()
        #expect(initialPubs.count == 1)
        #expect(initialPubs.first?.ownerID == nil)

        let initialUsages = try await aiRepo.fetchAll()
        #expect(initialUsages.count == 1)
        #expect(initialUsages.first?.userID == nil)

        // 2. Iniciar sesión y migrar datos
        try await dependencies.authService.signInWithApple(
            identityToken: "jwt_token",
            email: "test@lectoria.app",
            fullName: "Usuario Test"
        )
        
        let userID = dependencies.authService.currentUser!.id
        await dependencies.migrateGuestData(to: userID)

        // 3. Verificar que los registros locales ahora pertenecen al usuario autenticado
        let migratedPubs = try await pubRepo.fetchAll()
        #expect(migratedPubs.count == 1)
        #expect(migratedPubs.first?.ownerID == userID)

        let migratedUsages = try await aiRepo.fetchAll()
        #expect(migratedUsages.count == 1)
        #expect(migratedUsages.first?.userID == userID)
    }
}
