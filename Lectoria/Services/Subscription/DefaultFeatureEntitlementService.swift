import Foundation

// MARK: - DefaultFeatureEntitlementService

/// Implementación por defecto del servicio de límites y derechos de acceso.
///
/// Consulta los repositorios de persistencia locales para calcular el consumo acumulado
/// y contrasta con los límites definidos en el entorno del sistema.
public final class DefaultFeatureEntitlementService: FeatureEntitlementService, @unchecked Sendable {
    private let publicationRepository: any PublicationRepository
    private let highlightRepository: any HighlightRepository
    private let noteRepository: any NoteRepository
    private let aiUsageRepository: any AIUsageRepository
    private let subscriptionService: any SubscriptionService
    
    public init(
        publicationRepository: any PublicationRepository,
        highlightRepository: any HighlightRepository,
        noteRepository: any NoteRepository,
        aiUsageRepository: any AIUsageRepository,
        subscriptionService: any SubscriptionService
    ) {
        self.publicationRepository = publicationRepository
        self.highlightRepository = highlightRepository
        self.noteRepository = noteRepository
        self.aiUsageRepository = aiUsageRepository
        self.subscriptionService = subscriptionService
    }
    
    public func getLimits() async -> PlanLimits {
        let hasPremium = subscriptionService.hasActiveSubscription
        
        if hasPremium {
            return PlanLimits(
                documentsUsed: (try? await publicationRepository.fetchAll().count) ?? 0,
                documentsLimit: Int.max,
                highlightsUsed: (try? await highlightRepository.fetchAll().count) ?? 0,
                highlightsLimit: Int.max,
                notesUsed: (try? await noteRepository.fetchAll().count) ?? 0,
                notesLimit: Int.max,
                aiActionsUsed: 0,
                aiActionsLimit: Int.max,
                hasPremiumAccess: true
            )
        }
        
        // Calcular consumos actuales del plan gratuito
        let docsCount = (try? await publicationRepository.fetchAll().count) ?? 0
        let hlCount = (try? await highlightRepository.fetchAll().count) ?? 0
        let notesCount = (try? await noteRepository.fetchAll().count) ?? 0
        
        var aiCount = 0
        if let usages = try? await aiUsageRepository.fetchAll() {
            let calendar = Calendar.current
            let now = Date()
            let month = calendar.component(.month, from: now)
            let year = calendar.component(.year, from: now)
            
            aiCount = usages.filter {
                let m = calendar.component(.month, from: $0.createdAt)
                let y = calendar.component(.year, from: $0.createdAt)
                return m == month && y == year
            }.count
        }
        
        let env = AppEnvironment.current()
        
        return PlanLimits(
            documentsUsed: docsCount,
            documentsLimit: env.freeDocumentLimit,
            highlightsUsed: hlCount,
            highlightsLimit: env.freeHighlightLimit,
            notesUsed: notesCount,
            notesLimit: env.freeNoteLimit,
            aiActionsUsed: aiCount,
            aiActionsLimit: env.freeAIActionsPerMonth,
            hasPremiumAccess: false
        )
    }
    
    public func canPerformAction(_ action: EntitlementAction) async -> Bool {
        let limits = await getLimits()
        
        switch action {
        case .importDocument:
            return limits.documentsUsed < limits.documentsLimit
        case .createHighlight:
            return limits.highlightsUsed < limits.highlightsLimit
        case .createNote:
            return limits.notesUsed < limits.notesLimit
        case .performAIAction:
            return limits.aiActionsUsed < limits.aiActionsLimit
        }
    }
}
