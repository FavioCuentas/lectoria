import Testing
import Foundation
import SwiftData
@testable import Lectoria

// MARK: - LocalAITests

@MainActor
struct LocalAITests {
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

    @Test("LocalAIAvailability status properties and messages")
    func testLocalAIAvailabilityStates() async throws {
        let availableState = LocalAIAvailability.available
        let hardwareState = LocalAIAvailability.unsupportedHardware
        let osState = LocalAIAvailability.unsupportedOS

        #expect(availableState.isAvailable == true)
        #expect(hardwareState.isAvailable == false)
        #expect(osState.isAvailable == false)

        #expect(availableState.userMessage.contains("IA local activa"))
        #expect(hardwareState.userMessage.contains("iPhone 11"))
    }

    @Test("Mandatory AI legal disclaimer presence")
    func testAIDisclaimerPresence() async throws {
        #expect(!AIDisclaimer.text.isEmpty)
        #expect(AIDisclaimer.text.contains("Las funciones de inteligencia artificial pueden generar errores"))
    }

    @Test("3 monthly AI quota limit for Free plan")
    func testThreeMonthlyAIQuotaLimitFreePlan() async throws {
        let entitlementService = dependencies.entitlementService
        let aiRepo = dependencies.aiUsageRepository
        mockSub.hasActiveSubscription = false

        // Check initial access on Free
        let initialAccess = await entitlementService.canAccess(.useLocalAI)
        #expect(initialAccess == .allowed)

        // Save 3 local AI usage records in the current month (Free quota)
        for _ in 1...3 {
            let usage = AIUsage(
                id: UUID(),
                operation: "explain",
                creditCost: 1,
                createdAt: Date()
            )
            try await aiRepo.save(usage)
        }

        // 4th operation should be blocked on Free with 3-quota limit message
        let fourthAccess = await entitlementService.canAccess(.useLocalAI)
        #expect(fourthAccess == .limitReached(message: "Has alcanzado tu límite mensual de 3 consultas de IA local en el plan Free."))
    }

    @Test("Local Translation requires Premium on Free plan")
    func testLocalTranslationRequiresPremium() async throws {
        let entitlementService = dependencies.entitlementService
        let translationService = LocalTranslationService(entitlementService: entitlementService)

        // Free plan blocks translation
        mockSub.hasActiveSubscription = false

        do {
            _ = try await translationService.translate(text: "Hello world", targetLanguage: "es")
            #expect(Bool(false), "Should have thrown requiresPremium error")
        } catch let error as LocalTranslationError {
            #expect(error.errorDescription?.contains("Requiera una suscripción activa") == true || error.errorDescription?.contains("Traducción Local Premium") == true)
        }

        // Premium plan allows translation
        mockSub.hasActiveSubscription = true
        let translated = try await translationService.translate(text: "Hello world", targetLanguage: "es")
        #expect(translated.contains("Traducción Local"))
        #expect(translated.contains("offline y privada"))
    }

    @Test("LocalDeviceAIService explain and summarize generate local offline outputs")
    func testLocalDeviceAIServiceOfflineOutputs() async throws {
        let localAIService = LocalDeviceAIService()

        let explanation = try await localAIService.explain(text: "La relatividad general describe la gravedad.", sessionToken: nil)
        #expect(explanation.contains("Explicación local"))
        #expect(explanation.contains("Apple NaturalLanguage"))

        let summary = try await localAIService.summarize(text: "El sol es una estrella. La tierra gira a su alrededor. La luna es un satélite.", sessionToken: nil)
        #expect(summary.contains("Resumen local"))
    }
}
