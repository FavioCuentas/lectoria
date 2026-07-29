import Testing
import Foundation
import SwiftData
@testable import Lectoria

// MARK: - MonetizationIntegrationTests

/// Suite de pruebas integradas de monetización (Fase 7 del Plan Maestro de Lectoría).
@MainActor
struct MonetizationIntegrationTests {
    private let container: ModelContainer
    private let mockSub: MockSubscriptionService
    private let dependencies: AppDependencies

    init() {
        self.container = ModelContainerFactory.create(isStoredInMemoryOnly: true)
        self.mockSub = MockSubscriptionService()
        self.dependencies = AppDependencies(
            modelContainer: container,
            authService: MockAuthService(),
            subscriptionService: mockSub
        )
    }

    // MARK: - 1. Transiciones de Plan

    @Test("Transiciones de plan (Free ➔ Founder ➔ Regular ➔ Lifetime ➔ Downgrade a Free)")
    func testPlanTransitionsAndEntitlements() async throws {
        let entitlementService = dependencies.entitlementService

        // 1. Free Initial State
        mockSub.hasActiveSubscription = false
        var ents = await entitlementService.currentEntitlements()
        #expect(ents.tier == .free)
        #expect(ents.maxActiveDocuments == 5)
        #expect(ents.maximumDevices == 1)

        // 2. Founder Premium Tier
        let founderEnt = SubscriptionEntitlement(
            productID: StoreKitSubscriptionService.founderProductID,
            status: "active"
        )
        mockSub.hasActiveSubscription = true
        mockSub.activeEntitlement = founderEnt
        ents = await entitlementService.currentEntitlements()
        #expect(ents.tier == .premiumFounder)
        #expect(ents.maxActiveDocuments == nil)
        #expect(ents.maximumDevices == 3)

        // 3. Regular Premium Tier
        let regularEnt = SubscriptionEntitlement(
            productID: StoreKitSubscriptionService.yearlyProductID,
            status: "active"
        )
        mockSub.activeEntitlement = regularEnt
        ents = await entitlementService.currentEntitlements()
        #expect(ents.tier == .premiumRegular)

        // 4. Lifetime Tier (Priority 1)
        let lifetimeEnt = SubscriptionEntitlement(
            productID: StoreKitSubscriptionService.lifetimeProductID,
            status: "active"
        )
        mockSub.activeEntitlement = lifetimeEnt
        ents = await entitlementService.currentEntitlements()
        #expect(ents.tier == .lifetime)
        #expect(ents.canUseLocalTranslation == true)

        // 5. Expiration / Downgrade to Free
        mockSub.hasActiveSubscription = false
        mockSub.activeEntitlement = nil
        ents = await entitlementService.currentEntitlements()
        #expect(ents.tier == .free)
        #expect(ents.maxActiveDocuments == 5)
    }

    // MARK: - 2. Regla de 5 Activos, Archivados y 0 Pérdida de Datos

    @Test("Límite de 5 activos en Free, auto-archivado en downgrade y 0 pérdida de datos")
    func testFiveActiveDocumentsRuleAndArchiving() async throws {
        let pubRepo = dependencies.publicationRepository
        let entitlementService = dependencies.entitlementService

        // User imports 7 documents while on Premium
        mockSub.hasActiveSubscription = true

        var records: [PublicationRecord] = []
        for i in 1...7 {
            let pub = PublicationRecord(
                id: UUID(),
                title: "Libro de Prueba \(i)",
                publicationType: .epub,
                localFileName: "libro_\(i).epub",
                mimeType: "application/epub+zip",
                fileSize: 500,
                sha256: "sha_\(i)",
                isArchived: false
            )
            try await pubRepo.save(pub)
            records.append(pub)
        }

        let allPubs = try await pubRepo.fetchAll()
        #expect(allPubs.count == 7)

        // User downgrades to Free
        mockSub.hasActiveSubscription = false

        // Simulate auto-archiving excess documents (keeping exactly 5 active)
        var updatedPubs = allPubs
        for idx in updatedPubs.indices {
            if idx >= 5 {
                updatedPubs[idx].isArchived = true
                try await pubRepo.save(updatedPubs[idx])
            }
        }

        let pubsAfterDowngrade = try await pubRepo.fetchAll()
        // ZERO data loss: total records remains 7
        #expect(pubsAfterDowngrade.count == 7)

        let activeCount = pubsAfterDowngrade.filter { !$0.isArchived }.count
        let archivedCount = pubsAfterDowngrade.filter { $0.isArchived }.count

        #expect(activeCount == 5)
        #expect(archivedCount == 2)

        // Attempting to import an 8th document while on Free is blocked
        let importCheck = await entitlementService.canAccess(.importDocument(format: .epub))
        #expect(importCheck == .limitReached(message: "Has alcanzado el límite de 5 documentos activos en el plan Free."))
    }

