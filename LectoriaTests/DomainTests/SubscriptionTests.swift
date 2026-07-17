import Testing
import Foundation
import SwiftData
@testable import Lectoria

// MARK: - SubscriptionTests

@MainActor
struct SubscriptionTests {
    private let container: ModelContainer
    private let mockSub: MockSubscriptionService
    private let dependencies: AppDependencies

    init() {
        // Inicializar contenedor in-memory para base de datos de test
        self.container = ModelContainerFactory.create(isStoredInMemoryOnly: true)
        
        // Inicializar servicios mock
        self.mockSub = MockSubscriptionService()
        self.dependencies = AppDependencies(
            modelContainer: container,
            authService: MockAuthService(),
            subscriptionService: mockSub
        )
    }

    @Test("Limits enforcement for free plan")
    func freePlanLimits() async throws {
        let entitlementService = dependencies.entitlementService
        let pubRepo = dependencies.publicationRepository
        
        // 1. Verificar estado inicial bajo plan gratuito
        mockSub.hasActiveSubscription = false
        var limits = await entitlementService.getLimits()
        #expect(limits.hasPremiumAccess == false)
        #expect(limits.documentsLimit == 5)
        #expect(limits.highlightsLimit == 30)
        #expect(limits.notesLimit == 15)
        #expect(limits.aiActionsLimit == 3)
        
        #expect(await entitlementService.canPerformAction(.importDocument) == true)
        
        // 2. Llenar la base de datos hasta alcanzar el límite de 5 documentos
        for i in 1...5 {
            let pub = PublicationRecord(
                id: UUID(),
                title: "Libro \(i)",
                publicationType: .epub,
                localFileName: "book_\(i).epub",
                mimeType: "application/epub+zip",
                fileSize: 100,
                sha256: "sha_\(i)"
            )
            try await pubRepo.save(pub)
        }
        
        // 3. Validar que canPerformAction(.importDocument) ahora sea false
        limits = await entitlementService.getLimits()
        #expect(limits.documentsUsed == 5)
        #expect(await entitlementService.canPerformAction(.importDocument) == false)
    }

    @Test("Limits enforcement for premium plan")
    func premiumPlanLimits() async throws {
        let entitlementService = dependencies.entitlementService
        let pubRepo = dependencies.publicationRepository
        
        // 1. Activar suscripción premium simulada
        mockSub.hasActiveSubscription = true
        var limits = await entitlementService.getLimits()
        #expect(limits.hasPremiumAccess == true)
        #expect(limits.documentsLimit == Int.max)
        
        // 2. Guardar 5 publicaciones
        for i in 1...5 {
            let pub = PublicationRecord(
                id: UUID(),
                title: "Libro \(i)",
                publicationType: .epub,
                localFileName: "book_\(i).epub",
                mimeType: "application/epub+zip",
                fileSize: 100,
                sha256: "sha_\(i)"
            )
            try await pubRepo.save(pub)
        }
        
        // 3. Validar que la importación siga habilitada sin límites
        limits = await entitlementService.getLimits()
        #expect(limits.documentsUsed == 5)
        #expect(await entitlementService.canPerformAction(.importDocument) == true)
    }

    @Test("Mock subscription purchase and restoration lifecycle")
    func purchaseAndRestoreLifecycle() async throws {
        #expect(dependencies.subscriptionService.hasActiveSubscription == false)
        
        // 1. Simular restauración
        try await dependencies.subscriptionService.restorePurchases()
        #expect(dependencies.subscriptionService.hasActiveSubscription == true)
        #expect(dependencies.subscriptionService.activeEntitlement?.productID == "com.lectoria.premium.monthly")
    }
}
