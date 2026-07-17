import Testing
import Foundation
import SwiftData
@testable import Lectoria

// MARK: - AITests

@MainActor
struct AITests {
    private let container: ModelContainer
    private let mockAI: MockAIService
    private let dependencies: AppDependencies

    init() {
        // Inicializar contenedor in-memory para base de datos de test
        self.container = ModelContainerFactory.create(isStoredInMemoryOnly: true)
        
        // Inicializar servicios mock
        self.mockAI = MockAIService()
        self.dependencies = AppDependencies(
            modelContainer: container,
            authService: MockAuthService(),
            subscriptionService: MockSubscriptionService(),
            aiService: mockAI
        )
    }

    @Test("AI Consent tracking and toggling")
    func consentTracking() async throws {
        let aiService = dependencies.aiService
        
        // 1. Validar estado por defecto
        #expect(aiService.hasConsentedToAI == false)
        
        // 2. Dar consentimiento
        aiService.hasConsentedToAI = true
        #expect(aiService.hasConsentedToAI == true)
        
        // 3. Revocar consentimiento
        aiService.hasConsentedToAI = false
        #expect(aiService.hasConsentedToAI == false)
    }

    @Test("AI Service mock responses and limits tracking")
    func aiOperationsAndLimits() async throws {
        let aiService = dependencies.aiService
        let entitlementService = dependencies.entitlementService
        let usageRepo = dependencies.aiUsageRepository
        
        // 1. Dar consentimiento
        aiService.hasConsentedToAI = true
        
        // 2. Verificar límites iniciales del plan gratuito (3 usos permitidos)
        var limits = await entitlementService.getLimits()
        #expect(limits.aiActionsUsed == 0)
        #expect(limits.aiActionsLimit == 3)
        #expect(await entitlementService.canPerformAction(.performAIAction) == true)
        
        // 3. Realizar una petición de IA
        let rawText = "Lector inteligente de documentos"
        let explanation = try await aiService.explain(text: rawText, sessionToken: nil)
        #expect(explanation.contains(rawText))
        
        // 4. Registrar consumo (simulado igual que la hoja de respuesta)
        let usage = AIUsage(
            id: UUID(),
            userID: nil,
            operation: "explain",
            creditCost: 1
        )
        try await usageRepo.save(usage)
        
        // 5. Verificar que se ha incrementado el consumo de créditos
        limits = await entitlementService.getLimits()
        #expect(limits.aiActionsUsed == 1)
        #expect(await entitlementService.canPerformAction(.performAIAction) == true)
        
        // 6. Registrar dos consumos adicionales para llegar al límite
        try await usageRepo.save(AIUsage(id: UUID(), userID: nil, operation: "simplify", creditCost: 1))
        try await usageRepo.save(AIUsage(id: UUID(), userID: nil, operation: "translate", creditCost: 1))
        
        limits = await entitlementService.getLimits()
        #expect(limits.aiActionsUsed == 3)
        
        // 7. Validar que la cuota de IA gratuita está bloqueada
        #expect(await entitlementService.canPerformAction(.performAIAction) == false)
    }
}
