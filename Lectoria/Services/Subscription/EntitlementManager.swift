import Foundation

// MARK: - EntitlementManager

/// Capa centralizada responsable de evaluar los niveles de acceso de Lectoría (`free`, `premium_founder`, `premium_regular`, `lifetime`, `institutional`),
/// aplicar las reglas de prioridad de fuentes de autorización y hacer valer los feature gates.
public final class EntitlementManager: EntitlementService, @unchecked Sendable {
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

    // MARK: - EntitlementService Implementation

    /// Obtiene la fuente de verdad consolidada de los entitlements activos evaluando la prioridad de fuentes.
    public func currentEntitlements() async -> Entitlements {
        let activeSources = await detectActiveSources()
        let primarySource = resolveHighestPrioritySource(activeSources)
        let tier = primarySource.equivalentTier

        let expDate: Date?
        if let activeEnt = subscriptionService.activeEntitlement {
            expDate = activeEnt.expirationDate
        } else {
            expDate = nil
        }

        return Entitlements.defaultForTier(tier, expirationDate: expDate)
    }

    /// Fuerza la actualización de las fuentes de entitlements desde StoreKit y auth.
    public func refreshEntitlements() async throws {
        try await subscriptionService.restorePurchases()
    }

    /// Resuelve la fuente de mayor prioridad dada una lista de fuentes.
    public func resolveHighestPrioritySource(_ sources: [EntitlementSource]) -> EntitlementSource {
        guard !sources.isEmpty else { return .free }
        return sources.min(by: { $0.priority < $1.priority }) ?? .free
    }

    /// Evalúa si el usuario puede acceder a una característica tipada de la aplicación.
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
                    return .limitReached(message: String(localized: "Has alcanzado el límite de 5 documentos activos en el plan Free.", comment: "Import limit message"))
                }
            }
            return .allowed

        case .activeDocumentCount(let currentActive):
            if let maxDocs = entitlements.maxActiveDocuments, currentActive >= maxDocs {
                return .limitReached(message: String(localized: "Se ha alcanzado el número máximo de documentos activos permitidos para tu plan.", comment: "Active docs limit message"))
            }
            return .allowed

        case .createHighlight, .createNote:
            return .allowed

        case .exportAdvanced:
            return entitlements.canUseAdvancedExport ? .allowed : .requiresPremium

        case .viewAdvancedStatistics:
            return entitlements.canUseAdvancedStatistics ? .allowed : .requiresPremium

        case .useLocalAI:
            if !entitlements.canUseLocalAI {
                return .requiresPremium
            }
            if let limit = entitlements.monthlyAILimit {
                let used = await fetchMonthlyAIUsageCount()
                if used >= limit {
                    return .limitReached(message: String(localized: "Has alcanzado tu límite mensual de 10 consultas de IA local en el plan Free.", comment: "AI limit message"))
                }
            }
            return .allowed

        case .useLocalTranslation:
            return entitlements.canUseLocalTranslation ? .allowed : .requiresPremium

        case .manageDevices:
            return entitlements.canManageDevices ? .allowed : .requiresPremium

        case .accessInstitutionalLibrary:
            return entitlements.canUseInstitutionalLibrary ? .allowed : .institutionalOnly
        }
    }

    // MARK: - FeatureEntitlementService Backwards Compatibility

    public func currentPlan() async -> SubscriptionTier {
        let entitlements = await currentEntitlements()
        return entitlements.tier
    }

    public func getLimits() async -> PlanLimits {
        let entitlements = await currentEntitlements()
        let plan = entitlements.tier

        let docsCount = (try? await publicationRepository.fetchAll().count) ?? 0
        let hlCount = (try? await highlightRepository.fetchAll().count) ?? 0
        let notesCount = (try? await noteRepository.fetchAll().count) ?? 0
        let aiCount = await fetchMonthlyAIUsageCount()

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

        return PlanLimits(
            activePlan: plan,
            documentsUsed: docsCount,
            documentsLimit: entitlements.maxActiveDocuments ?? 5,
            highlightsUsed: hlCount,
            highlightsLimit: Int.max,
            notesUsed: notesCount,
            notesLimit: Int.max,
            aiActionsUsed: aiCount,
            aiActionsLimit: entitlements.monthlyAILimit ?? 10
        )
    }

    public func canPerformAction(_ action: EntitlementAction) async -> Bool {
        switch action {
        case .importDocument:
            let result = await canAccess(.importDocument(format: .epub))
            return result == .allowed
        case .createHighlight:
            return true
        case .createNote:
            return true
        case .performAIAction:
            let result = await canAccess(.useLocalAI)
            return result == .allowed
        }
    }

    // MARK: - Private Resolution Helpers

    private func detectActiveSources() async -> [EntitlementSource] {
        var sources: [EntitlementSource] = []

        // 1. Comprobar compras en StoreKit 2
        if subscriptionService.hasActiveSubscription {
            if let activeEnt = subscriptionService.activeEntitlement {
                if activeEnt.productID == "com.lectoria.premium.lifetime" {
                    sources.append(.lifetime)
                } else if activeEnt.productID == "com.lectoria.premium.founder" {
                    sources.append(.appleSubscription(tier: .premiumFounder))
                } else if activeEnt.productID == "com.lectoria.premium.yearly" || activeEnt.productID == "com.lectoria.premium.monthly" {
                    sources.append(.appleSubscription(tier: .premiumRegular))
                } else {
                    sources.append(.appleSubscription(tier: .premiumRegular))
                }
            } else {
                sources.append(.appleSubscription(tier: .premiumRegular))
            }
        }

        // 2. Comprobar licencias institucionales
        if let user = authService?.currentUser, let email = user.email {
            if isInstitutionalEmail(email) {
                sources.append(.institutional(licenseID: UUID()))
            }
        }

        // 3. Fallback a plan Free
        if sources.isEmpty {
            sources.append(.free)
        }

        return sources
    }

    private func fetchMonthlyAIUsageCount() async -> Int {
        guard let usages = try? await aiUsageRepository.fetchAll() else { return 0 }
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)

        return usages.filter {
            let m = calendar.component(.month, from: $0.createdAt)
            let y = calendar.component(.year, from: $0.createdAt)
            return m == month && y == year
        }.count
    }

    private func isInstitutionalEmail(_ email: String) -> Bool {
        let lower = email.lowercased()
        let institutionalDomains = [".edu", ".edu.pe", ".edu.co", ".edu.mx", ".edu.ar", ".edu.cl", ".ac.uk", ".edu.bo"]
        return institutionalDomains.contains { lower.contains($0) }
    }
}
