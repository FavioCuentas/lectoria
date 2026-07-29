import Foundation

// MARK: - DefaultFeatureEntitlementService

/// Implementación por defecto del servicio de límites y derechos de acceso.
///
/// Consulta los repositorios de persistencia locales para calcular el consumo acumulado
/// y contrasta con los límites definidos en el entorno del sistema.
public final class DefaultFeatureEntitlementService: EntitlementService, @unchecked Sendable {
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

    public func currentEntitlements() async -> Entitlements {
        let tier: SubscriptionTier = subscriptionService.hasActiveSubscription ? .premiumRegular : .free
        return Entitlements.defaultForTier(tier)
    }

    public func refreshEntitlements() async throws {
        try await subscriptionService.restorePurchases()
    }

    public func resolveHighestPrioritySource(_ sources: [EntitlementSource]) -> EntitlementSource {
        guard !sources.isEmpty else { return .free }
        return sources.min(by: { $0.priority < $1.priority }) ?? .free
    }

    public func canAccess(_ feature: AppFeature) async -> FeatureAccessResult {
        let entitlements = await currentEntitlements()

        switch feature {
        case .importDocument(let format):
            if !entitlements.allowedFormats.contains(format) {
                return .requiresPremium
            }
            if let maxDocs = entitlements.maxActiveDocuments {
                let currentDocs = (try? await publicationRepository.fetchAll().count) ?? 0
                if currentDocs >= maxDocs {
                    return .limitReached(message: String(localized: "Límite de documentos activos alcanzado.", comment: "Limit reached"))
                }
            }
            return .allowed

        case .activeDocumentCount(let currentActive):
            if let maxDocs = entitlements.maxActiveDocuments, currentActive >= maxDocs {
                return .limitReached(message: String(localized: "Límite de documentos alcanzado.", comment: "Limit reached"))
            }
            return .allowed

        case .createHighlight, .createNote:
            return .allowed

        case .exportAdvanced:
            return entitlements.canUseAdvancedExport ? .allowed : .requiresPremium

        case .viewAdvancedStatistics:
            return entitlements.canUseAdvancedStatistics ? .allowed : .requiresPremium

        case .useLocalAI:
            return entitlements.canUseLocalAI ? .allowed : .requiresPremium

        case .useLocalTranslation:
            return entitlements.canUseLocalTranslation ? .allowed : .requiresPremium

        case .manageDevices:
            return entitlements.canManageDevices ? .allowed : .requiresPremium

        case .accessInstitutionalLibrary:
            return entitlements.canUseInstitutionalLibrary ? .allowed : .institutionalOnly
        }
    }

    public func currentPlan() async -> PlanType {
        if subscriptionService.hasActiveSubscription {
            return .premiumRegular
        }
        return .free
    }

    public func getLimits() async -> PlanLimits {
        let hasPremium = subscriptionService.hasActiveSubscription
        let activePlan: PlanType = hasPremium ? .premiumRegular : .free
        
        if hasPremium {
            return PlanLimits(
                activePlan: activePlan,
                documentsUsed: (try? await publicationRepository.fetchAll().count) ?? 0,
                documentsLimit: Int.max,
                highlightsUsed: (try? await highlightRepository.fetchAll().count) ?? 0,
                highlightsLimit: Int.max,
                notesUsed: (try? await noteRepository.fetchAll().count) ?? 0,
                notesLimit: Int.max,
                aiActionsUsed: 0,
                aiActionsLimit: Int.max
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
            activePlan: activePlan,
            documentsUsed: docsCount,
            documentsLimit: env.freeDocumentLimit,
            highlightsUsed: hlCount,
            highlightsLimit: env.freeHighlightLimit,
            notesUsed: notesCount,
            notesLimit: env.freeNoteLimit,
            aiActionsUsed: aiCount,
            aiActionsLimit: env.freeAIActionsPerMonth
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
