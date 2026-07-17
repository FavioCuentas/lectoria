import Testing
import Foundation
import SwiftData
@testable import Lectoria

// MARK: - SyncTests

@MainActor
struct SyncTests {
    private let container: ModelContainer
    private let mockSync: MockSyncService
    private let dependencies: AppDependencies

    init() {
        // Inicializar contenedor in-memory para base de datos de test
        self.container = ModelContainerFactory.create(isStoredInMemoryOnly: true)
        
        // Inicializar servicios mock
        self.mockSync = MockSyncService()
        self.dependencies = AppDependencies(
            modelContainer: container,
            authService: MockAuthService(),
            subscriptionService: MockSubscriptionService(),
            aiService: MockAIService(),
            syncService: mockSync
        )
    }

    @Test("Track deletions in SyncOperation local queue")
    func trackDeletionsInQueue() async throws {
        let context = container.mainContext
        let bookmarkRepo = dependencies.bookmarkRepository
        
        // 1. Crear un marcador y guardarlo
        let id = UUID()
        let bookmark = Bookmark(
            id: id,
            publicationID: UUID(),
            anchor: "{page: 1}",
            title: "Marcador de test"
        )
        try await bookmarkRepo.save(bookmark)
        
        // 2. Verificar que no hay operaciones de eliminación en cola
        var ops = try context.fetch(FetchDescriptor<SyncOperationModel>())
        #expect(ops.isEmpty)
        
        // 3. Eliminar el marcador
        try await bookmarkRepo.delete(id: id)
        
        // 4. Validar que la eliminación se registró en la cola de sincronización local
        ops = try context.fetch(FetchDescriptor<SyncOperationModel>())
        #expect(ops.count == 1)
        #expect(ops.first?.entityType == "bookmark")
        #expect(ops.first?.entityID == id.uuidString)
        #expect(ops.first?.action == "delete")
    }

    @Test("Sync lifecycle with MockSyncService")
    func syncLifecycle() async throws {
        let syncService = dependencies.syncService
        
        // 1. Validar estado inicial
        #expect(syncService.isSyncing == false)
        #expect(syncService.lastSyncedAt == nil)
        
        // 2. Ejecutar sincronización
        try await syncService.syncAll()
        
        // 3. Verificar estado posterior a la sincronización
        #expect(syncService.isSyncing == false)
        #expect(syncService.lastSyncedAt != nil)
    }
}