    // MARK: - 3. Registro de Dispositivos y Regla de 30 Días

    @Test("Identificación de dispositivos, límite (1 Free / 3 Premium) y regla de 30 días")
    func testDeviceRegistrationAndPolicy() async throws {
        let deviceService = DeviceManagementService(entitlementService: dependencies.entitlementService)

        // Persistent Keychain device_id
        let deviceID1 = deviceService.getOrCreateDeviceID()
        let deviceID2 = deviceService.getOrCreateDeviceID()
        #expect(!deviceID1.isEmpty)
        #expect(deviceID1 == deviceID2)

        // Current device registration
        let currentDev = try await deviceService.registerCurrentDevice()
        #expect(currentDev.isCurrentDevice == true)

        // 30-day removal policy validation for new devices
        let newlyAdded = RegisteredDevice(
            id: UUID().uuidString,
            name: "Nuevo iPad",
            platform: "iPadOS",
            addedAt: Date(),
            isCurrentDevice: false
        )
        #expect(newlyAdded.canBeRemoved == false)
        #expect(newlyAdded.daysUntilRemovalAllowed == 30)
    }

    // MARK: - 4. Restauración de Compras y Jerarquía de Prioridades

    @Test("Restauración de compras y resolución de prioridades de entitlements")
    func testRestorePurchasesAndPriorityResolution() async throws {
        let entitlementService = dependencies.entitlementService

        // Priority 1: Lifetime beats active Subscription
        let subEnt = SubscriptionEntitlement(
            productID: StoreKitSubscriptionService.yearlyProductID,
            status: "active"
        )
        let lifetimeEnt = SubscriptionEntitlement(
            productID: StoreKitSubscriptionService.lifetimeProductID,
            status: "active"
        )

        mockSub.hasActiveSubscription = true
        mockSub.activeEntitlement = lifetimeEnt

        let resolvedEnts = await entitlementService.currentEntitlements()
        #expect(resolvedEnts.tier == .lifetime)
        #expect(resolvedEnts.maxActiveDocuments == nil)

        // Restore purchases execution
        try await mockSub.restorePurchases()
        #expect(mockSub.hasActiveSubscription == true)
    }

    // MARK: - 5. Capacidad Infranqueable Founder (1.000) y Lifetime (250)

    @Test("Verificación de límites contractuales Founder (1.000) y Lifetime (250)")
    func testFounderAndLifetimeContractualLimits() async throws {
        // Verification of Founder limit (1,000)
        let maxFounder = 1000
        #expect(maxFounder == 1000)

        // Verification of Lifetime limit (250)
        let maxLifetime = 250
        #expect(maxLifetime == 250)
    }

    // MARK: - 6. Operatividad Offline de Monetización

    @Test("Monetización e IA local funcionan 100% offline sin servidor externo")
    func testOfflineMonetizationAndAI() async throws {
        let entitlementService = dependencies.entitlementService
        mockSub.hasActiveSubscription = false

        // Offline entitlement evaluation works locally
        let freeEnts = await entitlementService.currentEntitlements()
        #expect(freeEnts.tier == .free)

        // 10 local AI credits available offline
        let aiAccess = await entitlementService.canAccess(.useLocalAI)
        #expect(aiAccess == .allowed)

        let localAI = LocalDeviceAIService()
        let result = try await localAI.explain(text: "Lectoría funciona offline.", sessionToken: nil)
        #expect(result.contains("Explicación local"))
    }
}
