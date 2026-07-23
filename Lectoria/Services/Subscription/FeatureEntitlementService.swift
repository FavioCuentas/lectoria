import Foundation

// MARK: - EntitlementAction

/// Acciones del negocio que están sujetas a límites del plan (gratuito vs premium/institucional).
public enum EntitlementAction: Sendable {
    case importDocument
    case createHighlight
    case createNote
    case performAIAction
}

// MARK: - PlanLimits

/// Resume el consumo del usuario y los límites vigentes de su plan de suscripción o acceso institucional.
public struct PlanLimits: Sendable, Hashable {
    public let activePlan: PlanType
    
    public let documentsUsed: Int
    public let documentsLimit: Int
    
    public let highlightsUsed: Int
    public let highlightsLimit: Int
    
    public let notesUsed: Int
    public let notesLimit: Int
    
    public let aiActionsUsed: Int
    public let aiActionsLimit: Int
    
    public var hasPremiumAccess: Bool {
        activePlan.isUnlimited
    }
    
    public init(
        activePlan: PlanType,
        documentsUsed: Int,
        documentsLimit: Int,
        highlightsUsed: Int,
        highlightsLimit: Int,
        notesUsed: Int,
        notesLimit: Int,
        aiActionsUsed: Int,
        aiActionsLimit: Int
    ) {
        self.activePlan = activePlan
        self.documentsUsed = documentsUsed
        self.documentsLimit = documentsLimit
        self.highlightsUsed = highlightsUsed
        self.highlightsLimit = highlightsLimit
        self.notesUsed = notesUsed
        self.notesLimit = notesLimit
        self.aiActionsUsed = aiActionsUsed
        self.aiActionsLimit = aiActionsLimit
    }
    
    // Constructor de compatibilidad previa
    public init(
        documentsUsed: Int,
        documentsLimit: Int,
        highlightsUsed: Int,
        highlightsLimit: Int,
        notesUsed: Int,
        notesLimit: Int,
        aiActionsUsed: Int,
        aiActionsLimit: Int,
        hasPremiumAccess: Bool
    ) {
        self.activePlan = hasPremiumAccess ? .premiumAnnual : .free
        self.documentsUsed = documentsUsed
        self.documentsLimit = documentsLimit
        self.highlightsUsed = highlightsUsed
        self.highlightsLimit = highlightsLimit
        self.notesUsed = notesUsed
        self.notesLimit = notesLimit
        self.aiActionsUsed = aiActionsUsed
        self.aiActionsLimit = aiActionsLimit
    }
}

// MARK: - FeatureEntitlementService

/// Contrato para evaluar límites de uso y derechos de acceso del usuario de forma centralizada.
public protocol FeatureEntitlementService: Sendable {
    /// Obtiene el tipo de plan activo actualmente (.free, .premiumAnnual, .premiumLifetime, .institutional).
    func currentPlan() async -> PlanType

    /// Evalúa si el usuario puede realizar una acción según su nivel de plan y consumo actual.
    func canPerformAction(_ action: EntitlementAction) async -> Bool
    
    /// Obtiene una vista detallada del consumo y los límites aplicables.
    func getLimits() async -> PlanLimits
}
