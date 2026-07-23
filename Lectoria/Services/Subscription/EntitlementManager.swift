import Foundation

// MARK: - EntitlementManager

/// Capa centralizada responsable de evaluar los 4 tipos de plan (`free`, `premium_annual`, `premium_lifetime`, `institutional`)
/// y aplicar los límites reales del sistema sin dispersar condicionales `isPremium` por las vistas.
public final class EntitlementManager: FeatureEntitlementService, @unchecked Sendable {
    private let publicationRepository: any PublicationRepository
    private let highlightRepository: any HighlightRepository
    private let noteRepository: any NoteRepository
    private let aiUsageRepository: any AIUsageRepository
    private let subscriptionService: any SubscriptionService
    private let authService: (any AuthService)?
    
    public init(
        publicationRepository: any PublicationRepository,
        highlightRepository: any HighlightRepository,
        noteRepository: any NoteRepository,
        aiUsageRepository: any AIUsageRepository,
        subscriptionService: any SubscriptionService,
        authService: (any AuthService)? = nil
    ) {
        self.publicationRepository = publicationRepository
        self.highlightRepository = highlightRepository
        self.noteRepository = noteRepository
        self.aiUsageRepository = aiUsageRepository
        self.subscriptionService = subscriptionService
        self.authService = authService
    }
    
    /// Evalúa y determina el `PlanType` activo del usuario.
    public func currentPlan() async -> PlanType {
        // 1. Comprobar si el usuario posee un acceso institucional verificado
        if let user = authService?.currentUser {
            if let userMetadata = user.email, isInstitutionalEmail(userMetadata) {
                return .institutional
            }
        }
        
        // 2. Comprobar si existe una suscripción o compra en StoreKit 2
        if subscriptionService.hasActiveSubscription {
            if let activeEnt = subscriptionService.activeEntitlement {
                if activeEnt.productID == "com.lectoria.premium.lifetime" {
                    return .premiumLifetime
                } else if activeEnt.productID == "com.lectoria.premium.yearly" || activeEnt.productID == "com.lectoria.premium.monthly" {
                    return .premiumAnnual
                }
            }
            return .premiumAnnual
        }
        
        // 3. De lo contrario, retorna Plan Gratuito
        return .free
    }
    
    public func getLimits() async -> PlanLimits {
        let plan = await currentPlan()
        
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
        
        if plan.isUnlimited {
            return PlanLimits(
                activePlan: plan,
                documentsUsed: docsCount,
                documentsLimit: Int.max,
                highlightsUsed: hlCount,
                highlightsLimit: Int.max,
                notesUsed: notesCount,
                notesLimit: Int.max,
                aiActionsUsed: aiCount,
                aiActionsLimit: Int.max
            )
        }
        
        let env = AppEnvironment.current()
        
        return PlanLimits(
            activePlan: plan,
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
        
        if limits.activePlan.isUnlimited {
            return true
        }
        
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
    
    // MARK: - Helpers
    
    private func isInstitutionalEmail(_ email: String) -> Bool {
        let lower = email.lowercased()
        let institutionalDomains = [".edu", ".edu.pe", ".edu.co", ".edu.mx", ".edu.ar", ".edu.cl", ".ac.uk"]
        return institutionalDomains.contains { lower.contains($0) }
    }
}
