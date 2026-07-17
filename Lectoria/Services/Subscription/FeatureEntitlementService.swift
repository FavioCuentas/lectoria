import Foundation

// MARK: - EntitlementAction

/// Acciones del negocio que están sujetas a límites del plan (gratuito vs premium).
public enum EntitlementAction: Sendable {
    case importDocument
    case createHighlight
    case createNote
    case performAIAction
}

// MARK: - PlanLimits

/// Resume el consumo del usuario y los límites vigentes de su plan de suscripción.
public struct PlanLimits: Sendable, Hashable {
    public let documentsUsed: Int
    public let documentsLimit: Int
    
    public let highlightsUsed: Int
    public let highlightsLimit: Int
    
    public let notesUsed: Int
    public let notesLimit: Int
    
    public let aiActionsUsed: Int
    public let aiActionsLimit: Int
    
    public let hasPremiumAccess: Bool
    
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
        self.documentsUsed = documentsUsed
        self.documentsLimit = documentsLimit
        self.highlightsUsed = highlightsUsed
        self.highlightsLimit = highlightsLimit
        self.notesUsed = notesUsed
        self.notesLimit = notesLimit
        self.aiActionsUsed = aiActionsUsed
        self.aiActionsLimit = aiActionsLimit
        self.hasPremiumAccess = hasPremiumAccess
    }
}

// MARK: - FeatureEntitlementService

/// Contrato para evaluar límites de uso y derechos de acceso del usuario de forma centralizada.
public protocol FeatureEntitlementService: Sendable {
    /// Evalúa si el usuario puede realizar una acción según su nivel de plan y consumo actual.
    func canPerformAction(_ action: EntitlementAction) async -> Bool
    
    /// Obtiene una vista detallada del consumo y los límites aplicables.
    func getLimits() async -> PlanLimits
}
